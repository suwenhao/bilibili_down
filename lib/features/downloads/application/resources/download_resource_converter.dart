import 'dart:convert';
import 'dart:io';

import '../../domain/download_extra_resource.dart';
import '../../domain/download_task_phase.dart';

/// ASS 固定头部由内存转换和流式文件转换共用，避免两条路径输出格式漂移。
const String _danmakuAssHeader = '''[Script Info]
ScriptType: v4.00+
PlayResX: 1920
PlayResY: 1080
WrapStyle: 2

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Microsoft YaHei,40,&H00FFFFFF,&H00FFFFFF,&H00101010,&H64000000,0,0,0,0,100,100,0,0,1,2,0,8,20,20,20,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
''';

/// 匹配一条完整 d 节点，属性顺序沿用 B 站 XML 接口约定。
final RegExp _danmakuElementPattern = RegExp(
  r'<d\s+[^>]*p="([^"]+)"[^>]*>(.*?)</d>',
  caseSensitive: false,
  dotAll: true,
);

/// 定位可能跨 UTF-8 分块边界的弹幕起始标签。
final RegExp _danmakuStartPattern = RegExp(r'<d\s', caseSensitive: false);

/// 定位一条弹幕的结束标签，容忍标签内非标准空白。
final RegExp _danmakuEndPattern = RegExp(r'</d\s*>', caseSensitive: false);

/// 将附加资源类型映射为最终产物分类。
DownloadArtifactKind artifactKindForExtraResource(
  DownloadExtraResource resource,
) {
  // 音频使用媒体管线的 output；其他类型保留更精确的资源语义。
  return switch (resource) {
    DownloadExtraResource.cover => DownloadArtifactKind.cover,
    DownloadExtraResource.audio => DownloadArtifactKind.output,
    DownloadExtraResource.danmakuXml ||
    DownloadExtraResource.danmakuAss => DownloadArtifactKind.danmaku,
    DownloadExtraResource.subtitles ||
    DownloadExtraResource.aiSubtitles => DownloadArtifactKind.subtitle,
  };
}

/// 把 B 站 XML 弹幕正文转换为基础 ASS 文件。
String biliDanmakuXmlToAss(String xml) {
  // 固定头部使用通用 1920x1080 画布和默认样式，播放器可按视频尺寸缩放。
  final buffer = StringBuffer(_danmakuAssHeader);
  // 每条 d 节点的 p 属性包含出现秒数、模式、字号和十进制 RGB 颜色。
  final matches = _danmakuElementPattern.allMatches(xml);
  for (final match in matches) {
    // 属性缺损的弹幕由共享转换函数跳过，不能让单条脏数据中断整份 ASS。
    final line = _danmakuMatchToAssLine(match);
    if (line != null) buffer.writeln(line);
  }
  // 返回完整文本，由调用方一次写入目标文件。
  return buffer.toString();
}

/// 流式读取 XML 并逐条写入 ASS，避免同时持有完整 XML 与完整 ASS 字符串。
Future<void> convertBiliDanmakuXmlFileToAss({
  required String inputPath,
  required String outputPath,
  int maximumEntryCharacters = 1024 * 1024,
}) async {
  // 单条弹幕不应接近一兆字符；该上限防止损坏 XML 缺少结束标签时缓存无限增长。
  if (maximumEntryCharacters <= 0) {
    throw ArgumentError.value(
      maximumEntryCharacters,
      'maximumEntryCharacters',
      '单条弹幕字符上限必须大于零。',
    );
  }
  // 输出使用 IOSink 增量写入，成功前不会把完整 ASS 保留在 Dart 堆中。
  final outputFile = File(outputPath);
  final sink = outputFile.openWrite();
  // 只保存尚未形成完整 d 节点的尾部文本，正常情况下长度仅为单条弹幕。
  var pending = '';
  try {
    sink.write(_danmakuAssHeader);
    // UTF-8 解码器会跨字节块保留不完整字符，中文不会在边界处损坏。
    await for (final chunk in File(
      inputPath,
    ).openRead().transform(utf8.decoder)) {
      pending += chunk;
      while (true) {
        // 丢弃 XML 头部和 d 节点之间的无关文本，只保留可能跨块的“<d”前缀。
        final startMatch = _danmakuStartPattern.firstMatch(pending);
        if (startMatch == null) {
          pending = pending.length <= 2
              ? pending
              : pending.substring(pending.length - 2);
          break;
        }
        // 找到开始标签后等待同一节点结束，期间限制异常单节点占用。
        // allMatches 的起始偏移避免结束标签搜索回到当前节点之前。
        final endMatches = _danmakuEndPattern
            .allMatches(pending, startMatch.start)
            .iterator;
        // 迭代器只取最近结束标签，不生成额外匹配列表。
        final endMatch = endMatches.moveNext() ? endMatches.current : null;
        if (endMatch == null) {
          pending = pending.substring(startMatch.start);
          if (pending.length > maximumEntryCharacters) {
            throw FormatException(
              '单条弹幕 XML 超过 $maximumEntryCharacters 字符安全上限。',
            );
          }
          break;
        }
        // 即使结束标签已经到达，完整节点仍必须满足相同单条大小上限。
        if (endMatch.end - startMatch.start > maximumEntryCharacters) {
          throw FormatException('单条弹幕 XML 超过 $maximumEntryCharacters 字符安全上限。');
        }
        // 当前节点已经完整，单独匹配属性并立即写入一行 ASS。
        final element = pending.substring(startMatch.start, endMatch.end);
        final match = _danmakuElementPattern.firstMatch(element);
        final line = match == null ? null : _danmakuMatchToAssLine(match);
        if (line != null) sink.writeln(line);
        // 移除已消费节点，继续解析同一输入块里的后续弹幕。
        pending = pending.substring(endMatch.end);
      }
    }
    // 等待操作系统写完所有输出块，发布成品前必须保证文件内容完整。
    await sink.flush();
  } catch (_) {
    // 转换失败时先关闭句柄并删除半成品，重试不能误用残留 ASS。
    await sink.close();
    if (await outputFile.exists()) await outputFile.delete();
    rethrow;
  }
  // 正常完成后关闭文件句柄，Android 发布器随后才能安全移动文件。
  await sink.close();
}

/// 把一条已匹配弹幕转换为 ASS Dialogue，脏属性返回空并由调用方跳过。
String? _danmakuMatchToAssLine(RegExpMatch match) {
  // p 属性包含出现秒数、模式、字号和十进制 RGB 颜色。
  final parts = (match.group(1) ?? '').split(',');
  if (parts.isEmpty) return null;
  final startSeconds = double.tryParse(parts.first);
  if (startSeconds == null) return null;
  // 默认展示五秒；滚动轨迹由 ASS move 标签从右向左实现。
  final endSeconds = startSeconds + 5;
  final mode = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
  final fontSize = parts.length > 2 ? int.tryParse(parts[2]) ?? 25 : 25;
  final color = parts.length > 3
      ? int.tryParse(parts[3]) ?? 0xFFFFFF
      : 0xFFFFFF;
  final text = _escapeAssText(_decodeXmlEntities(match.group(2) ?? ''));
  // 顶部、底部和滚动弹幕分别使用稳定 ASS 覆盖标签。
  final positionTag = switch (mode) {
    4 => r'{\an2}',
    5 => r'{\an8}',
    _ => r'{\move(1920,120,-400,120)}',
  };
  final styleTag =
      r'{\fs' + fontSize.toString() + r'\c&H' + _assBgrColor(color) + r'&}';
  return 'Dialogue: 0,${_assTime(startSeconds)},${_assTime(endSeconds)},'
      'Default,,0,0,0,,$positionTag$styleTag$text';
}

/// 把 B 站 BCC 字幕 JSON 转换为 SRT。
String biliSubtitleJsonToSrt(String source) {
  // 外部接口返回必须是 JSON 对象，格式异常时直接让任务进入失败态供用户重试。
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('字幕响应不是 JSON 对象。');
  }
  // body 是按时间排序的字幕段列表。
  final body = decoded['body'];
  if (body is! List) throw const FormatException('字幕响应缺少 body。');
  final buffer = StringBuffer();
  // 输出序号必须连续，跳过坏数据时不能沿用原列表索引。
  var sequence = 1;
  for (final item in body) {
    if (item is! Map) continue;
    final from = item['from'];
    final to = item['to'];
    final content = item['content'];
    if (from is! num || to is! num || content is! String) continue;
    buffer
      ..writeln(sequence++)
      ..writeln('${_srtTime(from.toDouble())} --> ${_srtTime(to.toDouble())}')
      ..writeln(content.trim())
      ..writeln();
  }
  // 空字幕也视为接口异常，避免生成看似成功的空文件。
  if (sequence == 1) throw const FormatException('字幕正文为空。');
  return buffer.toString();
}

/// 在读取前限制 BCC JSON 文件大小并转换为 SRT，避免异常响应占满 Dart 堆。
Future<void> convertBiliSubtitleJsonFileToSrt({
  required String inputPath,
  required String outputPath,
  int maximumInputBytes = 16 * 1024 * 1024,
}) async {
  // 字幕 JSON 正常远小于十六兆；非正上限属于调用方配置错误。
  if (maximumInputBytes <= 0) {
    throw ArgumentError.value(
      maximumInputBytes,
      'maximumInputBytes',
      '字幕 JSON 字节上限必须大于零。',
    );
  }
  // 读取文件内容前先查询大小，异常大响应不会先分配完整字符串。
  final inputFile = File(inputPath);
  final inputBytes = await inputFile.length();
  if (inputBytes > maximumInputBytes) {
    throw FormatException('字幕 JSON 超过 $maximumInputBytes 字节安全上限。');
  }
  // 通过上限后沿用原有严格 JSON 校验和连续编号转换规则。
  final source = await inputFile.readAsString();
  final srt = biliSubtitleJsonToSrt(source);
  // 转换成功后一次写入目标，JSON 格式错误时不会留下半成品。
  await File(outputPath).writeAsString(srt);
}

/// 把秒数格式化为 ASS 的 h:mm:ss.cc。
String _assTime(double seconds) {
  // 负时间统一截断为零，兼容接口异常时间戳。
  final centiseconds = (seconds.clamp(0, double.infinity) * 100).round();
  final hours = centiseconds ~/ 360000;
  final minutes = (centiseconds ~/ 6000) % 60;
  final secs = (centiseconds ~/ 100) % 60;
  final fraction = centiseconds % 100;
  return '$hours:${minutes.toString().padLeft(2, '0')}:'
      '${secs.toString().padLeft(2, '0')}.${fraction.toString().padLeft(2, '0')}';
}

/// 把秒数格式化为 SRT 的 HH:mm:ss,SSS。
String _srtTime(double seconds) {
  // SRT 使用毫秒精度，负值同样截断为零。
  final milliseconds = (seconds.clamp(0, double.infinity) * 1000).round();
  final hours = milliseconds ~/ 3600000;
  final minutes = (milliseconds ~/ 60000) % 60;
  final secs = (milliseconds ~/ 1000) % 60;
  final fraction = milliseconds % 1000;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${secs.toString().padLeft(2, '0')},${fraction.toString().padLeft(3, '0')}';
}

/// 将十进制 RGB 转为 ASS 使用的 BGR 十六进制。
String _assBgrColor(int rgb) {
  // ASS 颜色顺序为 BBGGRR，与接口 RGB 顺序相反。
  final red = (rgb >> 16) & 0xFF;
  final green = (rgb >> 8) & 0xFF;
  final blue = rgb & 0xFF;
  return '${blue.toRadixString(16).padLeft(2, '0')}'
          '${green.toRadixString(16).padLeft(2, '0')}'
          '${red.toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

/// 解码弹幕 XML 中常见实体和数字实体。
String _decodeXmlEntities(String value) {
  // 先处理数字实体，再处理五个 XML 预定义实体。
  final numeric = value.replaceAllMapped(RegExp(r'&#(x[0-9a-fA-F]+|\d+);'), (
    Match match,
  ) {
    final raw = match.group(1)!;
    final codePoint = raw.startsWith('x')
        ? int.tryParse(raw.substring(1), radix: 16)
        : int.tryParse(raw);
    // 非法码点保留原文本，避免转换阶段抛出范围异常。
    if (codePoint == null || codePoint < 0 || codePoint > 0x10FFFF) {
      return match.group(0)!;
    }
    return String.fromCharCode(codePoint);
  });
  return numeric
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
}

/// 转义 ASS 文本中的控制字符。
String _escapeAssText(String value) {
  // 反斜杠和花括号会被 ASS 当作样式指令，换行使用显式 \N。
  return value
      .replaceAll(r'\', r'\\')
      .replaceAll('{', r'\{')
      .replaceAll('}', r'\}')
      .replaceAll('\r\n', r'\N')
      .replaceAll('\n', r'\N')
      .replaceAll('\r', r'\N');
}
