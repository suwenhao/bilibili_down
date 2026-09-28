import 'bili_api_exception.dart';

/// 将动态 JSON 值转换为字符串键对象，类型不符时抛出接口响应异常。
Map<String, Object?> biliJsonObject(Object? value, String fieldName) {
  // B 站部分接口可能返回 null，调用方要求对象时视为结构错误。
  if (value is! Map) {
    throw BiliApiException(
      kind: BiliApiErrorKind.invalidResponse,
      message: 'B 站响应字段 $fieldName 不是对象。',
    );
  }
  // 动态键统一转成字符串，避免后续使用 dynamic 下标。
  return value.map(
    (Object? key, Object? item) => MapEntry(key.toString(), item),
  );
}

/// 将动态 JSON 数组转换为对象列表。
List<Map<String, Object?>> biliJsonObjectList(Object? value, String fieldName) {
  // 缺失的可选数组按空列表处理。
  if (value == null) return const <Map<String, Object?>>[];
  // 非数组字段说明接口结构发生变化。
  if (value is! List) {
    throw BiliApiException(
      kind: BiliApiErrorKind.invalidResponse,
      message: 'B 站响应字段 $fieldName 不是数组。',
    );
  }
  // 每个数组元素都必须是 JSON 对象。
  return value
      .map((Object? item) => biliJsonObject(item, '$fieldName[]'))
      .toList(growable: false);
}

/// 从 JSON 值读取字符串，数字等值会使用 toString 转换。
String biliJsonString(Object? value, {String fallback = ''}) {
  // null 使用调用方提供的默认值。
  if (value == null) return fallback;
  // 字符串保持原值，其他简单值转换为文本。
  return value is String ? value : value.toString();
}

/// 从 JSON 值读取整数，兼容 num 和数字字符串。
int? biliJsonInt(Object? value) {
  // num 直接截取整数，字符串尝试解析。
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  // 其他类型无法安全转换。
  return null;
}

/// 从 B 站秒级时间戳创建本地 DateTime。
DateTime? biliDateTimeFromSeconds(Object? value) {
  // 解析时间戳并过滤零或负值。
  final seconds = biliJsonInt(value);
  if (seconds == null || seconds <= 0) return null;
  // B 站时间戳以 Unix 秒表示，先创建 UTC 再转本地时间。
  return DateTime.fromMillisecondsSinceEpoch(
    seconds * 1000,
    isUtc: true,
  ).toLocal();
}

/// 读取 B 站 API 包装并返回 data 或 result 对象。
Map<String, Object?> biliEnvelopeData(
  Map<String, Object?> envelope, {
  String field = 'data',
}) {
  // 业务码缺失按响应结构错误处理。
  final code = biliJsonInt(envelope['code']);
  if (code == null) {
    throw const BiliApiException(
      kind: BiliApiErrorKind.invalidResponse,
      message: 'B 站响应缺少业务码。',
    );
  }
  // 非零业务码统一映射为稳定异常。
  if (code != 0) {
    final message = biliJsonString(
      envelope['message'] ?? envelope['msg'],
      fallback: 'B 站接口请求失败。',
    );
    throw BiliApiException.fromApi(code: code, message: message);
  }
  // 成功响应必须包含调用方指定的数据对象。
  return biliJsonObject(envelope[field], field);
}
