import 'dart:convert';

import 'package:bilibili_down/core/platform/output_path_policy.dart';
import 'package:bilibili_down/core/platform/runtime_platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 验证跨平台非法符号、尾部点号和 Windows 设备名都被稳定处理。
  test('清理非法字符和 Windows 保留名称', () {
    // 路径分隔符和特殊符号不能进入最终单段文件名。
    expect(sanitizeOutputPathSegment(' 标题<>:"/\\|?*. '), '标题_________');
    // 设备名追加扩展名后仍非法，因此必须统一添加安全前缀。
    expect(sanitizeOutputPathSegment('CON.txt'), '_CON.txt');
  });

  /// 验证中文和表情按 UTF-8 字节裁剪且不会产生损坏代理项。
  test('按 UTF-8 字节边界裁剪多字节标题', () {
    // 两个中文字符占六字节，五字节上限只能完整保留第一个。
    final sanitized = sanitizeOutputPathSegment('中文😀', maximumUtf8Bytes: 5);
    expect(sanitized, '中');
    expect(utf8.encode(sanitized), hasLength(3));
  });

  /// 验证 Windows 完整路径超过保守上限时在文件 API 前失败。
  test('拒绝超过 Windows 上限的完整路径', () {
    // 目录与文件名本身合法，但完整 UTF-16 路径超过产品保守限制。
    final longPath = 'C:\\${'deep\\' * 48}video.mp4';
    expect(
      () => validateOutputPath(
        longPath,
        operatingSystem: HostOperatingSystem.windows,
      ),
      throwsA(isA<OutputPathValidationException>()),
    );
  });

  /// 验证发布前校验会拒绝旧数据库中的非法最终文件名。
  test('拒绝非法最终文件名', () {
    // 冒号在 Windows 和跨平台安全策略中都不能作为普通文件名字符。
    expect(
      () => validateOutputPath(
        r'C:\Downloads\bad:name.mp4',
        operatingSystem: HostOperatingSystem.windows,
      ),
      throwsA(isA<OutputPathValidationException>()),
    );
  });
}
