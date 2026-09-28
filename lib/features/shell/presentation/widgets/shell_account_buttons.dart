part of '../app_shell.dart';

/// 桌面侧栏顶部的登录入口和账号头像。
final class DesktopAccountAvatar extends StatelessWidget {
  /// 创建随登录状态切换内容的圆形账号按钮。
  const DesktopAccountAvatar({
    super.key,
    required this.state,
    required this.onTap,
  });

  /// 当前账号状态和已经加载的个人资料。
  final AccountState state;

  /// 点击后进入账号中心页面。
  final VoidCallback onTap;

  /// 构建未登录文字、真实头像或头像加载状态。
  @override
  Widget build(BuildContext context) {
    // 检查 Cookie 时保留已有资料，避免刷新过程中的头像闪烁。
    final profile = state.profile;
    // 只有服务明确返回已登录资料时才加载远程头像。
    final loggedIn = profile?.isLoggedIn == true;
    // 读屏和悬停提示优先使用昵称，未登录时明确这是登录入口。
    final label = loggedIn ? profile?.userName ?? 'B站账号' : '登录 B站账号';
    // 圆形按钮使用项目主色状态层，保持与侧栏其他入口一致。
    final colorScheme = Theme.of(context).colorScheme;
    return AppTooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: loggedIn
              ? colorScheme.surfaceContainerHighest
              : colorScheme.primaryContainer,
          shape: CircleBorder(
            side: BorderSide(
              color: loggedIn
                  ? colorScheme.primary.withValues(alpha: 0.55)
                  : colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            mouseCursor: SystemMouseCursors.click,
            child: SizedBox.square(
              dimension: 36,
              child: loggedIn
                  ? _buildLoggedInAvatar(context, profile!.avatarUrl)
                  : Center(
                      child: Text(
                        '登录',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建缓存头像，并在地址缺失或加载失败时回退账号图标。
  Widget _buildLoggedInAvatar(BuildContext context, Uri? avatarUrl) {
    // 账号接口没有返回头像时仍保留可识别的圆形个人图标。
    if (avatarUrl == null) {
      return Icon(
        Icons.person_rounded,
        color: Theme.of(context).colorScheme.primary,
      );
    }
    // 头像与视频封面共用应用 covers 缓存，清除缓存设置会同步生效。
    final decodeSize = (36 * MediaQuery.devicePixelRatioOf(context)).ceil();
    return CachedNetworkImage(
      imageUrl: avatarUrl.toString(),
      cacheManager: CoverCacheManager.instance,
      fit: BoxFit.cover,
      width: 36,
      height: 36,
      // 头像只有 36dp，限制内存位图尺寸，避免完整解码远程大头像。
      memCacheWidth: decodeSize,
      memCacheHeight: decodeSize,
      placeholder: (BuildContext context, String url) => const Center(
        child: SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (BuildContext context, String url, Object error) => Icon(
        Icons.person_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
