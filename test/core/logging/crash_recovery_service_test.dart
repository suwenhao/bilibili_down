import 'dart:io';

import 'package:bilibili_down/core/logging/crash_recovery_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  /// 验证崩溃标记可跨启动读取且不会保存本地路径或凭据。
  test('写入并读取脱敏崩溃报告', () async {
    // 临时文件模拟应用数据目录中的持久崩溃标记。
    final directory = await Directory.systemTemp.createTemp(
      'bilidown-crash-test-',
    );
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final marker = File(p.join(directory.path, 'last_crash.json'));
    final occurredAt = DateTime.utc(2026, 7, 12, 1, 2, 3);

    await CrashRecoveryService.writeReport(
      marker,
      error: r'failed C:\Users\alice\video.mp4 token=secret-token',
      stackTrace: StackTrace.fromString(
        r'#0 C:\Users\alice\project\main.dart:10',
      ),
      occurredAt: occurredAt,
    );
    final raw = await marker.readAsString();
    final report = await CrashRecoveryService.readReport(marker);

    expect(raw, isNot(contains('alice')));
    expect(raw, isNot(contains('secret-token')));
    expect(report?.occurredAt, occurredAt);
    expect(report?.errorSummary, contains('<redacted-local-path>'));
    expect(report?.stackTraceSummary, contains('<redacted-local-path>'));
  });

  /// 验证半写入或非 JSON 标记不会阻止应用下一次启动。
  test('损坏崩溃标记按无报告处理', () async {
    // 无效 JSON 对应崩溃过程中进程在文件写完前被系统终止。
    final directory = await Directory.systemTemp.createTemp(
      'bilidown-crash-invalid-',
    );
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final marker = File(p.join(directory.path, 'last_crash.json'));
    await marker.writeAsString('{invalid');

    expect(await CrashRecoveryService.readReport(marker), isNull);
  });
}
