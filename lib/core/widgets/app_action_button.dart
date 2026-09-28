import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_toolbar_button_specs.dart';

/// 应用按钮的公共视觉类型。
enum AppActionButtonVariant {
  /// 主行动按钮，例如确认、开始或下载。
  filled,

  /// 普通默认描边按钮，使用中性前景和中性边框。
  outlined,

  /// 主色浅底描边按钮，适合需要主题色强调但不是主行动的操作。
  plain,

  /// 中性色描边按钮，适合路径更改等非主色操作。
  neutralOutlined,

  /// 危险描边按钮，适合清空或删除。
  destructiveOutlined,

  /// 文本按钮，适合弹窗取消或轻量链接。
  text,
}

/// 应用按钮的公共尺寸类型。
enum AppActionButtonSize {
  /// 大号按钮，用于登录、解析、下载等主要入口。
  large,

  /// 默认按钮，用于弹窗确认和普通表单操作。
  medium,

  /// 小号按钮，用于工具栏、表格行和紧凑操作区。
  small,
}

/// 应用内文字按钮、描边按钮和填充按钮的公共底座。
final class AppActionButton extends StatelessWidget {
  /// 创建统一尺寸、加载态、图标和状态样式的自绘按钮。
  const AppActionButton({
    required this.label,
    required this.onPressed,
    this.variant = AppActionButtonVariant.outlined,
    this.icon,
    this.loading = false,
    this.loadingLabel,
    this.textOnly = false,
    this.highlighted = false,
    this.size = AppActionButtonSize.medium,
    this.height,
    this.minWidth = 32,
    this.horizontalPadding,
    this.iconSize,
    this.textStyle,
    this.borderRadius,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    super.key,
  });

  /// 按钮显示的业务文案。
  final String label;

  /// 点击后的业务回调，空值表示禁用。
  final VoidCallback? onPressed;

  /// 当前按钮的视觉类型。
  final AppActionButtonVariant variant;

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

  /// 按钮语义尺寸；精确传入 height 时仅作为图标和留白的兜底参考。
  final AppActionButtonSize size;

  /// 按钮固定视觉高度；为空时使用当前按钮类型的默认高度。
  final double? height;

  /// 按钮最小宽度。
  final double minWidth;

  /// 按钮左右内边距；为空时按按钮类型推导。
  final double? horizontalPadding;

  /// 图标和加载圈尺寸；为空时按高度推导。
  final double? iconSize;

  /// 按钮文字样式。
  final TextStyle? textStyle;

  /// 按钮圆角；为空时使用 8dp 圆角。
  final BorderRadiusGeometry? borderRadius;

  /// 可选背景色覆盖，用于 SnackBar 等特殊局部控件。
  final Color? backgroundColor;

  /// 可选前景色覆盖，用于 SnackBar 等特殊局部控件。
  final Color? foregroundColor;

  /// 可选边框色覆盖，用于特殊局部控件。
  final Color? borderColor;

  /// 构建严格遵守传入高度的按钮。
  @override
  Widget build(BuildContext context) {
    // 传入高度必须被严格使用，避免 Flutter 原生按钮最小触控高度干扰布局。
    final resolvedHeight = height ?? _defaultHeight(size);
    // 加载态必须禁用按钮，防止重复提交或重复批量操作。
    final effectiveOnPressed = loading ? null : onPressed;
    // 当前按钮是否可以交互。
    final enabled = effectiveOnPressed != null;
    // 最终文案根据加载态切换，未传加载文案时沿用原文案。
    final effectiveLabel = loading ? loadingLabel ?? label : label;
    // 视觉状态统一从主题和变体解析。
    final resolvedColors = _resolveColors(context, enabled);
    // 特殊局部控件可以覆盖颜色，但默认仍走变体语义色。
    final colors = _AppActionButtonColors(
      background: backgroundColor ?? resolvedColors.background,
      foreground: foregroundColor ?? resolvedColors.foreground,
      border: borderColor ?? resolvedColors.border,
    );
    // 圆角统一在 Material 层裁剪，确保 hover 和水波不会溢出。
    final resolvedRadius =
        borderRadius ?? const BorderRadius.all(Radius.circular(8));
    // 图标和进度圈共享尺寸，避免状态切换时布局跳动。
    final resolvedIconSize = iconSize ?? _defaultIconSize(size);
    // 左右留白直接影响按钮真实内容宽度，不依赖原生按钮内部 padding。
    final resolvedHorizontalPadding =
        horizontalPadding ?? _defaultHorizontalPadding(size);
    // 默认按钮使用项目常规字重，不继承 Theme.labelLarge 的半粗字重。
    final resolvedTextStyle =
        (textStyle ?? AppTextStyles.selectableControlLabel).copyWith(
          color: colors.foreground,
        );
    // 加载态使用统一尺寸进度圈，颜色跟随当前前景色。
    final loadingIndicator = SizedBox.square(
      dimension: resolvedIconSize,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: colors.foreground,
      ),
    );
    // 图标模式使用公共图标/加载位置，不让页面自己拼 icon 分支。
    final leading = _leadingContent(
      loading: loading,
      textOnly: textOnly,
      icon: icon,
      iconSize: resolvedIconSize,
      foreground: colors.foreground,
      loadingIndicator: loadingIndicator,
    );
    // 纯文字加载态没有图标槽时，直接用加载圈作为主体内容。
    final text = loading && leading == null
        ? loadingIndicator
        : Text(
            effectiveLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolvedTextStyle,
          );
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minWidth,
        minHeight: resolvedHeight,
        maxHeight: resolvedHeight,
      ),
      child: Material(
        color: colors.background,
        shape: RoundedRectangleBorder(
          borderRadius: resolvedRadius,
          side: BorderSide(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: effectiveOnPressed,
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.forbidden,
          child: SizedBox(
            height: resolvedHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: resolvedHorizontalPadding,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (leading != null) ...<Widget>[
                    leading,
                    const SizedBox(width: 8),
                  ],
                  Flexible(child: text),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 返回按钮默认高度。
  double _defaultHeight(AppActionButtonSize resolvedSize) {
    // 文本按钮也需要明确高度，避免不同平台 Material 默认值不一致。
    return switch (resolvedSize) {
      AppActionButtonSize.large => AppControlSizes.buttonLargeHeight,
      AppActionButtonSize.medium => AppControlSizes.buttonMediumHeight,
      AppActionButtonSize.small => AppControlSizes.buttonSmallHeight,
    };
  }

  /// 根据按钮尺寸推导默认图标尺寸。
  double _defaultIconSize(AppActionButtonSize resolvedSize) {
    // 图标随尺寸分级，避免小按钮图标过大或大按钮图标偏弱。
    return switch (resolvedSize) {
      AppActionButtonSize.large => 18,
      AppActionButtonSize.medium => 17,
      AppActionButtonSize.small => 16,
    };
  }

  /// 根据按钮尺寸推导默认水平留白。
  double _defaultHorizontalPadding(AppActionButtonSize resolvedSize) {
    // 紧凑按钮减少左右留白，标准按钮保留更舒适的点击宽度。
    return switch (resolvedSize) {
      AppActionButtonSize.large => 18,
      AppActionButtonSize.medium => 14,
      AppActionButtonSize.small => 10,
    };
  }

  /// 根据 loading 和图标配置返回按钮左侧内容。
  Widget? _leadingContent({
    required bool loading,
    required bool textOnly,
    required IconData? icon,
    required double iconSize,
    required Color foreground,
    required Widget loadingIndicator,
  }) {
    // 加载态优先展示进度圈，避免图标和 loading 同时出现。
    if (loading) return loadingIndicator;
    // 纯文本按钮和无图标按钮不占用左侧槽位。
    if (textOnly || icon == null) return null;
    // 普通图标态使用统一尺寸和当前按钮前景色。
    return Icon(icon, size: iconSize, color: foreground);
  }

  /// 根据变体和启用状态解析按钮颜色。
  _AppActionButtonColors _resolveColors(BuildContext context, bool enabled) {
    // 语义色需要读取当前主题，保证亮暗主题可读。
    final colorScheme = Theme.of(context).colorScheme;
    // 禁用态保留按钮类型轮廓，但降低同类语义色透明度，避免可用和不可用状态混淆。
    if (!enabled) {
      return switch (variant) {
        AppActionButtonVariant.filled => _AppActionButtonColors(
          background: colorScheme.primary.withValues(alpha: 0.38),
          foreground: colorScheme.onPrimary.withValues(alpha: 0.62),
          border: Colors.transparent,
        ),
        AppActionButtonVariant.plain => _AppActionButtonColors(
          background: colorScheme.primary.withValues(alpha: 0.06),
          foreground: colorScheme.primary.withValues(alpha: 0.42),
          border: colorScheme.primary.withValues(alpha: 0.22),
        ),
        AppActionButtonVariant.text => _AppActionButtonColors(
          background: Colors.transparent,
          foreground: colorScheme.onSurface.withValues(alpha: 0.38),
          border: Colors.transparent,
        ),
        AppActionButtonVariant.outlined ||
        AppActionButtonVariant.neutralOutlined => _AppActionButtonColors(
          background: Colors.transparent,
          foreground: colorScheme.onSurface.withValues(alpha: 0.38),
          border: colorScheme.onSurface.withValues(alpha: 0.18),
        ),
        AppActionButtonVariant.destructiveOutlined => _AppActionButtonColors(
          background: Colors.transparent,
          foreground: colorScheme.error.withValues(alpha: 0.42),
          border: colorScheme.error.withValues(alpha: 0.22),
        ),
      };
    }
    return switch (variant) {
      AppActionButtonVariant.filled => _AppActionButtonColors(
        background: colorScheme.primary,
        foreground: Colors.white,
        border: Colors.transparent,
      ),
      AppActionButtonVariant.text => _AppActionButtonColors(
        background: Colors.transparent,
        foreground: colorScheme.primary,
        border: Colors.transparent,
      ),
      AppActionButtonVariant.plain => _AppActionButtonColors(
        background: colorScheme.primary.withValues(alpha: 0.10),
        foreground: colorScheme.primary,
        border: colorScheme.primary,
      ),
      AppActionButtonVariant.outlined => _AppActionButtonColors(
        background: highlighted
            ? colorScheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        foreground: highlighted ? colorScheme.primary : colorScheme.onSurface,
        border: highlighted ? colorScheme.primary : colorScheme.outline,
      ),
      AppActionButtonVariant.neutralOutlined => _AppActionButtonColors(
        background: Colors.transparent,
        foreground: colorScheme.onSurfaceVariant,
        border: colorScheme.outlineVariant,
      ),
      AppActionButtonVariant.destructiveOutlined => _AppActionButtonColors(
        background: Colors.transparent,
        foreground: colorScheme.error,
        border: colorScheme.error,
      ),
    };
  }
}

/// 按钮三类颜色的解析结果。
final class _AppActionButtonColors {
  /// 创建按钮颜色集合。
  const _AppActionButtonColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  /// 按钮填充色。
  final Color background;

  /// 文本、图标和加载圈颜色。
  final Color foreground;

  /// 边框颜色。
  final Color border;
}

/// 创建工具栏规格的应用按钮。
AppActionButton appToolbarActionButton({
  required String label,
  required VoidCallback? onPressed,
  required bool compact,
  required AppActionButtonVariant variant,
  IconData? icon,
  bool loading = false,
  String? loadingLabel,
  bool textOnly = false,
  bool highlighted = false,
  AppActionButtonSize size = AppActionButtonSize.medium,
}) {
  // 工具栏按钮固定为紧凑高度，便于各页面横排对齐。
  final height = AppToolbarButtonSpecs.height(compact: compact);
  return AppActionButton(
    label: label,
    onPressed: onPressed,
    variant: variant,
    icon: icon,
    loading: loading,
    loadingLabel: loadingLabel,
    textOnly: textOnly,
    highlighted: highlighted,
    size: size,
    height: height,
    minWidth: 32,
    horizontalPadding: compact ? 8 : 10,
    iconSize: AppToolbarButtonSpecs.iconSize(compact: compact),
    textStyle: AppTextStyles.selectableControlLabel,
    borderRadius: AppToolbarButtonSpecs.defaultBorderRadius,
  );
}
