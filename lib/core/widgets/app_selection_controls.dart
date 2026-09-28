import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_action_button.dart';
import 'app_tooltip.dart';

/// 应用内统一的单选或多选标签按钮。
final class AppSelectionChip extends StatelessWidget {
  /// 创建一个由业务层决定单选或多选语义的公共标签按钮。
  const AppSelectionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.enabled = true,
    this.visualDensity,
  });

  /// 按钮显示的单行标签。
  final String label;

  /// 当前是否处于选中状态。
  final bool selected;

  /// 用户切换选择状态后的业务回调。
  final ValueChanged<bool> onSelected;

  /// 未选中时显示的业务语义图标；选中后由勾选图标替换。
  final IconData? icon;

  /// 当前选项是否允许交互。
  final bool enabled;

  /// 窄屏或紧凑区域使用的视觉密度。
  final VisualDensity? visualDensity;

  /// 构建统一颜色、勾选状态和桌面鼠标指针的标签按钮。
  @override
  Widget build(BuildContext context) {
    // 标签按钮不区分单选或多选视觉，只由 selected 决定是否使用主题填充态。
    final colorScheme = Theme.of(context).colorScheme;
    // 当前控件的文字样式由公共组件显式控制，避免 FilterChip 内部继承在 Row 标签下失效。
    final labelTextStyle = AppTextStyles.selectableControlLabel.copyWith(
      color: _selectionForegroundColor(colorScheme, selected, enabled),
    );
    // 选中描边必须与填充使用同一主题色，未选中才回落到页面分隔色。
    final chipBorderSide = BorderSide(
      color: selected ? colorScheme.primary : Theme.of(context).dividerColor,
    );
    // 选中态图标跟随文字使用白色，确保所有主题色上都有统一前景。
    const selectedIconColor = Colors.white;
    // 未选中的业务图标跟随标签文字颜色，保证亮暗色主题视觉一致。
    final idleIconColor = labelTextStyle.color;
    // 有业务图标时由当前组件负责绘制前置图标，否则沿用 FilterChip 原生勾选。
    final hasLeadingIcon = icon != null;
    return FilterChip(
      // 颜色由公共组件按状态直接解析，避免 Material 默认状态层让选中底色偏离主题色。
      color: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        // 禁用状态继续交给 Chip 默认规则，保留不可用的弱化反馈。
        if (states.contains(WidgetState.disabled)) return null;
        // 选中态必须使用当前实际主题色，不能被种子色阶或状态层改淡。
        if (states.contains(WidgetState.selected)) return colorScheme.primary;
        return null;
      }),
      selectedColor: colorScheme.primary,
      side: chipBorderSide,
      checkmarkColor: Colors.white,
      labelStyle: labelTextStyle,
      mouseCursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      visualDensity: visualDensity,
      selected: selected,
      showCheckmark: !hasLeadingIcon,
      onSelected: enabled ? onSelected : null,
      label: hasLeadingIcon
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  selected ? Icons.check_rounded : icon,
                  size: 17,
                  color: selected ? selectedIconColor : idleIconColor,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelTextStyle,
                ),
              ],
            )
          : Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelTextStyle,
            ),
    );
  }
}

/// 设置类页面常用的紧凑描边操作按钮。
final class AppCompactOutlinedActionButton extends StatelessWidget {
  /// 创建带图标的紧凑操作按钮。
  const AppCompactOutlinedActionButton({
    super.key,
    required this.compact,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  /// 是否使用移动端触控尺寸；桌面端会进一步压缩高度与留白。
  final bool compact;

  /// 点击回调；为空时交给 Material 显示禁用状态。
  final VoidCallback? onPressed;

  /// 按钮前置语义图标。
  final IconData icon;

  /// 按钮单行文字。
  final String label;

  /// 构建统一高度、字号、图标和水平留白的描边按钮。
  @override
  Widget build(BuildContext context) {
    return AppActionButton(
      // 设置页操作按钮统一使用 medium，避免页面根据桌面或移动端各自计算高度。
      minWidth: 32,
      textStyle: AppTextStyles.selectableControlLabel,
      variant: AppActionButtonVariant.outlined,
      icon: icon,
      label: label,
      onPressed: onPressed,
    );
  }
}

/// 移动端网格中可铺满单元格的选择按钮。
final class AppMobileSelectionCell extends StatelessWidget {
  /// 创建带可选前置图标的移动端选择单元格。
  const AppMobileSelectionCell({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.enabled = true,
    this.expand = true,
  });

  /// 选项短标签。
  final String label;

  /// 是否为当前选中项。
  final bool selected;

  /// 点击后切换选项的回调。
  final VoidCallback onTap;

  /// 复选类选项使用的前置图标；普通单选项可为空。
  final Widget? leading;

  /// 当前选项是否允许交互。
  final bool enabled;

  /// 是否铺满父单元格；短标签横排时可关闭。
  final bool expand;

  /// 构建移动端 36dp 选择单元格。
  @override
  Widget build(BuildContext context) {
    // 读取主题颜色，选中、禁用和普通状态保持足够对比度。
    final colorScheme = Theme.of(context).colorScheme;
    // 选中项使用主色表面，未选中项沿用页面表面。
    final background = selected ? colorScheme.primary : colorScheme.surface;
    // 禁用项降低前景对比度，其他状态按选中表面选择前景色。
    final foreground = _selectionForegroundColor(
      colorScheme,
      selected,
      enabled,
    );
    // 外框始终存在，选中时使用主色强化状态。
    final borderColor = selected
        ? colorScheme.primary
        : Theme.of(context).dividerColor;
    return SizedBox(
      height: 36,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.forbidden,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (leading != null) ...<Widget>[
                  IconTheme(
                    data: IconThemeData(color: foreground),
                    child: leading!,
                  ),
                  const SizedBox(width: 5),
                ],
                if (expand)
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: foreground),
                    ),
                  )
                else
                  Text(
                    label,
                    maxLines: 1,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: foreground),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 根据选择和禁用状态返回选择控件前景色。
Color _selectionForegroundColor(
  ColorScheme colorScheme,
  bool selected,
  bool enabled,
) {
  // 禁用态优先降低对比度，避免误认为仍可点击。
  if (!enabled) return colorScheme.onSurface.withValues(alpha: 0.38);
  // 选中主色背景上统一使用白色前景。
  if (selected) return Colors.white;
  // 普通未选中状态沿用当前主题表面前景。
  return colorScheme.onSurface;
}

/// 可复用的单选圆点交互，避免被 Material 版本 Radio API 绑定。
final class AppRadioChoice<T> extends StatelessWidget {
  /// 创建单个单选项。
  const AppRadioChoice({
    super.key,
    required this.value,
    required this.groupValue,
    required this.label,
    required this.onSelected,
    this.enabled = true,
    this.disabledTooltip,
    this.infoTooltip,
    this.infoTooltipTapToShow = false,
  });

  /// 当前选项值。
  final T value;

  /// 当前组选择值。
  final T groupValue;

  /// 选项显示文案。
  final String label;

  /// 用户点击后的选择回调。
  final ValueChanged<T> onSelected;

  /// 当前选项是否允许点击。
  final bool enabled;

  /// 禁用项悬停时展示的业务原因。
  final String? disabledTooltip;

  /// 选项右侧信息图标展示的说明。
  final String? infoTooltip;

  /// 信息图标是否支持点击显示气泡，手机端没有悬停能力时启用。
  final bool infoTooltipTapToShow;

  /// 构建圆点和文字。
  @override
  Widget build(BuildContext context) {
    // 比较值确定当前项是否选中。
    final selected = value == groupValue;
    // 使用主题主色绘制选中状态。
    final colorScheme = Theme.of(context).colorScheme;
    // 禁用态降低文字和圆点对比度，避免被误认为仍可操作。
    final foregroundColor = enabled
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.38);
    // 信息提示图标只在提供说明时展示。
    final tooltip = infoTooltip?.trim();
    final infoIcon = tooltip != null && tooltip.isNotEmpty
        ? AppTooltip(
            message: tooltip,
            tapToShow: infoTooltipTapToShow,
            showArrow: infoTooltipTapToShow,
            child: MouseRegion(
              cursor: infoTooltipTapToShow
                  ? SystemMouseCursors.click
                  : MouseCursor.defer,
              child: SizedBox.square(
                dimension: infoTooltipTapToShow ? 28 : 16,
                child: Center(
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: enabled
                        ? colorScheme.outline
                        : colorScheme.outline.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          )
        : null;
    // 手机端信息图标会移出选择主体，避免点说明时误改编码；桌面端保持原有悬停结构。
    final choiceContent = InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled ? () => onSelected(value) : null,
      mouseCursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? (enabled
                          ? colorScheme.primary
                          : colorScheme.outline.withValues(alpha: 0.45))
                    : Colors.transparent,
                border: Border.all(
                  color: selected && enabled
                      ? colorScheme.primary
                      : (enabled
                            ? colorScheme.outline
                            : colorScheme.outline.withValues(alpha: 0.45)),
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.circle, size: 7, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 9),
            Text(label, style: TextStyle(color: foregroundColor)),
            if (!infoTooltipTapToShow && infoIcon != null) ...<Widget>[
              const SizedBox(width: 4),
              infoIcon,
            ],
          ],
        ),
      ),
    );
    final content = infoTooltipTapToShow && infoIcon != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              choiceContent,
              const SizedBox(width: 4),
              infoIcon,
            ],
          )
        : choiceContent;
    // 禁用原因包在整体外层，保证桌面悬停时仍能说明为什么不可选。
    if (!enabled && disabledTooltip != null) {
      return AppTooltip(
        message: disabledTooltip!,
        mouseCursor: SystemMouseCursors.forbidden,
        child: content,
      );
    }
    return content;
  }
}

/// 手机设置行使用的轻量单选组选项。
final class AppRadioChoiceWrap<T> extends StatelessWidget {
  /// 创建与设计稿一致的横向单选组。
  const AppRadioChoiceWrap({
    super.key,
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
    this.enabledBuilder,
    this.disabledTooltip,
    this.infoTooltipBuilder,
    this.infoTooltipTapToShow = false,
  });

  /// 全部可选值。
  final Iterable<T> values;

  /// 当前选中值。
  final T selected;

  /// 值到短标签的转换器。
  final String Function(T value) labelBuilder;

  /// 用户选择回调。
  final ValueChanged<T> onSelected;

  /// 可选值是否允许点击。
  final bool Function(T value)? enabledBuilder;

  /// 禁用项悬停时展示的业务原因。
  final String? disabledTooltip;

  /// 单个选项右侧信息图标的提示文案。
  final String? Function(T value)? infoTooltipBuilder;

  /// 信息提示是否允许点击展开，移动端设置页使用。
  final bool infoTooltipTapToShow;

  /// 构建允许窄屏换行的单选圆点和文字。
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 2,
      children: values
          .map(
            (T value) => AppRadioChoice<T>(
              value: value,
              groupValue: selected,
              label: labelBuilder(value),
              enabled: enabledBuilder?.call(value) ?? true,
              disabledTooltip: disabledTooltip,
              infoTooltip: infoTooltipBuilder?.call(value),
              infoTooltipTapToShow: infoTooltipTapToShow,
              onSelected: onSelected,
            ),
          )
          .toList(growable: false),
    );
  }
}

/// 使用 ChoiceChip 或移动端单元格组成可自动换行的单选组。
final class AppChoiceWrap<T> extends StatelessWidget {
  /// 创建响应式单选标签组。
  const AppChoiceWrap({
    super.key,
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
    this.enabledBuilder,
    this.disabledTooltip,
    this.compact = false,
    this.compactColumns,
  });

  /// 全部可选值。
  final Iterable<T> values;

  /// 当前选中值。
  final T selected;

  /// 值到显示文案的转换器。
  final String Function(T value) labelBuilder;

  /// 用户选择回调。
  final ValueChanged<T> onSelected;

  /// 可选值的启用规则；未提供时全部开放。
  final bool Function(T value)? enabledBuilder;

  /// 选项禁用时显示的原因；启用后不创建提示层。
  final String? disabledTooltip;

  /// 是否使用手机设计稿的紧凑选择单元格。
  final bool compact;

  /// 手机端等宽网格列数；为空时保持流式宽度。
  final int? compactColumns;

  /// 构建允许跨行排列的选择标签。
  @override
  Widget build(BuildContext context) {
    // 每个 ChoiceChip 都保持相同的单选和权限语义。
    Widget buildChip(T value) {
      // 登录权限等业务规则决定当前标签是否接受点击。
      final enabled = enabledBuilder?.call(value) ?? true;
      // 标签本体负责选择状态和禁用光标。
      final chip = AppSelectionChip(
        visualDensity: compactColumns == null ? null : VisualDensity.compact,
        label: labelBuilder(value),
        selected: value == selected,
        enabled: enabled,
        onSelected: (bool isSelected) {
          // 单选组取消当前项时保持原选择，仅处理新的选中事件。
          if (isSelected) onSelected(value);
        },
      );
      // 只有禁用且提供原因时才显示提示，恢复可用后不残留“请登录”。
      if (!enabled && disabledTooltip != null) {
        return AppTooltip(
          message: disabledTooltip!,
          mouseCursor: SystemMouseCursors.forbidden,
          child: chip,
        );
      }
      return chip;
    }

    // 手机质量选项使用铺满网格或紧凑横排的专用单元格。
    Widget buildMobileCell(T value) {
      // 登录状态决定高音质和高画质是否可以点击。
      final enabled = enabledBuilder?.call(value) ?? true;
      // 画质网格需要铺满列，音质横排则按文字紧凑排列。
      final expand = compactColumns != null;
      // 单元格只替换手机外观，选择回调和业务状态保持一致。
      final cell = AppMobileSelectionCell(
        label: labelBuilder(value),
        selected: value == selected,
        enabled: enabled,
        expand: expand,
        onTap: () => onSelected(value),
      );
      // 未登录禁用项继续保留“请登录”提示。
      if (!enabled && disabledTooltip != null) {
        return AppTooltip(
          message: disabledTooltip!,
          mouseCursor: SystemMouseCursors.forbidden,
          child: cell,
        );
      }
      return cell;
    }

    // PC 继续使用流式宽度，确保桌面布局不被移动端规格影响。
    if (!compact) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: values.map(buildChip).toList(growable: false),
      );
    }
    // 手机音质按内容宽度连续排列，不在五等分列中留下大块空白。
    if (compactColumns == null) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: values.map(buildMobileCell).toList(growable: false),
      );
    }
    // 手机按设计稿把音质和画质排成等宽网格。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 6dp 列间距需要从总宽度扣除后再分配每个标签宽度。
        final columns = compactColumns!;
        final itemWidth = (constraints.maxWidth - (columns - 1) * 6) / columns;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: values
              .map(
                (T value) =>
                    SizedBox(width: itemWidth, child: buildMobileCell(value)),
              )
              .toList(growable: false),
        );
      },
    );
  }
}
