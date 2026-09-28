import 'package:flutter/material.dart';

import 'app_icon_buttons.dart';

/// 全局列表“回到顶部”圆形按钮。
final class AppScrollToTopButton extends StatelessWidget {
  /// 创建可复用于页面浮层和列表浮层的回顶入口。
  const AppScrollToTopButton({
    required this.onPressed,
    this.tooltip = '回到顶部',
    this.size = 40,
    this.iconSize = 22,
    super.key,
  });

  /// 点击后滚动当前列表到顶部；为空时展示禁用光标。
  final VoidCallback? onPressed;

  /// 鼠标悬停和无障碍读取使用的操作说明。
  final String tooltip;

  /// 圆形按钮的外接正方形尺寸，默认匹配页面右下角浮动入口。
  final double size;

  /// 中心箭头图标尺寸，随按钮大小保持统一视觉重量。
  final double iconSize;

  /// 构建固定圆形的主色浮动按钮。
  @override
  Widget build(BuildContext context) {
    // 回顶入口必须保持正圆，避免各页面因 FAB 或局部 IconButton 主题产生差异。
    return AppCircleIconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      variant: AppCircleIconButtonVariant.filled,
      dimension: size,
      iconSize: iconSize,
      icon: const Icon(Icons.keyboard_arrow_up_rounded),
    );
  }
}
