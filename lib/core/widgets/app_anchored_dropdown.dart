import 'package:flutter/material.dart';

import 'app_popup_menu_items.dart';

/// 根据菜单展开状态构建锚定触发器。
typedef AppAnchoredDropdownChildBuilder =
    Widget Function(BuildContext context, bool open);

/// 应用内统一的锚定下拉菜单外壳。
final class AppAnchoredDropdownMenu<T> extends StatefulWidget {
  /// 创建统一弹层、展开状态和触发器的下拉菜单。
  const AppAnchoredDropdownMenu({
    required this.itemBuilder,
    required this.childBuilder,
    this.initialValue,
    this.onSelected,
    this.enabled = true,
    this.tooltip,
    this.constraints = const BoxConstraints(minWidth: 176, maxWidth: 176),
    this.maxMenuHeight,
    this.borderRadius,
    this.splashRadius,
    super.key,
  });

  /// 菜单项构造器，由业务侧决定具体候选内容。
  final PopupMenuItemBuilder<T> itemBuilder;

  /// 触发器构造器，会收到当前菜单是否展开。
  final AppAnchoredDropdownChildBuilder childBuilder;

  /// 菜单展开时需要自动滚动到的当前值。
  final T? initialValue;

  /// 用户选择候选项后的回调。
  final PopupMenuItemSelected<T>? onSelected;

  /// 当前菜单是否允许展开。
  final bool enabled;

  /// 悬停和无障碍读取使用的说明。
  final String? tooltip;

  /// 菜单宽度和高度约束。
  final BoxConstraints constraints;

  /// 菜单最大高度；为空时仅使用 constraints。
  final double? maxMenuHeight;

  /// 触发器水波反馈圆角。
  final BorderRadius? borderRadius;

  /// 触发器水波半径。
  final double? splashRadius;

  /// 创建展开状态。
  @override
  State<AppAnchoredDropdownMenu<T>> createState() =>
      _AppAnchoredDropdownMenuState<T>();
}

/// 管理锚定下拉菜单的展开状态。
final class _AppAnchoredDropdownMenuState<T>
    extends State<AppAnchoredDropdownMenu<T>> {
  /// 当前菜单是否已经展开，用于同步箭头方向。
  bool _open = false;

  /// 构建统一菜单外壳和业务触发器。
  @override
  Widget build(BuildContext context) {
    return AppPopupMenuButton<T>(
      enabled: widget.enabled,
      initialValue: widget.initialValue,
      tooltip: widget.tooltip,
      constraints: widget.constraints,
      maxMenuHeight: widget.maxMenuHeight,
      borderRadius: widget.borderRadius,
      splashRadius: widget.splashRadius,
      onOpened: () {
        // PopupMenuButton 不会自动把展开状态回传给自定义 child，需要本组件维护。
        if (mounted) setState(() => _open = true);
      },
      onCanceled: () {
        // 点击菜单外部关闭时恢复触发器箭头方向。
        if (mounted) setState(() => _open = false);
      },
      onSelected: (T value) {
        // 选择候选后先恢复触发器状态，再交给业务层保存。
        if (mounted) setState(() => _open = false);
        widget.onSelected?.call(value);
      },
      itemBuilder: widget.itemBuilder,
      child: widget.childBuilder(context, _open),
    );
  }
}

/// 下拉菜单中表示“无”的稳定哨兵值。
final class _AppDropdownClearSelection {
  /// 创建不可变哨兵值。
  const _AppDropdownClearSelection();
}

/// 通用的单选候选下拉菜单。
final class AppAnchoredSelectionMenu<T> extends StatelessWidget {
  /// 创建带可选“无”候选的锚定单选菜单。
  const AppAnchoredSelectionMenu({
    required this.options,
    required this.labelBuilder,
    required this.selectedBuilder,
    required this.onSelected,
    this.fieldBuilder,
    this.fieldLabel,
    this.fieldValue,
    this.fieldHeight = 30,
    this.fieldHorizontalPadding = 10,
    this.fieldLabelGap = 8,
    this.fieldBorderRadius = const BorderRadius.all(Radius.circular(7)),
    this.fieldIconSize = 17,
    this.fieldLabelStyle,
    this.fieldValueStyle,
    this.fieldValueTextAlign = TextAlign.left,
    this.fieldFillColor,
    this.height,
    this.onClear,
    this.cleared = false,
    this.clearLabel = '无',
    this.enabled = true,
    this.enabledTooltip,
    this.disabledTooltip,
    this.constraints = const BoxConstraints(minWidth: 176, maxWidth: 176),
    this.maxMenuHeight = 320,
    this.borderRadius,
    this.splashRadius,
    super.key,
  });

  /// 下拉候选集合。
  final List<T> options;

  /// 候选项显示文案转换器。
  final String Function(T option) labelBuilder;

  /// 判断候选项是否为当前选择。
  final bool Function(T option) selectedBuilder;

  /// 用户选择普通候选后的回调。
  final ValueChanged<T> onSelected;

  /// 根据展开状态构建触发字段。
  final Widget Function(BuildContext context, bool open)? fieldBuilder;

  /// 标准触发字段左侧可选标签。
  final String? fieldLabel;

  /// 标准触发字段当前值；未传 fieldBuilder 时必须提供。
  final String? fieldValue;

  /// 标准触发字段高度。
  final double fieldHeight;

  /// 标准触发字段左右内边距。
  final double fieldHorizontalPadding;

  /// 标准触发字段标签和值之间的间距。
  final double fieldLabelGap;

  /// 标准触发字段圆角。
  final BorderRadius fieldBorderRadius;

  /// 标准触发字段展开箭头尺寸。
  final double fieldIconSize;

  /// 标准触发字段标签文字样式。
  final TextStyle? fieldLabelStyle;

  /// 标准触发字段当前值文字样式。
  final TextStyle? fieldValueStyle;

  /// 标准触发字段当前值对齐方式。
  final TextAlign fieldValueTextAlign;

  /// 标准触发字段填充色。
  final Color? fieldFillColor;

  /// 菜单触发器外层固定高度；为空时由触发字段自身决定高度。
  final double? height;

  /// 用户选择“无”时的回调；为空时不展示“无”候选。
  final VoidCallback? onClear;

  /// “无”是否为当前选择。
  final bool cleared;

  /// “无”候选的显示文案。
  final String clearLabel;

  /// 当前菜单是否允许展开。
  final bool enabled;

  /// 可展开时的提示文案。
  final String? enabledTooltip;

  /// 不可展开时的提示文案。
  final String? disabledTooltip;

  /// 菜单宽度和高度约束。
  final BoxConstraints constraints;

  /// 菜单最大高度。
  final double? maxMenuHeight;

  /// 触发器水波反馈圆角。
  final BorderRadius? borderRadius;

  /// 触发器水波半径。
  final double? splashRadius;

  /// 构建统一候选菜单。
  @override
  Widget build(BuildContext context) {
    // 缺少候选清单或禁用状态不能展开，但触发字段仍要展示当前保存值。
    final canOpenMenu = enabled && options.isNotEmpty;
    // 提示需要说明不能展开的业务原因，避免空候选像是点击失效。
    final tooltip = canOpenMenu ? enabledTooltip : disabledTooltip;
    // 当前选择交给 PopupMenuButton 定位，长菜单展开后会直接滚动到该项。
    Object? initialValue;
    if (onClear != null && cleared) {
      // “无”使用稳定哨兵值，使清空状态也能作为菜单初始定位目标。
      initialValue = const _AppDropdownClearSelection();
    } else {
      // 普通候选按业务选择器查找；未选中任何项时保持默认顶部位置。
      for (final option in options) {
        if (selectedBuilder(option)) {
          initialValue = option as Object;
          break;
        }
      }
    }
    // 标准触发字段覆盖大多数音画质下拉，特殊行布局仍可传入 fieldBuilder。
    Widget buildDefaultField(BuildContext context, bool open) {
      final value = fieldValue;
      assert(
        value != null,
        'fieldValue is required when fieldBuilder is null.',
      );
      return AppAnchoredDropdownField(
        label: fieldLabel,
        value: value ?? '',
        open: open,
        enabled: canOpenMenu,
        height: fieldHeight,
        horizontalPadding: fieldHorizontalPadding,
        labelGap: fieldLabelGap,
        borderRadius: fieldBorderRadius,
        iconSize: fieldIconSize,
        labelStyle: fieldLabelStyle,
        valueStyle: fieldValueStyle,
        valueTextAlign: fieldValueTextAlign,
        fillColor: fieldFillColor,
      );
    }

    // 菜单本体只负责候选项和展开状态，外层高度由可选 height 统一收口。
    final menu = AppAnchoredDropdownMenu<Object>(
      enabled: canOpenMenu,
      initialValue: initialValue,
      tooltip: tooltip,
      constraints: constraints,
      maxMenuHeight: maxMenuHeight,
      borderRadius: borderRadius,
      splashRadius: splashRadius,
      onSelected: (Object choice) {
        // 哨兵项用于取消当前媒体流，普通项保持泛型候选回调。
        if (choice is _AppDropdownClearSelection) {
          onClear?.call();
          return;
        }
        onSelected(choice as T);
      },
      itemBuilder: (BuildContext context) {
        // 可选的“无”固定放在首项，其余候选保持业务给定顺序。
        return <PopupMenuEntry<Object>>[
          if (onClear != null)
            PopupMenuItem<Object>(
              value: const _AppDropdownClearSelection(),
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AppSelectableMenuItemRow(
                label: clearLabel,
                selected: cleared,
              ),
            ),
          ...options.map(
            (T option) => PopupMenuItem<Object>(
              value: option as Object,
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AppSelectableMenuItemRow(
                label: labelBuilder(option),
                selected: selectedBuilder(option),
              ),
            ),
          ),
        ];
      },
      childBuilder: fieldBuilder ?? buildDefaultField,
    );
    if (height == null) return menu;
    return SizedBox(height: height, child: menu);
  }
}

/// 下载任务卡片音质和画质使用的统一下拉触发字段。
final class AppAnchoredDropdownField extends StatelessWidget {
  /// 创建带边框、单行值和展开箭头的下拉字段。
  const AppAnchoredDropdownField({
    required this.value,
    required this.open,
    this.label,
    this.enabled = true,
    this.height = 30,
    this.horizontalPadding = 10,
    this.labelGap = 8,
    this.borderRadius = const BorderRadius.all(Radius.circular(7)),
    this.iconSize = 17,
    this.labelStyle,
    this.valueStyle,
    this.valueTextAlign = TextAlign.left,
    this.fillColor,
    super.key,
  });

  /// 左侧可选标签，例如音质或画质。
  final String? label;

  /// 当前选中的展示文案。
  final String value;

  /// 菜单是否展开，用于切换箭头方向。
  final bool open;

  /// 当前字段是否可展开。
  final bool enabled;

  /// 字段高度，默认沿用下载任务桌面卡片的音画质字段。
  final double height;

  /// 字段左右内边距。
  final double horizontalPadding;

  /// 标签和值之间的间距。
  final double labelGap;

  /// 字段圆角。
  final BorderRadius borderRadius;

  /// 展开箭头尺寸。
  final double iconSize;

  /// 标签文字样式。
  final TextStyle? labelStyle;

  /// 当前值文字样式。
  final TextStyle? valueStyle;

  /// 当前值对齐方式。
  final TextAlign valueTextAlign;

  /// 可选填充色；为空时不绘制填充背景。
  final Color? fillColor;

  /// 构建统一触发字段。
  @override
  Widget build(BuildContext context) {
    // 禁用态降低整个字段透明度，保留当前值供用户判断任务状态。
    final opacity = enabled ? 1.0 : 0.55;
    // 颜色来自当前主题，确保亮暗主题下边框和弱文字可读。
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveValueStyle =
        valueStyle ?? Theme.of(context).textTheme.bodySmall;
    final effectiveLabelStyle =
        labelStyle ??
        Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);
    return Opacity(
      opacity: opacity,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        decoration: BoxDecoration(
          color: fillColor ?? Colors.transparent,
          borderRadius: borderRadius,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: <Widget>[
            if (label != null) ...<Widget>[
              Text(label!, style: effectiveLabelStyle),
              SizedBox(width: labelGap),
            ],
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: valueTextAlign,
                style: effectiveValueStyle,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              open
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: iconSize,
            ),
          ],
        ),
      ),
    );
  }
}

/// 行内布局使用的下拉触发器。
final class AppAnchoredDropdownInlineRow extends StatelessWidget {
  /// 创建没有边框、只占一行文字高度的下拉触发器。
  const AppAnchoredDropdownInlineRow({
    required this.label,
    required this.value,
    required this.open,
    this.padding = const EdgeInsets.symmetric(vertical: 11),
    this.gap = 10,
    this.iconSize = 17,
    this.textStyle,
    super.key,
  });

  /// 左侧字段标签。
  final String label;

  /// 右侧当前值。
  final String value;

  /// 菜单是否展开，用于切换箭头方向。
  final bool open;

  /// 行内触发器上下内边距。
  final EdgeInsetsGeometry padding;

  /// 标签和值之间的间距。
  final double gap;

  /// 展开箭头尺寸。
  final double iconSize;

  /// 标签和值共用的文字样式。
  final TextStyle? textStyle;

  /// 构建行内下拉触发器。
  @override
  Widget build(BuildContext context) {
    // 行内触发器用于手机详情行，不能绘制额外边框或背景。
    final effectiveTextStyle =
        textStyle ?? Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Text(label, style: effectiveTextStyle),
          SizedBox(width: gap),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: effectiveTextStyle,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            open
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: iconSize,
          ),
        ],
      ),
    );
  }
}
