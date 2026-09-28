import 'package:bilibili_down/core/theme/app_theme.dart';
import 'package:bilibili_down/core/theme/theme_accent_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 验证明暗中点保持用户选择的品牌原色不变。
  test('中点保持主题原色', () {
    // 使用默认绿色验证中性设置不会产生累计颜色漂移。
    const source = Color(0xFF3F9E6E);
    expect(
      adjustThemeAccentBrightness(source, defaultThemeAccentBrightness),
      source,
    );
  });

  /// 验证滑块两端按固定方向改变亮度并保持完全不透明。
  test('滑块从暗到亮且保持不透明', () {
    // 使用中等亮度颜色同时覆盖向黑和向白两条混合分支。
    const source = Color(0xFF3F9E6E);
    final darker = adjustThemeAccentBrightness(source, 0);
    final brighter = adjustThemeAccentBrightness(source, 1);

    expect(darker.computeLuminance(), lessThan(source.computeLuminance()));
    expect(brighter.computeLuminance(), greaterThan(source.computeLuminance()));
    expect(darker.a, 1);
    expect(brighter.a, 1);
  });

  /// 验证三类标准按钮不会因页面或按钮类型产生高度和字重差异。
  test('标准按钮高度与文字排版统一', () {
    // 默认暗色主题用于解析三类按钮最终生效的全局样式。
    final theme = AppTheme.dark(accentColor: ThemeAccent.original.darkColor);
    // 空状态集合代表按钮处于普通启用状态。
    const states = <WidgetState>{};
    // 三类按钮样式必须全部由主题提供，页面无需重复声明字号和高度。
    final styles = <ButtonStyle>[
      theme.filledButtonTheme.style!,
      theme.outlinedButtonTheme.style!,
      theme.textButtonTheme.style!,
    ];

    for (final style in styles) {
      // 统一高度避免填充按钮和描边按钮并排时出现上下错位。
      expect(
        style.minimumSize?.resolve(states)?.height,
        AppControlSizes.standardHeight,
      );
      // 用户要求按钮文字使用常规字重，不再显示粗体。
      expect(style.textStyle?.resolve(states)?.fontWeight, FontWeight.w400);
      expect(
        style.textStyle?.resolve(states)?.fontSize,
        AppTextStyles.selectableControlLabel.fontSize,
      );
    }
  });

  /// 验证全部品牌色及明暗滑块端点上的填充按钮文字仍具备可读对比度。
  test('全部主题色的主按钮前景保持可读', () {
    // 两种界面亮度都必须独立生成并验证主题前景色。
    for (final brightness in Brightness.values) {
      // 遍历全部内置品牌色，防止新增主题色后遗漏按钮前景判断。
      for (final accent in ThemeAccent.values) {
        // 中点及两端覆盖原色、最暗和最亮三种用户可选状态。
        for (final level in <double>[0, 0.5, 1]) {
          // 当前背景色来源于品牌色、界面模式和明暗滑块的组合。
          final accentColor = adjustThemeAccentBrightness(
            accent.colorFor(brightness),
            level,
          );
          // 按当前界面模式生成最终 ColorScheme。
          final theme = brightness == Brightness.dark
              ? AppTheme.dark(accentColor: accentColor)
              : AppTheme.light(accentColor: accentColor);
          // 主按钮背景和文字对比度按 WCAG 相对亮度公式计算。
          final contrast = _contrastRatio(
            theme.colorScheme.primary,
            theme.colorScheme.onPrimary,
          );

          expect(
            contrast,
            greaterThanOrEqualTo(4.5),
            reason: '${accent.label} $brightness level=$level',
          );
        }
      }
    }
  });
}

/// 计算两个不透明颜色之间的 WCAG 对比度。
double _contrastRatio(Color first, Color second) {
  // 较亮和较暗颜色分别进入标准对比度公式。
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first.computeLuminance()
      : second.computeLuminance();
  final darker = first.computeLuminance() > second.computeLuminance()
      ? second.computeLuminance()
      : first.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}
