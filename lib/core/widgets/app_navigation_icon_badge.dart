import 'package:flutter/material.dart';

/// 应用一级导航图标右上角的数量角标。
final class AppNavigationIconBadge extends StatelessWidget {
  /// 创建在数量大于零时显示角标的导航图标。
  const AppNavigationIconBadge({
    required this.icon,
    required this.count,
    this.color,
    this.size = 20,
    super.key,
  });

  /// 导航入口使用的 Material 图标。
  final IconData icon;

  /// 当前需要提示的数量。
  final int count;

  /// 图标颜色；为空时继承当前 IconTheme。
  final Color? color;

  /// 图标尺寸。
  final double size;

  /// 构建图标及其右上角数量标签。
  @override
  Widget build(BuildContext context) {
    // 角标最多显示 99+，避免极端数量把手机底栏或桌面侧栏撑宽。
    final label = count > 99 ? '99+' : count.toString();
    return SizedBox.square(
      dimension: size + 12,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          Icon(icon, size: size, color: color),
          if (count > 0)
            Positioned(
              top: -3,
              right: -4,
              child: _NavigationCountBadge(label: label),
            ),
        ],
      ),
    );
  }
}

/// 导航数量角标，按一位、两位和 99+ 自适应宽度。
final class _NavigationCountBadge extends StatelessWidget {
  /// 创建紧凑但不裁剪文字的导航角标。
  const _NavigationCountBadge({required this.label});

  /// 已经完成上限处理的显示文案。
  final String label;

  /// 构建自适应红色胶囊角标。
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.visible,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onErrorContainer,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
