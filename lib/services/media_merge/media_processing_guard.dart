import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../core/logging/app_debug_log.dart';

/// 在媒体合并期间维持平台后台执行能力的统一接口。
abstract interface class MediaProcessingGuard {
  /// 合并前申请必要的平台资源。
  Future<void> start();

  /// 合并结束后恢复通知并释放平台资源。
  Future<void> stop();
}

/// 不需要额外后台保活的平台使用的空实现。
final class NoopMediaProcessingGuard implements MediaProcessingGuard {
  /// 创建无状态守卫。
  const NoopMediaProcessingGuard();

  /// 桌面和 iOS 当前不需要额外前台服务。
  @override
  Future<void> start() async {}

  /// 空实现没有资源需要释放。
  @override
  Future<void> stop() async {}
}

/// Android 合并期间创建或复用前台服务，避免任务被系统挂起。
final class AndroidMediaProcessingGuard implements MediaProcessingGuard {
  /// Android 前台服务通知使用 Manifest 中声明的单色小图标。
  static const NotificationIcon _notificationIcon = NotificationIcon(
    metaDataName: 'com.bilidown.app.NOTIFICATION_ICON',
  );

  /// 当前守卫是否自行启动了媒体处理服务。
  bool _ownsService = false;

  /// 当前守卫是否复用了已存在的下载服务。
  bool _reusedDownloadService = false;

  /// 按需请求通知权限并启动或复用 Android 前台服务。
  @override
  Future<void> start() async {
    // Android 13+ 的通知权限只影响通知栏展示，不能阻断已经下载完成的媒体合并。
    var permission = await FlutterForegroundTask.checkNotificationPermission();
    // 仅在真正进入合并阶段时请求，避免首次启动无业务上下文弹窗。
    if (permission != NotificationPermission.granted) {
      permission = await FlutterForegroundTask.requestNotificationPermission();
    }
    // 拒绝权限后仍由前台服务维持处理，系统会在任务管理界面保留可见入口。
    if (permission != NotificationPermission.granted) {
      AppDebugLog.ffmpeg(
        'Android notification permission denied; media processing continues without drawer notifications.',
      );
    }

    // 配置媒体处理通知渠道和 CPU 唤醒锁，不需要额外 Wi-Fi 锁。
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'bili_media_processing',
        channelName: 'BiliDown 媒体处理',
        channelDescription: '显示音视频合并进度。',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );

    // aria2 下载服务已运行时复用它，避免 Android 同时维护两个服务实例。
    if (await FlutterForegroundTask.isRunningService) {
      // 临时把现有通知更新为音视频合并状态。
      await FlutterForegroundTask.updateService(
        notificationTitle: 'BiliDown 正在合并',
        notificationText: '正在合并音视频，请勿关闭应用',
        notificationIcon: _notificationIcon,
      );
      // 记录所有权，停止时只恢复通知而不能结束下载服务。
      _ownsService = false;
      _reusedDownloadService = true;
      return;
    }
    // 没有现有服务时，创建 mediaProcessing 类型前台服务。
    final result = await FlutterForegroundTask.startService(
      serviceId: 2108,
      serviceTypes: const [ForegroundServiceTypes.mediaProcessing],
      notificationTitle: 'BiliDown 正在合并',
      notificationText: '正在合并音视频，请勿关闭应用',
      notificationIcon: _notificationIcon,
      callback: mediaProcessingForegroundCallback,
    );
    // 插件报告失败时中止合并，避免误以为已经获得后台能力。
    if (result case ServiceRequestFailure(:final error)) {
      throw StateError('Unable to start media processing service: $error');
    }
    // 标记服务由当前守卫拥有，合并结束时需要主动停止。
    _ownsService = true;
    _reusedDownloadService = false;
  }

  /// 根据服务所有权停止媒体服务或恢复下载通知。
  @override
  Future<void> stop() async {
    // 自行启动的媒体处理服务应在合并结束后停止。
    if (_ownsService && await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
      // 复用下载服务时不能停止服务，只恢复 aria2 下载通知。
    } else if (_reusedDownloadService &&
        await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'BiliDown 下载服务',
        notificationText: 'aria2 已连接',
        notificationIcon: _notificationIcon,
      );
    }
    // 清空所有权状态，允许同一守卫处理下一项合并任务。
    _ownsService = false;
    _reusedDownloadService = false;
  }
}

/// Android 媒体处理前台 isolate 入口，必须保留给原生回调调用。
@pragma('vm:entry-point')
void mediaProcessingForegroundCallback() {
  // 注册仅负责维持服务生命周期的空任务处理器。
  FlutterForegroundTask.setTaskHandler(_MediaProcessingTaskHandler());
}

/// 媒体合并实际在主 isolate 执行，此处理器只承接前台服务生命周期。
final class _MediaProcessingTaskHandler extends TaskHandler {
  /// 服务启动时无需创建额外任务。
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  /// 媒体合并不依赖周期事件。
  @override
  void onRepeatEvent(DateTime timestamp) {}

  /// 所有合并资源由主 isolate 清理，此处无需额外处理。
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
