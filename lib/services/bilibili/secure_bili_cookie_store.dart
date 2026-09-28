import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'bili_cookie_store.dart';

/// 使用系统 Keychain、Keystore 或凭据库保存 B 站 Cookie。
final class SecureBiliCookieStore implements BiliCookieStore {
  /// 支持注入安全存储实例，默认使用插件推荐配置。
  SecureBiliCookieStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// Cookie 在安全存储中使用的固定键。
  static const String _cookieKey = 'bilibili.cookie_header';

  /// 刷新令牌在安全存储中使用的固定键。
  static const String _refreshTokenKey = 'bilibili.refresh_token';

  /// 新版把 Cookie 与 Refresh Token 作为单份 JSON 原子语义快照保存。
  static const String _sessionKey = 'bilibili.login_session.v2';

  /// 设备态扫码登录使用的稳定设备 ID，不属于账号凭据，退出登录时保留。
  static const String _loginDeviceIdKey = 'bilibili.login_device_id';

  /// 跨平台安全存储插件。
  final FlutterSecureStorage _storage;

  /// 从安全存储读取完整 Cookie。
  @override
  Future<String?> readCookieHeader() async {
    // 优先读取单键会话快照，避免两次安全存储写入产生新旧凭据错配。
    final session = await _readSession();
    if (session != null) return session.cookieHeader;
    // 升级前安装仍使用旧 Cookie 键，首次新会话写入后会自动迁移清理。
    return _storage.read(key: _cookieKey);
  }

  /// 从安全存储读取刷新令牌。
  @override
  Future<String?> readRefreshToken() async {
    // Cookie 和 Refresh Token 从同一快照读取，保证属于同一次登录或刷新。
    final session = await _readSession();
    if (session != null) return session.refreshToken;
    // 兼容旧版独立刷新令牌键。
    return _storage.read(key: _refreshTokenKey);
  }

  /// 读取设备态扫码登录使用的稳定设备 ID。
  @override
  Future<String?> readLoginDeviceId() async {
    // 设备 ID 只用于 B 站扫码设备展示，不包含账号 Cookie。
    final deviceId = await _storage.read(key: _loginDeviceIdKey);
    return deviceId?.trim().isEmpty == false ? deviceId!.trim() : null;
  }

  /// 保存设备态扫码登录使用的稳定设备 ID。
  @override
  Future<void> writeLoginDeviceId(String deviceId) async {
    // 空设备 ID 不能覆盖已有稳定身份，避免下一次登录设备列表反复变化。
    if (deviceId.trim().isEmpty) {
      throw ArgumentError.value(deviceId, 'deviceId', '设备 ID 不能为空');
    }
    await _storage.write(key: _loginDeviceIdKey, value: deviceId.trim());
  }

  /// 校验非空后写入完整登录会话。
  @override
  Future<void> writeLoginSession({
    required String cookieHeader,
    String? refreshToken,
  }) async {
    // 空 Cookie 不应覆盖仍有效的登录会话。
    if (cookieHeader.trim().isEmpty) {
      throw ArgumentError.value(cookieHeader, 'cookieHeader', 'Cookie 不能为空');
    }
    // 单次安全存储写入同时替换两项敏感值，避免进程中断留下半份新会话。
    await _storage.write(
      key: _sessionKey,
      value: jsonEncode(<String, Object?>{
        'cookieHeader': cookieHeader.trim(),
        'refreshToken': refreshToken?.trim().isEmpty == false
            ? refreshToken!.trim()
            : null,
      }),
    );
    // 新快照落盘后再清理旧键，升级中断仍至少保留一份完整可读会话。
    await _storage.delete(key: _cookieKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  /// 删除安全存储中的登录会话。
  @override
  Future<void> clear() async {
    // 先删除新版单键快照，再清除升级前可能残留的两个旧键。
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _cookieKey);
    // Cookie 清除后刷新令牌也必须同步删除。
    await _storage.delete(key: _refreshTokenKey);
    // 设备 ID 不随账号退出删除，保持下一次扫码仍显示同一台设备。
  }

  /// 解析新版单键安全会话，损坏值回退旧键而不把异常带到网络层。
  Future<_StoredBiliSession?> _readSession() async {
    final encoded = await _storage.read(key: _sessionKey);
    if (encoded == null || encoded.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;
      final cookieHeader = decoded['cookieHeader']?.toString().trim();
      if (cookieHeader == null || cookieHeader.isEmpty) return null;
      final refreshToken = decoded['refreshToken']?.toString().trim();
      return _StoredBiliSession(
        cookieHeader: cookieHeader,
        refreshToken: refreshToken?.isEmpty == true ? null : refreshToken,
      );
    } on FormatException {
      // 安全存储值被截断时不暴露内容，允许读取旧键或重新登录。
      return null;
    }
  }
}

/// 从单键 JSON 解码后的内存会话快照。
final class _StoredBiliSession {
  /// 保存同一次写入产生的 Cookie 与可选刷新令牌。
  const _StoredBiliSession({
    required this.cookieHeader,
    required this.refreshToken,
  });

  /// 完整浏览器请求 Cookie。
  final String cookieHeader;

  /// 与 Cookie 同批签发的刷新令牌。
  final String? refreshToken;
}
