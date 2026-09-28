import 'package:flutter/material.dart';

import 'app_icon_buttons.dart';

/// 应用内统一样式的弹出菜单按钮。
final class AppPopupMenuButton<T> extends StatelessWidget {
  /// 创建统一表面、边框和间距的弹出菜单。
  const AppPopupMenuButton({
    super.key,
    required this.itemBuilder,
    this.initialValue,
    this.onSelected,
    this.enabled = true,
    this.tooltip,
    this.onOpened,
    this.onCanceled,
    this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius,
    this.splashRadius,
    this.position = PopupMenuPosition.under,
    this.offset = const Offset(0, 4),
    this.menuPadding = const EdgeInsets.symmetric(vertical: 4),
    this.constraints = const BoxConstraints(minWidth: 176, maxWidth: 176),
    this.maxMenuHeight,
  });

  /// 菜单项构造器；由业务侧决定具体条目和可见性。
  final PopupMenuItemBuilder<T> itemBuilder;

  /// 菜单展开时需要定位并高亮的当前值。
  final T? initialValue;

  /// 用户选择菜单项后的业务回调。
  final PopupMenuItemSelected<T>? onSelected;

  /// 当前菜单是否允许展开。
  final bool enabled;

  /// 菜单触发器的提示文案。
  final String? tooltip;

  /// 菜单展开后的生命周期回调。
  final VoidCallback? onOpened;

  /// 用户点击菜单外部取消时的生命周期回调。
  final VoidCallback? onCanceled;

  /// 菜单触发器；为空时使用 Flutter 默认图标按钮。
  final Widget? child;

  /// 触发器外层点击区域留白。
  final EdgeInsetsGeometry padding;

  /// 触发器反馈圆角。
  final BorderRadius? borderRadius;

  /// 触发器水波半径。
  final double? splashRadius;

  /// 菜单相对触发器的位置。
  final PopupMenuPosition position;

  /// 菜单相对触发器的偏移。
  final Offset offset;

  /// 菜单内部上下留白。
  final EdgeInsetsGeometry menuPadding;

  /// 菜单宽度约束。
  final BoxConstraints constraints;

  /// 菜单最大高度；为空时使用 constraints 自身限制。
  final double? maxMenuHeight;

  /// 构建统一主题弹出菜单。
  @override
  Widget build(BuildContext context) {
    // 弹出菜单边框仍跟随主题明暗，背景本身固定为中性白或暗色，避免被主题色染色。
    final colorScheme = Theme.of(context).colorScheme;
    // 主题色只影响边框和文字，不影响弹层底色。
    final menuColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1B1B1F)
        : Colors.white;
    // 部分菜单需要单独限制高度，优先尊重外部传入的 maxMenuHeight。
    final effectiveConstraints = maxMenuHeight == null
        ? constraints
        : constraints.copyWith(maxHeight: maxMenuHeight);
    // 光标必须放进 PopupMenuButton 实际创建的 InkWell 内部；放在组件外层会被触发层覆盖。
    final trigger = child == null
        ? null
        : MouseRegion(
            cursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.forbidden,
            child: child!,
          );
    // PopupMenuButton 的原生 tooltip 会插入临时语义节点，统一关闭后由外层 Semantics 提供稳定说明。
    final menuButton = PopupMenuButton<T>(
      enabled: enabled,
      // Flutter 会根据初始值定位对应菜单项，长列表展开时自动滚动到当前选择。
      initialValue: initialValue,
      // 禁用 Material 默认 “Show menu”，避免英文浮层和 Windows AXTree 临时节点。
      tooltip: '',
      padding: padding,
      borderRadius: borderRadius,
      splashRadius: splashRadius,
      position: position,
      offset: offset,
      menuPadding: menuPadding,
      constraints: effectiveConstraints,
      color: menuColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      onOpened: onOpened,
      onCanceled: onCanceled,
      onSelected: onSelected,
      itemBuilder: itemBuilder,
      child: trigger,
    );
    final clippedButton = borderRadius == null
        ? menuButton
        : ClipRRect(borderRadius: borderRadius!, child: menuButton);
    if (tooltip == null || tooltip!.trim().isEmpty) return clippedButton;
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: clippedButton,
    );
  }
}

/// 圆形“三点更多”弹出菜单按钮。
final class AppCircleMoreMenuButton<T> extends StatelessWidget {
  /// 创建和任务卡片一致的圆形更多菜单按钮。
  const AppCircleMoreMenuButton({
    super.key,
    required this.itemBuilder,
    this.onSelected,
    this.enabled = true,
    this.tooltip = '更多操作',
    this.constraints = const BoxConstraints(minWidth: 176, maxWidth: 176),
    this.maxMenuHeight,
    this.dimension = 32,
    this.iconSize = 18,
    this.variant = AppCircleIconButtonVariant.outlined,
  }) : assert(tooltip != '', '圆形更多按钮必须提供非空 tooltip。');

  /// 菜单项构造器。
  final PopupMenuItemBuilder<T> itemBuilder;

  /// 用户选择菜单项后的业务回调。
  final PopupMenuItemSelected<T>? onSelected;

  /// 当前菜单是否允许展开。
  final bool enabled;

  /// 菜单触发器的提示文案；圆形图标按钮没有文字，必须提供说明。
  final String tooltip;

  /// 菜单宽度约束。
  final BoxConstraints constraints;

  /// 菜单最大高度。
  final double? maxMenuHeight;

  /// 圆形按钮的宽高。
  final double dimension;

  /// 三点图标尺寸。
  final double iconSize;

  /// 圆形触发器的视觉变体；由调用方按业务语义选择主色、危险色或普通描边。
  final AppCircleIconButtonVariant variant;

  /// 构建圆形触发按钮和统一菜单表面。
  @override
  Widget build(BuildContext context) {
    // 圆形更多按钮必须复用公共圆形按钮，确保 hover 和水波只裁剪在圆内。
    return AppPopupMenuButton<T>(
      enabled: enabled,
      tooltip: tooltip,
      onSelected: onSelected,
      itemBuilder: itemBuilder,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(dimension / 2),
      splashRadius: dimension / 2,
      constraints: constraints,
      maxMenuHeight: maxMenuHeight,
      child: IgnorePointer(
        // 外层 PopupMenuButton 负责点击和展开，内部公共按钮只提供统一视觉与裁剪。
        child: AppCircleIconButton(
          variant: variant,
          tooltip: tooltip,
          onPressed: enabled ? () {} : null,
          dimension: dimension,
          iconSize: iconSize,
          icon: const Icon(Icons.more_horiz_rounded),
        ),
      ),
    );
  }
}

/// 全局弹出菜单里的固定宽度操作行。
final class AppPopupMenuItemRow extends StatelessWidget {
  /// 创建一个带图标和单行文字的菜单项内容。
  const AppPopupMenuItemRow({
    required this.icon,
    required this.label,
    super.key,
  });

  /// 菜单动作图标。
  final IconData icon;

  /// 菜单动作文案。
  final String label;

  /// 构建统一的紧凑菜单行。
  @override
  Widget build(BuildContext context) {
    // 菜单项统一宽度、行高和字号，避免不同页面里的更多菜单视觉漂移。
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(5)),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// 全局弹出菜单里的复选项行。
final class AppCheckboxMenuItemRow extends StatelessWidget {
  /// 创建使用主题色表达选中状态的复选菜单项。
  const AppCheckboxMenuItemRow({
    required this.label,
    required this.selected,
    super.key,
  });

  /// 复选项文案。
  final String label;

  /// 当前复选项是否已经选中。
  final bool selected;

  /// 构建紧凑的复选菜单行。
  @override
  Widget build(BuildContext context) {
    // 只有选中复选框使用主题色，菜单背景和普通文字继续保持中性色。
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(5)),
      child: Row(
        children: <Widget>[
          Icon(
            selected
                ? Icons.check_box_rounded
                : Icons.check_box_outline_blank_rounded,
            size: 18,
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// 全局弹出菜单里的可选项行。
final class AppSelectableMenuItemRow extends StatelessWidget {
  /// 创建一个可显示选中态的菜单项内容。
  const AppSelectableMenuItemRow({
    required this.label,
    required this.selected,
    super.key,
  });

  /// 候选项文案。
  final String label;

  /// 当前候选项是否已选中。
  final bool selected;

  /// 构建紧凑的选中态菜单行。
  @override
  Widget build(BuildContext context) {
    // 选中态应该跟随主题色，和弹层自身的中性背景形成清晰区分。
    final colorScheme = Theme.of(context).colorScheme;
    final selectedForeground = selected ? Colors.white : colorScheme.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? colorScheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            selected ? Icons.check_rounded : Icons.circle_outlined,
            size: 16,
            color: selectedForeground,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: selectedForeground),
            ),
          ),
        ],
      ),
    );
  }
}
