import 'package:flutter/material.dart';

import '../../../../core/theme/theme_accent_controller.dart';
import '../../../../core/widgets/app_anchored_dropdown.dart';

/// 设置页中控制主题色从暗到亮的滑块。
final class ThemeAccentBrightnessSlider extends StatelessWidget {
  /// 创建显示当前明暗级别的主题色滑块。
  const ThemeAccentBrightnessSlider({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// 当前零到一范围的主题色明暗级别。
  final double value;

  /// 用户拖动滑块时即时更新主题的回调。
  final ValueChanged<double> onChanged;

  /// 构建带暗色和亮色方向提示的响应式滑块。
  @override
  Widget build(BuildContext context) {
    // 百分比用于让键盘和鼠标用户明确当前调整位置。
    final percentage = (value * 100).round();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Row(
        children: <Widget>[
          // 左端月亮图标表示向左拖动会降低主题色亮度。
          Icon(
            Icons.brightness_2_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Slider(
              value: value,
              min: 0,
              max: 1,
              divisions: 100,
              label: '$percentage%',
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 8),
          // 右端太阳图标表示向右拖动会提高主题色亮度。
          Icon(
            Icons.brightness_7_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 42,
            child: Text(
              '$percentage%',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// 点击后在锚点浮层中展开颜色宫格的主题色选择器。
final class ThemeAccentPicker extends StatelessWidget {
  /// 创建与相邻 ChoiceChip 同高的主题色展开入口。
  const ThemeAccentPicker({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// 当前已经生效的主题色。
  final ThemeAccent selected;

  /// 用户在浮层中点击颜色后的回调。
  final ValueChanged<ThemeAccent> onSelected;

  /// 构建当前颜色按钮和不含名称、色值的颜色宫格浮层。
  @override
  Widget build(BuildContext context) {
    // 当前主题提供浮层背景、外框和入口交互色。
    final colorScheme = Theme.of(context).colorScheme;
    // 入口展示当前实际主题色，包含用户通过“主题色明暗”滑块得到的最终 primary。
    final activeAccentColor = colorScheme.primary;
    // 主题色宫格属于自定义菜单内容，但仍复用公共锚定弹层。
    return AppAnchoredDropdownMenu<ThemeAccent>(
      constraints: const BoxConstraints(minWidth: 222, maxWidth: 222),
      borderRadius: BorderRadius.circular(8),
      splashRadius: 17,
      itemBuilder: (BuildContext menuContext) {
        // 浮层中只生成颜色方块，不渲染名称和十六进制文本。
        return <PopupMenuEntry<ThemeAccent>>[
          _ThemeAccentPaletteMenuEntry(
            selected: selected,
            onSelected: (ThemeAccent value) {
              // 颜色方块自行关闭当前弹层，再交给控制器持久化主题选择。
              Navigator.of(menuContext).pop();
              onSelected(value);
            },
          ),
        ];
      },
      childBuilder: (BuildContext context, bool open) {
        // 入口只展示当前颜色与展开箭头，高度与“暗色”等按钮一致。
        return Semantics(
          button: true,
          expanded: open,
          child: SizedBox.square(
            dimension: 34,
            child: Material(
              color: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: activeAccentColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(
                    open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 17,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 主题色宫格菜单项，避免使用 PopupMenuItem 默认的整行 hover 背景。
final class _ThemeAccentPaletteMenuEntry extends PopupMenuEntry<ThemeAccent> {
  /// 创建只承载颜色方块的自定义菜单内容。
  const _ThemeAccentPaletteMenuEntry({
    required this.selected,
    required this.onSelected,
  });

  /// 当前已经生效的主题色。
  final ThemeAccent selected;

  /// 用户点击色块后的回调。
  final ValueChanged<ThemeAccent> onSelected;

  /// 菜单路由用于估算滚动定位的高度。
  @override
  double get height => 122;

  /// 宫格本身没有“代表某个值”的单行语义，定位交给内部色块。
  @override
  bool represents(ThemeAccent? value) => false;

  @override
  State<_ThemeAccentPaletteMenuEntry> createState() =>
      _ThemeAccentPaletteMenuEntryState();
}

/// 主题色宫格菜单项的渲染状态。
final class _ThemeAccentPaletteMenuEntryState
    extends State<_ThemeAccentPaletteMenuEntry> {
  /// 构建无整行 hover 的颜色宫格。
  @override
  Widget build(BuildContext context) {
    // 自定义菜单项只提供留白和布局，不创建 PopupMenuItem 的 InkWell 背景。
    return Padding(
      padding: const EdgeInsets.all(10),
      child: SizedBox(
        width: 202,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ThemeAccent.values
              .map<Widget>(
                (ThemeAccent accent) => _ThemeAccentChoice(
                  accent: accent,
                  selected: accent == widget.selected,
                  onSelected: widget.onSelected,
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

/// 设置页中与模式按钮同高的单个主题色方块。
final class _ThemeAccentChoice extends StatelessWidget {
  /// 创建一个仅展示颜色和选中勾选的主题色按钮。
  const _ThemeAccentChoice({
    required this.accent,
    required this.selected,
    required this.onSelected,
  });

  /// 当前方块代表的主题色。
  final ThemeAccent accent;

  /// 当前主题色是否已经生效。
  final bool selected;

  /// 用户点击颜色方块后的回调。
  final ValueChanged<ThemeAccent> onSelected;

  /// 构建与相邻 ChoiceChip 等高的圆角正方形颜色按钮。
  @override
  Widget build(BuildContext context) {
    // 外框使用当前主题语义色，使未选和选中状态在亮暗模式下都可辨认。
    final colorScheme = Theme.of(context).colorScheme;
    // 默认绿在亮暗模式有不同色值，色块必须展示当前实际生效颜色。
    final brightness = Theme.of(context).brightness;
    // 34 像素与桌面端 ChoiceChip 的实际视觉高度一致，避免颜色方块突出一截。
    return Semantics(
      button: true,
      selected: selected,
      child: SizedBox.square(
        dimension: 34,
        child: Material(
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: MouseRegion(
            // 色块不需要 hover/ripple，只保留桌面端可点击指针。
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              // 点击后立即切换全局主题并由控制器持久化本次选择。
              onTap: () => onSelected(accent),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.colorFor(brightness),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: accent.foregroundColorFor(brightness),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
