import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:bilibili_down/core/platform/native_tool_resolver.dart';
import 'package:bilibili_down/services/download_engine/aria2/aria2_download_engine.dart';
import 'package:bilibili_down/services/download_engine/aria2/aria2_runtime.dart';
import 'package:bilibili_down/services/download_engine/download_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  /// 验证真实 aria2 核心在慢速大文件流上暂停后停止写入，继续后恢复进度。
  test('真实 aria2 慢速大文件暂停后停止写入并可继续', () async {
    // 本地慢速 Range 服务只作为可控下载源，下载核心仍使用项目真实 aria2。
    final server = await _SlowRangeServer.start(
      totalBytes: 48 * 1024 * 1024,
      chunkSize: 64 * 1024,
      delay: const Duration(milliseconds: 3),
    );
    final harness = await _Aria2StressHarness.create();
    final events = <DownloadEvent>[];
    final subscription = harness.engine.watchEvents().listen(events.add);
    addTearDown(() async {
      await subscription.cancel();
      await harness.dispose();
      await server.close();
    });

    // 目标文件路径由真实 aria2 写入，用于校验 paused 后底层是否仍在落盘。
    final outputPath = p.join(harness.downloadDirectory.path, 'single.bin');
    await harness.engine.enqueue(
      DownloadRequest(
        taskId: 'real-single',
        url: server.url,
        destinationPath: outputPath,
      ),
    );
    await _waitForBytes(events, 'real-single', 512 * 1024);

    await harness.engine.pause('real-single');
    await _waitForStatus(events, 'real-single', DownloadStatus.paused);
    final pausedLength = await _fileLength(outputPath);
    await Future<void>.delayed(const Duration(milliseconds: 250));

    // 暂停后目标文件不能继续增长，避免 UI paused 但 aria2 仍在写数据。
    expect(await _fileLength(outputPath), pausedLength);

    await harness.engine.resume('real-single');
    await _waitForBytes(events, 'real-single', pausedLength + 1);
    expect(_latestStatus(events, 'real-single'), isNot(DownloadStatus.failed));

    await harness.engine.cancel('real-single');
  });

  /// 验证真实 aria2 并发下载下快速暂停和继续不会卡死或误失败。
  test('真实 aria2 并发任务快速暂停继续保持进度一致', () async {
    // 两个独立慢速源避免 aria2 对相同 URL 的调度影响压测目标。
    final servers = await Future.wait<_SlowRangeServer>([
      _SlowRangeServer.start(
        totalBytes: 128 * 1024 * 1024,
        chunkSize: 64 * 1024,
        delay: const Duration(milliseconds: 8),
      ),
      _SlowRangeServer.start(
        totalBytes: 128 * 1024 * 1024,
        chunkSize: 64 * 1024,
        delay: const Duration(milliseconds: 8),
      ),
    ]);
    // 任务 ID 与下载源一一对应，模拟真实批量队列中的多个并发任务。
    final taskUrls = <String, Uri>{
      'real-concurrent-a': servers[0].url,
      'real-concurrent-b': servers[1].url,
    };
    final harness = await _Aria2StressHarness.create();
    final events = <DownloadEvent>[];
    final subscription = harness.engine.watchEvents().listen(events.add);
    addTearDown(() async {
      await subscription.cancel();
      await harness.dispose();
      for (final server in servers) {
        await server.close();
      }
    });

    for (final entry in taskUrls.entries) {
      await harness.engine.enqueue(
        DownloadRequest(
          taskId: entry.key,
          url: entry.value,
          destinationPath: p.join(
            harness.downloadDirectory.path,
            '${entry.key}.bin',
          ),
        ),
      );
    }

    for (var round = 0; round < 3; round++) {
      // 每轮都先确认两个真实 aria2 任务在推进，再执行批量暂停。
      for (final taskId in taskUrls.keys) {
        await _waitForBytes(events, taskId, 512 * 1024 * (round + 1));
      }
      await Future.wait<void>(
        taskUrls.keys.map((String taskId) => harness.engine.pause(taskId)),
      );
      for (final taskId in taskUrls.keys) {
        await _waitForStatus(events, taskId, DownloadStatus.paused);
      }
      final pausedLengths = <String, int>{
        for (final taskId in taskUrls.keys)
          taskId: await _fileLength(
            p.join(harness.downloadDirectory.path, '$taskId.bin'),
          ),
      };
      await Future<void>.delayed(const Duration(milliseconds: 300));
      for (final taskId in taskUrls.keys) {
        expect(
          await _fileLength(
            p.join(harness.downloadDirectory.path, '$taskId.bin'),
          ),
          pausedLengths[taskId],
        );
      }
      await Future.wait<void>(
        taskUrls.keys.map((String taskId) => harness.engine.resume(taskId)),
      );
    }

    for (final taskId in taskUrls.keys) {
      await _waitForBytes(events, taskId, 2 * 1024 * 1024);
      expect(_latestStatus(events, taskId), isNot(DownloadStatus.failed));
      await harness.engine.cancel(taskId);
    }
  });
}

final class _Aria2StressHarness {
  const _Aria2StressHarness._({
    required this.engine,
    required this.supportDirectory,
    required this.downloadDirectory,
  });

  final Aria2DownloadEngine engine;
  final Directory supportDirectory;
  final Directory downloadDirectory;

  static Future<_Aria2StressHarness> create() async {
    // 解析项目当前平台的真实 aria2c；没有随包二进制时明确跳过而不是换假实现。
    final toolPaths = await NativeToolResolver().resolve();
    final executable = toolPaths.aria2Executable;
    if (executable == null || !await File(executable).exists()) {
      markTestSkipped('当前平台没有可用 aria2c，无法运行真实下载核心压测。');
    }
    // 临时目录隔离 aria2 会话文件和下载产物，避免污染用户真实下载数据。
    final root = await Directory.systemTemp.createTemp('bilidown-real-aria2-');
    final supportDirectory = Directory(p.join(root.path, 'support'));
    final downloadDirectory = Directory(p.join(root.path, 'downloads'));
    final runtime = Aria2Runtime(
      toolPaths: toolPaths,
      supportDirectory: supportDirectory,
      downloadDirectory: downloadDirectory,
      initialMaxOverallDownloadLimitMegabytesPerSecond: 100,
    );
    final engine = Aria2DownloadEngine(
      runtime,
      pollInterval: const Duration(milliseconds: 80),
    );
    return _Aria2StressHarness._(
      engine: engine,
      supportDirectory: supportDirectory,
      downloadDirectory: downloadDirectory,
    );
  }

  Future<void> dispose() async {
    await engine.dispose();
    final root = supportDirectory.parent;
    if (await root.exists()) await root.delete(recursive: true);
  }
}

final class _SlowRangeServer {
  const _SlowRangeServer._(this._server, this.url);

  final HttpServer _server;
  final Uri url;

  static Future<_SlowRangeServer> start({
    required int totalBytes,
    required int chunkSize,
    required Duration delay,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    // 固定内容块避免在压测里持有完整大文件内存。
    final payload = Uint8List(chunkSize);
    unawaited(() async {
      await for (final request in server) {
        // 每个 HTTP 请求独立处理，避免暂停后的新 Range 请求被旧慢连接阻塞。
        unawaited(
          _handleRequest(
            request,
            totalBytes: totalBytes,
            chunkSize: chunkSize,
            delay: delay,
            payload: payload,
          ),
        );
      }
    }());
    return _SlowRangeServer._(
      server,
      Uri.parse('http://127.0.0.1:${server.port}/large.bin'),
    );
  }

  Future<void> close() => _server.close(force: true);

  static Future<void> _handleRequest(
    HttpRequest request, {
    required int totalBytes,
    required int chunkSize,
    required Duration delay,
    required Uint8List payload,
  }) async {
    var start = 0;
    final range = request.headers.value(HttpHeaders.rangeHeader);
    // aria2 恢复下载会发送 Range，这里按真实断点续传语义返回 206。
    if (range != null) {
      final match = RegExp(r'bytes=(\d+)-').firstMatch(range);
      if (match != null) start = int.parse(match.group(1)!);
    }
    if (start >= totalBytes) {
      request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      await request.response.close();
      return;
    }
    final remaining = totalBytes - start;
    request.response.statusCode = start > 0
        ? HttpStatus.partialContent
        : HttpStatus.ok;
    request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    request.response.headers.contentLength = remaining;
    if (start > 0) {
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-${totalBytes - 1}/$totalBytes',
      );
    }
    var sent = 0;
    while (sent < remaining) {
      final size = math.min(chunkSize, remaining - sent);
      try {
        request.response.add(
          size == chunkSize ? payload : Uint8List.sublistView(payload, 0, size),
        );
        await request.response.flush();
      } on IOException {
        return;
      }
      sent += size;
      // 慢速发送用于给 pause/resume 竞态留下可观测窗口。
      if (delay > Duration.zero) await Future<void>.delayed(delay);
    }
    await request.response.close();
  }
}

Future<int> _fileLength(String path) async {
  final file = File(path);
  if (!await file.exists()) return 0;
  return file.length();
}

DownloadStatus? _latestStatus(List<DownloadEvent> events, String taskId) {
  for (final event in events.reversed) {
    if (event.taskId == taskId) return event.status;
  }
  return null;
}

int _latestBytes(List<DownloadEvent> events, String taskId) {
  for (final event in events.reversed) {
    if (event.taskId == taskId) return event.downloadedBytes;
  }
  return 0;
}

Future<void> _waitForBytes(
  List<DownloadEvent> events,
  String taskId,
  int minimumBytes,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (DateTime.now().isBefore(deadline)) {
    if (_latestBytes(events, taskId) >= minimumBytes) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Timed out waiting for $taskId to reach $minimumBytes bytes.');
}

Future<void> _waitForStatus(
  List<DownloadEvent> events,
  String taskId,
  DownloadStatus status,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(deadline)) {
    if (_latestStatus(events, taskId) == status) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Timed out waiting for $taskId status $status.');
}
