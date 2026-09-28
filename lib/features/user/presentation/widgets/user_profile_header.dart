part of '../user_center_page.dart';

/// 用户中心顶部导航。
final class UserTopBar extends StatelessWidget {
  /// 创建带返回按钮和标题的用户页顶栏。
  const UserTopBar({super.key, required this.mobile, required this.onBack});

  /// 是否使用手机紧凑高度。
  final bool mobile;

  /// 返回上一页回调。
  final VoidCallback onBack;

  /// 构建页面标题栏。
  @override
  Widget build(BuildContext context) {
    return Container(
      height: mobile ? 54 : 60,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: mobile ? 6 : 14),
      child: Row(
        children: <Widget>[
          AppCircleIconButton(
            onPressed: onBack,
            tooltip: '返回',
            dimension: 40,
            iconSize: 22,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Text('个人中心', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

/// 个人资料顶部卡片。
final class ProfileHero extends StatelessWidget {
  /// 创建展示头像、昵称和会员状态的个人资料卡。
  const ProfileHero({
    super.key,
    required this.profile,
    required this.mobile,
    required this.busy,
    required this.onLogout,
  });

  /// 当前登录账号资料。
  final BiliLoginProfile profile;

  /// 是否使用移动端紧凑排版。
  final bool mobile;

  /// 是否有互斥操作正在执行，执行期间禁用退出按钮。
  final bool busy;

  /// 退出登录回调。
  final VoidCallback onLogout;

  /// 构建响应主题色的资料区。
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: <Color>[
            colorScheme.primary.withValues(alpha: 0.22),
            colorScheme.surfaceContainerHigh,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(mobile ? 16 : 22),
        child: Row(
          children: <Widget>[
            AvatarImage(profile: profile, size: mobile ? 58 : 72),
            SizedBox(width: mobile ? 14 : 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    profile.userName ?? 'B站用户',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mobile
                        ? Theme.of(context).textTheme.titleLarge
                        : Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'UID ${profile.userId ?? '-'} · ${profile.isVip ? '大会员' : '普通账号'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!mobile) ...<Widget>[
              const SizedBox(width: 16),
              AppActionButton(
                variant: AppActionButtonVariant.destructiveOutlined,
                onPressed: busy ? null : onLogout,
                icon: Icons.logout_rounded,
                label: '退出登录',
              ),
            ] else ...<Widget>[
              const SizedBox(width: 8),
              AppCircleIconButton(
                onPressed: busy ? null : onLogout,
                tooltip: '退出登录',
                variant: AppCircleIconButtonVariant.destructiveOutlined,
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 用户头像图片。
final class AvatarImage extends StatelessWidget {
  /// 创建固定尺寸圆形头像。
  const AvatarImage({super.key, required this.profile, required this.size});

  /// 登录资料中可能包含的头像地址。
  final BiliLoginProfile profile;

  /// 头像宽高。
  final double size;

  /// 构建缓存头像或默认图标。
  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile.avatarUrl;
    final colorScheme = Theme.of(context).colorScheme;
    if (avatarUrl == null) {
      return CircleAvatar(
        radius: size / 2,
        child: Icon(Icons.person_rounded, size: size * 0.52),
      );
    }
    final decodeSize = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatarUrl.toString(),
        cacheManager: CoverCacheManager.instance,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: decodeSize,
        memCacheHeight: decodeSize,
        placeholder: (context, url) => ColoredBox(
          color: colorScheme.surfaceContainerHighest,
          child: const Center(
            child: SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => ColoredBox(
          color: colorScheme.surfaceContainerHighest,
          child: Icon(Icons.person_rounded, color: colorScheme.primary),
        ),
      ),
    );
  }
}
