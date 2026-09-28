import 'package:flutter/material.dart';

import 'app_action_button.dart';
import '../theme/app_theme.dart';
import 'app_toolbar_button_specs.dart';

/// 工具栏操作按钮的公共视觉类型。
enum AppToolbarActionVariant {
  /// 主行动按钮，例如开始下载或继续任务。
  filled,

  /// 普通次级描边按钮。
  outlined,

  /// 主色浅底描边按钮，用于需要主题色强调的次级操作。
  plain,

  /// 中性色描边按钮，适合目录更改等非主色操作。
  neutralOutlined,

  /// 危险描边按钮，适合清空或删除。
  destructiveOutlined,
}

/// 页面工具栏统一操作按钮。
final class AppToolbarActionButton extends StatelessWidget {
  /// 创建统一高度、圆角、加载态和鼠标指针的工具栏按钮。
  const AppToolbarActionButton({
    required this.label,
    required this.onPressed,
    this.compact = false,
    this.variant = AppToolbarActionVariant.outlined,
    this.icon,
    this.loading = false,
    this.loadingLabel,
    this.textOnly = false,
    this.highlighted = false,
    super.key,
  });

  /// 按钮显示的业务文案。
  final String label;

  /// 点击后的业务回调，空值表示禁用。
  final VoidCallback? onPressed;

  /// 是否使用紧凑布局参数。
  final bool compact;

  /// 当前按钮视觉类型。
  final AppToolbarActionVariant variant;

  /// 非纯文字模式下显示的前置图标。
  final IconData? icon;

  /// 是否展示加载状态并禁用点击。
  final bool loading;

  /// 加载时替换原文案的短文案。
  final String? loadingLabel;

  /// 是否隐藏图标，仅展示文字或加载指示器。
  final bool textOnly;

  /// 是否用主色描边强调已启用状态。
  final bool highlighted;

  /// 构建 Material 按钮并统一外层高度。
  @override
  Widget build(BuildContext context) {
    // 工具栏按钮只负责选择紧凑规格，具体按钮行为由 AppActionButton 底座提供。
    return appToolbarActionButton(
      label: label,
      onPressed: onPressed,
      compact: compact,
      variant: switch (variant) {
        AppToolbarActionVariant.filled => AppActionButtonVariant.filled,
        AppToolbarActionVariant.outlined => AppActionButtonVariant.outlined,
        AppToolbarActionVariant.plain => AppActionButtonVariant.plain,
        AppToolbarActionVariant.neutralOutlined =>
          AppActionButtonVariant.neutralOutlined,
        AppToolbarActionVariant.destructiveOutlined =>
          AppActionButtonVariant.destructiveOutlined,
      },
      icon: icon,
      loading: loading,
      loadingLabel: loadingLabel,
      textOnly: textOnly,
      highlighted: highlighted,
    );
  }
}

/// 可点击的工具栏信息字段。
final class AppToolbarInfoField extends StatelessWidget {
  /// 创建带图标、前缀和值的紧凑信息字段。
  const AppToolbarInfoField({
    required this.value,
    this.prefix,
    this.icon,
    this.onTap,
    this.actionLabel,
    this.compact = false,
    this.borderRadius = AppToolbarButtonSpecs.defaultBorderRadius,
    super.key,
  });

  /// 字段主体值，例如目录路径。
  final String value;

  /// 字段前缀，例如“存储：”。
  final String? prefix;

  /// 左侧语义图标。
  final IconData? icon;

  /// 点击字段后的业务回调，空值表示禁用。
  final VoidCallback? onTap;

  /// 右侧内嵌操作按钮的文案，空值表示不显示尾部按钮。
  final String? actionLabel;

  /// 是否使用紧凑布局参数。
  final bool compact;

  /// 字段圆角。
  final BorderRadiusGeometry borderRadius;

  /// 构建带裁剪反馈的可点击字段。
  @override
  Widget build(BuildContext context) {
    // 字段高度和图标尺寸与同排工具栏按钮保持一致。
    final height = AppToolbarButtonSpecs.height(compact: compact);
    // 图标尺寸跟随工具栏规格，避免字段比按钮显重。
    final iconSize = AppToolbarButtonSpecs.iconSize(compact: compact);
    // 当前字段是否可点击由业务回调决定。
    final enabled = onTap != null;
    // 尾部操作文案决定是否在字段内部收纳一个小按钮。
    final inlineActionLabel = actionLabel;
    // 内嵌按钮高度比外框略小，形成类似输入框内按钮的视觉层级。
    final inlineActionHeight = height - 8;
    // 字段使用中性色，避免被误认为主行动按钮。
    final colorScheme = Theme.of(context).colorScheme;
    // 禁用态降低文字和图标透明度。
    final foregroundColor = enabled
        ? colorScheme.onSurfaceVariant
        : colorScheme.onSurface.withValues(alpha: 0.38);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              0,
              inlineActionLabel == null ? 12 : 4,
              0,
            ),
            child: Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: iconSize, color: foregroundColor),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    '${prefix ?? ''}$value',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: AppTextStyles.selectableControlLabel.copyWith(
                      color: foregroundColor,
                    ),
                  ),
                ),
                if (inlineActionLabel != null) ...<Widget>[
                  const SizedBox(width: 8),
                  // 尾部文案只提供视觉提示，点击和 hover 统一交给整条字段处理。
                  Container(
                    constraints: BoxConstraints(
                      minWidth: 32,
                      minHeight: inlineActionHeight,
                      maxHeight: inlineActionHeight,
                    ),
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(6)),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Text(
                      inlineActionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.selectableControlLabel.copyWith(
                        color: foregroundColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
