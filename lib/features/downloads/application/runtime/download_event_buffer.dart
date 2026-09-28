import 'dart:collection';

import '../../../../services/download_engine/download_engine.dart';

/// 保存尚未持久化的下载事件，并只合并同一连续区间内的普通下载进度。
final class DownloadEventBuffer {
  /// 按引擎实际到达顺序保存事件节点，终态和阶段事件始终独占一个节点。
  final ListQueue<_BufferedDownloadEvent> _events =
      ListQueue<_BufferedDownloadEvent>();

  /// 记录每个任务当前可被新进度替换的节点，阶段事件会切断合并区间。
  final Map<String, _BufferedDownloadEvent> _replaceableProgressByTaskId =
      <String, _BufferedDownloadEvent>{};

  /// 当前没有任何等待处理的事件。
  bool get isEmpty => _events.isEmpty;

  /// 等待处理的实际节点数，连续进度合并后不会随回调次数增长。
  int get length => _events.length;

  /// 按业务顺序加入事件；仅 downloading 快照允许覆盖同任务上一条待处理进度。
  void add(DownloadEvent event) {
    // 普通下载进度没有状态机副作用，只需保留进入数据库前的最新快照。
    if (event.status == DownloadStatus.downloading) {
      final existing = _replaceableProgressByTaskId[event.taskId];
      if (existing != null) {
        // 节点位置保持不变，只替换字节、速度和总大小，避免打乱跨任务顺序。
        existing.event = event;
        return;
      }
      // 当前任务没有可替换节点时创建新的连续进度区间。
      final buffered = _BufferedDownloadEvent(event);
      _replaceableProgressByTaskId[event.taskId] = buffered;
      _events.addLast(buffered);
      return;
    }

    // 排队、暂停、失败、取消和完成都可能推进状态机，必须切断此前进度合并区间。
    _replaceableProgressByTaskId.remove(event.taskId);
    _events.addLast(_BufferedDownloadEvent(event));
  }

  /// 移除并返回最早到达的事件，调用方负责串行执行其数据库副作用。
  DownloadEvent removeFirst() {
    // 空队列由调用方通过 isEmpty 防护，ListQueue 会在误用时主动抛出状态错误。
    final buffered = _events.removeFirst();
    // 只有映射仍指向当前节点时才能清除，不能误删阶段事件后的新进度区间。
    if (identical(
      _replaceableProgressByTaskId[buffered.event.taskId],
      buffered,
    )) {
      _replaceableProgressByTaskId.remove(buffered.event.taskId);
    }
    return buffered.event;
  }
}

/// 允许后续进度原位替换事件值，同时保持队列节点顺序稳定。
final class _BufferedDownloadEvent {
  /// 创建持有一条下载事件的可变节点。
  _BufferedDownloadEvent(this.event);

  /// 当前区间内最新的下载事件快照。
  DownloadEvent event;
}
