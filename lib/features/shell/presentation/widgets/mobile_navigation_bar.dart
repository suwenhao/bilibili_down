part of '../app_shell.dart';

/// 手机底部导航，按设计图只用图标与文字颜色表达当前页面。
final class MobileBottomNavigationBar extends StatelessWidget {
  /// 创建无默认胶囊和悬停底色的手机底栏。
  const MobileBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.queuedTaskCount,
    required this.parserShowsTop,
    required this.taskShowsTop,
    required this.userCenterShowsTop,
    required this.onOpenParser,
    required this.onOpenTasks,
    required this.onOpenAccount,
    required this.onDestinationSelected,
  });

  /// 当前一级页面索引。
  final int selectedIndex;

  /// 待下载任务数量，用于任务入口角标。
  final int queuedTaskCount;

  /// 解析结果滚动较深时，解析入口临时变为回顶部入口。
  final bool parserShowsTop;

  /// 当前任务页签滚动较深时，任务入口临时变为回到顶部入口。
  final bool taskShowsTop;

  /// 个人中心滚动较深时，个人入口临时变为回到顶部入口。
  final bool userCenterShowsTop;

  /// 点击解析入口后切换页面或请求结果列表回到顶部。
  final VoidCallback onOpenParser;

  /// 点击任务入口后切换页面或请求当前任务页签回到顶部。
  final VoidCallback onOpenTasks;

  /// 点击个人入口后进入个人分支或请求当前个人页回顶部。
  final VoidCallback onOpenAccount;

  /// 点击某个入口后切换一级页面。
  final ValueChanged<int> onDestinationSelected;

  /// 构建固定高度的四等分底栏。
  @override
  Widget build(BuildContext context) {
    // 底栏颜色沿用主题表面色，与页面内容之间保留一条细分隔线。
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: <Widget>[
              MobileNavigationItem(
                label: parserShowsTop ? '回顶部' : '解析',
                icon: parserShowsTop
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.link_rounded,
                selectedIcon: parserShowsTop
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.link_rounded,
                selected: selectedIndex == 0,
                onTap: onOpenParser,
              ),
              MobileNavigationItem(
                label: taskShowsTop ? '回顶部' : '任务',
                icon: taskShowsTop
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.download_outlined,
                selectedIcon: taskShowsTop
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.download_rounded,
                selected: selectedIndex == 1,
                badgeCount: taskShowsTop ? 0 : queuedTaskCount,
                onTap: onOpenTasks,
              ),
              MobileNavigationItem(
                label: userCenterShowsTop ? '回顶部' : '个人',
                icon: userCenterShowsTop
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.account_circle_outlined,
                selectedIcon: userCenterShowsTop
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.account_circle_rounded,
                selected: selectedIndex == 3,
                onTap: onOpenAccount,
              ),
              MobileNavigationItem(
                label: '设置',
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings_rounded,
                selected: selectedIndex == 2,
                onTap: () => onDestinationSelected(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 手机底栏中的单个入口，不绘制任何胶囊状态背景。
final class MobileNavigationItem extends StatelessWidget {
  /// 创建一个只靠颜色变化表达选中的导航入口。
  const MobileNavigationItem({
    super.key,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  /// 入口文案和无障碍名称。
  final String label;

  /// 未选中图标。
  final IconData icon;

  /// 选中图标。
  final IconData selectedIcon;

  /// 是否是当前页面。
  final bool selected;

  /// 任务入口角标数量。
  final int badgeCount;

  /// 点击后切换页面。
  final VoidCallback onTap;

  /// 构建无水波纹、无悬停底色的点击区域。
  @override
  Widget build(BuildContext context) {
    // 选中态使用主题主色，普通态使用弱前景色。
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    // “回顶部”入口使用主题色圆形上箭头，和普通个人头像入口区分清楚。
    final useTopIconStyle =
        selected && selectedIcon == Icons.keyboard_arrow_up_rounded;
    // 读屏需要知道当前入口和待下载任务数量，不能只依赖视觉角标。
    final semanticsLabel = badgeCount > 0 ? '$label，$badgeCount 个待下载任务' : label;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: semanticsLabel,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (useTopIconStyle)
                  SizedBox.square(
                    // 回顶部也占用和普通导航图标一致的槽位，避免替换后图标和文字跳位。
                    dimension: 36,
                    child: Center(
                      child: Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          selectedIcon,
                          size: 22,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  )
                else
                  AppNavigationIconBadge(
                    icon: selected ? selectedIcon : icon,
                    count: badgeCount,
                    color: foregroundColor,
                    size: 24,
                  ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foregroundColor,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
