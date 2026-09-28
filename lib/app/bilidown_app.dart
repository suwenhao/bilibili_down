import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

import '../core/database/database_providers.dart';
import '../core/logging/app_debug_log.dart';
import '../core/logging/crash_recovery_service.dart';
import '../core/logging/diagnostic_log_export_service.dart';
import '../core/platform/platform_providers.dart';
import '../core/sound/app_tap_sound_region.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_accent_controller.dart';
import '../core/theme/theme_mode_controller.dart';
import '../core/widgets/app_snack_bar.dart';
import '../features/user/application/account_controller.dart';
import '../features/downloads/application/lifecycle/automatic_shutdown_controller.dart';
import '../features/downloads/application/lifecycle/background_download_recovery.dart';
import '../features/downloads/application/runtime/download_task_scheduler.dart';
import '../features/downloads/application/ui_state/download_sound_observer.dart';
import '../features/onboarding/application/onboarding_controller.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/parser/application/clipboard_monitor_controller.dart';
import '../features/parser/application/parser_controller.dart';
import '../features/settings/application/app_settings_controller.dart';
import '../features/settings/application/download_directory_selection_service.dart';
import '../features/settings/domain/app_settings.dart';
import 'app_router.dart';
import 'app_overlays.dart';
import 'desktop_runtime_access_service.dart';
import 'desktop_shutdown_coordinator.dart';
import 'desktop_tray_controller.dart';

/// BiliDown 应用根组件。
final class BiliDownApp extends ConsumerStatefulWidget {
  /// 创建应用根组件。
  const BiliDownApp({super.key});

  /// 创建负责应用级资源与窗口生命周期的状态。
  @override
  ConsumerState<BiliDownApp> createState() => _BiliDownAppState();
}

/// 管理桌面关闭请求，并在窗口销毁前等待下载资源释放。
final class _BiliDownAppState extends ConsumerState<BiliDownApp> {
  /// 保存唯一退出任务，防止用户连续点击关闭导致重复释放资源。
  Future<void>? _closeFuture;

  /// 是否正在执行不可中断的桌面资源清理流程。
  bool _isClosing = false;

  /// 退出弹窗当前展示的具体清理阶段。
  String _closingDetail = '正在安全关闭下载服务，请稍候…';

  /// 桌面窗口与托盘监听器；移动端保持为空。
  DesktopTrayController? _desktopTrayController;

  /// 上次未处理异常报告，用户确认后在本次会话中清除。
  CrashRecoveryReport? _pendingCrashReport;

  /// 位于应用最外层 Stack 顶部的提示 Overlay。
  final GlobalKey<OverlayState> _topSnackBarOverlayKey =
      GlobalKey<OverlayState>();

  /// 桌面首次说明与每次启动真实能力检查的当前状态。
  DesktopRuntimeAccessState _desktopRuntimeAccess =
      const DesktopRuntimeAccessState(
        phase: DesktopRuntimeAccessPhase.checking,
      );

  /// 只有首次确认或真实检查失败时才展示说明页，后台复查保持普通启动画面。
  bool _desktopRuntimeAccessGateVisible = false;

  /// 当前平台是否需要通过 window_manager 拦截窗口关闭。
  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// 注册桌面窗口生命周期监听。
  @override
  void initState() {
    super.initState();
    // 应用级提示需要盖住路由、弹窗和异常恢复遮罩。
    AppSnackBar.registerTopOverlay(_topSnackBarOverlayKey);
    // main 已在 runApp 前读取标记，首帧即可展示恢复提示。
    _pendingCrashReport = CrashRecoveryService.pendingReport;
    // 移动端没有桌面窗口，不能注册 window_manager 监听器。
    if (_isDesktop) {
      // 托盘对象只转发关闭和明确退出事件，业务决策仍由根状态执行。
      final controller = DesktopTrayController(
        onWindowCloseRequested: _handleDesktopCloseRequest,
        onExitRequested: _closeDesktopApplication,
      );
      _desktopTrayController = controller;
      // 同步注册监听，托盘资源在控制器内部异步初始化。
      controller.start();
      // 首帧后读取设置并检查目录与 aria2，避免 initState 直接依赖异步 Provider。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_prepareDesktopRuntimeAccess());
      });
    }
  }

  /// 恢复首次说明状态，并决定等待确认还是直接复查桌面能力。
  Future<void> _prepareDesktopRuntimeAccess() async {
    // 根组件销毁后不再启动新的平台服务或刷新界面。
    if (!mounted || !_isDesktop) return;
    final service = ref.read(desktopRuntimeAccessServiceProvider);
    try {
      // 设置必须先恢复，防止检查产品默认目录后又被用户目录覆盖。
      await ref
          .read(appSettingsControllerProvider.notifier)
          .loadReadySettings();
      final directoryPath = await ref.read(
        effectiveDownloadDirectoryProvider.future,
      );
      final acknowledged = await service.hasAcknowledged();
      // 首次启动必须先解释用途，不能在用户确认前静默启动 aria2 子进程。
      if (!acknowledged) {
        if (!mounted) return;
        setState(() {
          _desktopRuntimeAccessGateVisible = true;
          _desktopRuntimeAccess = DesktopRuntimeAccessState(
            phase: DesktopRuntimeAccessPhase.needsConfirmation,
            directoryPath: directoryPath,
          );
        });
        return;
      }
      // 已确认用户仍需每次启动复查，权限或安全软件规则可能已经改变。
      await _verifyDesktopRuntimeAccess(
        requestedPath: directoryPath,
        revealGateWhileChecking: false,
      );
    } catch (error) {
      // 设置或目录解析失败时保持全屏门禁，禁止下载调度器在未知状态启动。
      if (!mounted) return;
      AppDebugLog.app('Desktop startup capability check failed: $error');
      setState(() {
        _desktopRuntimeAccessGateVisible = true;
        _desktopRuntimeAccess = DesktopRuntimeAccessState(
          phase: DesktopRuntimeAccessPhase.blocked,
          errorMessage: '启动检查未完成，请重新检查或更换保存位置。',
        );
      });
    }
  }

  /// 验证下载目录与下载后端，并在全部成功后保存首次确认。
  Future<void> _verifyDesktopRuntimeAccess({
    String? requestedPath,
    bool revealGateWhileChecking = true,
  }) async {
    // 防止按钮连点创建多个 aria2 初始化流程。
    if (_desktopRuntimeAccess.phase == DesktopRuntimeAccessPhase.verifying) {
      return;
    }
    final directoryPath =
        requestedPath ??
        await ref.read(effectiveDownloadDirectoryProvider.future) ??
        (throw StateError('无法解析桌面下载目录。'));
    if (!mounted) return;
    setState(() {
      // 用户主动操作时保留检查反馈；后台启动复查不显示说明卡片。
      if (revealGateWhileChecking) _desktopRuntimeAccessGateVisible = true;
      _desktopRuntimeAccess = DesktopRuntimeAccessState(
        phase: DesktopRuntimeAccessPhase.verifying,
        directoryPath: directoryPath,
      );
    });
    final service = ref.read(desktopRuntimeAccessServiceProvider);
    final result = await service.verify(
      directoryPath: directoryPath,
      verifyDownloadService: () async {
        // 解析当前架构随包工具，不能用其他平台二进制误判下载服务可用。
        final paths = await ref.read(nativeToolPathsProvider.future);
        final executablePath = paths.aria2Executable;
        // 桌面发行包缺少 aria2 时保持门禁，避免进入任务页后才暴露安装损坏。
        if (executablePath == null || !await File(executablePath).exists()) {
          throw StateError('当前平台的 aria2 可执行文件不存在。');
        }
        // 只运行版本检查验证系统允许启动组件，不加载会话、不联网也不恢复任务。
        final processResult = await Process.run(executablePath, <String>[
          '--version',
        ]).timeout(const Duration(seconds: 8));
        // 非零退出码表示文件损坏或被安全软件阻止，不能标记下载服务可用。
        if (processResult.exitCode != 0) {
          throw ProcessException(
            executablePath,
            const <String>['--version'],
            'aria2 版本检查异常退出。',
            processResult.exitCode,
          );
        }
      },
    );
    // 检查期间窗口可能已经被用户关闭，迟到结果不能更新已销毁状态。
    if (!mounted) return;
    if (result.phase == DesktopRuntimeAccessPhase.ready) {
      // 只有目录和下载服务都可用时才记录确认，失败重启仍会继续阻断。
      await service.saveAcknowledged();
    }
    if (!mounted) return;
    setState(() {
      // 检查成功后进入主界面，真实失败才从普通启动画面切换到说明页。
      _desktopRuntimeAccessGateVisible =
          result.phase == DesktopRuntimeAccessPhase.blocked;
      _desktopRuntimeAccess = result;
    });
  }

  /// 通过系统目录选择器更换下载位置，并立即重新执行能力检查。
  Future<void> _chooseDesktopRuntimeDirectory() async {
    // 选择器需要当前路径作为初始位置，空值时重新解析平台默认目录。
    final currentPath =
        _desktopRuntimeAccess.directoryPath ??
        await ref.read(effectiveDownloadDirectoryProvider.future) ??
        (throw StateError('无法解析当前桌面下载目录。'));
    final selected = await ref
        .read(downloadDirectorySelectionServiceProvider)
        .chooseAndSave(
          controller: ref.read(appSettingsControllerProvider.notifier),
          currentDisplayPath: currentPath,
        );
    // 用户取消选择时保持原阻断原因，不将取消误报为授权失败。
    if (!selected) return;
    // 设置变更后清除旧 Future 缓存，确保立刻检查新选择的目录。
    ref.invalidate(effectiveDownloadDirectoryProvider);
    final selectedPath = await ref.read(
      effectiveDownloadDirectoryProvider.future,
    );
    await _verifyDesktopRuntimeAccess(requestedPath: selectedPath);
  }

  /// 解除窗口监听，避免根组件销毁后继续收到关闭回调。
  @override
  void dispose() {
    // 根组件释放后不再把提示插入已销毁的最高 Overlay。
    AppSnackBar.unregisterTopOverlay(_topSnackBarOverlayKey);
    // 只有桌面端注册过监听器，释放时保持同样的平台边界。
    if (_isDesktop) {
      // 控制器负责成对解除窗口和托盘原生监听。
      _desktopTrayController?.dispose();
    }
    super.dispose();
  }

  /// 根据持久化退出行为隐藏到托盘或执行安全退出。
  Future<void> _handleDesktopCloseRequest() async {
    // 已进入真正退出流程时忽略系统重复关闭事件。
    if (_closeFuture != null) return;
    try {
      // 等待 SharedPreferences 恢复，避免首帧默认值覆盖用户选择。
      final settings = await ref
          .read(appSettingsControllerProvider.notifier)
          .loadReadySettings();
      if (settings.exitBehavior == AppExitBehavior.minimizeToTray &&
          _desktopTrayController?.isReady == true) {
        // 最小化到托盘仅隐藏窗口，下载调度器和后台任务继续运行。
        await _desktopTrayController!.hideMainWindow();
        return;
      }
      if (settings.exitBehavior == AppExitBehavior.minimizeToTray) {
        // 托盘不可用时不能隐藏唯一窗口，回退安全退出避免后台孤儿进程。
        AppDebugLog.app(
          'Desktop tray unavailable; falling back to application exit.',
        );
      }
    } catch (error) {
      // 设置读取失败时回退安全退出，避免窗口关闭后进程无界面残留。
      AppDebugLog.app('Desktop exit behavior read failed: $error');
    }
    // 退出程序选项继续使用原有不可中断资源清理流程。
    await _closeDesktopApplication();
  }

  /// 复用或创建一次桌面退出任务。
  Future<void> _closeDesktopApplication() {
    // 连续关闭请求必须等待同一个 Future，不能重复关闭事件流。
    final existing = _closeFuture;
    if (existing != null) return existing;
    // 先保存任务引用，再开始执行，避免同步重入创建第二条退出链路。
    final closeFuture = _performDesktopClose();
    _closeFuture = closeFuture;
    return closeFuture;
  }

  /// 依次释放下载资源、解除关闭保护并销毁桌面窗口。
  Future<void> _performDesktopClose() async {
    // 全局看门狗保证插件或原生 Future 永久不返回时进程仍能最终退出。
    final forceExitTimer = Timer(const Duration(seconds: 20), () {
      // 到达总时限说明常规清理链路已经失去进展，记录后强制结束当前进程。
      AppDebugLog.app('Application shutdown watchdog forced process exit.');
      exit(0);
    });
    // 资源协调器保持原有调度器、协调器、FFmpeg、aria2 和数据库关闭顺序。
    final shutdownCoordinator = DesktopShutdownCoordinator(
      ref: ref,
      onDetailChanged: (String detail) {
        // 根组件仍存在时才刷新不可关闭的退出遮罩。
        if (mounted) setState(() => _closingDetail = detail);
      },
    );
    try {
      // 先展示阻断弹窗，让用户明确知道窗口正在安全退出。
      await _showClosingOverlay();
      // 下载、合并和 aria2 必须在 Flutter 进程仍存活时完成清理。
      await shutdownCoordinator.shutdownDownloadResources();
      // 资源清理完成后销毁托盘，防止退出期间仍接受菜单点击。
      await shutdownCoordinator.runStep(
        'desktop-tray',
        tray.trayManager.destroy,
        detail: '正在关闭系统托盘…',
      );
      // 清理完成后允许窗口管理器执行真正的关闭操作。
      await shutdownCoordinator.runStep(
        'window-close-protection',
        () => windowManager.setPreventClose(false),
        detail: '正在关闭应用窗口…',
      );
      // destroy 失败或不返回时仍由步骤超时和最终 exit 兜底。
      await shutdownCoordinator.runStep(
        'window-destroy',
        windowManager.destroy,
        detail: '正在关闭应用窗口…',
      );
    } finally {
      // 正常链路完成后取消看门狗并结束残留插件线程，防止只销毁窗口不退进程。
      forceExitTimer.cancel();
      exit(0);
    }
  }

  /// 展示全局退出遮罩，并等待首帧完成后再启动耗时资源清理。
  Future<void> _showClosingOverlay() async {
    // 根组件已经销毁时没有可展示的窗口，直接进入兜底清理。
    if (!mounted) return;
    // 状态只从未退出切换为退出中，后续关闭请求复用同一个 Future。
    setState(() => _isClosing = true);
    // 等待弹窗实际绘制，避免快速进入原生清理后界面看起来无响应。
    await WidgetsBinding.instance.endOfFrame;
  }

  /// 构建路由、亮色主题和暗色主题。
  @override
  Widget build(BuildContext context) {
    // 监听持久化主题模式，用户切换后立即重建 MaterialApp。
    final themeMode = ref.watch(themeModeControllerProvider);
    // 监听持久化品牌色，选择后同步重建亮色和暗色主题。
    final themeAccent = ref.watch(themeAccentControllerProvider);
    // 监听主题色明暗级别，拖动滑块时同步重建两套主题。
    final themeAccentBrightness = ref.watch(
      themeAccentBrightnessControllerProvider,
    );
    // 亮色主题使用亮色品牌基准并应用用户选择的明暗级别。
    final lightAccentColor = adjustThemeAccentBrightness(
      themeAccent.color,
      themeAccentBrightness,
    );
    // 暗色主题从对应暗色基准独立调整，保留默认绿的历史双配色。
    final darkAccentColor = adjustThemeAccentBrightness(
      themeAccent.darkColor,
      themeAccentBrightness,
    );
    // 桌面能力未确认或检查失败时不创建路由与下载调度器，避免后台绕过门禁。
    if (_isDesktop &&
        _desktopRuntimeAccess.phase != DesktopRuntimeAccessPhase.ready) {
      return MaterialApp(
        title: 'BiliDown',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(accentColor: lightAccentColor),
        darkTheme: AppTheme.dark(accentColor: darkAccentColor),
        themeMode: themeMode,
        builder: (BuildContext context, Widget? child) =>
            _buildWithTapSounds(context, child, null),
        home: _desktopRuntimeAccessGateVisible
            ? DesktopRuntimeAccessGate(
                state: _desktopRuntimeAccess,
                onConfirmOrRetry: () =>
                    unawaited(_verifyDesktopRuntimeAccess()),
                onChooseDirectory: () =>
                    unawaited(_chooseDesktopRuntimeDirectory()),
              )
            : const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    // 自动关机倒计时由根界面展示，路由切换不会关闭取消入口。
    final automaticShutdown = ref.watch(automaticShutdownControllerProvider);
    // 剪贴板建议由根组件消费，发现新链接后自动进入解析页。
    ref.listen<ClipboardParseSuggestion?>(clipboardMonitorControllerProvider, (
      ClipboardParseSuggestion? previous,
      ClipboardParseSuggestion? next,
    ) {
      // 只有新的有效候选需要触发跳转，空状态来自已消费或关闭设置。
      if (next == null || _isClosing) return;
      // 路由和顶层 Overlay 要等当前构建帧结束后再访问。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 组件销毁或退出清理期间不能再发起解析与页面跳转。
        if (!mounted || _isClosing) return;
        _acceptClipboardSuggestion();
      });
    });
    // 倒计时首次出现时恢复托盘窗口，确保不可逆操作对用户可见。
    ref.listen<AutomaticShutdownState?>(automaticShutdownControllerProvider, (
      AutomaticShutdownState? previous,
      AutomaticShutdownState? next,
    ) {
      if (previous == null && next != null && _isDesktop) {
        // Provider 监听回调不能等待窗口恢复，异步显示并聚焦主窗口。
        final controller = _desktopTrayController;
        if (controller != null) unawaited(controller.showMainWindow());
      }
    });
    // 应用启动即校验账号，使音画质权限和默认值不依赖用户先打开账号页。
    ref.watch(accountControllerProvider);
    // 应用首屏前主动打开数据库并执行建表或版本迁移。
    final databaseReady = ref.watch(appDatabaseReadyProvider);
    // 数据库打开失败时不能进入会持续查询任务的主界面。
    if (databaseReady.hasError) {
      // 返回带重试入口的主题化错误页。
      return MaterialApp(
        title: 'BiliDown',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(accentColor: lightAccentColor),
        darkTheme: AppTheme.dark(accentColor: darkAccentColor),
        themeMode: themeMode,
        builder: (BuildContext context, Widget? child) =>
            _buildWithTapSounds(context, child, automaticShutdown),
        home: DatabaseStartupError(
          error: databaseReady.error!,
          onRetry: () {
            // 销毁失败实例后重新创建连接并执行启动查询。
            ref.invalidate(appDatabaseProvider);
          },
        ),
      );
    }
    // 数据库尚未完成打开和迁移时显示短暂启动状态。
    if (!databaseReady.hasValue) {
      // 主路由不会提前构建，因此页面查询不会与迁移竞争。
      return MaterialApp(
        title: 'BiliDown',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(accentColor: lightAccentColor),
        darkTheme: AppTheme.dark(accentColor: darkAccentColor),
        themeMode: themeMode,
        builder: (BuildContext context, Widget? child) =>
            _buildWithTapSounds(context, child, automaticShutdown),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    // 数据库就绪后先暂停上次进程遗留的活动任务，避免调度器抢先自动续传。
    final startupPause = ref.watch(downloadTaskStartupPauseProvider);
    // 恢复事务失败时不能进入会自动认领 waitingToStart 的主界面。
    if (startupPause.hasError) {
      // 复用启动错误页提供明确错误和重试入口，不隐式忽略持久化失败。
      return MaterialApp(
        title: 'BiliDown',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(accentColor: lightAccentColor),
        darkTheme: AppTheme.dark(accentColor: darkAccentColor),
        themeMode: themeMode,
        builder: (BuildContext context, Widget? child) =>
            _buildWithTapSounds(context, child, automaticShutdown),
        home: DatabaseStartupError(
          error: startupPause.error!,
          onRetry: () {
            // 仅重试活动任务暂停事务，数据库连接和用户任务记录保持不变。
            ref.invalidate(downloadTaskStartupPauseProvider);
          },
        ),
      );
    }
    // 暂停事务完成前不创建路由、页面查询和下载调度器。
    if (!startupPause.hasValue) {
      // 使用与数据库打开阶段一致的轻量启动状态。
      return MaterialApp(
        title: 'BiliDown',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(accentColor: lightAccentColor),
        darkTheme: AppTheme.dark(accentColor: darkAccentColor),
        themeMode: themeMode,
        builder: (BuildContext context, Widget? child) =>
            _buildWithTapSounds(context, child, automaticShutdown),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    // 移动端在数据库恢复完成后读取版本化引导标记，桌面端始终跳过该流程。
    if (!_isDesktop) {
      // 监听完成与设置页重看状态，变化后在引导页和主路由之间即时切换。
      final onboarding = ref.watch(onboardingControllerProvider);
      // 恢复期间显示主题化加载页，避免首次引导在已完成用户设备上短暂闪现。
      if (onboarding.isRestoring || !onboarding.isCompleted) {
        return MaterialApp(
          title: 'BiliDown',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(accentColor: lightAccentColor),
          darkTheme: AppTheme.dark(accentColor: darkAccentColor),
          themeMode: themeMode,
          builder: (BuildContext context, Widget? child) =>
              _buildWithTapSounds(context, child, automaticShutdown),
          home: onboarding.isRestoring
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : const OnboardingPage(),
        );
      }
    }
    // 监听应用级 GoRouter 实例。
    final router = ref.watch(appRouterProvider);
    // 数据库就绪后启动应用级下载声音观察器，页面切换不会中断状态判断。
    ref.watch(downloadSoundObserverProvider);
    // 应用级调度器持续恢复等待任务，并按设置并发数分配真实下载槽位。
    ref.watch(downloadTaskSchedulerProvider);
    // Android 前台断网时注册等待联网的一次性 WorkManager 恢复任务。
    ref.watch(backgroundDownloadRecoveryRegistrationProvider);
    // 使用 router 构造器确保桌面和移动端共享同一导航状态。
    return MaterialApp.router(
      title: 'BiliDown',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accentColor: lightAccentColor),
      darkTheme: AppTheme.dark(accentColor: darkAccentColor),
      themeMode: themeMode,
      routerConfig: router,
      builder: (BuildContext context, Widget? child) =>
          _buildWithTapSounds(context, child, automaticShutdown),
    );
  }

  /// 在 MaterialApp 生成的全部页面外包裹统一按钮点击音监听区域。
  Widget _buildWithTapSounds(
    BuildContext context,
    Widget? child,
    AutomaticShutdownState? automaticShutdown,
  ) {
    // MaterialApp 正常始终提供 child，空值时使用零尺寸占位保护启动边界。
    final appChild = child ?? const SizedBox.shrink();
    // 根 Stack 让退出遮罩覆盖所有路由、弹窗和启动错误页面。
    return AppTapSoundRegion(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          appChild,
          // 自动关机提示覆盖路由但保留明确取消按钮，避免静默关机。
          if (automaticShutdown != null && !_isClosing)
            AutomaticShutdownOverlay(
              state: automaticShutdown,
              onCancel: ref
                  .read(automaticShutdownControllerProvider.notifier)
                  .cancel,
            ),
          // 上次未处理异常提示高于普通会话提示，用户可先导出诊断信息。
          if (_pendingCrashReport != null && !_isClosing)
            CrashRecoveryOverlay(
              report: _pendingCrashReport!,
              onDismiss: () => unawaited(_dismissCrashRecovery()),
              onExport: () => unawaited(_exportCrashDiagnostic()),
            ),
          // 清理期间拦截全部点击和返回操作，避免产生新的数据库或下载请求。
          if (_isClosing) ApplicationClosingOverlay(detail: _closingDetail),
          // 最高层提示必须放在所有自绘遮罩之后，保证操作反馈不会被弹窗盖住。
          Overlay(key: _topSnackBarOverlayKey),
        ],
      ),
    );
  }

  /// 消费剪贴板建议、切换解析页并启动自动解析。
  void _acceptClipboardSuggestion() {
    // accept 会同步清空候选并返回当前输入，迟到监听可能得到空值。
    final input = ref
        .read(clipboardMonitorControllerProvider.notifier)
        .accept();
    if (input == null) return;
    // 先写入解析输入，路由构建输入框时即可显示同一内容。
    final parser = ref.read(parserControllerProvider.notifier);
    parser.updateInput(input);
    // 使用应用级路由跳转解析页，再执行剪贴板触发的网络解析。
    ref.read(appRouterProvider).go('/parse');
    // 顶层提示替代原确认按钮，让自动行为对用户可见但不阻断操作。
    _showTopSnackBar(message: '检测到 B 站链接，正在自动解析。', type: AppSnackBarType.info);
    unawaited(parser.parse());
  }

  /// 确认上次崩溃提示并删除持久标记。
  Future<void> _dismissCrashRecovery() async {
    await CrashRecoveryService.dismiss();
    if (!mounted) return;
    setState(() => _pendingCrashReport = null);
  }

  /// 从恢复提示直接导出脱敏日志，成功后保留提示供用户自行确认。
  Future<void> _exportCrashDiagnostic() async {
    try {
      // 系统保存对话框返回 true 才代表文件已经成功写入目标位置。
      final exported = await DiagnosticLogExportService.export();
      // 用户取消选择文件时保持恢复提示，不显示成功或失败消息。
      if (!exported || !mounted) return;
      // 路由已经挂载时给出明确的导出成功反馈。
      _showRouterSnackBar(message: '诊断日志已导出。', type: AppSnackBarType.success);
    } catch (error) {
      // 导出失败加入本次脱敏日志，用户仍可稍后从设置页重试。
      AppDebugLog.settings('Crash diagnostic export failed error=$error');
      // 文案经过脱敏以免暴露目标路径。
      _showRouterSnackBar(
        message: '导出诊断日志失败：${AppDebugLog.sanitize(error.toString())}',
        type: AppSnackBarType.error,
      );
    }
  }

  /// 在根路由 Overlay 上显示提示，供没有页面 BuildContext 的应用级回调使用。
  void _showRouterSnackBar({
    required String message,
    required AppSnackBarType type,
  }) {
    // Navigator 自身的 context 位于内部 Overlay 之上，必须直接读取子 Overlay 状态。
    final overlay = ref
        .read(appRouterProvider)
        .routerDelegate
        .navigatorKey
        .currentState
        ?.overlay;
    // 路由尚未挂载或正在销毁时放弃提示，避免错误恢复流程再次抛出 FlutterError。
    if (overlay == null || !overlay.mounted) return;
    AppSnackBar.showInOverlay(overlay, message: message, type: type);
  }

  /// 在应用最外层 Overlay 显示不依赖当前路由的提示。
  void _showTopSnackBar({
    required String message,
    required AppSnackBarType type,
  }) {
    // 剪贴板自动解析可能发生在路由首帧前，优先使用根 Stack 顶部 Overlay。
    final overlay = _topSnackBarOverlayKey.currentState;
    if (overlay == null || !overlay.mounted) return;
    AppSnackBar.showInOverlay(overlay, message: message, type: type);
  }
}
