import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file_manager/open_file_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/logging/app_debug_log.dart';
import '../../../../core/logging/diagnostic_log_export_service.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../services/cache/app_cache_manager.dart';
import '../../../downloads/application/queue/download_queue_service.dart';
import '../../../onboarding/application/onboarding_controller.dart';
import '../../application/app_settings_controller.dart';
import '../../application/download_directory_selection_service.dart';
import '../../domain/app_settings.dart';
import '../dialogs/naming_template_dialog.dart';
import '../dialogs/storage_advanced_dialog.dart';
import '../naming_template_page.dart';
import '../models/settings_page_state.dart';
import '../models/settings_labels.dart';
import '../storage_advanced_page.dart';

/// 异步读取当前安装包版本，避免设置页面重复请求平台通道。
final settingsPackageVersionProvider = FutureProvider<String>((Ref ref) async {
  // 获取当前平台安装包元数据。
  final packageInfo = await PackageInfo.fromPlatform();
  // 返回用户可识别的语义化版本号。
  return packageInfo.version;
});

/// 异步统计封面缓存和 aria2 日志等可清理缓存大小。
final settingsAppCacheSizeProvider = FutureProvider<int>((Ref ref) async {
  // 文件遍历放在 Provider 中，页面重建不会重复启动统计任务。
  return AppCacheManager.sizeInBytes();
});

/// 设置页页面级动作和 busy 状态入口。
final settingsPageControllerProvider =
    NotifierProvider<SettingsPageController, SettingsPageState>(
      SettingsPageController.new,
    );

/// 承接设置页弹窗、文件系统、缓存和待下载任务同步等页面动作。
final class SettingsPageController extends Notifier<SettingsPageState> {
  /// 创建初始页面控制状态。
  @override
  SettingsPageState build() => SettingsPageState.initial();

  /// 执行一项已经即时更新界面的设置写入，并在持久化失败时统一反馈。
  Future<void> saveSettingWithFeedback(
    BuildContext context,
    Future<void> Function() saveSetting,
  ) async {
    try {
      // 等待本次 SharedPreferences 写入，避免 fire-and-forget 异常静默丢失。
      await saveSetting();
    } catch (error) {
      AppDebugLog.settings('Save setting failed error=$error');
      // 页面关闭后不再访问已经失效的根 Overlay。
      if (!context.mounted) return;
      // 设置控件已经即时显示新值，必须明确告知该值可能未保存到下次启动。
      _showMessage(
        context,
        '保存设置失败，重启后可能不会保留：$error',
        type: AppSnackBarType.error,
      );
    }
  }

  /// 保存重名文件处理策略，并在启用覆盖前取得用户明确确认。
  Future<void> selectOutputConflictStrategy(
    BuildContext context,
    OutputConflictStrategy strategy,
  ) async {
    // 自动编号和跳过不会删除现有内容，可直接保存。
    if (strategy != OutputConflictStrategy.overwrite) {
      AppDebugLog.settings(
        'Output conflict strategy selected strategy=${strategy.name}',
      );
      await ref
          .read(appSettingsControllerProvider.notifier)
          .setOutputConflictStrategy(strategy);
      return;
    }
    // 覆盖会替换磁盘上的同名成品，必须先说明不可恢复影响。
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: const Text('启用覆盖同名文件？'),
      content: const Text('后续下载遇到同名成品时会替换原文件，此操作无法撤销。'),
      confirmLabel: '确认启用',
    );
    // 页面关闭或用户取消时不能修改当前偏好。
    if (!confirmed || !context.mounted) {
      AppDebugLog.settings('Output conflict overwrite cancelled');
      return;
    }
    AppDebugLog.settings(
      'Output conflict strategy selected strategy=${strategy.name}',
    );
    // 用户已经明确确认覆盖风险，持久化用于后续入队任务。
    await ref
        .read(appSettingsControllerProvider.notifier)
        .setOutputConflictStrategy(strategy);
  }

  /// 保存质量相关设置并同步尚未启动任务的实际 DASH 选择。
  Future<void> saveQualityAndSynchronize(
    BuildContext context,
    Future<void> Function() saveSetting,
  ) async {
    try {
      // 先保存设置，使同步服务读取到用户本次最终选择。
      await saveSetting();
      // 页面在设置持久化期间关闭时不再启动页面关联同步。
      if (!context.mounted) return;
      // 从各任务解析时入库的 DASH 候选中执行本地质量降级选择。
      final result = await _synchronizeQueuedTasks(
        context,
        refreshQuality: true,
      );
      AppDebugLog.settings(
        'Quality setting synchronized failed=${result.failed}',
      );
    } catch (error) {
      AppDebugLog.settings(
        'Quality setting synchronization failed error=$error',
      );
      // 页面被关闭后不再访问根 Overlay。
      if (!context.mounted) return;
      // 设置已保存但同步失败时给出明确提示。
      _showMessage(context, '同步待下载任务失败：$error', type: AppSnackBarType.error);
    }
  }

  /// 打开系统目录选择器并保存用户选择。
  Future<void> chooseDirectory(BuildContext context) async {
    // 防止系统目录选择器被快速重复打开。
    if (state.choosingDirectory) return;
    AppDebugLog.settings('Directory selection started');
    state = state.copyWith(choosingDirectory: true);
    try {
      // 获取当前实际目录作为系统选择器初始位置。
      final currentDirectory = await ref.read(
        effectiveDownloadDirectoryProvider.future,
      );
      // 设置页和任务页共用同一套真实目录选择逻辑。
      final changed = await ref
          .read(downloadDirectorySelectionServiceProvider)
          .chooseAndSave(
            controller: ref.read(appSettingsControllerProvider.notifier),
            currentDisplayPath: currentDirectory,
          );
      // 用户取消或选择原目录时保持当前任务路径。
      if (!changed) {
        AppDebugLog.settings('Directory selection unchanged');
        return;
      }
      // 页面在设置持久化期间关闭时不再继续访问页面依赖。
      if (!context.mounted) return;
      // 重新计算 queued 任务的根目录、高级子目录和最终输出路径。
      final result = await _synchronizeQueuedTasks(
        context,
        refreshQuality: false,
      );
      AppDebugLog.settings(
        'Directory changed synchronized failed=${result.failed}',
      );
      // 部分任务同步失败时保留警告，不再用成功提示覆盖具体问题。
      if (!context.mounted || result.failed > 0) return;
      // 读取设置变更后的最终展示目录，展示值与真实写入路径一致。
      final updatedDirectory = await ref.read(
        effectiveDownloadDirectoryProvider.future,
      );
      if (!context.mounted) return;
      // 顶部居中提示明确反馈目录已经保存并生效。
      _showCenteredMessage(context, '默认存储位置已修改：$updatedDirectory');
    } catch (error) {
      AppDebugLog.settings('Directory selection failed error=$error');
      // 页面卸载后不再显示平台选择器错误。
      if (!context.mounted) return;
      // 使用应用级提示反馈平台不支持或选择器启动失败。
      _showMessage(context, '选择目录失败：$error', type: AppSnackBarType.error);
    } finally {
      state = state.copyWith(choosingDirectory: false);
    }
  }

  /// 清除自定义真实路径并恢复平台默认成品目录。
  Future<void> resetDirectory(BuildContext context) async {
    // 防止恢复默认目录时重复写入设置和同步任务。
    if (state.resettingDirectory) return;
    AppDebugLog.settings('Directory reset started');
    state = state.copyWith(resettingDirectory: true);
    try {
      // 控制器同时清理保存值和 Android 旧持久授权。
      await ref
          .read(appSettingsControllerProvider.notifier)
          .resetDownloadDirectoryPath();
      // 页面关闭后不再同步依赖界面的待下载任务。
      if (!context.mounted) return;
      // queued 任务重新使用平台默认目录，活动任务保持原交付目标。
      final result = await _synchronizeQueuedTasks(
        context,
        refreshQuality: false,
      );
      AppDebugLog.settings(
        'Directory reset synchronized failed=${result.failed}',
      );
      // 存在同步失败时只保留警告，避免同时出现矛盾的成功反馈。
      if (!context.mounted || result.failed > 0) return;
      // 恢复后读取当前平台解析出的真实默认目录。
      final defaultDirectory = await ref.read(
        effectiveDownloadDirectoryProvider.future,
      );
      if (!context.mounted) return;
      // 恢复默认目录同样给出明确完成反馈。
      _showCenteredMessage(context, '已恢复默认存储位置：$defaultDirectory');
    } catch (error) {
      AppDebugLog.settings('Directory reset failed error=$error');
      // 恢复失败时保留页面并显示真实错误。
      if (!context.mounted) return;
      _showMessage(context, '恢复默认目录失败：$error', type: AppSnackBarType.error);
    } finally {
      state = state.copyWith(resettingDirectory: false);
    }
  }

  /// 打开允许手动输入或恢复系统目录的高级弹窗。
  Future<void> showDirectoryDialog(
    BuildContext context, {
    required bool compact,
  }) async {
    AppDebugLog.settings('Storage advanced opened compact=$compact');
    // 读取实际下载根目录供弹窗生成路径预览。
    final directory = await ref.read(effectiveDownloadDirectoryProvider.future);
    // 页面在异步目录解析期间被关闭时不再弹出对话框。
    if (!context.mounted) return;
    // 读取当前高级文件夹模板。
    final folderTemplate = ref
        .read(appSettingsControllerProvider)
        .folderTemplate;
    // 保存逻辑在弹窗和移动端页面之间复用，避免两套路径同步行为分叉。
    Future<void> saveFolderTemplate(String template) async {
      // 保存根目录下的动态子文件夹模板。
      await ref
          .read(appSettingsControllerProvider.notifier)
          .setFolderTemplate(template);
      AppDebugLog.settings('Folder template saved length=${template.length}');
      // 设置页在持久化期间关闭时终止后续界面关联操作。
      if (!context.mounted) return;
      // 高级目录模板保存后立即重算尚未启动任务的输出路径。
      final result = await _synchronizeQueuedTasks(
        context,
        refreshQuality: false,
      );
      AppDebugLog.settings(
        'Folder template synchronized failed=${result.failed}',
      );
      // 全部任务同步成功后显示统一保存反馈，部分失败时保留警告。
      if (context.mounted && result.failed == 0) {
        _showSettingsSaveSuccess(context);
      }
    }

    if (compact) {
      // 手机端使用真正页面入栈，而不是全屏 Dialog。
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (BuildContext routeContext) => StorageAdvancedPage(
            baseDirectory: directory,
            initialTemplate: folderTemplate,
            onSave: saveFolderTemplate,
          ),
        ),
      );
      return;
    }
    // PC 端保留原来的居中弹窗体验。
    await showStorageAdvancedDialog(
      context: context,
      baseDirectory: directory,
      initialTemplate: folderTemplate,
      onSave: saveFolderTemplate,
    );
  }

  /// 打开命名模板编辑弹窗。
  Future<void> showNamingDialog(
    BuildContext context, {
    required bool compact,
  }) async {
    AppDebugLog.settings('Naming template opened compact=$compact');
    // 获取当前模板供弹窗编辑。
    final template = ref.read(appSettingsControllerProvider).namingTemplate;
    // 保存逻辑在弹窗和移动端页面之间复用，确保任务路径刷新一致。
    Future<void> saveNamingTemplate(String value) async {
      // 保存用户确认的命名模板。
      await ref
          .read(appSettingsControllerProvider.notifier)
          .setNamingTemplate(value);
      AppDebugLog.settings('Naming template saved length=${value.length}');
      // 文件名属于任务输出快照；保存后立即刷新尚未启动的任务，
      // 避免用户看到新预览但实际下载仍沿用入队时的旧名称。
      if (!context.mounted) return;
      final result = await _synchronizeQueuedTasks(
        context,
        refreshQuality: false,
      );
      AppDebugLog.settings(
        'Naming template synchronized failed=${result.failed}',
      );
      // 命名设置和现有待下载任务均更新成功后展示完成提示。
      if (context.mounted && result.failed == 0) {
        _showSettingsSaveSuccess(context);
      }
    }

    if (compact) {
      // 手机端使用真正页面入栈，与设置页其它详情页保持一致。
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (BuildContext routeContext) => NamingTemplatePage(
            initialTemplate: template,
            onSave: saveNamingTemplate,
          ),
        ),
      );
      return;
    }
    // PC 端继续使用原有弹窗，不打断设置中心上下文。
    await showNamingTemplateDialog(
      context: context,
      initialTemplate: template,
      onSave: saveNamingTemplate,
    );
  }

  /// 确认后清除磁盘和内存中的应用缓存。
  Future<void> clearAppCache(BuildContext context, int currentSize) async {
    // 防止确认后清理过程被重复触发。
    if (state.clearingCache) return;
    // 桌面端封面缓存会进入系统回收站，移动端仍直接清理应用沙箱缓存。
    final usesSystemTrash =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    AppDebugLog.settings('Cache clear confirmation opened size=$currentSize');
    // 清除属于破坏性操作，必须先展示当前占用和重新下载影响。
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: const Text('清除缓存'),
      content: Text(
        '当前缓存：${formatCacheSize(currentSize)}\n'
        '${usesSystemTrash ? '封面缓存将移入系统回收站' : '将清除封面缓存'}，'
        'aria2 日志将被清空；封面将在下次显示时重新下载。',
      ),
      confirmLabel: '确认清除',
    );
    // 用户取消或页面已经销毁时停止后续操作。
    if (!confirmed || !context.mounted) {
      AppDebugLog.settings('Cache clear cancelled');
      return;
    }
    AppDebugLog.settings('Cache clear started');
    state = state.copyWith(clearingCache: true);
    // 等待 Material 弹窗退出动画完成，确保后续 SnackBar 不与模态遮罩重叠。
    await Future<void>.delayed(kThemeAnimationDuration);
    // 动画等待期间页面可能已经关闭，不能继续访问缓存状态和根 Overlay。
    if (!context.mounted) {
      state = state.copyWith(clearingCache: false);
      return;
    }
    try {
      // 同时清除封面缓存、Flutter 内存图片和 aria2 运行日志。
      await AppCacheManager.clear();
      AppDebugLog.settings('Cache clear completed');
      // 重新统计目录大小，使设置行立即显示清除后的结果。
      ref.invalidate(settingsAppCacheSizeProvider);
      if (!context.mounted) return;
      _showCenteredMessage(context, '清除成功');
    } catch (error) {
      AppDebugLog.settings('Cache clear failed error=$error');
      // 文件被系统占用或权限异常时保留真实错误供用户处理。
      if (!context.mounted) return;
      _showMessage(context, '清除缓存失败：$error', type: AppSnackBarType.error);
    } finally {
      state = state.copyWith(clearingCache: false);
    }
  }

  /// 导出当前进程内存中的脱敏诊断日志并反馈结果。
  Future<void> exportDiagnosticLog(BuildContext context) async {
    // 防止重复打开系统保存对话框。
    if (state.exportingDiagnosticLog) return;
    AppDebugLog.settings('Diagnostic log export started');
    state = state.copyWith(exportingDiagnosticLog: true);
    try {
      final exported = await DiagnosticLogExportService.export();
      // 用户取消系统对话框不显示成功或错误提示。
      if (!exported || !context.mounted) {
        AppDebugLog.settings('Diagnostic log export cancelled');
        return;
      }
      AppDebugLog.settings('Diagnostic log export completed');
      AppSnackBar.show(
        context,
        message: '诊断日志已导出。',
        type: AppSnackBarType.success,
      );
    } catch (error) {
      AppDebugLog.settings('Diagnostic log export failed error=$error');
      if (!context.mounted) return;
      // 文件权限或平台选择器失败时给出可重试提示，不泄露目标绝对路径。
      AppSnackBar.show(
        context,
        message: '导出诊断日志失败：${AppDebugLog.sanitize(error.toString())}',
        type: AppSnackBarType.error,
      );
    } finally {
      state = state.copyWith(exportingDiagnosticLog: false);
    }
  }

  /// 当前会话切回移动端引导，磁盘完成标记保持不变。
  void showOnboardingAgain() {
    // 引导控制器负责展示状态，设置页不直接管理弹窗生命周期。
    AppDebugLog.settings('Onboarding requested from settings');
    ref.read(onboardingControllerProvider.notifier).showAgain();
  }

  /// 打开 Flutter 注册表中的开源许可证页面。
  void showOpenSourceLicensePage(
    BuildContext context, {
    required String version,
    required bool compact,
  }) {
    // 手机端使用根导航覆盖整个 Shell，避免继续显示“设置中心”头部。
    AppDebugLog.settings('Open source license page opened compact=$compact');
    if (compact) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (BuildContext routeContext) => LicensePage(
            applicationName: 'BiliDown',
            applicationVersion: version,
            applicationLegalese: '非官方工具，请遵守内容版权与平台条款。',
          ),
        ),
      );
      return;
    }
    // 桌面端沿用 Flutter 原生许可证页，继续显示在当前设置内容区域内。
    showLicensePage(
      context: context,
      applicationName: 'BiliDown',
      applicationVersion: version,
      applicationLegalese: '非官方工具，请遵守内容版权与平台条款。',
    );
  }

  /// 使用当前系统文件管理器打开下载目录。
  Future<void> openDirectory(BuildContext context, String path) async {
    try {
      // Android 通过系统文件管理器打开真实目录路径。
      if (Platform.isAndroid) {
        // 插件接受相对 Download 路径和绝对自定义路径，统一由系统文件管理器解析。
        await openFileManager(
          androidConfig: AndroidConfig(
            folderType: AndroidFolderType.other,
            folderPath: path,
          ),
        );
      } else if (Platform.isWindows) {
        // Windows 使用 Explorer 打开实际目录。
        await Process.start('explorer.exe', <String>[path]);
      } else if (Platform.isMacOS) {
        // macOS 使用 Finder 打开实际目录。
        await Process.start('open', <String>[path]);
      } else if (Platform.isLinux) {
        // Linux 交给桌面环境默认文件管理器。
        await Process.start('xdg-open', <String>[path]);
      } else {
        // 当前未为 iOS 提供公共 Download 目录语义，保持明确错误。
        throw UnsupportedError('当前平台不支持直接打开目录。');
      }
    } catch (error) {
      // 页面卸载后不再访问根 Overlay。
      if (!context.mounted) return;
      // 用非阻塞提示反馈系统文件管理器启动失败。
      _showMessage(context, '打开目录失败：$error', type: AppSnackBarType.error);
    }
  }

  /// 使用当前设置批量刷新 queued 任务并报告单任务失败。
  Future<QueuedTaskSettingsSyncResult> _synchronizeQueuedTasks(
    BuildContext context, {
    required bool refreshQuality,
  }) async {
    // 读取随最新设置重建的入队服务。
    final service = ref.read(downloadQueueServiceProvider);
    // 执行质量或路径同步并等待 Drift 写入完成。
    final result = await service.synchronizeQueuedTasks(
      refreshQuality: refreshQuality,
    );
    // 页面仍存在且有失败项时展示准确警告，调用方据结果决定后续反馈。
    if (result.failed > 0 && context.mounted) {
      // 部分视频因失效、下架或路径问题未同步时提示准确数量。
      _showMessage(
        context,
        '${result.failed} 个待下载任务同步失败，请稍后重试。',
        type: AppSnackBarType.warning,
      );
    }
    // 返回统计供目录、质量等不同调用场景决定后续反馈。
    return result;
  }

  /// 在设置弹窗保存完成后展示统一的顶部居中成功反馈。
  void _showSettingsSaveSuccess(BuildContext context) {
    // 页面已关闭时根 Overlay 不再属于当前设置流程，跳过过期提示。
    if (!context.mounted) return;
    // 使用简短文案同时适配高级存储和自定义命名弹窗。
    _showCenteredMessage(context, '保存成功');
  }

  /// 展示顶部居中成功提示。
  void _showCenteredMessage(BuildContext context, String message) {
    // 设置页的完成反馈需要避开底部导航栏，统一放到顶部居中。
    AppSnackBar.show(
      context,
      message: message,
      type: AppSnackBarType.success,
      position: AppSnackBarPosition.top,
      layout: AppSnackBarLayout.centered,
    );
  }

  /// 展示顶部错误或警告提示。
  void _showMessage(
    BuildContext context,
    String message, {
    required AppSnackBarType type,
  }) {
    // 页面级错误统一放在顶部，避免被移动端底部栏遮挡。
    AppSnackBar.show(
      context,
      message: message,
      type: type,
      position: AppSnackBarPosition.top,
    );
  }
}
