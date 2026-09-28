/// 下载任务从排队到结束的统一状态。
enum DownloadStatus {
  queued,
  resolving,
  downloading,
  paused,
  completed,
  failed,
  canceled,
}

/// 提交给下载引擎的不可变任务参数。
final class DownloadRequest {
  /// 创建包含任务标识、地址、保存位置和请求头的下载请求。
  const DownloadRequest({
    required this.taskId,
    required this.url,
    required this.destinationPath,
    this.backupUrls = const <Uri>[],
    this.headers = const {},
  });

  /// 业务层生成的稳定任务标识。
  final String taskId;

  /// 需要下载的远程资源地址。
  final Uri url;

  /// 主地址传输失败时可由支持的下载后端继续尝试的备用地址。
  final List<Uri> backupUrls;

  /// 下载完成后的目标文件绝对路径。
  final String destinationPath;

  /// 访问 B 站资源时需要透传的 HTTP 请求头。
  final Map<String, String> headers;
}

/// 下载引擎向界面和持久化层发送的状态事件。
final class DownloadEvent {
  /// 创建一次任务状态快照。
  const DownloadEvent({
    required this.taskId,
    required this.status,
    this.downloadedBytes = 0,
    this.totalBytes,
    this.downloadSpeedBytesPerSecond = 0,
    this.errorCode,
    this.errorMessage,
  });

  /// 事件对应的业务任务标识。
  final String taskId;

  /// 当前下载状态。
  final DownloadStatus status;

  /// 已经写入本地的字节数。
  final int downloadedBytes;

  /// 服务端声明的总字节数，未知时为空。
  final int? totalBytes;

  /// 当前网络下载速度，单位为字节每秒，未知或非下载阶段为零。
  final int downloadSpeedBytesPerSecond;

  /// 下载后端提供的稳定错误码，例如 aria2 tellStatus.errorCode。
  final String? errorCode;

  /// 下载失败时的错误说明。
  final String? errorMessage;
}

/// 所有下载后端必须实现的生命周期与任务控制接口。
abstract interface class DownloadEngine {
  /// 监听任务状态和进度变化。
  Stream<DownloadEvent> watchEvents();

  /// 新建并启动一项下载任务。
  Future<void> enqueue(DownloadRequest request);

  /// 暂停指定任务。
  Future<void> pause(String taskId);

  /// 恢复指定任务。
  Future<void> resume(String taskId);

  /// 取消指定任务并清理引擎状态。
  Future<void> cancel(String taskId);

  /// 从本地缓存恢复未结束任务。
  Future<void> restore();

  /// 释放进程、定时器和事件流资源。
  Future<void> dispose();
}
