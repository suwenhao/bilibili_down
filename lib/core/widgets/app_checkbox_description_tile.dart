import 'package:flutter/material.dart';

/// 弹窗或设置中使用的低层级复选说明项。
final class AppCheckboxDescriptionTile extends StatelessWidget {
  /// 创建带标题和说明文字的复选项。
  const AppCheckboxDescriptionTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
  });

  /// 当前复选项是否选中。
  final bool value;

  /// 用户切换复选项后的回调；为空时显示禁用状态。
  final ValueChanged<bool?>? onChanged;

  /// 复选项主标题，用于说明被勾选后的具体动作。
  final String title;

  /// 复选项补充说明，用于解释风险、恢复方式或平台限制。
  final String subtitle;

  /// 构建低于弹窗标题和主体说明的复选层级。
  @override
  Widget build(BuildContext context) {
    // 复选项通常是附加风险选项，字号和行高必须低于弹窗标题与主体说明。
    final textTheme = Theme.of(context).textTheme;
    // 说明文字使用次级颜色，避免和主要确认文案抢层级。
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        title,
        style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: textTheme.bodySmall?.copyWith(color: subtitleColor),
      ),
    );
  }
}
