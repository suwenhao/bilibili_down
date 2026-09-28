part of '../app_shell.dart';

/// 桌面侧栏中的单个语义导航入口。
final class DesktopNavigationItem extends StatelessWidget {
  /// 创建由单层 Material 和 InkWell 组成的导航入口。
  const DesktopNavigationItem({
    super.key,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  /// 悬停提示和无障碍名称。
  final String label;

  /// 未选中图标。
  final IconData icon;

  /// 选中图标。
  final IconData selectedIcon;

  /// 是否为当前一级页面。
  final bool selected;

  /// 大于零时展示在图标右上角的数量。
  final int badgeCount;

  /// 点击后切换一级路由的回调。
  final VoidCallback onTap;

  /// 构建唯一的圆角状态层及框架原生 Hover、焦点和按压反馈。
  @override
  Widget build(BuildContext context) {
    // 读取项目主题颜色，参考图只提供形状和尺寸而不复制颜色。
    final colorScheme = Theme.of(context).colorScheme;
    // 选中入口使用主色浅背景，未选中入口保持透明。
    final backgroundColor = selected
        ? colorScheme.primary.withValues(alpha: 0.14)
        : Colors.transparent;
    // 选中图标使用主色，普通图标使用次级前景色。
    final foregroundColor = selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    // 有待下载任务时把数量加入无障碍名称，读屏无需依赖视觉角标。
    final semanticsLabel = badgeCount > 0 ? '$label，$badgeCount 个待下载任务' : label;
    // 公共悬停提示只显示视觉说明，完整语义由内层 Semantics 提供。
    return AppTooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: semanticsLabel,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Material(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            // 数量角标需要溢出到图标右上角，不能被导航项状态层裁剪。
            clipBehavior: Clip.none,
            child: InkWell(
              onTap: onTap,
              mouseCursor: SystemMouseCursors.click,
              borderRadius: BorderRadius.circular(8),
              hoverColor: selected
                  ? colorScheme.primary.withValues(alpha: 0.08)
                  : colorScheme.onSurface.withValues(alpha: 0.08),
              focusColor: colorScheme.primary.withValues(alpha: 0.10),
              splashColor: colorScheme.primary.withValues(alpha: 0.12),
              child: SizedBox.square(
                dimension: 36,
                child: Center(
                  child: AppNavigationIconBadge(
                    icon: selected ? selectedIcon : icon,
                    count: badgeCount,
                    color: foregroundColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
