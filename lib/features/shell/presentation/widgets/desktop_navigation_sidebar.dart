part of '../app_shell.dart';

/// 固定 48dp、只包含一层 Material 状态反馈的桌面侧栏。
final class DesktopNavigationSidebar extends StatelessWidget {
  /// 创建与当前一级路由同步的桌面侧栏。
  const DesktopNavigationSidebar({
    super.key,
    required this.selectedIndex,
    required this.queuedTaskCount,
    required this.accountState,
    required this.onOpenAccount,
    required this.onToggleTheme,
    required this.onDestinationSelected,
  });

  /// 当前选中的一级导航索引。
  final int selectedIndex;

  /// 当前待下载任务数量，用于任务入口角标。
  final int queuedTaskCount;

  /// 当前登录阶段和可选账号资料，用于顶部头像。
  final AccountState accountState;

  /// 打开账号中心回调。
  final VoidCallback onOpenAccount;

  /// 快捷切换亮暗主题回调。
  final VoidCallback onToggleTheme;

  /// 用户点击一级导航入口后的回调。
  final ValueChanged<int> onDestinationSelected;

  /// 构建固定宽度的导航入口和底部全局操作。
  @override
  Widget build(BuildContext context) {
    // 48dp 是参考图在 150% Windows 缩放下换算得到的布局原值。
    return SizedBox(
      width: 48,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 8),
            DesktopAccountAvatar(state: accountState, onTap: onOpenAccount),
            const SizedBox(height: 4),
            DesktopNavigationItem(
              label: '视频解析',
              icon: Icons.link_rounded,
              selectedIcon: Icons.link_rounded,
              selected: selectedIndex == 0,
              onTap: () {
                // 第一项进入视频解析页。
                onDestinationSelected(0);
              },
            ),
            DesktopNavigationItem(
              label: '任务列表',
              icon: Icons.download_outlined,
              selectedIcon: Icons.download_rounded,
              selected: selectedIndex == 1,
              badgeCount: queuedTaskCount,
              onTap: () {
                // 第二项进入下载任务页。
                onDestinationSelected(1);
              },
            ),
            DesktopNavigationItem(
              label: '账号中心',
              icon: Icons.account_circle_outlined,
              selectedIcon: Icons.account_circle_rounded,
              selected: selectedIndex == 3,
              onTap: () {
                // 第三项按登录状态打开登录弹窗或进入右侧用户中心。
                onOpenAccount();
              },
            ),
            const Spacer(),
            DesktopNavigationItem(
              label: '切换亮色 / 暗色',
              icon: Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              selectedIcon: Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              selected: false,
              onTap: () {
                // 倒数第二项切换当前主题。
                onToggleTheme();
              },
            ),
            DesktopNavigationItem(
              label: '设置中心',
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings_rounded,
              selected: selectedIndex == 2,
              onTap: () {
                // 最底部入口进入设置中心。
                onDestinationSelected(2);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
