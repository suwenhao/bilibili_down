part of '../user_center_page.dart';

/// 登录要求空态。
final class LoginRequiredView extends StatelessWidget {
  /// 创建需要登录提示。
  const LoginRequiredView({
    super.key,
    required this.checking,
    required this.embedded,
    required this.onBack,
    required this.onLogin,
  });

  /// 是否正在检查登录状态。
  final bool checking;

  /// 是否嵌入桌面主内容区，嵌入时不展示独立页面返回栏。
  final bool embedded;

  /// 返回回调。
  final VoidCallback onBack;

  /// 登录回调。
  final VoidCallback onLogin;

  /// 构建登录提示。
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        if (!embedded) UserTopBar(mobile: true, onBack: onBack),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.account_circle_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      checking ? '正在检查登录状态…' : '登录后查看个人内容',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '历史、收藏和最近点赞需要当前账号授权后才能读取。',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    AppActionButton(
                      variant: AppActionButtonVariant.filled,
                      onPressed: checking ? null : onLogin,
                      loading: checking,
                      icon: Icons.login_rounded,
                      label: checking ? '检查中…' : '去登录',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 用户中心加载态。
final class UserLoadingState extends StatelessWidget {
  /// 创建居中加载状态。
  const UserLoadingState({super.key, this.label});

  /// 加载中需要补充展示的业务进度。
  final String? label;

  /// 构建加载进度。
  @override
  Widget build(BuildContext context) {
    final trimmedLabel = label?.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            if (trimmedLabel != null && trimmedLabel.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                trimmedLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 用户中心错误态。
final class UserErrorState extends StatelessWidget {
  /// 创建错误说明和重试按钮。
  const UserErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  /// 用户可读错误文案。
  final String message;

  /// 重试回调。
  final VoidCallback onRetry;

  /// 构建错误态。
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            AppActionButton(
              variant: AppActionButtonVariant.outlined,
              onPressed: onRetry,
              icon: Icons.refresh_rounded,
              label: '重试',
            ),
          ],
        ),
      ),
    );
  }
}

/// 用户中心空态。
final class UserEmptyState extends StatelessWidget {
  /// 创建空态说明。
  const UserEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  /// 空态图标。
  final IconData icon;

  /// 空态标题。
  final String title;

  /// 空态说明。
  final String description;

  /// 构建空态卡。
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 46, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
