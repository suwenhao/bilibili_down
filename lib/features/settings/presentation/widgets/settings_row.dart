import 'package:flutter/material.dart';

/// 通知设置中带文字标签的紧凑声音开关。
final class SoundToggle extends StatelessWidget {
  /// 创建由独立状态和回调控制的声音选项。
  const SoundToggle({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// 当前声音选项的展示名称。
  final String label;

  /// 当前声音选项是否启用。
  final bool value;

  /// 用户切换开关后的状态回调。
  final ValueChanged<bool> onChanged;

  /// 构建与原系统提示音一致的开关尺寸和文字间距。
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 44,
          height: 28,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Switch(
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              value: value,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

/// 统一设置行，桌面横向排列，手机纵向排列。
final class SettingsRow extends StatelessWidget {
  /// 创建一条响应式设置行。
  const SettingsRow({
    required this.compact,
    required this.label,
    required this.child,
    this.showDivider = true,
    this.compactStacked = false,
    super.key,
  });

  /// 是否使用手机紧凑布局。
  final bool compact;

  /// 左侧或顶部设置名称。
  final String label;

  /// 当前设置的交互控件。
  final Widget child;

  /// 是否在当前行底部绘制分隔线。
  final bool showDivider;

  /// 手机端是否使用标题在上、控件在下的分组布局。
  final bool compactStacked;

  /// 根据可用宽度排列设置名称和控件。
  @override
  Widget build(BuildContext context) {
    // 手机的大型选项组使用上下结构，普通设置按设计稿保持标签和控件同一行。
    final content = _content(context);
    // 每行使用统一垂直间距和分隔线。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 9 : 10),
          child: content,
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
      ],
    );
  }

  /// 根据当前响应式状态构建设置行内容。
  Widget _content(BuildContext context) {
    // 手机大型选项组使用标题在上、控件在下的结构。
    if (compact && compactStacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _labelText(context),
          const SizedBox(height: 8),
          child,
        ],
      );
    }
    // 手机普通设置标签更窄，保留更多空间给右侧控件。
    if (compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(width: 66, child: _labelText(context)),
          Expanded(child: child),
        ],
      );
    }
    // 桌面设置行使用固定标签列，控件占据剩余宽度。
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox(width: 112, child: _labelText(context)),
        Expanded(child: child),
      ],
    );
  }

  /// 构建设置项标题文本。
  Widget _labelText(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
      style: Theme.of(context).textTheme.titleSmall,
    );
  }
}
