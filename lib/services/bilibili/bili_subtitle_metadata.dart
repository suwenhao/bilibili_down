import 'dart:convert';
import 'dart:typed_data';

/// 解码新版字幕接口的 data(1) / subtitles(3)，输出与旧 JSON 接口相同的字段。
List<Map<String, Object?>> decodeBiliSubtitleMetadata(Uint8List bytes) {
  // 此接口只返回轨道元数据，限制大小防止异常响应拖慢主 isolate。
  if (bytes.length > 1024 * 1024) {
    throw const FormatException('字幕元数据超过大小上限。');
  }
  // 顶层字段 1 包含字幕数据，字段 3 的每条消息对应一个字幕轨道。
  final tracks = <Map<String, Object?>>[];
  for (final data in _messageFields(bytes, 1)) {
    for (final track in _messageFields(data, 3)) {
      // 已知字符串字段为语言代码、显示名称和短期下载地址。
      final fields = <int, String>{};
      final reader = _SubtitleWireReader(track);
      while (!reader.isAtEnd) {
        final (field, value) = reader.readField();
        if (value != null && field >= 3 && field <= 5) {
          fields[field] = utf8.decode(value);
        }
      }
      tracks.add(<String, Object?>{
        'lan': fields[3],
        'lan_doc': fields[4],
        'subtitle_url': fields[5],
      });
    }
  }
  return tracks;
}

/// 仅遍历指定的长度字段，不递归解码未知数据，兼容接口增加字段。
Iterable<Uint8List> _messageFields(Uint8List bytes, int fieldNumber) sync* {
  // 每层消息独立维护游标，嵌套边界不能越过父消息长度。
  final reader = _SubtitleWireReader(bytes);
  while (!reader.isAtEnd) {
    final (field, value) = reader.readField();
    if (field == fieldNumber && value != null) yield value;
  }
}

/// 读取字幕接口需要的 Protobuf wire 类型，遇到截断或非法长度立即失败。
final class _SubtitleWireReader {
  /// 保存当前层消息的字节视图，读取不会修改输入。
  _SubtitleWireReader(this._bytes);

  /// 当前消息的完整边界。
  final Uint8List _bytes;

  /// 下一个未消费字节的偏移量。
  int _offset = 0;

  /// 是否已完整消费当前消息。
  bool get isAtEnd => _offset == _bytes.length;

  /// 返回字段号与可选长度字段内容；整数和定长未知字段只跳过。
  (int, Uint8List?) readField() {
    // tag 的低三位描述 wire 类型，其余位是字段号。
    final tag = _readVarint();
    final field = tag >> 3;
    if (field <= 0 || field > 0x1fffffff) {
      throw const FormatException('字幕元数据字段号无效。');
    }
    switch (tag & 7) {
      case 0:
        // ID 等整数不参与轨道选择，但必须完整消费。
        _readVarint();
        return (field, null);
      case 1:
        // 跳过未知的 64 位字段。
        _take(8);
        return (field, null);
      case 2:
        // 字符串和嵌套消息均使用显式字节长度。
        return (field, _take(_readVarint()));
      case 5:
        // 跳过未知的 32 位字段。
        _take(4);
        return (field, null);
      default:
        // 当前字幕协议不使用 group，拒绝错误页面或未知结构。
        throw const FormatException('字幕元数据编码类型不受支持。');
    }
  }

  /// 读取最多十字节的整数，防止损坏输入导致无限循环。
  int _readVarint() {
    // 累加每个字节的低七位，最高位只用于判断是否继续。
    var value = 0;
    for (var index = 0; index < 10; index++) {
      if (isAtEnd) throw const FormatException('字幕元数据整数被截断。');
      final byte = _bytes[_offset++];
      if (index == 9 && byte > 1) {
        throw const FormatException('字幕元数据整数超出范围。');
      }
      value |= (byte & 0x7f) << (index * 7);
      if (byte < 0x80) return value;
    }
    throw const FormatException('字幕元数据整数过长。');
  }

  /// 返回边界内的零拷贝视图并推进游标。
  Uint8List _take(int length) {
    // 使用剩余长度比较，负数或超出消息边界的长度均不可接受。
    if (length < 0 || length > _bytes.length - _offset) {
      throw const FormatException('字幕元数据字段被截断。');
    }
    final start = _offset;
    _offset += length;
    return Uint8List.sublistView(_bytes, start, _offset);
  }
}
