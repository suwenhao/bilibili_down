import 'package:bilibili_down/features/downloads/application/runtime/download_event_buffer.dart';
import 'package:bilibili_down/services/download_engine/download_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 创建指定状态和字节数的稳定测试事件。
  DownloadEvent event(
    String taskId,
    DownloadStatus status, {
    int downloadedBytes = 0,
  }) {
    return DownloadEvent(
      taskId: taskId,
      status: status,
      downloadedBytes: downloadedBytes,
    );
  }

  test('同一任务连续下载进度只保留最新快照', () {
    // 缓冲器模拟数据库写入落后于系统下载回调的场景。
    final buffer = DownloadEventBuffer();
    buffer
      ..add(event('video', DownloadStatus.downloading, downloadedBytes: 10))
      ..add(event('video', DownloadStatus.downloading, downloadedBytes: 20))
      ..add(event('video', DownloadStatus.downloading, downloadedBytes: 30));

    // 三次回调合并为一个节点，并保留最后一次真实字节数。
    expect(buffer.length, 1);
    expect(buffer.removeFirst().downloadedBytes, 30);
    expect(buffer.isEmpty, isTrue);
  });

  test('终态事件切断进度合并区间并保持严格顺序', () {
    // 完成前后的进度属于不同区间，不能跨越终态互相覆盖。
    final buffer = DownloadEventBuffer();
    buffer
      ..add(event('video', DownloadStatus.downloading, downloadedBytes: 10))
      ..add(event('video', DownloadStatus.completed, downloadedBytes: 20))
      ..add(event('video', DownloadStatus.downloading, downloadedBytes: 30));

    // 消费顺序必须与状态机边界一致，完成事件永远不会被丢弃。
    expect(buffer.removeFirst().downloadedBytes, 10);
    expect(buffer.removeFirst().status, DownloadStatus.completed);
    expect(buffer.removeFirst().downloadedBytes, 30);
    expect(buffer.isEmpty, isTrue);
  });

  test('不同任务的进度分别合并且保留首次入队顺序', () {
    // 视频和音频分流可以交错回调，但各自只需要最新的进度快照。
    final buffer = DownloadEventBuffer();
    buffer
      ..add(event('video', DownloadStatus.downloading, downloadedBytes: 10))
      ..add(event('audio', DownloadStatus.downloading, downloadedBytes: 5))
      ..add(event('video', DownloadStatus.downloading, downloadedBytes: 20))
      ..add(event('audio', DownloadStatus.downloading, downloadedBytes: 15));

    // 节点位置不随覆盖改变，避免跨分流数据库顺序漂移。
    expect(buffer.removeFirst().taskId, 'video');
    expect(buffer.removeFirst().taskId, 'audio');
    expect(buffer.isEmpty, isTrue);
  });
}
