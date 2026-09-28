part of '../app_shell.dart';

/// 应用全局顶栏。
final class AppHeader extends StatelessWidget {
  /// 创建带主题和账号操作的顶栏。
  const AppHeader({
    super.key,
    required this.accountState,
    required this.onToggleTheme,
    required this.onOpenAccount,
  });

  /// 当前账号状态，用于在移动顶栏展示真实头像或未登录图标。
  final AccountState accountState;

  /// 快捷切换亮暗主题回调。
  final VoidCallback onToggleTheme;

  /// 打开账号页回调。
  final VoidCallback onOpenAccount;

  /// 构建品牌标识和全局操作。
  @override
  Widget build(BuildContext context) {
    // 顶栏使用主题表面色并保留底部分隔线。
    return Container(
      // 解析和任务页与设置中心统一使用 54dp 手机标题栏高度。
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: <Widget>[
          // 品牌图标使用主色背景和播放符号。
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 12),
          // 产品名保持单行并占用剩余空间。
          Expanded(
            child: Text(
              'BiliDown',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          // 主题按钮带语义提示，键鼠和触摸均可操作。
          AppCircleIconButton(
            onPressed: onToggleTheme,
            tooltip: '切换亮色 / 暗色',
            dimension: 40,
            iconSize: 22,
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          const SizedBox(width: 4),
          // 账号入口放在顶栏，已登录展示头像，未登录展示账号图标。
          MobileAccountButton(state: accountState, onTap: onOpenAccount),
        ],
      ),
    );
  }
}

/// 移动端顶栏的账号按钮，登录后展示头像。
final class MobileAccountButton extends StatelessWidget {
  /// 创建移动端账号入口。
  const MobileAccountButton({
    super.key,
    required this.state,
    required this.onTap,
  });

  /// 当前账号状态和可选登录资料。
  final AccountState state;

  /// 点击后进入个人分支的账号中心。
  final VoidCallback onTap;

  /// 构建 40dp 点击区域，视觉内容保持 32dp 圆形头像。
  @override
  Widget build(BuildContext context) {
    final profile = state.profile;
    // 只有已登录资料存在时才展示远程头像，否则保持未登录图标。
    final loggedIn = profile?.isLoggedIn == true;
    // Dart 的可空提升不能跨三元表达式稳定传递，单独保存已登录资料用于头像和提示。
    final loggedInProfile = loggedIn ? profile : null;
    final avatarUrl = loggedInProfile?.avatarUrl;
    return AppTooltip(
      message: loggedIn ? loggedInProfile?.userName ?? '个人中心' : '登录 B站账号',
      child: Semantics(
        button: true,
        label: loggedIn ? '个人中心' : '登录 B站账号',
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            mouseCursor: SystemMouseCursors.click,
            child: SizedBox.square(
              dimension: 40,
              child: Center(child: _avatarContent(context, avatarUrl)),
            ),
          ),
        ),
      ),
    );
  }

  /// 根据登录资料构建默认账号图标或远程头像。
  Widget _avatarContent(BuildContext context, Uri? avatarUrl) {
    final colorScheme = Theme.of(context).colorScheme;
    if (avatarUrl == null) {
      return Icon(
        Icons.account_circle_outlined,
        color: colorScheme.onSurfaceVariant,
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatarUrl.toString(),
        cacheManager: CoverCacheManager.instance,
        width: 32,
        height: 32,
        fit: BoxFit.cover,
        // 顶栏头像很小，限制解码尺寸减少内存占用。
        memCacheWidth: (32 * MediaQuery.devicePixelRatioOf(context)).ceil(),
        memCacheHeight: (32 * MediaQuery.devicePixelRatioOf(context)).ceil(),
        placeholder: (context, url) => const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: (context, url, error) => Icon(
          Icons.account_circle_outlined,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
