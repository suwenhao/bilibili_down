import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../core/logging/app_debug_log.dart';
import '../download_engine.dart';
import 'aria2_error_policy.dart';
import 'aria2_rpc_client.dart';
import 'aria2_runtime.dart';

/// 使用 aria2 RPC 实现任务控制、进度轮询和任务映射恢复。
final class Aria2DownloadEngine implements DownloadEngine {
  /// 使用指定运行时和轮询间隔创建下载引擎。
  Aria2DownloadEngine(
    this._runtime, {
    this.pollInterval = const Duration(seconds: 1),
  });

  /// 管理 aria2 进程与 RPC 客户端的运行时。
  final Aria2Runtime _runtime;

  /// 查询任务状态的时间间隔。
  final Duration pollInterval;

  /// 业务任务 ID 到 aria2 GID 的内存映射。
  final Map<String, String> _gidByTaskId = {};

  /// 保存最近一次已记录状态，避免每秒轮询重复输出相同日志。
  final Map<String, DownloadStatus> _lastStatusByTaskId = {};

  /// 向多个界面订阅者广播下载状态。
  final StreamController<DownloadEvent> _events =
      StreamController<DownloadEvent>.broadcast();

  /// 当前进度轮询定时器。
  Timer? _pollTimer;

  /// 防止定时器触发重叠 RPC 轮询的互斥标记。
  bool _polling = false;

  /// 当前轮询完成信号，退出时用于等待已发出的 RPC 查询结束。
  Completer<void>? _pollDone;

  /// 串行化本地任务映射写入，避免 enqueue、poll 和 cancel 同时改写临时文件。
  Future<void> _taskMapSaveQueue = Future<void>.value();

  /// 引擎是否已经释放。
  bool _disposed = false;

  /// 返回下载事件广播流。
  @override
  Stream<DownloadEvent> watchEvents() => _events.stream;

  /// 将新任务提交给 aria2，并持久化任务与 GID 的映射。
  @override
  Future<void> enqueue(DownloadRequest request) async {
    // 已释放的引擎不能再接受任务。
    _ensureNotDisposed();
    // aria2 只接受可直接下载的 HTTP(S) 地址，其他地址应停在业务解析层。
    _ensureDownloadableUrl(request.url);
    // 地址仅记录主机摘要，目标只记录文件名，避免敏感参数进入截图。
    AppDebugLog.aria2(
      'Enqueue requested task=${request.taskId} '
      'url=${AppDebugLog.safeUri(request.url)} '
      'file=${p.basename(request.destinationPath)}',
    );
    // 确保 aria2 进程和 RPC 服务已经就绪。
    await _runtime.start();
    // 根据稳定任务 ID 生成可重复计算的 aria2 GID。
    final gid = _gidForTask(request.taskId);
    // 先让 aria2 真正接受任务，再登记映射，避免提交失败后留下脏状态。
    final acceptedGid = await _addUriWithStaleGidCleanup(request, gid: gid);
    // 使用 aria2 返回的 GID 作为实际映射值；正常情况下它等于我们传入的稳定 GID。
    _gidByTaskId[request.taskId] = acceptedGid;
    // RPC 已接受后才通知界面进入队列，失败任务不会短暂占用下载中状态。
    _events.add(
      DownloadEvent(taskId: request.taskId, status: DownloadStatus.queued),
    );
    // 保存已广播的初始状态，轮询只记录后续变化。
    _lastStatusByTaskId[request.taskId] = DownloadStatus.queued;
    // RPC 已接受任务并返回后记录稳定 GID。
    AppDebugLog.aria2(
      'Enqueue accepted task=${request.taskId} gid=$acceptedGid',
    );
    // 原子保存映射，使应用重启后仍能恢复任务。
    await _saveTaskMap();
    // 启动或复用周期进度轮询。
    _startPolling();
  }

  /// 提交 aria2 任务；如果旧终态记录占着稳定 GID，则清理后重试一次。
  Future<String> _addUriWithStaleGidCleanup(
    DownloadRequest request, {
    required String gid,
  }) async {
    // 实际提交逻辑收敛在闭包中，保证第一次和清理后的重试参数完全一致。
    Future<String> submit() {
      // 通过 RPC 提交下载地址、保存路径和鉴权请求头。
      return _runtime.client.addUri(
        request.url,
        directory: p.dirname(request.destinationPath),
        outputName: p.basename(request.destinationPath),
        gid: gid,
        backupUris: request.backupUrls,
        headers: request.headers,
      );
    }

    try {
      // 首次提交应覆盖绝大多数正常下载启动场景。
      return await submit();
    } on Aria2RpcException catch (error) {
      // aria2 会保留失败/完成结果，重试同一业务任务时稳定 GID 可能被旧结果占用。
      if (!isAria2GidConflict(error)) rethrow;
      AppDebugLog.aria2(
        'Stale aria2 gid detected task=${request.taskId} gid=$gid; cleanup',
      );
      try {
        // 清理旧活动任务或结果记录后再提交，等价于从最新解析结果重新启动。
        await _runtime.client.remove(gid);
      } catch (cleanupError) {
        // 清理失败仍保留原始 GID 冲突语义，调用方会把任务标记为可重试失败。
        AppDebugLog.aria2(
          'Stale gid cleanup failed task=${request.taskId} '
          'gid=$gid error=$cleanupError',
        );
        rethrow;
      }
      // 只重试一次，避免真实重复启动或异常后端进入无限循环。
      return submit();
    }
  }

  /// 暂停指定业务任务。
  @override
  Future<void> pause(String taskId) async {
    // 启动运行时后将业务 ID 转换为 GID 调用 aria2。
    await _runtime.start();
    await _runtime.client.pause(_requireGid(taskId));
  }

  /// 恢复指定业务任务并重新开启进度轮询。
  @override
  Future<void> resume(String taskId) async {
    // 确保 RPC 可用后恢复下载。
    await _runtime.start();
    await _runtime.client.resume(_requireGid(taskId));
    // 暂停期间定时器可能已经停止，恢复后必须重新启动。
    _startPolling();
  }

  /// 取消任务、移除映射并广播取消状态。
  @override
  Future<void> cancel(String taskId) async {
    // 确保 RPC 可用后移除 aria2 任务或结果记录。
    await _runtime.start();
    // 失败终态可能已经被轮询移除内存映射，仍要用稳定 ID 清理 aria2 结果占位。
    final gid = _gidByTaskId[taskId] ?? _gidForTask(taskId);
    await _runtime.client.remove(gid);
    // 删除内存映射并同步到磁盘。
    _gidByTaskId.remove(taskId);
    await _saveTaskMap();
    // 主动广播取消结果，无需等待下一轮状态查询。
    _events.add(DownloadEvent(taskId: taskId, status: DownloadStatus.canceled));
  }

  /// 从磁盘恢复任务映射，并继续观察未结束任务。
  @override
  Future<void> restore() async {
    // 防止在引擎释放后执行恢复。
    _ensureNotDisposed();
    // 先恢复 aria2 运行时，再读取映射文件。
    await _runtime.start();
    await _loadTaskMap();
    // 输出恢复映射数量，便于判断是否加载了陈旧任务。
    AppDebugLog.aria2('Engine restored mappedTasks=${_gidByTaskId.length}');
    // 只有存在任务时才创建轮询定时器。
    if (_gidByTaskId.isNotEmpty) _startPolling();
  }

  /// 停止轮询、关闭 aria2 运行时并释放事件流。
  @override
  Future<void> dispose() async {
    // 重复释放直接返回，避免重复关闭 StreamController。
    if (_disposed) return;
    // 先设置释放标记，阻止并发任务继续进入。
    _disposed = true;
    // 取消轮询并清除定时器引用。
    _pollTimer?.cancel();
    _pollTimer = null;
    // 已经开始的状态查询必须先结束，避免关闭 RPC 后仍写入下载进度事件。
    await _pollDone?.future;
    // 记录引擎停止前仍保留的映射数量。
    AppDebugLog.aria2('Engine disposing mappedTasks=${_gidByTaskId.length}');
    // 保存 aria2 会话并关闭底层进程。
    await _runtime.stop();
    // 关闭广播流，通知订阅者生命周期结束。
    await _events.close();
  }

  /// 保证只有一个定时器运行，并立即执行一次状态查询。
  void _startPolling() {
    // 定时器不存在时创建；回调不等待异步轮询以免阻塞调度器。
    _pollTimer ??= Timer.periodic(pollInterval, (_) => unawaited(_poll()));
    // 不等首个间隔，启动后立即刷新一次界面状态。
    unawaited(_poll());
  }

  /// 查询所有已知 GID，并处理终态、错误和映射持久化。
  Future<void> _poll() async {
    // 已有轮询执行或引擎已释放时跳过本轮，避免并发修改映射。
    if (_polling || _disposed) return;
    // 设置互斥标记，并记录本轮是否需要写入映射文件。
    _polling = true;
    // 为本轮创建完成信号，dispose 会等待 finally 执行后再关闭运行时。
    final pollDone = Completer<void>();
    _pollDone = pollDone;
    var taskMapChanged = false;
    try {
      // 使用快照遍历，允许循环内安全移除原 Map 条目。
      for (final entry in _gidByTaskId.entries.toList(growable: false)) {
        try {
          // 查询 aria2 状态并转换成业务事件。
          final status = await _runtime.client.tellStatus(entry.value);
          final event = _eventFromStatus(entry.key, status);
          // 仅在任务状态变化时输出，避免每秒进度轮询刷屏。
          final previousStatus = _lastStatusByTaskId[entry.key];
          if (previousStatus != event.status) {
            AppDebugLog.aria2(
              'Status task=${entry.key} ${previousStatus?.name ?? 'unknown'} '
              '-> ${event.status.name} '
              'bytes=${event.downloadedBytes}/${event.totalBytes ?? -1}',
            );
            // 保存本次状态供下一轮比较。
            _lastStatusByTaskId[entry.key] = event.status;
          }
          // 将最新状态广播给所有订阅者。
          _events.add(event);
          // 任务进入任一终态后不再轮询，并标记映射已改变。
          if (event.status == DownloadStatus.completed ||
              event.status == DownloadStatus.failed ||
              event.status == DownloadStatus.canceled) {
            _gidByTaskId.remove(entry.key);
            // 终态任务不再需要保留最近状态。
            _lastStatusByTaskId.remove(entry.key);
            taskMapChanged = true;
          }
        } on Aria2RpcException catch (error) {
          // 单任务轮询异常输出任务 ID 和 RPC 根因。
          AppDebugLog.aria2(
            'Status poll failed task=${entry.key} error=$error',
          );
          // 单个任务查询失败不会中断其他任务轮询，单独广播失败事件。
          _events.add(
            DownloadEvent(
              taskId: entry.key,
              status: DownloadStatus.failed,
              errorMessage: error.message,
            ),
          );
        }
      }
      // 所有任务结束后取消定时器，避免空轮询消耗资源。
      if (_gidByTaskId.isEmpty) {
        _pollTimer?.cancel();
        _pollTimer = null;
      }
      // 仅终态移除发生时写盘，减少不必要的磁盘操作。
      if (taskMapChanged) await _saveTaskMap();
    } finally {
      // 无论 RPC 是否异常都释放互斥标记，允许下一轮继续。
      _polling = false;
      // 只清理当前轮询信号，避免未来扩展时旧回调覆盖新轮询。
      if (identical(_pollDone, pollDone)) _pollDone = null;
      // 唤醒正在等待当前进度查询完成的退出流程。
      if (!pollDone.isCompleted) pollDone.complete();
    }
  }

  /// 将 aria2 状态字段转换为项目统一下载事件。
  DownloadEvent _eventFromStatus(String taskId, Map<String, Object?> status) {
    // 读取 aria2 的文本状态。
    final ariaStatus = status['status']?.toString();
    // 映射到业务层枚举，未知状态按失败处理以避免任务永久悬挂。
    final downloadStatus = switch (ariaStatus) {
      'waiting' => DownloadStatus.queued,
      'active' => DownloadStatus.downloading,
      'paused' => DownloadStatus.paused,
      'complete' => DownloadStatus.completed,
      'error' => DownloadStatus.failed,
      'removed' => DownloadStatus.canceled,
      _ => DownloadStatus.failed,
    };
    // 同时解析已下载字节、总大小和错误消息。
    return DownloadEvent(
      taskId: taskId,
      status: downloadStatus,
      downloadedBytes:
          int.tryParse(status['completedLength']?.toString() ?? '') ?? 0,
      totalBytes: int.tryParse(status['totalLength']?.toString() ?? ''),
      downloadSpeedBytesPerSecond:
          int.tryParse(status['downloadSpeed']?.toString() ?? '') ?? 0,
      errorCode: status['errorCode']?.toString(),
      errorMessage: status['errorMessage']?.toString(),
    );
  }

  /// 从业务任务 ID 生成符合 aria2 要求的 16 位十六进制 GID。
  String _gidForTask(String taskId) {
    // SHA-256 保证同一任务可稳定恢复，并降低不同任务碰撞概率。
    return sha256.convert(utf8.encode(taskId)).toString().substring(0, 16);
  }

  /// 从本地 JSON 文件恢复业务任务与 GID 的映射。
  Future<void> _loadTaskMap() async {
    // 获取运行时约定的映射文件路径。
    final file = _runtime.taskMapFile;
    // 首次启动没有缓存时直接保留空映射。
    if (!await file.exists()) return;
    try {
      // 读取并解析 JSON，根节点必须是对象。
      final data = jsonDecode(await file.readAsString());
      if (data is! Map) return;
      // 清空旧内存数据后，把动态键值统一转换成字符串。
      _gidByTaskId
        ..clear()
        ..addAll(
          data.map((key, value) => MapEntry(key.toString(), value.toString())),
        );
      // 记录从磁盘成功恢复的任务映射数量。
      AppDebugLog.aria2('Loaded task map entries=${_gidByTaskId.length}');
    } catch (error) {
      // 缓存损坏时忽略该文件，后续仍以 Drift 任务数据库作为业务事实来源。
      AppDebugLog.aria2('Task map ignored error=$error');
    }
  }

  /// 通过临时文件原子保存任务映射。
  Future<void> _saveTaskMap() async {
    // 保存调用可能来自并发路径，排队写入可以避免多个调用争抢同一个 tmp 文件。
    final snapshot = Map<String, String>.of(_gidByTaskId);
    final saveOperation = _taskMapSaveQueue.then(
      (_) => _writeTaskMapSnapshot(snapshot),
    );
    // 即使某次写入失败，后续保存也不能永久挂在失败 Future 后面。
    _taskMapSaveQueue = saveOperation.catchError((_) {});
    await saveOperation;
  }

  /// 将指定快照写入本地任务映射文件。
  Future<void> _writeTaskMapSnapshot(Map<String, String> snapshot) async {
    // 获取目标文件并确保父目录存在。
    final file = _runtime.taskMapFile;
    await file.parent.create(recursive: true);
    // 唯一临时文件避免连续保存争抢同一个 tasks.json.tmp。
    final temporary = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      // 编码当前映射并强制刷盘。
      await temporary.writeAsString(jsonEncode(snapshot), flush: true);
      // 文件系统、索引服务或同步盘可能短暂占用目标文件，做有限重试即可。
      await _replaceTaskMapFileWithRetry(temporary, file);
    } finally {
      // 异常退出时清理未被 rename 消耗的临时文件，避免缓存目录堆积。
      if (await temporary.exists()) {
        try {
          await temporary.delete();
        } catch (_) {
          // 临时文件清理失败不影响下次保存，后续缓存清理可兜底处理。
        }
      }
    }
  }

  /// 用完整临时文件替换任务映射，兼容文件系统偶发占用。
  Future<void> _replaceTaskMapFileWithRetry(File temporary, File target) async {
    // 最多等待约 280ms，足够覆盖连续保存和系统短暂占用，不会阻塞下载队列。
    const retryDelays = <Duration>[
      Duration(milliseconds: 20),
      Duration(milliseconds: 60),
      Duration(milliseconds: 200),
    ];
    for (var attempt = 0; ; attempt++) {
      try {
        // 删除旧文件后将完整临时文件替换为正式文件。
        if (await target.exists()) await target.delete();
        await temporary.rename(target.path);
        return;
      } on FileSystemException {
        // 最后一次仍失败时把异常交给调用方记录并保持任务可恢复。
        if (attempt >= retryDelays.length) rethrow;
        await Future<void>.delayed(retryDelays[attempt]);
      }
    }
  }

  /// 校验下载入口地址，避免无效 URL 进入 aria2 后变成难懂的 RPC 错误。
  void _ensureDownloadableUrl(Uri url) {
    // B 站媒体地址必须是 HTTP(S)，空地址、相对地址或其他协议都不能交给 aria2。
    if (url.scheme == 'http' || url.scheme == 'https') return;
    throw StateError('播放地址无效，请重新解析后重试。');
  }

  /// 将业务任务 ID 转换为已登记的 aria2 GID。
  String _requireGid(String taskId) {
    // 从内存映射读取 GID。
    final gid = _gidByTaskId[taskId];
    // 未知任务不能发送暂停、恢复或取消 RPC。
    if (gid == null) throw StateError('Unknown aria2 task: $taskId');
    return gid;
  }

  /// 确保公开操作不会在引擎释放后执行。
  void _ensureNotDisposed() {
    // 释放后的 Stream 和运行时均不可复用。
    if (_disposed) throw StateError('Aria2DownloadEngine is disposed.');
  }
}
