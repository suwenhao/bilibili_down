import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/application/app_settings_controller.dart';
import '../logging/app_debug_log.dart';

/// 应用下载状态通知的稳定类型。
enum AppNotificationKind { downloadCompleted, downloadFailed }

/// 隔离通知插件平台调用，业务层和测试只依赖该接口。
abstract interface class AppNotificationClient {
  /// 初始化全部已支持平台并创建 Android 通知通道。
  Future<void> initialize();

  /// 在需要通知时请求当前平台的提醒权限。
  Future<void> requestPermissions();

  /// 显示一条下载状态通知。
  Future<void> show({
    required int id,
    required String title,
    required String body,
  });
}

/// 使用 flutter_local_notifications 实现跨平台通知。
final class FlutterLocalNotificationClient implements AppNotificationClient {
  /// 创建并持有唯一插件实例。
  FlutterLocalNotificationClient({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Android 下载状态通知通道 ID，发布后保持稳定。
  static const String channelId = 'bilidown_download_status';

  /// Android 通知中心展示的通道名称。
  static const String channelName = '下载状态';

  /// Windows 未打包 EXE 使用的稳定应用标识。
  static const String windowsAppUserModelId = 'BiliDown.Desktop';

  /// Windows 通知注册使用的固定 GUID，升级时不得随机变化。
  static const String windowsGuid = 'a9c356c1-95e9-4f9b-a483-197e68a06a2e';

  /// Android 通知栏小图标资源名，必须位于 drawable 且不带文件扩展名。
  static const String androidNotificationIcon = 'ic_notification';

  /// 平台通知插件实例。
  final FlutterLocalNotificationsPlugin _plugin;

  /// 初始化 Android、Apple、Linux 和 Windows 通知后端。
  @override
  Future<void> initialize() async {
    // 初始化阶段不主动请求权限，权限由用户设置开启状态决定。
    final settings = InitializationSettings(
      android: AndroidInitializationSettings(androidNotificationIcon),
      iOS: IOSInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      linux: LinuxInitializationSettings(
        defaultActionName: '打开 BiliDown',
        defaultIcon: AssetsLinuxIcon('assets/images/tray_icon.png'),
      ),
      windows: WindowsInitializationSettings(
        appName: 'BiliDown',
        appUserModelId: windowsAppUserModelId,
        guid: windowsGuid,
      ),
    );
    // 插件初始化失败由上层统一吞掉，不能阻断下载状态机。
    await _plugin.initialize(settings: settings);
    // Android 通道必须在首条通知前创建，重复创建会安全复用已有用户设置。
    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: '显示下载完成、失败和后台任务状态。',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// 请求 Android 13+、iOS 和 macOS 的通知权限。
  @override
  Future<void> requestPermissions() async {
    // Android 旧版本会直接返回，Android 13+ 展示系统权限弹窗。
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    // iOS 只请求提醒和声音，本应用不使用角标。
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: false, sound: true);
    // macOS 权限模型与 iOS 分开请求，桌面首次开启时由系统确认。
    await _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: false, sound: true);
  }

  /// 使用各平台原生通知样式显示下载状态。
  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) {
    // 同一详情同时覆盖五个平台，未运行的平台配置不会产生调用。
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: '显示下载完成、失败和后台任务状态。',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        threadIdentifier: 'bilidown_downloads',
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        threadIdentifier: 'bilidown_downloads',
      ),
      linux: LinuxNotificationDetails(),
      windows: WindowsNotificationDetails(),
    );
    // 固定 ID 使同类通知更新而不是无限堆积。
    return _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}

/// 提供应用级下载通知服务并监听设置开启后的权限请求。
final appNotificationServiceProvider = Provider<AppNotificationService>((
  Ref ref,
) {
  // 服务读取实时设置，使关闭开关后下一条通知立即停止。
  final service = AppNotificationService(
    FlutterLocalNotificationClient(),
    () => ref.read(appSettingsControllerProvider).systemSoundEnabled,
  );
  // 设置恢复和用户重新开启时初始化后端并请求权限。
  ref.listen(appSettingsControllerProvider, (previous, next) {
    final newlyEnabled =
        next.systemSoundEnabled &&
        (previous == null || !previous.systemSoundEnabled);
    if (newlyEnabled) unawaited(service.initializeAndRequestPermissions());
  }, fireImmediately: true);
  return service;
});

/// 受用户系统提示开关控制的下载通知业务服务。
final class AppNotificationService {
  /// 创建可测试的通知服务。
  AppNotificationService(this._client, this._isEnabled);

  /// 平台通知客户端。
  final AppNotificationClient _client;

  /// 实时读取系统提示开关。
  final bool Function() _isEnabled;

  /// 唯一初始化任务，快速连续事件复用相同 Future。
  Future<void>? _initialization;

  /// 初始化插件并请求当前平台权限。
  Future<void> initializeAndRequestPermissions() async {
    try {
      // 初始化只执行一次，失败时清空引用允许后续重新开启重试。
      _initialization ??= _client.initialize();
      await _initialization;
      await _client.requestPermissions();
    } catch (error) {
      // 通知权限或平台注册失败不能影响下载，只输出调试诊断。
      _initialization = null;
      AppDebugLog.notification('初始化失败: $error');
    }
  }

  /// 通知一整轮下载全部成功。
  Future<void> showBatchCompleted() => _showIfEnabled(
    kind: AppNotificationKind.downloadCompleted,
    title: '下载完成',
    body: '本轮下载任务已全部完成。',
  );

  /// 通知本次数据库快照中新出现的失败任务数量。
  Future<void> showTasksFailed(int count) => _showIfEnabled(
    kind: AppNotificationKind.downloadFailed,
    title: '下载失败',
    body: count == 1 ? '有 1 个任务下载失败，请打开应用查看。' : '有 $count 个任务下载失败，请打开应用查看。',
  );

  /// 设置开启时初始化后端并显示一条去重通知。
  Future<void> _showIfEnabled({
    required AppNotificationKind kind,
    required String title,
    required String body,
  }) async {
    // 设置关闭时不初始化插件、不请求权限也不发送通知。
    if (!_isEnabled()) return;
    try {
      // 首次状态事件可能早于权限初始化完成，需要等待同一初始化任务。
      _initialization ??= _client.initialize();
      await _initialization;
      // 两类通知使用稳定 ID，相同状态只更新现有系统通知。
      final id = switch (kind) {
        AppNotificationKind.downloadCompleted => 1001,
        AppNotificationKind.downloadFailed => 1002,
      };
      await _client.show(id: id, title: title, body: body);
    } catch (error) {
      // 系统通知失败不允许把已经完成的任务改成失败。
      AppDebugLog.notification('显示失败: $error');
    }
  }
}
