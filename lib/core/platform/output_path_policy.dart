import 'dart:convert';

import 'package:path/path.dart' as p;

import 'runtime_platform.dart';

/// 输出路径不满足目标平台文件系统约束时抛出的业务异常。
final class OutputPathValidationException implements Exception {
  /// 保存用户可理解的失败原因和被拒绝路径。
  const OutputPathValidationException(this.message, this.path);

  /// 路径校验失败的具体原因。
  final String message;

  /// 入队或发布前被拒绝的完整路径。
  final String path;

  /// 日志和界面统一展示中文失败原因。
  @override
  String toString() => '$message：$path';
}

/// Windows 保留设备名，即使追加扩展名也不能作为普通文件名使用。
final RegExp _windowsReservedName = RegExp(
  r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
  caseSensitive: false,
);

/// 所有目标平台统一拒绝的控制字符和 Windows 特殊字符。
final RegExp _illegalOutputNameCharacters = RegExp(
  r'[<>:"/\\|?*\x00-\x1F\x7F]',
);

/// 把外部标题转换为可在全部支持平台创建的单个路径段。
String sanitizeOutputPathSegment(
  String value, {
  String fallback = '未命名视频',
  int maximumUtf8Bytes = 180,
}) {
  // 先替换控制符、分隔符和 Windows 特殊字符，再移除尾部点号与空格。
  var sanitized = value
      .replaceAll(_illegalOutputNameCharacters, '_')
      .trim()
      .replaceAll(RegExp(r'[. ]+$'), '');
  // Windows 设备名在其他平台也统一加前缀，保证设置跨平台迁移后仍可创建。
  if (_windowsReservedName.hasMatch(sanitized)) sanitized = '_$sanitized';
  // 全部字符被清理后使用稳定回退，不能创建空名称任务。
  if (sanitized.isEmpty) sanitized = fallback;
  // 按 UTF-8 字节裁剪，避免中文标题虽然字符数短却超过文件系统 NAME_MAX。
  sanitized = _truncateUtf8(sanitized, maximumUtf8Bytes);
  // 极端配置把字节上限设得过小时仍需返回非空安全名称。
  return sanitized.isEmpty
      ? _truncateUtf8(fallback, maximumUtf8Bytes)
      : sanitized;
}

/// 在任务入队或平台发布前验证完整输出路径和最终文件名。
void validateOutputPath(
  String outputPath, {
  required HostOperatingSystem operatingSystem,
}) {
  // 空路径没有可发布目标，应在进入文件 API 前给出稳定业务错误。
  if (outputPath.trim().isEmpty) {
    throw OutputPathValidationException('输出路径不能为空', outputPath);
  }
  // 最终文件名必须是单一安全路径段，目录部分由下载根目录和安全模板生成。
  final fileName = p.basename(outputPath);
  if (fileName.isEmpty ||
      fileName == '.' ||
      fileName == '..' ||
      _illegalOutputNameCharacters.hasMatch(fileName) ||
      RegExp(r'[. ]$').hasMatch(fileName) ||
      _windowsReservedName.hasMatch(fileName)) {
    throw OutputPathValidationException('输出文件名包含平台不支持的字符或名称', outputPath);
  }
  // Windows 使用 UTF-16 路径计数，其他目标平台按文件系统常见 UTF-8 字节限制。
  final pathLength = operatingSystem == HostOperatingSystem.windows
      ? outputPath.codeUnits.length
      : utf8.encode(outputPath).length;
  final maximumPathLength = switch (operatingSystem) {
    HostOperatingSystem.windows => 240,
    HostOperatingSystem.ios || HostOperatingSystem.macos => 1024,
    HostOperatingSystem.android || HostOperatingSystem.linux => 4096,
    HostOperatingSystem.unsupported => 1024,
  };
  if (pathLength > maximumPathLength) {
    throw OutputPathValidationException(
      '输出路径过长（当前 $pathLength，上限 $maximumPathLength）',
      outputPath,
    );
  }
  // 单个文件名统一限制在 255 UTF-8 字节内，兼容 NTFS、APFS 与常见 Linux 文件系统。
  final fileNameBytes = utf8.encode(fileName).length;
  if (fileNameBytes > 255) {
    throw OutputPathValidationException(
      '输出文件名过长（当前 $fileNameBytes 字节，上限 255）',
      outputPath,
    );
  }
}

/// 在不截断 Unicode 码点的前提下限制 UTF-8 字节数。
String _truncateUtf8(String value, int maximumBytes) {
  // 非正上限没有可容纳内容，返回空值交给调用方回退。
  if (maximumBytes <= 0) return '';
  final buffer = StringBuffer();
  var usedBytes = 0;
  for (final rune in value.runes) {
    // 单个码点转换后才能准确计算中英文和表情占用字节。
    final character = String.fromCharCode(rune);
    final characterBytes = utf8.encode(character).length;
    // 加入当前码点会越界时停止，不能留下半个代理项或损坏 UTF-8。
    if (usedBytes + characterBytes > maximumBytes) break;
    buffer.write(character);
    usedBytes += characterBytes;
  }
  // 返回按码点边界完成的安全前缀。
  return buffer.toString();
}
