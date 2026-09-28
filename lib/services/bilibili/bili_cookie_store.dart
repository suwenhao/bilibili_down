/// 读取和保存完整 B 站 Cookie 请求头的安全存储接口。
abstract interface class BiliCookieStore {
  /// 读取当前登录会话的完整 Cookie 文本。
  Future<String?> readCookieHeader();

  /// 读取二维码登录返回的刷新令牌。
  Future<String?> readRefreshToken();

  /// 读取当前设备态扫码登录使用的稳定设备 ID。
  Future<String?> readLoginDeviceId();

  /// 保存当前设备态扫码登录使用的稳定设备 ID。
  Future<void> writeLoginDeviceId(String deviceId);

  /// 保存二维码登录返回的完整 Cookie 和可选刷新令牌。
  Future<void> writeLoginSession({
    required String cookieHeader,
    String? refreshToken,
  });

  /// 退出登录时清除 Cookie 和刷新令牌。
  Future<void> clear();
}
