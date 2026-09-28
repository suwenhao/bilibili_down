import 'package:bilibili_down/features/parser/application/clipboard_monitor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 验证分享文案只提取受信任 B 站链接并清理末尾标点。
  test('从分享文案提取 B 站链接', () {
    // 标题和中文标点不应进入解析页输入框。
    const text = '分享视频：https://www.bilibili.com/video/BV1nfj86AEAo？';
    expect(
      extractBiliClipboardCandidate(text),
      'https://www.bilibili.com/video/BV1nfj86AEAo',
    );
  });

  /// 验证纯文本 BV、AV、EP、SS 可以识别且前缀规范化。
  test('识别纯文本媒体标识', () {
    // BVID 主体保留原字符，BV 前缀统一大写。
    expect(extractBiliClipboardCandidate('bv1nfj86AEAo'), 'BV1nfj86AEAo');
    // AV 号属于普通视频旧标识，前缀统一小写。
    expect(extractBiliClipboardCandidate('AV170001'), 'av170001');
    // 番剧分集和季度前缀统一小写。
    expect(extractBiliClipboardCandidate('EP12345'), 'ep12345');
    expect(extractBiliClipboardCandidate('SS28770'), 'ss28770');
  });

  /// 验证相似域名和普通文本不会产生解析提示。
  test('拒绝非 B 站剪贴板内容', () {
    // 域名后缀相似也不能绕过精确白名单。
    expect(
      extractBiliClipboardCandidate(
        'https://www.bilibili.com.example.com/video/BV1nfj86AEAo',
      ),
      isNull,
    );
    // 普通文字不应打扰用户。
    expect(extractBiliClipboardCandidate('今天没有需要下载的视频'), isNull);
  });
}
