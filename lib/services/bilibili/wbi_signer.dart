import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/network/bili_network_client.dart';
import 'bili_api_exception.dart';
import 'bili_json.dart';

/// 为需要 WBI 的 B 站接口生成 wts 与 w_rid 参数。
final class WbiSigner {
  /// 使用统一网络客户端获取 nav 中的 WBI 图片密钥。
  WbiSigner(this._networkClient);

  /// WBI 混合密钥使用的固定字符位置表。
  static const List<int> _mixinKeyOrder = <int>[
    46,
    47,
    18,
    2,
    53,
    8,
    23,
    32,
    15,
    50,
    10,
    31,
    58,
    3,
    45,
    35,
    27,
    43,
    5,
    49,
    33,
    9,
    42,
    19,
    29,
    28,
    14,
    39,
    12,
    38,
    41,
    13,
    37,
    48,
    7,
    16,
    24,
    55,
    40,
    61,
    26,
    17,
    0,
    1,
    60,
    51,
    30,
    4,
    22,
    25,
    54,
    21,
    56,
    59,
    6,
    63,
    57,
    62,
    11,
    36,
    20,
    34,
    44,
    52,
  ];

  /// 获取 WBI 密钥的 nav 接口地址。
  static final Uri _navUri = Uri.https(
    'api.bilibili.com',
    '/x/web-interface/nav',
  );

  /// 统一网络客户端。
  final BiliNetworkClient _networkClient;

  /// 当前缓存的 32 字节混合密钥。
  String? _cachedMixinKey;

  /// 混合密钥缓存到期时间。
  DateTime? _cacheExpiresAt;

  /// 为任意字符串参数生成 WBI 签名。
  Future<Map<String, Object?>> sign(Map<String, Object?> parameters) async {
    // 获取缓存或重新请求混合密钥。
    final mixinKey = await _getMixinKey();
    // 复制输入参数，避免给调用方 Map 注入签名字段。
    final signed = <String, Object?>{...parameters};
    // WBI 时间戳使用当前 Unix 秒。
    signed['wts'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // 按键名排序后清理值中的 WBI 禁止字符。
    final sortedKeys = signed.keys.toList()..sort();
    final sanitizedParameters = <String, String>{};
    for (final key in sortedKeys) {
      // null 参数不参与查询和签名。
      final value = signed[key];
      if (value == null) continue;
      // B 站算法要求去掉 !'()* 五类字符。
      sanitizedParameters[key] = value.toString().replaceAll(
        RegExp(r"[!'()*]"),
        '',
      );
    }
    // 使用 Dart Uri 生成稳定的百分号编码查询串。
    final query = Uri(queryParameters: sanitizedParameters).query;
    // 查询串拼接混合密钥后计算 MD5 得到 w_rid。
    final digest = md5.convert(utf8.encode('$query$mixinKey')).toString();
    // 返回原排序参数和签名值。
    return <String, Object?>{...sanitizedParameters, 'w_rid': digest};
  }

  /// 获取有效缓存密钥或从 nav 接口刷新。
  Future<String> _getMixinKey() async {
    // 读取当前时间用于判断缓存是否仍有效。
    final now = DateTime.now();
    final cachedKey = _cachedMixinKey;
    final expiresAt = _cacheExpiresAt;
    // 十分钟内复用密钥，降低接口调用和风控概率。
    if (cachedKey != null && expiresAt != null && now.isBefore(expiresAt)) {
      return cachedKey;
    }
    // nav 未登录时可能返回 -101，但 data.wbi_img 仍然有效，因此读取原始包装。
    final envelope = await _networkClient.getJson(_navUri);
    final data = biliJsonObject(envelope['data'], 'data');
    final wbiImage = biliJsonObject(data['wbi_img'], 'data.wbi_img');
    // 从图片 URL 文件名提取 img_key 和 sub_key。
    final imageKey = _fileStem(biliJsonString(wbiImage['img_url']));
    final subKey = _fileStem(biliJsonString(wbiImage['sub_url']));
    // 两个密钥拼接后必须至少覆盖位置表。
    final sourceKey = '$imageKey$subKey';
    if (sourceKey.length < 64) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidResponse,
        message: 'B 站 WBI 密钥长度无效。',
      );
    }
    // 按固定位置表重排并截取前 32 个字符。
    final buffer = StringBuffer();
    for (final index in _mixinKeyOrder) {
      buffer.write(sourceKey[index]);
    }
    final mixinKey = buffer.toString().substring(0, 32);
    // 缓存十分钟，过期后重新读取 nav 以适应密钥变化。
    _cachedMixinKey = mixinKey;
    _cacheExpiresAt = now.add(const Duration(minutes: 10));
    // 返回新混合密钥。
    return mixinKey;
  }

  /// 从 WBI 图片 URL 中提取不含扩展名的文件名。
  String _fileStem(String url) {
    // 解析 URL 并读取最后一个路径段。
    final uri = Uri.tryParse(url);
    final filename = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : '';
    // 去掉最后一个点及其扩展名。
    final dot = filename.lastIndexOf('.');
    final stem = dot > 0 ? filename.substring(0, dot) : filename;
    // 空文件名说明 nav 返回结构异常。
    if (stem.isEmpty) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidResponse,
        message: 'B 站 WBI 图片地址无效。',
      );
    }
    // 返回图片密钥文本。
    return stem;
  }
}
