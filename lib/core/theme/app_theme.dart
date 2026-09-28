import 'package:flutter/material.dart';

/// BiliDown 全局字号令牌，修改这里即可统一调整应用排版。
abstract final class AppFontSizes {
  /// 超大展示文字。
  static const double displayLarge = 57;

  /// 中等展示文字。
  static const double displayMedium = 45;

  /// 小型展示文字。
  static const double displaySmall = 36;

  /// 一级大标题。
  static const double headlineLarge = 32;

  /// 二级大标题。
  static const double headlineMedium = 28;

  /// 页面标题。
  static const double headlineSmall = 24;

  /// 区块大标题。
  static const double titleLarge = 22;

  /// 卡片和对话框标题。
  static const double titleMedium = 16;

  /// 紧凑区块标题。
  static const double titleSmall = 14;

  /// 强调正文。
  static const double bodyLarge = 16;

  /// 默认正文。
  static const double bodyMedium = 14;

  /// 次级说明和错误信息。
  static const double bodySmall = 12;

  /// 全局 SnackBar 紧凑正文，按 Windows 150% 参考图换算为逻辑字号。
  static const double snackBar = 13;

  /// 按钮和主要标签。
  static const double labelLarge = 14;

  /// 次级标签。
  static const double labelMedium = 12;

  /// 时长角标等最小标签。
  static const double labelSmall = 11;
}

/// BiliDown 跨页面复用的交互控件尺寸令牌。
abstract final class AppControlSizes {
  /// 输入框、填充按钮和描边按钮统一使用的标准高度。
  static const double standardHeight = 46;

  /// 桌面工具栏使用的紧凑高度，减少鼠标操作区不必要的纵向占用。
  static const double compactHeight = 40;

  /// 大号按钮高度，用于解析等主入口。
  static const double buttonLargeHeight = 40;

  /// 默认按钮高度，用于设置页、工具栏和弹窗操作。
  static const double buttonMediumHeight = 36;

  /// 小号按钮高度，用于卡片内局部操作。
  static const double buttonSmallHeight = 32;
}

/// BiliDown 需要跨组件复用的语义文字样式。
abstract final class AppTextStyles {
  /// FilterChip、ChoiceChip 等可选按钮统一使用的普通字重文字。
  static const TextStyle selectableControlLabel = TextStyle(
    fontSize: AppFontSizes.labelLarge,
    fontWeight: FontWeight.w400,
  );
}

/// BiliDown 亮色与暗色主题工厂。
final class AppTheme {
  /// 中文界面优先使用各系统自带中文字体，不再随应用打包字体资源。
  static const List<String> _systemChineseFontFallback = <String>[
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'PingFang SC',
    'Hiragino Sans GB',
    'Noto Sans CJK SC',
    'Noto Sans SC',
    'Source Han Sans SC',
    'WenQuanYi Micro Hei',
    'Droid Sans Fallback',
    'sans-serif',
  ];

  /// 主题工厂只提供静态配置，不允许实例化。
  const AppTheme._();

  /// 应用所有语义文本层级，页面不得再直接写字号。
  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(fontSize: AppFontSizes.displayLarge),
    displayMedium: TextStyle(fontSize: AppFontSizes.displayMedium),
    displaySmall: TextStyle(fontSize: AppFontSizes.displaySmall),
    headlineLarge: TextStyle(fontSize: AppFontSizes.headlineLarge),
    headlineMedium: TextStyle(fontSize: AppFontSizes.headlineMedium),
    headlineSmall: TextStyle(
      fontSize: AppFontSizes.headlineSmall,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: TextStyle(
      fontSize: AppFontSizes.titleLarge,
      fontWeight: FontWeight.w700,
    ),
    titleMedium: TextStyle(
      fontSize: AppFontSizes.titleMedium,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: TextStyle(
      fontSize: AppFontSizes.titleSmall,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(fontSize: AppFontSizes.bodyLarge),
    bodyMedium: TextStyle(fontSize: AppFontSizes.bodyMedium),
    bodySmall: TextStyle(fontSize: AppFontSizes.bodySmall),
    labelLarge: TextStyle(
      fontSize: AppFontSizes.labelLarge,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: TextStyle(fontSize: AppFontSizes.labelMedium),
    labelSmall: TextStyle(fontSize: AppFontSizes.labelSmall),
  );

  /// 使用用户选择的品牌色创建亮色主题。
  static ThemeData light({required Color accentColor}) {
    // 使用品牌色生成完整 Material 3 色阶，再固定主色为用户看到的原始色值。
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.light,
      surface: const Color(0xFFFFFFFF),
      error: const Color(0xFFC23B3B),
    ).copyWith(primary: accentColor, onPrimary: Colors.white);
    // 返回全局统一的圆角、输入框和导航样式。
    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackground: colorScheme.surfaceContainerLowest,
      secondarySurface: colorScheme.surfaceContainerLow,
      dividerColor: colorScheme.outlineVariant,
    );
  }

  /// 使用用户选择的品牌色创建暗色主题。
  static ThemeData dark({required Color accentColor}) {
    // 暗色主题沿用同一品牌色，并让 Material 生成适配深色表面的辅助色阶。
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.dark,
      surface: const Color(0xFF1A1F1C),
      error: const Color(0xFFFF6B6B),
    ).copyWith(primary: accentColor, onPrimary: Colors.white);
    // 返回与亮色相同布局规格的暗色主题。
    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackground: colorScheme.surfaceContainerLowest,
      secondarySurface: colorScheme.surfaceContainerLow,
      dividerColor: colorScheme.outlineVariant,
    );
  }

  /// 使用主题令牌组装共享 Material 组件样式。
  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color secondarySurface,
    required Color dividerColor,
  }) {
    // 统一内容和按钮圆角，避免页面各自硬编码。
    const controlRadius = BorderRadius.all(Radius.circular(10));
    // 所有标准可点击控件使用手型，禁用状态使用禁止光标明确表达不可操作。
    final clickableMouseCursor = WidgetStateProperty<MouseCursor?>.fromMap(
      <WidgetStatesConstraint, MouseCursor?>{
        WidgetState.disabled: SystemMouseCursors.forbidden,
        WidgetState.any: SystemMouseCursors.click,
      },
    );
    // 主题数据是所有页面读取颜色和排版的唯一入口。
    return ThemeData(
      useMaterial3: true,
      fontFamilyFallback: _systemChineseFontFallback,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      dividerColor: dividerColor,
      canvasColor: colorScheme.surface,
      cardColor: colorScheme.surface,
      textTheme: _textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: const OutlineInputBorder(borderRadius: controlRadius),
        enabledBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.22),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: dividerColor),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: AppFontSizes.bodyMedium,
          height: 1.45,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        clipBehavior: Clip.antiAlias,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: dividerColor),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          enabledMouseCursor: SystemMouseCursors.click,
          disabledMouseCursor: SystemMouseCursors.forbidden,
          // 填充按钮固定主色底和白色前景，避免浅色主题下出现黑字。
          foregroundColor: Colors.white,
          minimumSize: const Size(44, AppControlSizes.standardHeight),
          shape: const RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: AppTextStyles.selectableControlLabel,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          enabledMouseCursor: SystemMouseCursors.click,
          disabledMouseCursor: SystemMouseCursors.forbidden,
          // 次级操作使用主题主色文字和中性描边，避免高饱和主题产生大面积色块。
          foregroundColor: colorScheme.primary,
          minimumSize: const Size(44, AppControlSizes.standardHeight),
          shape: const RoundedRectangleBorder(borderRadius: controlRadius),
          side: BorderSide(color: dividerColor),
          textStyle: AppTextStyles.selectableControlLabel,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          enabledMouseCursor: SystemMouseCursors.click,
          disabledMouseCursor: SystemMouseCursors.forbidden,
          // 纯文字操作与另外两类按钮保持同一字号和字重。
          foregroundColor: colorScheme.primary,
          minimumSize: const Size(44, AppControlSizes.standardHeight),
          textStyle: AppTextStyles.selectableControlLabel,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          enabledMouseCursor: SystemMouseCursors.click,
          disabledMouseCursor: SystemMouseCursors.forbidden,
        ),
      ),
      checkboxTheme: CheckboxThemeData(mouseCursor: clickableMouseCursor),
      radioTheme: RadioThemeData(
        mouseCursor: clickableMouseCursor,
        fillColor: WidgetStateProperty.resolveWith<Color>((
          Set<WidgetState> states,
        ) {
          // 选中的单选圆点使用主题色，未选中保持中性描边。
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return colorScheme.outline;
        }),
      ),
      switchTheme: SwitchThemeData(
        mouseCursor: clickableMouseCursor,
        thumbColor: WidgetStateProperty.resolveWith<Color>((
          Set<WidgetState> states,
        ) {
          // 主色轨道上的滑块固定白色，避免浅色主题下变成黑色。
          if (states.contains(WidgetState.selected)) return Colors.white;
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          // 选中轨道跟随主题色，关闭态沿用 Material 默认轨道。
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return null;
        }),
      ),
      popupMenuTheme: PopupMenuThemeData(mouseCursor: clickableMouseCursor),
      sliderTheme: SliderThemeData(mouseCursor: clickableMouseCursor),
      segmentedButtonTheme: SegmentedButtonThemeData(
        // 分段按钮经常作为弹窗页签，统一补齐手型、字号和高度，避免继承 Material 默认粗字重。
        style: ButtonStyle(
          mouseCursor: clickableMouseCursor,
          textStyle: const WidgetStatePropertyAll<TextStyle>(
            AppTextStyles.selectableControlLabel,
          ),
          minimumSize: const WidgetStatePropertyAll<Size>(
            Size(44, AppControlSizes.buttonMediumHeight),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        // 桌面悬浮操作按钮不经过 IconButtonTheme，需要单独声明鼠标指针。
        mouseCursor: clickableMouseCursor,
      ),
      chipTheme: ChipThemeData(
        // 普通 Chip 使用当前主题正文色，避免亮色模式继承白色前景而看不见。
        labelStyle: AppTextStyles.selectableControlLabel.copyWith(
          color: colorScheme.onSurface,
        ),
        // 选中 Chip 使用主色底和白色前景，避免不同主题出现黑白两套前景。
        secondaryLabelStyle: AppTextStyles.selectableControlLabel.copyWith(
          color: Colors.white,
        ),
        // 未选中状态保持页面表面色，与输入框和卡片一致。
        backgroundColor: colorScheme.surface,
        // 选中状态直接使用主色，不再让浅色主题生成黑色前景。
        selectedColor: colorScheme.primary,
        // 勾选图标与选中文字使用同一前景色。
        checkmarkColor: Colors.white,
        // Chip 边框沿用全局分隔色，亮色模式下仍能识别未选项边界。
        side: BorderSide(color: dividerColor),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        // 手机底栏按设计图只用图标和文字变色表达选中，不显示 Material 默认胶囊底。
        indicatorColor: Colors.transparent,
        // 底栏高度控制图标与文字的上下留白，避免比设计图显得厚重。
        height: 72,
        // 底栏贴在页面底部，不再叠加阴影或表面染色。
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        // 按压反馈只保留轻微色层，不能出现与选中态混淆的块状背景。
        overlayColor: WidgetStateProperty.resolveWith((states) {
          // 禁用状态由目标按钮自己处理，底栏不额外加视觉状态。
          if (states.contains(WidgetState.disabled)) return Colors.transparent;
          // 选中和未选中都使用主色轻触反馈，保持主题一致。
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return colorScheme.primary.withValues(alpha: 0.08);
          }
          return Colors.transparent;
        }),
        // 图标选中走主题色，未选中走弱前景色，贴近设计图的轻量导航。
        iconTheme: WidgetStateProperty.resolveWith((states) {
          // 是否选中来自 NavigationBar 注入的状态集合。
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            size: 24,
          );
        }),
        // 标签字号和字重固定，选中只增强颜色与字重，不改变布局高度。
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          // 选中态与图标保持同色，未选中态降低层级。
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            fontSize: AppFontSizes.labelSmall,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            height: 1.1,
          );
        }),
      ),
      extensions: <ThemeExtension<dynamic>>[
        BiliDownColors(secondarySurface: secondarySurface),
      ],
    );
  }
}

/// Material 配色之外的产品表面颜色。
final class BiliDownColors extends ThemeExtension<BiliDownColors> {
  /// 创建产品扩展颜色。
  const BiliDownColors({required this.secondarySurface});

  /// 次级容器背景色。
  final Color secondarySurface;

  /// 按主题动画要求复制扩展颜色。
  @override
  BiliDownColors copyWith({Color? secondarySurface}) {
    // 未提供新值时保留当前颜色。
    return BiliDownColors(
      secondarySurface: secondarySurface ?? this.secondarySurface,
    );
  }

  /// 在亮暗主题切换时插值扩展颜色。
  @override
  BiliDownColors lerp(covariant BiliDownColors? other, double t) {
    // 缺少目标主题时保持当前扩展，避免动画期间空值。
    if (other == null) return this;
    // 使用 Color.lerp 平滑过渡表面颜色。
    return BiliDownColors(
      secondarySurface:
          Color.lerp(secondarySurface, other.secondarySurface, t) ??
          secondarySurface,
    );
  }
}

/// 从当前主题读取产品扩展颜色。
extension BiliDownThemeContext on BuildContext {
  /// 返回已经注册的 BiliDown 扩展颜色。
  BiliDownColors get biliDownColors {
    // 应用根主题始终注册该扩展，缺失时使用当前表面色安全回退。
    return Theme.of(this).extension<BiliDownColors>() ??
        BiliDownColors(secondarySurface: Theme.of(this).colorScheme.surface);
  }
}
