import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../core/logging/app_debug_log.dart';

/// 启动 aria2c 所需的路径、RPC 和数据文件配置。
final class Aria2LaunchConfig {
  /// 创建一份完整且不可变的进程启动配置。
  const Aria2LaunchConfig({
    required this.executablePath,
    required this.port,
    required this.secret,
    required this.downloadDirectory,
    required this.sessionFile,
    required this.logFile,
    required this.maxOverallDownloadLimitMegabytesPerSecond,
    this.caCertificatePath,
  });

  /// 从前台服务持久化的 JSON 数据恢复启动配置。
  factory Aria2LaunchConfig.fromJson(Map<String, Object?> json) {
    // 字段由应用内部生成，缺失时立即暴露配置不完整问题。
    return Aria2LaunchConfig(
      executablePath: json['executablePath']! as String,
      port: json['port']! as int,
      secret: json['secret']! as String,
      downloadDirectory: json['downloadDirectory']! as String,
      sessionFile: json['sessionFile']! as String,
      logFile: json['logFile']! as String,
      maxOverallDownloadLimitMegabytesPerSecond:
          json['maxOverallDownloadLimitMegabytesPerSecond']! as int,
      caCertificatePath: json['caCertificatePath'] as String?,
    );
  }

  /// aria2c 可执行文件绝对路径。
  final String executablePath;

  /// 仅监听本机回环地址的 RPC 端口。
  final int port;

  /// JSON-RPC 鉴权密钥。
  final String secret;

  /// aria2 默认下载目录。
  final String downloadDirectory;

  /// 记录未完成任务的会话文件。
  final String sessionFile;

  /// 记录 aria2 警告与错误的日志文件。
  final String logFile;

  /// aria2 全局下载速度上限，单位为 MB/s。
  final int maxOverallDownloadLimitMegabytesPerSecond;

  /// Android 静态 OpenSSL 使用的系统根证书合并文件；桌面端保持为空。
  final String? caCertificatePath;

  /// 将配置转换为安全、可恢复下载的 aria2 命令行参数。
  List<String> get arguments => [
    '--enable-rpc=true',
    '--rpc-listen-all=false',
    '--rpc-listen-port=$port',
    '--rpc-secret=$secret',
    '--rpc-allow-origin-all=false',
    // 应用只下载 HTTP(S) 资源，关闭 BT/DHT 入站能力以免桌面防火墙误判为服务器。
    '--enable-dht=false',
    '--enable-dht6=false',
    '--bt-enable-lpd=false',
    '--enable-peer-exchange=false',
    '--check-certificate=true',
    if (caCertificatePath != null) '--ca-certificate=$caCertificatePath',
    '--dir=$downloadDirectory',
    '--input-file=$sessionFile',
    '--save-session=$sessionFile',
    '--save-session-interval=30',
    '--continue=true',
    '--max-overall-download-limit=${maxOverallDownloadLimitMegabytesPerSecond}M',
    '--auto-file-renaming=false',
    '--allow-overwrite=true',
    '--file-allocation=none',
    '--console-log-level=warn',
    '--summary-interval=0',
    '--log=$logFile',
  ];

  /// 转换为可跨 isolate 保存的 JSON 对象。
  Map<String, Object?> toJson() => {
    'executablePath': executablePath,
    'port': port,
    'secret': secret,
    'downloadDirectory': downloadDirectory,
    'sessionFile': sessionFile,
    'logFile': logFile,
    'maxOverallDownloadLimitMegabytesPerSecond':
        maxOverallDownloadLimitMegabytesPerSecond,
    'caCertificatePath': caCertificatePath,
  };
}

/// aria2 控制器发现底层服务不可用时通知运行时清理 RPC 客户端。
typedef Aria2RuntimeInvalidationHandler = void Function(String reason);

/// 不同平台启动和停止 aria2 进程的统一接口。
abstract interface class Aria2ProcessController {
  /// 注册底层进程失效回调，运行时据此丢弃已缓存的 RPC 客户端。
  void setRuntimeInvalidationHandler(Aria2RuntimeInvalidationHandler? handler);

  /// 返回控制器明确知道当前服务不可用的状态，未知时返回 false 交给 RPC 探测兜底。
  Future<bool> isKnownUnavailable();

  /// 按给定配置启动进程。
  Future<void> start(Aria2LaunchConfig config);

  /// 停止进程并释放输出流资源。
  Future<void> stop();
}

/// 桌面端直接创建并管理 aria2 子进程。
final class LocalAria2ProcessController implements Aria2ProcessController {
  /// 当前正在运行的 aria2 子进程。
  Process? _process;

  /// 标准输出订阅，持续消费数据以防管道阻塞。
  StreamSubscription<List<int>>? _stdoutSubscription;

  /// 标准错误订阅，持续消费数据以防管道阻塞。
  StreamSubscription<List<int>>? _stderrSubscription;

  /// 进程自然退出时通知 Runtime 丢弃旧 RPC 端口。
  Aria2RuntimeInvalidationHandler? _onRuntimeInvalidated;

  /// 保存运行时失效监听，桌面端进程退出回调会使用它清理 RPC 客户端。
  @override
  void setRuntimeInvalidationHandler(Aria2RuntimeInvalidationHandler? handler) {
    _onRuntimeInvalidated = handler;
  }

  /// 桌面端可能复用上次残留的外部 aria2 进程，不能仅凭本控制器没有 _process 就判定失效。
  @override
  Future<bool> isKnownUnavailable() async => false;

  /// 启动本地 aria2 子进程，重复调用时复用现有进程。
  @override
  Future<void> start(Aria2LaunchConfig config) async {
    // 已存在进程时不重复创建。
    if (_process != null) {
      AppDebugLog.aria2('Desktop process already running.');
      return;
    }
    // 记录不包含 RPC 密钥的桌面进程启动信息。
    AppDebugLog.aria2(
      'Desktop process starting executable=${config.executablePath} '
      'port=${config.port}',
    );
    // 使用普通模式启动，便于后续监听退出状态并主动终止。
    final process = await Process.start(
      config.executablePath,
      config.arguments,
      mode: ProcessStartMode.normal,
    );
    // 保存进程引用供 stop 和退出回调使用。
    _process = process;
    // 记录操作系统进程 ID，方便任务管理器和日志交叉确认。
    AppDebugLog.aria2('Desktop process started pid=${process.pid}');
    // 消费两个输出管道，避免 aria2 因缓冲区写满而挂起。
    _stdoutSubscription = process.stdout.listen((List<int> bytes) {
      // 标准输出仅在 Debug 模式脱敏后转发到 Flutter 控制台。
      _logAria2ProcessOutput('stdout', bytes);
    });
    _stderrSubscription = process.stderr.listen((List<int> bytes) {
      // 标准错误通常包含启动失败根因，需要提供给调试截图。
      _logAria2ProcessOutput('stderr', bytes);
    });
    // 异步监听自然退出，不阻塞 start 返回。
    unawaited(
      process.exitCode.then((int exitCode) {
        // 无论主动停止还是异常退出都记录最终返回码。
        AppDebugLog.aria2(
          'Desktop process exited pid=${process.pid} code=$exitCode',
        );
        // 仅清理当前同一进程，避免旧回调覆盖后来启动的新进程。
        if (identical(_process, process)) {
          _process = null;
          // 主动通知 Runtime 清理旧 RPC 客户端，避免下一次 addUri 命中失效端口。
          _onRuntimeInvalidated?.call(
            'desktop process exited pid=${process.pid} code=$exitCode',
          );
        }
      }),
    );
  }

  /// 终止本地进程并取消所有输出订阅。
  @override
  Future<void> stop() async {
    // 记录桌面进程清理开始，热重启时可以与异常退出区分。
    AppDebugLog.aria2('Desktop process stop requested.');
    // 先摘除共享引用，防止停止期间被视为仍可用。
    final process = _process;
    _process = null;
    // 只有真实存在的进程才需要发送终止信号并等待退出。
    if (process != null) {
      // 请求子进程退出。
      process.kill();
      // 最多等待三秒，超时后继续释放 Flutter 侧资源。
      await process.exitCode.timeout(
        const Duration(seconds: 3),
        onTimeout: () => -1,
      );
    }
    // 取消标准输出和错误流订阅。
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    // 清空订阅引用，允许控制器后续重新启动。
    _stdoutSubscription = null;
    _stderrSubscription = null;
    // 桌面进程和输出订阅已经全部释放。
    AppDebugLog.aria2('Desktop process stopped.');
  }
}

/// Android 通过前台服务维持 aria2 子进程和网络锁。
final class AndroidAria2ProcessController implements Aria2ProcessController {
  /// 跨 isolate 保存启动配置时使用的固定键。
  static const String _configKey = 'aria2LaunchConfig';

  /// Android 前台服务通知使用 Manifest 中声明的单色小图标。
  static const NotificationIcon _notificationIcon = NotificationIcon(
    metaDataName: 'com.bilidown.app.NOTIFICATION_ICON',
  );

  /// Android 前台服务运行在独立 isolate，当前插件链路无法直接回调主 isolate。
  @override
  void setRuntimeInvalidationHandler(
    Aria2RuntimeInvalidationHandler? handler,
  ) {}

  /// Android 的 aria2 只由前台服务承载，服务停止即可确定旧 RPC 客户端不可复用。
  @override
  Future<bool> isKnownUnavailable() async {
    return !await FlutterForegroundTask.isRunningService;
  }

  /// 按需请求通知权限、保存配置并启动下载前台服务。
  @override
  Future<void> start(Aria2LaunchConfig config) async {
    // Android 13+ 的通知权限只控制通知栏可见性，不应成为下载能力的硬门禁。
    var permission = await FlutterForegroundTask.checkNotificationPermission();
    // 用户首次真正开始下载时再请求权限，避免应用启动阶段无上下文弹窗。
    if (permission != NotificationPermission.granted) {
      permission = await FlutterForegroundTask.requestNotificationPermission();
    }
    // 用户拒绝后继续启动前台服务；系统仍会在任务管理界面展示活动服务。
    if (permission != NotificationPermission.granted) {
      AppDebugLog.aria2(
        'Android notification permission denied; download service continues without drawer notifications.',
      );
    }

    // 配置下载通知渠道、唤醒锁以及 Wi-Fi 锁策略。
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'bili_download_service',
        channelName: 'BiliDown 下载服务',
        channelDescription: '显示正在进行的 B 站视频下载任务。',
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
        allowWifiLock: true,
        // 用户从最近任务关闭应用时同步销毁前台服务，由 onDestroy 终止 aria2。
        stopWithTask: true,
      ),
    );

    // 将配置序列化保存，前台 isolate 启动后据此创建 aria2 进程。
    await FlutterForegroundTask.saveData(
      key: _configKey,
      value: jsonEncode(config.toJson()),
    );
    // 已有服务可能持有旧配置，先停止再使用新配置重启。
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
    // 启动 dataSync 类型前台服务并注册顶层回调入口。
    final result = await FlutterForegroundTask.startService(
      serviceId: 2107,
      serviceTypes: const [ForegroundServiceTypes.dataSync],
      notificationTitle: 'BiliDown 正在运行',
      notificationText: '下载服务已启动',
      notificationIcon: _notificationIcon,
      callback: aria2ForegroundCallback,
    );
    // 插件返回失败对象时转换成下载进程异常并保留底层错误。
    if (result case ServiceRequestFailure(:final error)) {
      throw Aria2ProcessException(
        'Unable to start Android foreground service.',
        error,
      );
    }
  }

  /// 停止仍在运行的 Android 下载前台服务。
  @override
  Future<void> stop() async {
    // 服务未运行时无需调用停止接口。
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}

/// Android 前台 isolate 的固定入口，必须避免被树摇优化删除。
@pragma('vm:entry-point')
void aria2ForegroundCallback() {
  // 为插件注册实际管理 aria2 子进程的任务处理器。
  FlutterForegroundTask.setTaskHandler(_Aria2ForegroundTaskHandler());
}

/// 运行在 Android 前台服务 isolate 中的 aria2 进程处理器。
final class _Aria2ForegroundTaskHandler extends TaskHandler {
  /// 前台 isolate 持有的 aria2 子进程。
  Process? _process;

  /// 标准输出订阅，防止输出管道阻塞。
  StreamSubscription<List<int>>? _stdoutSubscription;

  /// 标准错误订阅，防止错误管道阻塞。
  StreamSubscription<List<int>>? _stderrSubscription;

  /// 前台服务启动时读取配置并创建 aria2 进程。
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // 记录 Android 前台 isolate 的启动入口。
    AppDebugLog.aria2('Android foreground process starting.');
    // 从插件共享存储读取主 isolate 保存的 JSON 配置。
    final encoded = await FlutterForegroundTask.getData<String>(
      key: AndroidAria2ProcessController._configKey,
    );
    // 配置缺失时无法安全启动进程，直接报告错误。
    if (encoded == null) {
      throw const Aria2ProcessException('Missing Android aria2 launch config.');
    }
    // 解析动态 JSON Map 并恢复强类型启动配置。
    final config = Aria2LaunchConfig.fromJson(
      (jsonDecode(encoded) as Map).map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
    // 在前台服务 isolate 中启动 aria2 子进程。
    final process = await Process.start(
      config.executablePath,
      config.arguments,
      mode: ProcessStartMode.normal,
    );
    // 保存引用并持续消费输出，供服务销毁时统一清理。
    _process = process;
    _stdoutSubscription = process.stdout.listen((List<int> bytes) {
      // 前台 isolate 标准输出使用同一脱敏日志前缀。
      _logAria2ProcessOutput('android-stdout', bytes);
    });
    _stderrSubscription = process.stderr.listen((List<int> bytes) {
      // Android 原生进程错误直接转发到 Debug 控制台。
      _logAria2ProcessOutput('android-stderr', bytes);
    });
    // 记录前台服务创建的 aria2 进程 ID。
    AppDebugLog.aria2('Android foreground process started pid=${process.pid}');
    // 更新通知，告诉用户 aria2 进程已经成功创建。
    FlutterForegroundTask.updateService(
      notificationTitle: 'BiliDown 下载服务',
      notificationText: 'aria2 已连接',
      notificationIcon: AndroidAria2ProcessController._notificationIcon,
    );
  }

  /// 当前服务不需要周期事件，下载进度由主 isolate 通过 RPC 轮询。
  @override
  void onRepeatEvent(DateTime timestamp) {}

  /// 前台服务销毁时终止 aria2 并释放输出订阅。
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // 记录前台服务销毁来源，区分系统超时和正常停止。
    AppDebugLog.aria2('Android foreground process stopping timeout=$isTimeout');
    // 先摘除进程引用，避免重复销毁。
    final process = _process;
    _process = null;
    // 发送终止信号并取消两个输出流订阅。
    process?.kill();
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    // Android 前台进程清理完成。
    AppDebugLog.aria2('Android foreground process stopped.');
  }
}

/// 把 aria2 子进程输出按行转换为脱敏 Debug 日志。
void _logAria2ProcessOutput(String channel, List<int> bytes) {
  // 原生输出可能包含非 UTF-8 字节，允许替换异常字符避免日志处理失败。
  final text = utf8.decode(bytes, allowMalformed: true).trim();
  // 空白输出不写入控制台。
  if (text.isEmpty) return;
  // 单次管道数据可能包含多行，逐行添加进程通道名称。
  for (final line in const LineSplitter().convert(text)) {
    // AppDebugLog 会再次清理 URL、token 和 Cookie。
    AppDebugLog.aria2('process[$channel] $line');
  }
}

/// aria2 进程或 Android 前台服务启动失败异常。
final class Aria2ProcessException implements Exception {
  /// 保存可读消息和可选底层原因。
  const Aria2ProcessException(this.message, [this.cause]);

  /// 错误说明。
  final String message;

  /// 插件或系统返回的底层异常。
  final Object? cause;

  /// 输出带异常类型的诊断信息。
  @override
  String toString() => 'Aria2ProcessException: $message';
}
