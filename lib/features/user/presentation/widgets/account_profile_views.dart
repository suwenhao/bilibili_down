part of '../dialogs/account_dialog.dart';

/// 已登录账号资料。
final class LoggedInAccount extends StatelessWidget {
  /// 创建资料和退出操作。
  const LoggedInAccount({
    super.key,
    required this.profile,
    required this.onLogout,
  });

  /// B 站账号资料。
  final BiliLoginProfile profile;

  /// 退出登录回调。
  final VoidCallback onLogout;

  /// 构建头像、昵称、会员状态和退出按钮。
  @override
  Widget build(BuildContext context) {
    // 有效头像地址使用网络圆形图，失败时回退账号图标。
    final avatar = profile.avatarUrl == null
        ? const CircleAvatar(
            radius: 42,
            child: Icon(Icons.person_rounded, size: 42),
          )
        : CircleAvatar(
            radius: 42,
            backgroundImage: NetworkImage(profile.avatarUrl.toString()),
          );
    // 账号内容居中展示。
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(child: avatar),
        const SizedBox(height: 16),
        Text(
          profile.userName ?? 'B站用户',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          profile.isVip ? '大会员有效，可解析账号可用高画质' : '普通账号',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: profile.isVip
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        if (profile.userId != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            'UID ${profile.userId}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ],
        const SizedBox(height: 24),
        AppActionButton(
          variant: AppActionButtonVariant.outlined,
          onPressed: onLogout,
          icon: Icons.logout_rounded,
          label: '退出登录',
        ),
      ],
    );
  }
}

/// 账号服务错误内容。
final class AccountError extends StatelessWidget {
  /// 创建错误说明和重试操作。
  const AccountError({super.key, required this.message, required this.onRetry});

  /// 错误文本。
  final String message;

  /// 重试回调。
  final VoidCallback onRetry;

  /// 构建错误内容。
  @override
  Widget build(BuildContext context) {
    // 错误页保留重试和返回未登录流程的能力。
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Icon(
          Icons.error_outline_rounded,
          size: 56,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 20),
        AppActionButton(
          variant: AppActionButtonVariant.filled,
          onPressed: onRetry,
          icon: Icons.refresh_rounded,
          label: '重新检查',
        ),
      ],
    );
  }
}
