import 'package:flutter/material.dart';

import '../../../../core/widgets/app_selection_controls.dart';

/// 设置页统一的轻量单选组。
final class AdaptiveSettingsChoiceWrap<T> extends StatelessWidget {
  /// 创建一组设置项选择控件。
  const AdaptiveSettingsChoiceWrap({
    required this.compact,
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
    this.enabledBuilder,
    this.disabledTooltip,
    this.infoTooltipBuilder,
    super.key,
  });

  /// 是否处于手机紧凑布局，决定信息提示是否可点击展开。
  final bool compact;

  /// 全部可选业务值。
  final Iterable<T> values;

  /// 当前已选中的业务值。
  final T selected;

  /// 把业务值转换成界面短标签。
  final String Function(T value) labelBuilder;

  /// 用户选择某个值后的业务回调。
  final ValueChanged<T> onSelected;

  /// 可选值是否可用的业务判断。
  final bool Function(T value)? enabledBuilder;

  /// 禁用项悬停时展示的原因。
  final String? disabledTooltip;

  /// 每个选项右侧信息图标的说明。
  final String? Function(T value)? infoTooltipBuilder;

  /// 构建统一的单选圆点控件。
  @override
  Widget build(BuildContext context) {
    // 设置页单选项在手机和桌面统一使用轻量圆点样式，避免同一语义出现两套外观。
    return AppRadioChoiceWrap<T>(
      values: values,
      selected: selected,
      enabledBuilder: enabledBuilder,
      disabledTooltip: disabledTooltip,
      infoTooltipBuilder: infoTooltipBuilder,
      infoTooltipTapToShow: compact,
      labelBuilder: labelBuilder,
      onSelected: onSelected,
    );
  }
}
