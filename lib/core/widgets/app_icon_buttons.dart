import 'package:flutter/material.dart';

import 'app_tooltip.dart';

/// 圆形图标按钮的公共视觉类型。
enum AppCircleIconButtonVariant {
  /// 透明背景的普通圆形操作。
  plain,

  /// 主色裸图标圆形操作，适合 PC 端下载、继续等局部操作。
  primaryPlain,

  /// 警告裸图标圆形操作，适合 PC 端失败重试等局部操作。
  warningPlain,

  /// 危险裸图标圆形操作，适合 PC 端删除、移除等破坏性局部操作。
  destructivePlain,

  /// 带轮廓的次级圆形操作。
  outlined,

  /// 主色描边圆形操作，适合下载、继续等强调型局部操作。
  primaryOutlined,

  /// 警告描边圆形操作，适合失败重试等需要提醒但不破坏数据的操作。
  warningOutlined,

  /// 危险描边圆形操作，适合删除、移除等破坏性局部操作。
  destructiveOutlined,

  /// 主色填充圆形操作，适合回顶和下载等明确主操作。
  filled,
}

/// 圆形图标按钮的公共尺寸类型。
enum AppCircleIconButtonSize {
  /// 大号圆形按钮，用于悬浮返回顶部等强入口。
  large,

  /// 默认圆形按钮，用于常规图标操作。
  medium,

  /// 小号圆形按钮，用于紧凑工具栏或列表行操作。
  small,
}

/// 可复用的圆形图标操作按钮。
final class AppCircleIconButton extends StatelessWidget {
  /// 创建统一 Tooltip、鼠标指针和圆形反馈区域的图标按钮。
  const AppCircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.variant = AppCircleIconButtonVariant.plain,
    this.size = AppCircleIconButtonSize.medium,
    this.dimension,
    this.iconSize,
    this.foregroundColor,
    this.backgroundColor,
    this.borderColor,
    super.key,
  }) : assert(tooltip != '', '图标按钮必须提供非空 tooltip，避免无文字按钮缺少说明。');

  /// 按钮中心的业务图标。
  final Widget icon;

  /// 鼠标悬停和无障碍读取使用的操作说明。
  final String tooltip;

  /// 点击回调；为空时显示禁用状态和禁止光标。
  final VoidCallback? onPressed;

  /// 当前按钮的基础视觉类型。
  final AppCircleIconButtonVariant variant;

  /// 圆形按钮语义尺寸；精确传入 dimension 时仅作为图标尺寸兜底参考。
  final AppCircleIconButtonSize size;

  /// 圆形按钮外接正方形尺寸覆盖值。
  final double? dimension;

  /// 图标尺寸覆盖值。
  final double? iconSize;

  /// 可选前景色覆盖。
  final Color? foregroundColor;

  /// 可选背景色覆盖。
  final Color? backgroundColor;

  /// 可选边框色覆盖。
  final Color? borderColor;

  /// 构建严格圆形的自绘图标按钮。
  @override
  Widget build(BuildContext context) {
    // 当前按钮是否可点击决定回调、光标和禁用色。
    final enabled = onPressed != null;
    // 颜色按视觉类型解析，页面只在必要时覆盖。
    final colors = _resolveColors(context, enabled);
    // 语义尺寸统一解析为真实外框尺寸，特殊局部控件仍可精确覆盖。
    final resolvedDimension = dimension ?? _defaultDimension(size);
    // 图标跟随按钮尺寸分级，避免页面手动计算大小。
    final resolvedIconSize = iconSize ?? _defaultIconSize(size);
    // 自定义悬停提示使用公共 OverlayEntry 组件，避开原生 Tooltip 的 OverlayPortal 布局问题。
    return AppTooltip(
      message: tooltip,
      preferBelow: false,
      mouseCursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: Material(
          color: backgroundColor ?? colors.background,
          shape: CircleBorder(
            side: BorderSide(color: borderColor ?? colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            mouseCursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.forbidden,
            child: SizedBox.square(
              dimension: resolvedDimension,
              child: IconTheme(
                data: IconThemeData(
                  size: resolvedIconSize,
                  color: foregroundColor ?? colors.foreground,
                ),
                child: Center(child: icon),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 根据语义尺寸返回圆形按钮外框尺寸。
  double _defaultDimension(AppCircleIconButtonSize resolvedSize) {
    // 三档尺寸对应普通按钮 large、medium、small 的视觉节奏。
    return switch (resolvedSize) {
      AppCircleIconButtonSize.large => 48,
      AppCircleIconButtonSize.medium => 40,
      AppCircleIconButtonSize.small => 32,
    };
  }

  /// 根据语义尺寸返回图标尺寸。
  double _defaultIconSize(AppCircleIconButtonSize resolvedSize) {
    // 图标尺寸跟随外框缩放，保证圆形按钮在列表和浮层中重量一致。
    return switch (resolvedSize) {
      AppCircleIconButtonSize.large => 22,
      AppCircleIconButtonSize.medium => 20,
      AppCircleIconButtonSize.small => 16,
    };
  }

  /// 根据视觉类型和启用状态解析图标按钮颜色。
  _AppCircleIconButtonColors _resolveColors(
    BuildContext context,
    bool enabled,
  ) {
    // 图标按钮使用主题语义色，确保亮暗模式都可读。
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // 警告色使用固定语义色，避免不同主题缺少 warning token 时漂移。
    final warning = _warningColor(theme.brightness);
    if (!enabled) {
      // 禁用态和普通按钮保持同一规则：保留按钮形态，降低当前类型的视觉强度。
      return switch (variant) {
        AppCircleIconButtonVariant.plain => _AppCircleIconButtonColors(
          background: Colors.transparent,
          foreground: colorScheme.onSurface.withValues(alpha: 0.38),
          border: Colors.transparent,
        ),
        AppCircleIconButtonVariant.primaryPlain => _AppCircleIconButtonColors(
          background: Colors.transparent,
          foreground: colorScheme.primary.withValues(alpha: 0.42),
          border: Colors.transparent,
        ),
        AppCircleIconButtonVariant.warningPlain => _AppCircleIconButtonColors(
          background: Colors.transparent,
          foreground: warning.withValues(alpha: 0.42),
          border: Colors.transparent,
        ),
        AppCircleIconButtonVariant.destructivePlain =>
          _AppCircleIconButtonColors(
            background: Colors.transparent,
            foreground: colorScheme.error.withValues(alpha: 0.42),
            border: Colors.transparent,
          ),
        AppCircleIconButtonVariant.outlined => _AppCircleIconButtonColors(
          background: Colors.transparent,
          foreground: colorScheme.onSurface.withValues(alpha: 0.38),
          border: colorScheme.onSurface.withValues(alpha: 0.18),
        ),
        AppCircleIconButtonVariant.primaryOutlined =>
          _AppCircleIconButtonColors(
            background: Colors.transparent,
            foreground: colorScheme.primary.withValues(alpha: 0.42),
            border: colorScheme.primary.withValues(alpha: 0.22),
          ),
        AppCircleIconButtonVariant.warningOutlined =>
          _AppCircleIconButtonColors(
            background: Colors.transparent,
            foreground: warning.withValues(alpha: 0.42),
            border: warning.withValues(alpha: 0.22),
          ),
        AppCircleIconButtonVariant.destructiveOutlined =>
          _AppCircleIconButtonColors(
            background: Colors.transparent,
            foreground: colorScheme.error.withValues(alpha: 0.42),
            border: colorScheme.error.withValues(alpha: 0.22),
          ),
        AppCircleIconButtonVariant.filled => _AppCircleIconButtonColors(
          background: colorScheme.primary.withValues(alpha: 0.38),
          foreground: colorScheme.onPrimary.withValues(alpha: 0.62),
          border: Colors.transparent,
        ),
      };
    }
    return switch (variant) {
      AppCircleIconButtonVariant.plain => _AppCircleIconButtonColors(
        background: Colors.transparent,
        foreground: colorScheme.onSurfaceVariant,
        border: Colors.transparent,
      ),
      AppCircleIconButtonVariant.primaryPlain => _AppCircleIconButtonColors(
        background: Colors.transparent,
        foreground: colorScheme.primary,
        border: Colors.transparent,
      ),
      AppCircleIconButtonVariant.warningPlain => _AppCircleIconButtonColors(
        background: Colors.transparent,
        foreground: warning,
        border: Colors.transparent,
      ),
      AppCircleIconButtonVariant.destructivePlain => _AppCircleIconButtonColors(
        background: Colors.transparent,
        foreground: colorScheme.error,
        border: Colors.transparent,
      ),
      AppCircleIconButtonVariant.outlined => _AppCircleIconButtonColors(
        background: Colors.transparent,
        foreground: colorScheme.onSurfaceVariant,
        border: colorScheme.outline,
      ),
      AppCircleIconButtonVariant.primaryOutlined => _AppCircleIconButtonColors(
        background: Colors.transparent,
        foreground: colorScheme.primary,
        border: colorScheme.primary,
      ),
      AppCircleIconButtonVariant.warningOutlined => _AppCircleIconButtonColors(
        background: Colors.transparent,
        foreground: warning,
        border: warning,
      ),
      AppCircleIconButtonVariant.destructiveOutlined =>
        _AppCircleIconButtonColors(
          background: Colors.transparent,
          foreground: colorScheme.error,
          border: colorScheme.error,
        ),
      AppCircleIconButtonVariant.filled => _AppCircleIconButtonColors(
        background: colorScheme.primary,
        foreground: Colors.white,
        border: Colors.transparent,
      ),
    };
  }

  /// 返回全局警告语义色，和提示条里的 warning 强调色保持一致。
  Color _warningColor(Brightness brightness) {
    // 暗色模式需要更亮的琥珀色，亮色模式使用更稳的棕橙色保证对比度。
    return brightness == Brightness.dark
        ? const Color(0xFFF6C453)
        : const Color(0xFFA86400);
  }
}

/// 圆形图标按钮颜色集合。
final class _AppCircleIconButtonColors {
  /// 创建按钮颜色集合。
  const _AppCircleIconButtonColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  /// 按钮背景色。
  final Color background;

  /// 图标前景色。
  final Color foreground;

  /// 边框颜色。
  final Color border;
}
