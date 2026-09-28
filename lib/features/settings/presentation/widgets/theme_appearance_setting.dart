import 'package:flutter/material.dart';

import '../../../../core/theme/theme_accent_controller.dart';
import '../../../../core/widgets/app_selection_controls.dart';
import '../models/settings_labels.dart';
import 'theme_accent_controls.dart';

/// 将亮暗模式与品牌主题色入口排列在同一行。
final class ThemeAppearanceSetting extends StatelessWidget {
  /// 创建响应式主题外观选择区域。
  const ThemeAppearanceSetting({
    required this.compact,
    required this.themeMode,
    required this.themeAccent,
    required this.onThemeModeSelected,
    required this.onThemeAccentSelected,
    super.key,
  });

  /// 是否使用手机端轻量单选样式。
  final bool compact;

  /// 当前生效的亮暗主题模式。
  final ThemeMode themeMode;

  /// 当前生效的品牌主题色。
  final ThemeAccent themeAccent;

  /// 用户选择亮暗模式后的回调。
  final ValueChanged<ThemeMode> onThemeModeSelected;

  /// 用户选择品牌主题色后的回调。
  final ValueChanged<ThemeAccent> onThemeAccentSelected;

  /// 构建可随可用宽度自动换行的模式按钮和颜色方块。
  @override
  Widget build(BuildContext context) {
    // 三种模式直接成为 Wrap 子项，确保颜色入口紧跟最后一个模式按钮。
    final modeChoices = ThemeMode.values.map<Widget>((ThemeMode mode) {
      // 手机端和桌面端统一使用单选圆点样式，保持设置页单选语义一致。
      return AppRadioChoice<ThemeMode>(
        value: mode,
        groupValue: themeMode,
        label: themeModeLabel(mode),
        onSelected: onThemeModeSelected,
      );
    });
    // 模式按钮和主题色展开入口共享流式布局，宽度不足时自然换行。
    return Wrap(
      spacing: compact ? 12 : 10,
      runSpacing: compact ? 4 : 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        ...modeChoices,
        ThemeAccentPicker(
          selected: themeAccent,
          onSelected: onThemeAccentSelected,
        ),
      ],
    );
  }
}
