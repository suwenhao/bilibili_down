import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:path/path.dart' as p;

import '../download_engine.dart';
import 'background_download_client.dart';

/// 使用平台系统后台传输能力实现统一下载接口，iOS 固定使用该实现。
final class SystemDownloadEngine implements DownloadEngine {
  /// 创建系统下载引擎并立即监听原生任务更新。
  SystemDownloadEngine({BackgroundDownloadClient? client})
    : _client = client ?? BackgroundDownloaderClient() {
    // 在调用 restore 前建立监听，避免遗漏后台恢复过程重新投递的事件。
    _updateSubscription = _client.watchUpdates().listen(_handleUpdate);
  }

  /// 系统下载任务使用的固定插件分组，避免接收其他模块的传输事件。
  static const String taskGroup = 'bilidown.system';

  /// 隔离 background_downloader 单例调用的客户端。
  final BackgroundDownloadClient _client;

  /// 向界面和任务协调器广播统一下载事件。
  final StreamController<DownloadEvent> _events =
      StreamController<DownloadEvent>.broadcast();

  /// 保存插件任务更新流订阅，释放引擎时必须取消。
  late final StreamSubscription<TaskUpdate> _updateSubscription;

  /// 缓存每个任务最近一次已下载字节数，状态事件可继续携带进度。
  final Map<String, int> _downloadedBytesByTaskId = <String, int>{};

  /// 缓存每个任务最近一次总字节数。
  final Map<String, int> _totalBytesByTaskId = <String, int>{};

  /// 缓存每个任务最近一次网络速度，单位统一为字节每秒。
  final Map<String, int> _downloadSpeedByTaskId = <String, int>{};

  /// 标记引擎是否已经释放。
  bool _disposed = false;

  /// 返回系统下载状态与进度广播流。
  @override
  Stream<DownloadEvent> watchEvents() => _events.stream;

  /// 创建精确目标路径的系统后台下载任务并提交到原生队列。
  @override
  Future<void> enqueue(DownloadRequest request) async {
    // 已释放的引擎不能继续提交原生任务。
    _ensureNotDisposed();
    // 系统下载器同样只能处理 HTTP(S) 媒体地址，解析异常不能传给原生层。
    _ensureDownloadableUrl(request.url);
    // 目标目录必须在系统下载任务启动前存在。
    final destinationDirectory = Directory(p.dirname(request.destinationPath));
    // 递归创建目录，避免原生下载完成后无法移动到目标位置。
    await destinationDirectory.create(recursive: true);
    // 使用 UriDownloadTask 保留业务层传入的精确绝对文件路径。
    final task = UriDownloadTask(
      taskId: request.taskId,
      url: request.url.toString(),
      filename: p.basename(request.destinationPath),
      headers: request.headers,
      directoryUri: Uri.directory(
        destinationDirectory.absolute.path,
        windows: Platform.isWindows,
      ),
      group: taskGroup,
      updates: Updates.statusAndProgress,
      allowPause: true,
      retries: 0,
      metaData: request.taskId,
    );
    // 调用系统下载器提交任务，并检查原生平台是否接受。
    final accepted = await _client.enqueue(task);
    // 原生队列拒绝任务时抛出错误，不能向界面伪报已排队。
    if (!accepted) {
      throw StateError('System downloader rejected task: ${request.taskId}');
    }
    // 原生状态回调可能稍后到达，因此先广播排队状态改善界面响应。
    _events.add(
      DownloadEvent(taskId: request.taskId, status: DownloadStatus.queued),
    );
  }

  /// 暂停指定系统下载任务。
  @override
  Future<void> pause(String taskId) async {
    // 检查生命周期后调用系统下载器暂停接口。
    _ensureNotDisposed();
    final accepted = await _client.pause(taskId);
    // 系统不支持断点或任务不存在时返回明确错误。
    if (!accepted) {
      throw StateError('System downloader could not pause task: $taskId');
    }
  }

  /// 恢复指定系统下载任务。
  @override
  Future<void> resume(String taskId) async {
    // 检查生命周期后调用系统下载器恢复接口。
    _ensureNotDisposed();
    final accepted = await _client.resume(taskId);
    // 缺少系统断点数据或任务不存在时不能静默成功。
    if (!accepted) {
      throw StateError('System downloader could not resume task: $taskId');
    }
  }

  /// 取消指定系统下载任务。
  @override
  Future<void> cancel(String taskId) async {
    // 检查生命周期后向原生平台发出取消请求。
    _ensureNotDisposed();
    final accepted = await _client.cancel(taskId);
    // 取消请求未被平台接受时保留现有任务状态并报告错误。
    if (!accepted) {
      throw StateError('System downloader could not cancel task: $taskId');
    }
  }

  /// 从插件持久化数据库恢复任务状态和进度。
  @override
  Future<void> restore() async {
    // 已释放的引擎不能重新建立后台下载状态。
    _ensureNotDisposed();
    // 获取固定任务分组的持久化记录；客户端会保证跟踪只初始化一次。
    final records = await _client.restore(taskGroup);
    // 每次调用都重放数据库快照，使后创建的协调器也能校准真实系统状态。
    for (final record in records) {
      _handleRecord(record);
    }
  }

  /// 取消插件更新订阅并关闭业务事件流，不主动取消系统后台任务。
  @override
  Future<void> dispose() async {
    // 重复释放直接返回，避免重复关闭广播流。
    if (_disposed) return;
    // 先设置释放标记，阻止新的任务控制调用。
    _disposed = true;
    // 取消当前引擎的更新监听；系统任务仍由原生平台继续执行。
    await _updateSubscription.cancel();
    // 关闭业务事件流，通知订阅者生命周期结束。
    await _events.close();
  }

  /// 将插件状态或进度更新转换为统一下载事件。
  void _handleUpdate(TaskUpdate update) {
    // 引擎释放后忽略可能已经排队的最后一条插件事件。
    if (_disposed) return;
    // 只处理 BiliDown 系统下载分组，避免串入其他插件任务。
    if (update.task.group != taskGroup) return;
    // 状态与进度是两个独立更新类型，需要分别转换。
    switch (update) {
      case TaskStatusUpdate statusUpdate:
        _handleStatusUpdate(statusUpdate);
      case TaskProgressUpdate progressUpdate:
        _handleProgressUpdate(progressUpdate);
    }
  }

  /// 将持久化任务记录转换为一次状态快照。
  void _handleRecord(TaskRecord record) {
    // 插件数据库记录包含最近进度和预计文件大小，先更新字节缓存。
    _cacheProgress(
      record.taskId,
      progress: record.progress,
      expectedFileSize: record.expectedFileSize,
    );
    // 使用数据库状态和异常说明广播恢复结果。
    _emitStatus(
      taskId: record.taskId,
      status: record.status,
      errorMessage: record.exception?.description,
    );
  }

  /// 处理系统下载器的状态变化。
  void _handleStatusUpdate(TaskStatusUpdate update) {
    // HTTP 状态码优先加入错误信息，便于后续识别 401/403 并刷新媒体 URL。
    final errorMessage = _errorMessageFor(update);
    // 广播包含最近字节进度的统一状态事件。
    _emitStatus(
      taskId: update.task.taskId,
      status: update.status,
      errorMessage: errorMessage,
    );
  }

  /// 处理系统下载器的进度变化。
  void _handleProgressUpdate(TaskProgressUpdate update) {
    // 负进度值代表失败、取消等终态，这些终态由状态回调负责处理。
    if (update.progress < 0) return;
    // 缓存总大小和按比例计算的已下载字节。
    _cacheProgress(
      update.task.taskId,
      progress: update.progress,
      expectedFileSize: update.expectedFileSize,
    );
    // 进度达到 100% 时先按完成广播，否则表示正在下载。
    final status = update.progress >= 1
        ? DownloadStatus.completed
        : DownloadStatus.downloading;
    // 插件速度单位是十进制 MB/s，统一转换为字节每秒供上层跨后端汇总。
    final downloadSpeedBytesPerSecond =
        status == DownloadStatus.downloading && update.networkSpeed > 0
        ? (update.networkSpeed * 1000 * 1000).round()
        : 0;
    // 保存最近速度，后续状态事件可以沿用下载阶段快照。
    _downloadSpeedByTaskId[update.task.taskId] = downloadSpeedBytesPerSecond;
    // 广播带字节进度的统一事件。
    _events.add(
      DownloadEvent(
        taskId: update.task.taskId,
        status: status,
        downloadedBytes: _downloadedBytesByTaskId[update.task.taskId] ?? 0,
        totalBytes: _totalBytesByTaskId[update.task.taskId],
        downloadSpeedBytesPerSecond: downloadSpeedBytesPerSecond,
      ),
    );
  }

  /// 缓存插件比例对应的总字节数和已下载字节数。
  void _cacheProgress(
    String taskId, {
    required double progress,
    required int expectedFileSize,
  }) {
    // 服务端没有提供有效文件大小时保留已有缓存，不能计算伪造字节数。
    if (expectedFileSize <= 0) return;
    // 保存有效总大小供后续状态事件复用。
    _totalBytesByTaskId[taskId] = expectedFileSize;
    // 仅 0 至 1 的正常进度可以转换为已下载字节。
    if (progress >= 0) {
      // 限制比例上限，避免平台浮点误差产生超过总大小的结果。
      final normalizedProgress = progress.clamp(0.0, 1.0);
      // 将比例转换为最接近的整数字节数。
      _downloadedBytesByTaskId[taskId] = (normalizedProgress * expectedFileSize)
          .round();
    }
  }

  /// 把插件任务状态映射为项目状态并广播。
  void _emitStatus({
    required String taskId,
    required TaskStatus status,
    String? errorMessage,
  }) {
    // 插件等待重试仍属于排队，404 与其他失败统一映射为 failed。
    final downloadStatus = switch (status) {
      TaskStatus.enqueued || TaskStatus.waitingToRetry => DownloadStatus.queued,
      TaskStatus.running => DownloadStatus.downloading,
      TaskStatus.complete => DownloadStatus.completed,
      TaskStatus.paused => DownloadStatus.paused,
      TaskStatus.notFound || TaskStatus.failed => DownloadStatus.failed,
      TaskStatus.canceled => DownloadStatus.canceled,
    };
    // 暂停、排队和终态不能沿用上一次下载回调中的旧速度。
    if (downloadStatus != DownloadStatus.downloading) {
      _downloadSpeedByTaskId[taskId] = 0;
    }
    // 广播状态并附带缓存的最近进度与错误说明。
    _events.add(
      DownloadEvent(
        taskId: taskId,
        status: downloadStatus,
        downloadedBytes: _downloadedBytesByTaskId[taskId] ?? 0,
        totalBytes: _totalBytesByTaskId[taskId],
        downloadSpeedBytesPerSecond:
            downloadStatus == DownloadStatus.downloading
            ? _downloadSpeedByTaskId[taskId] ?? 0
            : 0,
        errorMessage: errorMessage,
      ),
    );
    // 终态结束后释放内存进度缓存，持久化事实仍由插件数据库和后续 Drift 保存。
    if (status.isFinalState) {
      _downloadedBytesByTaskId.remove(taskId);
      _totalBytesByTaskId.remove(taskId);
      _downloadSpeedByTaskId.remove(taskId);
    }
  }

  /// 组合 HTTP 状态码与插件异常，形成可诊断错误文本。
  String? _errorMessageFor(TaskStatusUpdate update) {
    // 非失败状态不需要附加错误消息。
    if (update.status != TaskStatus.failed &&
        update.status != TaskStatus.notFound) {
      return null;
    }
    // 优先读取平台返回的 HTTP 响应码，401/403 后续可触发播放地址刷新。
    final responseCode = update.responseStatusCode;
    // 读取插件异常中的平台原始说明。
    final description = update.exception?.description;
    // 同时存在响应码和说明时组合成一条诊断文本。
    if (responseCode != null && description != null) {
      return 'HTTP $responseCode: $description';
    }
    // 只有响应码时仍返回稳定的 HTTP 错误文本。
    if (responseCode != null) return 'HTTP $responseCode';
    // 404 状态在部分平台没有 responseStatusCode，需要补充明确说明。
    if (update.status == TaskStatus.notFound) return 'HTTP 404: 资源不存在';
    // 最后回退插件原始异常说明。
    return description;
  }

  /// 确保公开操作不会在引擎释放后执行。
  void _ensureNotDisposed() {
    // 已关闭订阅和事件流的实例不能再次使用。
    if (_disposed) throw StateError('SystemDownloadEngine is disposed.');
  }

  /// 校验下载入口地址，避免原生下载器收到空地址或非网络协议。
  void _ensureDownloadableUrl(Uri url) {
    // 系统下载后端需要可直接访问的 HTTP(S) 地址。
    if (url.scheme == 'http' || url.scheme == 'https') return;
    throw StateError('播放地址无效，请重新解析后重试。');
  }
}
