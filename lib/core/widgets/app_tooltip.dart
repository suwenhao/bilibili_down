import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 应用内统一的悬停提示。
final class AppTooltip extends StatefulWidget {
  /// 创建不依赖 Flutter 原生 Tooltip 的提示包装。
  const AppTooltip({
    super.key,
    required this.message,
    required this.child,
    this.waitDuration = const Duration(milliseconds: 450),
    this.verticalOffset = 8,
    this.preferBelow = true,
    this.tapToShow = false,
    this.showArrow = false,
    this.mouseCursor = SystemMouseCursors.click,
  });

  /// 悬停时展示的短说明。
  final String message;

  /// 需要展示提示的业务控件。
  final Widget child;

  /// 鼠标停留多久后插入浮层。
  final Duration waitDuration;

  /// 提示框和目标控件之间的垂直距离。
  final double verticalOffset;

  /// 常规空间充足时是否优先显示在控件下方。
  final bool preferBelow;

  /// 是否允许点击目标控件显示提示；手机端没有悬停能力时使用。
  final bool tapToShow;

  /// 是否在提示框朝向目标控件的一侧显示小三角。
  final bool showArrow;

  /// 鼠标悬停到气泡触发区域时使用的光标。
  final MouseCursor mouseCursor;

  @override
  State<AppTooltip> createState() => _AppTooltipState();
}

/// 管理提示浮层的生命周期。
final class _AppTooltipState extends State<AppTooltip> {
  /// 延迟展示计时器，避免鼠标快速经过时频繁插入浮层。
  Timer? _showTimer;

  /// 当前插入到根 Overlay 的提示层。
  OverlayEntry? _entry;

  /// 清理未触发的计时器和已经插入的浮层。
  @override
  void dispose() {
    _hideTooltip();
    super.dispose();
  }

  /// 构建可跟随目标控件定位的悬停区域。
  @override
  Widget build(BuildContext context) {
    final hoverChild = MouseRegion(
      cursor: widget.mouseCursor,
      onEnter: (_) => _scheduleTooltip(),
      onExit: (_) => _hideTooltip(),
      child: widget.child,
    );
    if (!widget.tapToShow) return hoverChild;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _toggleTooltip,
      child: hoverChild,
    );
  }

  /// 点击触发时切换提示浮层，便于手机端再次点击图标关闭。
  void _toggleTooltip() {
    if (_entry == null) {
      _showTooltip();
    } else {
      _hideTooltip();
    }
  }

  /// 安排延迟展示提示，贴近系统 Tooltip 的交互节奏。
  void _scheduleTooltip() {
    _showTimer?.cancel();
    _showTimer = Timer(widget.waitDuration, _showTooltip);
  }

  /// 插入提示浮层。
  void _showTooltip() {
    final message = widget.message.trim();
    if (!mounted || _entry != null || message.isEmpty) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final placement = _resolvePlacement(
      message,
      Theme.of(context).textTheme.labelSmall,
    );
    if (placement == null) return;
    _entry = OverlayEntry(
      builder: (BuildContext overlayContext) {
        final theme = Theme.of(overlayContext);
        final colorScheme = theme.colorScheme;
        final tooltip = Material(
          color: Colors.transparent,
          child: SizedBox(
            width: placement.width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (widget.showArrow && placement.showBelow)
                  _AppTooltipArrow(
                    color: colorScheme.inverseSurface,
                    centerX: placement.arrowCenterX,
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.inverseSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Text(
                      message,
                      maxLines: widget.tapToShow ? 4 : 3,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onInverseSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (widget.showArrow && !placement.showBelow)
                  _AppTooltipArrow(
                    color: colorScheme.inverseSurface,
                    centerX: placement.arrowCenterX,
                    pointsDown: true,
                  ),
              ],
            ),
          ),
        );
        return Positioned.fill(
          child: Stack(
            children: <Widget>[
              if (widget.tapToShow)
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _hideTooltip,
                  child: const SizedBox.expand(),
                ),
              Positioned(
                left: placement.left,
                top: placement.top,
                bottom: placement.bottom,
                child: widget.tapToShow
                    ? tooltip
                    : IgnorePointer(child: tooltip),
              ),
            ],
          ),
        );
      },
    );
    overlay.insert(_entry!);
  }

  /// 根据目标控件位置计算不越界的浮层位置。
  _AppTooltipPlacement? _resolvePlacement(
    String message,
    TextStyle? textStyle,
  ) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    final size = MediaQuery.maybeSizeOf(context);
    if (size == null || size.width <= 16) return null;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final targetRect = topLeft & renderObject.size;
    // 顶部空间不足时强制向下展示，底部空间不足时强制向上展示。
    var showBelow = widget.preferBelow;
    if (targetRect.top < 56) {
      showBelow = true;
    } else if (size.height - targetRect.bottom < 56) {
      showBelow = false;
    }
    final tooltipWidth = _measureTooltipWidth(message, textStyle, size.width);
    final preferredLeft = targetRect.center.dx - tooltipWidth / 2;
    final left = preferredLeft.clamp(8.0, size.width - tooltipWidth - 8.0);
    final arrowCenterX = (targetRect.center.dx - left).clamp(
      12.0,
      tooltipWidth - 12.0,
    );
    final arrowSpace = widget.showArrow ? 6.0 : 0.0;
    return _AppTooltipPlacement(
      left: left,
      top: showBelow
          ? targetRect.bottom + widget.verticalOffset - arrowSpace
          : null,
      bottom: showBelow
          ? null
          : size.height - targetRect.top + widget.verticalOffset - arrowSpace,
      width: tooltipWidth,
      arrowCenterX: arrowCenterX,
      showBelow: showBelow,
    );
  }

  /// 按实际文案估算提示宽度，避免短提示被最大宽度计算推离目标控件。
  double _measureTooltipWidth(
    String message,
    TextStyle? textStyle,
    double width,
  ) {
    final maxWidth = math.min(320.0, width - 16);
    const horizontalPadding = 20.0;
    final textPainter = TextPainter(
      text: TextSpan(text: message, style: textStyle),
      maxLines: widget.tapToShow ? 4 : 3,
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
    )..layout(maxWidth: maxWidth - horizontalPadding);
    final measuredWidth = textPainter.width + horizontalPadding;
    return measuredWidth.clamp(44.0, maxWidth);
  }

  /// 移除提示浮层。
  void _hideTooltip() {
    _showTimer?.cancel();
    _showTimer = null;
    _entry?.remove();
    _entry = null;
  }
}

/// 提示浮层的小三角，点击弹出模式下用来指向触发图标。
final class _AppTooltipArrow extends StatelessWidget {
  /// 创建朝上或朝下的小三角。
  const _AppTooltipArrow({
    required this.color,
    required this.centerX,
    this.pointsDown = false,
  });

  /// 小三角填充色，需要与提示框背景一致。
  final Color color;

  /// 小三角中心相对提示框左侧的距离。
  final double centerX;

  /// 是否朝下指向位于下方的触发控件。
  final bool pointsDown;

  /// 构建与提示框同宽的三角占位，避免左右贴边时箭头错位。
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 6,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // 小三角按实际提示框宽度定位，避免浮层贴屏幕边缘时箭头离开图标。
          final left = (centerX - 6).clamp(0.0, constraints.maxWidth - 12);
          return Stack(
            children: <Widget>[
              Positioned(
                left: left,
                child: CustomPaint(
                  size: const Size(12, 6),
                  painter: _AppTooltipArrowPainter(
                    color,
                    pointsDown: pointsDown,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 绘制提示框三角箭头。
final class _AppTooltipArrowPainter extends CustomPainter {
  /// 创建箭头画笔。
  const _AppTooltipArrowPainter(this.color, {required this.pointsDown});

  /// 箭头颜色。
  final Color color;

  /// 是否绘制朝下箭头。
  final bool pointsDown;

  /// 按方向绘制三角形。
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointsDown) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height);
    } else {
      path
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  /// 颜色或方向变化时才需要重绘。
  @override
  bool shouldRepaint(covariant _AppTooltipArrowPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.pointsDown != pointsDown;
  }
}

/// 提示浮层在根 Overlay 中的绝对位置。
final class _AppTooltipPlacement {
  /// 创建已经贴边修正过的提示位置。
  const _AppTooltipPlacement({
    required this.left,
    required this.top,
    required this.bottom,
    required this.width,
    required this.arrowCenterX,
    required this.showBelow,
  });

  /// 浮层左侧坐标，已限制在窗口安全边距内。
  final double left;

  /// 向下展示时使用的顶部坐标。
  final double? top;

  /// 向上展示时使用的底部坐标。
  final double? bottom;

  /// 当前提示按文案测量后的实际宽度。
  final double width;

  /// 小三角中心相对浮层左侧的位置。
  final double arrowCenterX;

  /// 当前浮层是否显示在目标控件下方。
  final bool showBelow;
}
