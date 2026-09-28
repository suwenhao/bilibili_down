/// B 站网页二维码登录的一次请求。
final class BiliQrLoginRequest {
  /// 创建包含二维码内容和轮询键的不可变请求。
  const BiliQrLoginRequest({
    required this.qrCodeUrl,
    required this.qrCodeKey,
    required this.createdAt,
  });

  /// 应交给二维码组件生成图形的 B 站登录地址。
  final Uri qrCodeUrl;

  /// 后续查询扫码状态使用的一次性键。
  final String qrCodeKey;

  /// 本地创建时间，用于界面展示剩余有效期。
  final DateTime createdAt;
}

/// 二维码登录轮询状态。
enum BiliQrLoginStatus {
  /// 手机端尚未扫描二维码。
  waitingForScan,

  /// 手机端已经扫描，等待用户确认登录。
  waitingForConfirmation,

  /// 二维码已经过期，需要重新生成。
  expired,

  /// 登录成功且会话已经安全保存。
  success,
}

/// 一次二维码登录轮询结果。
final class BiliQrLoginPollResult {
  /// 创建可供登录界面展示的轮询结果。
  const BiliQrLoginPollResult({required this.status, required this.message});

  /// 当前二维码状态。
  final BiliQrLoginStatus status;

  /// B 站返回或本地补充的状态说明。
  final String message;

  /// 当前状态是否已经结束，不应继续轮询。
  bool get isTerminal {
    // 成功或过期都会使当前二维码失效。
    return status == BiliQrLoginStatus.success ||
        status == BiliQrLoginStatus.expired;
  }
}

/// 当前 B 站账号登录状态和基础资料。
final class BiliLoginProfile {
  /// 创建登录状态快照。
  const BiliLoginProfile({
    required this.isLoggedIn,
    this.userId,
    this.userName,
    this.avatarUrl,
    this.isVip = false,
  });

  /// 创建明确的未登录状态。
  const BiliLoginProfile.loggedOut()
    : isLoggedIn = false,
      userId = null,
      userName = null,
      avatarUrl = null,
      isVip = false;

  /// 当前 Cookie 是否仍被 B 站认可。
  final bool isLoggedIn;

  /// 登录账号数字 UID。
  final int? userId;

  /// 登录账号昵称。
  final String? userName;

  /// 登录账号头像地址。
  final Uri? avatarUrl;

  /// 当前账号是否处于大会员有效状态。
  final bool isVip;
}
