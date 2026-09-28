import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app/bilidown_app.dart';
import 'core/logging/app_debug_log.dart';
import 'core/logging/crash_recovery_service.dart';
import 'features/downloads/application/lifecycle/background_download_recovery.dart';
import 'services/image_cache/cover_cache_manager.dart';

/// 桌面端窗口最小高度，避免用户把窗口压到页面无法操作。
const double _desktopMinimumWindowHeight = 360;

/// 随包原生组件许可证 asset 清单。
const List<_NativeRuntimeLicenseAsset>
_nativeRuntimeLicenseAssets = <_NativeRuntimeLicenseAsset>[
  _NativeRuntimeLicenseAsset(
    label: 'Aria2Android GPL-3.0-only',
    assetPath: 'assets/licenses/aria2android-gpl-3.0.txt',
    sourceUrl: 'https://github.com/devgianlu/Aria2Android/blob/master/LICENSE',
  ),
  _NativeRuntimeLicenseAsset(
    label: 'aria2 GPL-2.0-or-later',
    assetPath: 'assets/licenses/aria2-gpl-2.0.txt',
    sourceUrl: 'https://github.com/aria2/aria2/blob/master/COPYING',
  ),
  _NativeRuntimeLicenseAsset(
    label: 'FFmpegKit LGPL-3.0-or-later',
    assetPath: 'assets/licenses/ffmpeg-kit-builders-license.txt',
    sourceUrl:
        'https://github.com/akashskypatel/ffmpeg-kit-builders/blob/master/LICENSE',
  ),
  _NativeRuntimeLicenseAsset(
    label: 'FFmpeg CLI LGPL-3.0-or-later',
    assetPath: 'assets/licenses/lgpl-3.0.txt',
    sourceUrl: 'https://www.gnu.org/licenses/lgpl-3.0.txt',
  ),
];

/// 初始化跨 isolate 通信、桌面关闭拦截和 Riverpod 应用根节点。
Future<void> main() async {
  // Zone 捕获没有进入 FlutterError 或 PlatformDispatcher 的异步未处理异常。
  await runZonedGuarded<Future<void>>(_runApplication, (
    Object error,
    StackTrace stackTrace,
  ) {
    AppDebugLog.app('Unhandled zone error=$error');
    unawaited(CrashRecoveryService.record(error, stackTrace));
  });
}

/// 在统一异常 Zone 内完成插件、崩溃恢复和应用根节点初始化。
Future<void> _runApplication() async {
  // Flutter 插件在应用启动前需要完成绑定初始化。
  WidgetsFlutterBinding.ensureInitialized();
  // 先读取上次异常，再安装本次处理器，避免旧标记被误判为当前崩溃。
  await CrashRecoveryService.initialize();
  final previousFlutterErrorHandler = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    // 框架布局、绘制和回调异常写入下次启动恢复标记。
    AppDebugLog.app('Unhandled Flutter error=${details.exception}');
    unawaited(
      CrashRecoveryService.record(
        details.exception,
        details.stack ?? StackTrace.current,
      ),
    );
    // Debug 模式继续使用 Flutter 默认控制台展示和错误界面。
    previousFlutterErrorHandler?.call(details);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    // 平台消息和根 isolate 异步异常由分发器兜底记录。
    AppDebugLog.app('Unhandled platform error=$error');
    unawaited(CrashRecoveryService.record(error, stackTrace));
    return true;
  };
  // 网络封面组件构建前解析自定义 covers 目录并初始化唯一缓存管理器。
  await CoverCacheManager.initialize();
  // 将随包原生组件也登记到 Flutter 许可证页，避免只展示 Dart 依赖许可证。
  _registerNativeRuntimeLicenses();
  // Android 前台服务需要在 runApp 前注册主 isolate 通信端口。
  FlutterForegroundTask.initCommunicationPort();
  // 桌面端必须拦截关闭请求，等待 aria2 和媒体进程完成清理后再销毁窗口。
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // window_manager 初始化完成后才能启用关闭保护。
    await windowManager.ensureInitialized();
    // 只限制桌面窗口高度，移动端 viewport 由系统和设备方向自然决定。
    await windowManager.setMinimumSize(
      const Size(0, _desktopMinimumWindowHeight),
    );
    // 阻止系统立即结束进程，由应用根组件执行可等待的退出流程。
    await windowManager.setPreventClose(true);
  }
  // ProviderScope 保存主题、解析、登录和下载等应用级状态。
  runApp(
    const _WindowsAccessibilityBridgeGuard(
      child: ProviderScope(child: BiliDownApp()),
    ),
  );
  // 首帧展示后再注册非首屏必需服务，减少 Android 启动白屏等待时间。
  unawaited(_initializeDeferredStartupServices());
}

/// 向 Flutter 原生许可证页追加随包 aria2 和 FFmpeg 组件说明。
void _registerNativeRuntimeLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final licenseAsset in _nativeRuntimeLicenseAssets) {
      // Flutter 许可证页无法点击链接，但可以展示随包 LICENSE 原文和可复制来源地址。
      final licenseText = await rootBundle.loadString(licenseAsset.assetPath);
      yield LicenseEntryWithLineBreaks(<String>[
        'BiliDown 原生运行时组件',
        licenseAsset.label,
      ], '来源：${licenseAsset.sourceUrl}\n\n$licenseText');
    }
  });
}

/// 原生组件许可证 asset 配置。
final class _NativeRuntimeLicenseAsset {
  /// 创建一条可登记到 Flutter 许可证页的本地许可证记录。
  const _NativeRuntimeLicenseAsset({
    required this.label,
    required this.assetPath,
    required this.sourceUrl,
  });

  /// Flutter 许可证页中的组件名称。
  final String label;

  /// 许可证全文资源路径。
  final String assetPath;

  /// 许可证上游来源页面。
  final String sourceUrl;
}

/// 初始化不影响首屏展示的后台能力。
Future<void> _initializeDeferredStartupServices() async {
  try {
    // 移动端后台恢复只负责系统兜底调度，不需要阻塞用户看到主界面。
    await initializeBackgroundDownloadRecovery();
  } catch (error, stackTrace) {
    // 启动后服务注册失败要记录诊断日志，但不能让应用回到启动白屏或崩溃。
    AppDebugLog.app('Deferred startup service failed error=$error');
    unawaited(CrashRecoveryService.record(error, stackTrace));
  }
}

/// Windows 端关闭 Flutter 语义树提交，规避引擎 AXTree 桥接错误刷屏。
final class _WindowsAccessibilityBridgeGuard extends StatelessWidget {
  /// 创建平台限定的无障碍桥接保护层。
  const _WindowsAccessibilityBridgeGuard({required this.child});

  /// 实际应用根组件。
  final Widget child;

  /// 根据当前桌面平台决定是否排除整棵语义子树。
  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) return child;
    // Windows Flutter 引擎在热重启、刷新和大列表更新时可能反复提交过期 AXTree 节点。
    return ExcludeSemantics(child: child);
  }
}
