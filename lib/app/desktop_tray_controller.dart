import 'dart:async';
import 'dart:io';

import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

import '../core/logging/app_debug_log.dart';

/// 管理桌面窗口关闭事件、托盘菜单以及窗口显示状态。
final class DesktopTrayController with WindowListener, tray.TrayListener {
  /// 创建托盘生命周期控制器。
  DesktopTrayController({
    required this.onWindowCloseRequested,
    required this.onExitRequested,
  });

  /// 系统关闭按钮触发后的异步业务回调。
  final Future<void> Function() onWindowCloseRequested;

  /// 托盘“退出程序”触发后的安全退出回调。
  final Future<void> Function() onExitRequested;

  /// 托盘菜单中恢复主窗口的稳定键。
  static const String _showWindowMenuKey = 'show_window';

  /// 托盘菜单中安全退出应用的稳定键。
  static const String _exitApplicationMenuKey = 'exit_application';

  /// 图标和菜单是否已经成功创建，可安全隐藏唯一主窗口。
  bool isReady = false;

  /// 注册窗口和托盘监听，并异步创建原生托盘资源。
  void start() {
    // 监听注册必须同步完成，避免初始化托盘期间漏掉窗口关闭事件。
    windowManager.addListener(this);
    tray.trayManager.addListener(this);
    // 托盘初始化不阻塞首帧，失败时仍可使用普通窗口和安全退出。
    unawaited(_initializeTray());
  }

  /// 解除监听；原生托盘销毁仍由安全退出链在资源关闭后执行。
  void dispose() {
    // 根组件销毁后不再接收窗口和托盘事件。
    windowManager.removeListener(this);
    tray.trayManager.removeListener(this);
  }

  /// 创建托盘图标、提示文字和基础菜单。
  Future<void> _initializeTray() async {
    try {
      // Windows 托盘使用 ICO，macOS 和 Linux 使用透明 PNG 资源。
      final iconPath = Platform.isWindows
          ? 'assets/images/tray_icon.ico'
          : 'assets/images/tray_icon.png';
      // 原生托盘插件从 Flutter 资源目录解析对应平台图标。
      await tray.trayManager.setIcon(iconPath);
      if (!Platform.isLinux) {
        // Linux 后端不支持 Tooltip，Windows 和 macOS 显示产品名。
        await tray.trayManager.setToolTip('BiliDown');
      }
      // 菜单只保留恢复和安全退出，所有退出入口复用同一清理链路。
      final menu = tray.Menu(
        items: <tray.MenuItem>[
          tray.MenuItem(key: _showWindowMenuKey, label: '显示主窗口'),
          tray.MenuItem.separator(),
          tray.MenuItem(key: _exitApplicationMenuKey, label: '退出程序'),
        ],
      );
      // 将菜单交给原生托盘，右键时由插件显示平台菜单。
      await tray.trayManager.setContextMenu(menu);
      // 图标和菜单都成功后才允许关闭按钮隐藏主窗口。
      isReady = true;
    } catch (error) {
      // 托盘初始化失败不能阻断应用启动，记录后继续使用普通窗口。
      AppDebugLog.app('Desktop tray initialization failed: $error');
    }
  }

  /// 隐藏主窗口并保留后台下载任务。
  Future<void> hideMainWindow() async {
    // 只有托盘已经就绪时调用方才会隐藏唯一窗口。
    await windowManager.hide();
  }

  /// 从托盘恢复最小化或隐藏的主窗口。
  Future<void> showMainWindow() async {
    try {
      // 最小化窗口先恢复尺寸，隐藏窗口再重新显示。
      if (await windowManager.isMinimized()) await windowManager.restore();
      await windowManager.show();
      // 最后聚焦窗口，使用户操作立即回到应用。
      await windowManager.focus();
    } catch (error) {
      // 平台窗口恢复失败只记录诊断，不影响后台下载继续运行。
      AppDebugLog.app('Desktop window restore failed: $error');
    }
  }

  /// 接收系统窗口关闭请求并交给应用根状态读取退出设置。
  @override
  void onWindowClose() {
    // 原生回调不能返回 Future，异步业务由根组件负责串行化。
    unawaited(onWindowCloseRequested());
  }

  /// 单击托盘图标时恢复并聚焦主窗口。
  @override
  void onTrayIconMouseDown() {
    // 托盘回调不能等待 Future，由窗口管理器异步恢复界面。
    unawaited(showMainWindow());
  }

  /// 处理托盘菜单的显示和安全退出命令。
  @override
  void onTrayMenuItemClick(tray.MenuItem menuItem) {
    switch (menuItem.key) {
      case _showWindowMenuKey:
        // “显示主窗口”与单击托盘图标保持相同行为。
        unawaited(showMainWindow());
        break;
      case _exitApplicationMenuKey:
        // 托盘退出必须先显示窗口，确保用户能看到退出中遮罩。
        unawaited(_exitFromTray());
        break;
    }
  }

  /// 从托盘菜单恢复窗口后强制执行安全退出。
  Future<void> _exitFromTray() async {
    // 先恢复窗口，让退出中遮罩和资源清理状态对用户可见。
    await showMainWindow();
    // 托盘明确退出不再读取“最小化到托盘”设置。
    await onExitRequested();
  }
}
