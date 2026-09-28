import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 页面工具栏按钮的共享尺寸和样式规格。
abstract final class AppToolbarButtonSpecs {
  /// 工具栏按钮使用较小圆角，避免 medium 高度下呈现胶囊按钮。
  static const BorderRadiusGeometry defaultBorderRadius = BorderRadius.all(
    Radius.circular(8),
  );

  /// 返回任务页工具栏使用的普通按钮高度。
  static double height({required bool compact}) {
    // 任务页工具栏按设计规范使用 medium 按钮，不再使用小号卡片按钮尺寸。
    return AppControlSizes.buttonMediumHeight;
  }

  /// 返回工具栏按钮图标尺寸。
  static double iconSize({required bool compact}) {
    // medium 按钮使用 17dp 图标，和公共按钮尺寸令牌保持一致。
    return 17.0;
  }

  /// 创建工具栏按钮共用的字号、最小尺寸和水平留白。
  static ButtonStyle style({
    required bool compact,
    BorderRadiusGeometry borderRadius = defaultBorderRadius,
  }) {
    // 当前布局对应的按钮高度用于覆盖全局 48dp 最小高度。
    final resolvedHeight = height(compact: compact);
    // 手机横向空间更紧张，左右留白比桌面再缩小 2dp。
    final horizontalPadding = compact ? 8.0 : 10.0;
    return ButtonStyle(
      minimumSize: WidgetStatePropertyAll<Size>(Size(32, resolvedHeight)),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: horizontalPadding),
      ),
      textStyle: const WidgetStatePropertyAll<TextStyle>(
        AppTextStyles.selectableControlLabel,
      ),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: borderRadius),
      ),
    );
  }

  /// 创建会随启用状态切换描边和文字颜色的危险操作按钮样式。
  static ButtonStyle destructiveOutlinedStyle(BuildContext context) {
    // 读取当前主题色，保证亮色和暗色主题都具备足够的状态对比度。
    final colorScheme = Theme.of(context).colorScheme;
    // 禁用态必须回到中性轮廓色，避免不可点击时仍像可执行的红色危险操作。
    Color resolveColor(Set<WidgetState> states) {
      return states.contains(WidgetState.disabled)
          ? colorScheme.onSurface.withValues(alpha: 0.38)
          : colorScheme.error;
    }

    // 文字、图标和描边共用同一状态解析规则。
    return ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith(resolveColor),
      side: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) => BorderSide(color: resolveColor(states)),
      ),
    );
  }
}
