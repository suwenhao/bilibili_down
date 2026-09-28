import 'package:background_downloader/background_downloader.dart';

/// 封装 background_downloader 插件调用，便于下载引擎隔离单例和数据库细节。
abstract interface class BackgroundDownloadClient {
  /// 监听系统下载器产生的状态与进度更新。
  Stream<TaskUpdate> watchUpdates();

  /// 将任务提交给 iOS URLSession 或其他平台的系统下载实现。
  Future<bool> enqueue(DownloadTask task);

  /// 暂停指定系统下载任务。
  Future<bool> pause(String taskId);

  /// 恢复指定系统下载任务。
  Future<bool> resume(String taskId);

  /// 取消指定系统下载任务。
  Future<bool> cancel(String taskId);

  /// 启用插件持久化跟踪，并返回指定分组的已保存任务记录。
  Future<List<TaskRecord>> restore(String group);
}

/// 使用 background_downloader 默认单例实现系统下载客户端。
final class BackgroundDownloaderClient implements BackgroundDownloadClient {
  /// 支持注入下载器实例，默认使用插件提供的全局下载器。
  BackgroundDownloaderClient({FileDownloader? downloader})
    : _downloader = downloader ?? FileDownloader();

  /// 插件下载器负责与各平台原生后台传输 API 通信。
  final FileDownloader _downloader;

  /// 当前已经启用持久化跟踪的任务分组，避免重复初始化数据库监听。
  final Set<String> _trackedGroups = <String>{};

  /// 返回插件统一的任务更新广播流。
  @override
  Stream<TaskUpdate> watchUpdates() {
    // 直接复用插件广播流，状态转换由上层统一下载引擎完成。
    return _downloader.updates;
  }

  /// 将下载任务提交给平台原生队列。
  @override
  Future<bool> enqueue(DownloadTask task) {
    // 调用插件 enqueue，布尔结果表示原生平台是否接受任务。
    return _downloader.enqueue(task);
  }

  /// 查询任务对象后调用插件暂停接口。
  @override
  Future<bool> pause(String taskId) async {
    // 暂停需要完整 DownloadTask，因此先从活动队列或持久化数据库恢复对象。
    final task = await _findDownloadTask(taskId);
    // 找不到任务时返回失败，让引擎输出明确的任务不存在错误。
    if (task == null) return false;
    // 调用系统下载器保存断点并暂停任务。
    return _downloader.pause(task);
  }

  /// 查询任务对象后调用插件恢复接口。
  @override
  Future<bool> resume(String taskId) async {
    // 恢复任务同样需要原始 URL、请求头和断点信息对应的任务对象。
    final task = await _findDownloadTask(taskId);
    // 持久化记录也不存在时无法恢复。
    if (task == null) return false;
    // 将暂停任务重新提交给平台后台队列继续下载。
    return _downloader.resume(task);
  }

  /// 按任务 ID 请求平台取消下载。
  @override
  Future<bool> cancel(String taskId) {
    // 插件支持直接按 ID 取消，不需要先查询任务对象。
    return _downloader.cancelTaskWithId(taskId);
  }

  /// 恢复插件后台期间保存的事件和指定分组的数据库快照。
  @override
  Future<List<TaskRecord>> restore(String group) async {
    // 每个任务分组只注册一次数据库跟踪，防止重复监听和重复写入。
    if (!_trackedGroups.contains(group)) {
      // 完整文件存在时自动把后台完成的任务校准为 complete。
      await _downloader.trackTasksInGroup(group, markDownloadedComplete: true);
      // 只有插件初始化成功后才记录分组，失败时允许下次恢复重试。
      _trackedGroups.add(group);
    }
    // 拉取应用挂起期间由原生平台缓存的状态和进度事件。
    await _downloader.resumeFromBackground();
    // 返回插件持久化数据库中的当前任务快照供引擎立即恢复界面状态。
    return _downloader.database.allRecords(group: group);
  }

  /// 从活动队列或插件数据库查找可暂停、恢复的下载任务。
  Future<DownloadTask?> _findDownloadTask(String taskId) async {
    // 优先查询原生活动队列，避免使用已经过期的数据库快照。
    final activeTask = await _downloader.taskForId(taskId);
    // UriDownloadTask 继承 DownloadTask，因此该判断同时覆盖精确文件路径任务。
    if (activeTask is DownloadTask) return activeTask;
    // 活动队列没有结果时读取持久化记录，用于应用重启后的暂停和恢复。
    final record = await _downloader.database.recordForId(taskId);
    // 数据库记录可能包含其他任务类型，只接受下载任务。
    return record?.task is DownloadTask ? record!.task as DownloadTask : null;
  }
}
