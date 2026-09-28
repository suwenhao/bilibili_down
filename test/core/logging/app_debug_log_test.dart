import 'package:bilibili_down/core/logging/app_debug_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(AppDebugLog.clear);

  /// 验证导出前会同时清除凭据、URL、IP 和常见平台绝对路径。
  test('诊断日志清除常见敏感信息', () {
    // 一条消息故意混合多类敏感值，确保规则组合后不会相互漏过。
    const raw =
        'cookie=SESSDATA-secret '
        'refresh_token=refresh-secret '
        'url=https://cdn.example/video.m4s?token=query-secret '
        r'path=C:\Users\alice\Downloads\video.mp4 '
        'ip=192.168.1.20';
    final sanitized = AppDebugLog.sanitize(raw);

    expect(sanitized, isNot(contains('SESSDATA-secret')));
    expect(sanitized, isNot(contains('refresh-secret')));
    expect(sanitized, isNot(contains('query-secret')));
    expect(sanitized, isNot(contains('alice')));
    expect(sanitized, isNot(contains('192.168.1.20')));
    expect(sanitized, contains('<redacted-credential>'));
    expect(sanitized, contains('<redacted-url>'));
    expect(sanitized, contains('<redacted-local-path>'));
    expect(sanitized, contains('<redacted-ip>'));
  });

  /// 验证写入日志后导出文本只包含脱敏版本和标准说明头。
  test('导出文本只包含脱敏内存记录', () {
    // 公共日志入口在 Release 和 Debug 都会先脱敏再进入有界内存环形缓冲。
    AppDebugLog.aria2(
      r'failed path=C:\Users\alice\secret.mp4 token:rpc-secret',
    );
    final exported = AppDebugLog.exportText();

    expect(exported, contains('# BiliDown diagnostic log'));
    expect(exported, contains('[BiliDown][aria2]'));
    expect(exported, isNot(contains('alice')));
    expect(exported, isNot(contains('rpc-secret')));
  });
}
