import 'package:flutter/material.dart';

import '../../domain/download_task_phase.dart';

/// 桌面下载和合并阶段使用的流动斜纹进度条。
final class AnimatedTaskProgressBar extends StatefulWidget {
  /// 创建与任务阶段同步的进度条。
  const AnimatedTaskProgressBar({
    required this.progress,
    required this.phase,
    super.key,
  });

  /// 当前持久化进度，范围由调用方限制在 0 到 1。
  final double progress;

  /// 当前任务阶段，用于决定确定进度、加载段或合并动画。
  final DownloadTaskPhase phase;

  /// 创建进度动画状态。
  @override
  State<AnimatedTaskProgressBar> createState() =>
      _AnimatedTaskProgressBarState();
}

/// 驱动斜纹移动并尊重系统减少动画设置。
final class _AnimatedTaskProgressBarState extends State<AnimatedTaskProgressBar>
    with SingleTickerProviderStateMixin {
  /// 斜纹每 900 毫秒循环一次，速度明显但不会产生闪烁。
  late final AnimationController _stripeController;

  /// 初始化循环控制器，实际启动时机由当前阶段和媒体设置共同决定。
  @override
  void initState() {
    super.initState();
    // 控制器只提供 0 到 1 的平移进度，不持有任务业务状态。
    _stripeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  /// 主题、TickerMode 或减少动画设置变化时同步动画状态。
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 依赖 MediaQuery 和 TickerMode，必须在依赖完成后再决定是否循环。
    _synchronizeAnimation();
  }

  /// 任务阶段变化时立即启动或停止动画。
  @override
  void didUpdateWidget(covariant AnimatedTaskProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 暂停、完成或失败后不能继续消耗帧回调。
    if (oldWidget.phase != widget.phase) _synchronizeAnimation();
  }

  /// 释放斜纹动画控制器。
  @override
  void dispose() {
    // 页面移除任务卡片时同步释放 Ticker。
    _stripeController.dispose();
    super.dispose();
  }

  /// 根据任务阶段、页面可见性和辅助功能设置控制循环。
  void _synchronizeAnimation() {
    // 等待、解析、下载、等待合并和合并阶段都需要表达仍在进行。
    final activePhase = switch (widget.phase) {
      DownloadTaskPhase.waitingToStart ||
      DownloadTaskPhase.resolving ||
      DownloadTaskPhase.downloading ||
      DownloadTaskPhase.waitingForMerge ||
      DownloadTaskPhase.merging => true,
      _ => false,
    };
    // 用户要求减少动画或当前路由不可见时停止循环，保留静态状态即可。
    final shouldAnimate =
        activePhase &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (shouldAnimate) {
      // 已经循环时不重复调用 repeat，避免阶段进度更新重置动画。
      if (!_stripeController.isAnimating) {
        _stripeController.repeat();
      }
      return;
    }
    // 暂停动画时保留当前纹理位置，避免突然跳回起点。
    _stripeController.stop();
  }

  /// 构建圆角轨道、移动斜纹和无障碍进度说明。
  @override
  Widget build(BuildContext context) {
    // 等待合并和合并中表示两个媒体流已经下载完成，视觉进度铺满。
    final completedStreams =
        widget.phase == DownloadTaskPhase.waitingForMerge ||
        widget.phase == DownloadTaskPhase.merging;
    // 等待启动和解析阶段没有可用百分比，改用横向移动的加载段。
    final indeterminate =
        widget.phase == DownloadTaskPhase.waitingToStart ||
        widget.phase == DownloadTaskPhase.resolving;
    // 暂停阶段保留确定进度，但不绘制运动斜纹。
    final animateStripes = widget.phase != DownloadTaskPhase.paused;
    // 无障碍朗读使用真实阶段，不把合并动画误报为下载百分比。
    final semanticValue = switch (widget.phase) {
      DownloadTaskPhase.waitingToStart => '等待开始下载',
      DownloadTaskPhase.resolving => '正在解析',
      DownloadTaskPhase.waitingForMerge => '等待合并',
      DownloadTaskPhase.merging => '正在合并',
      _ => '${(widget.progress * 100).round()}%',
    };
    return Semantics(
      label: '任务进度',
      value: semanticValue,
      child: RepaintBoundary(
        child: SizedBox(
          height: 10,
          child: AnimatedBuilder(
            animation: _stripeController,
            builder: (BuildContext context, Widget? child) {
              // 减少动画时让加载段停在中部，仍保持可辨识状态。
              final animationValue = _progressAnimationValue(indeterminate);
              return CustomPaint(
                painter: _TaskProgressPainter(
                  progress: completedStreams ? 1 : widget.progress,
                  animationValue: animationValue,
                  indeterminate: indeterminate,
                  animateStripes: animateStripes,
                  trackColor: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.12),
                  primaryColor: Theme.of(context).colorScheme.primary,
                ),
                isComplex: true,
                willChange: _stripeController.isAnimating,
              );
            },
          ),
        ),
      ),
    );
  }

  /// 根据动画状态返回进度条纹理偏移值。
  double _progressAnimationValue(bool indeterminate) {
    // 动画运行时使用控制器实时值。
    if (_stripeController.isAnimating) return _stripeController.value;
    // 减少动画时让加载段停在中部，仍保持可辨识状态。
    if (indeterminate) return 0.5;
    // 普通确定进度无需纹理偏移。
    return 0.0;
  }
}

/// 绘制圆角轨道、确定进度、加载段和流动斜纹。
final class _TaskProgressPainter extends CustomPainter {
  /// 创建一帧任务进度绘制参数。
  const _TaskProgressPainter({
    required this.progress,
    required this.animationValue,
    required this.indeterminate,
    required this.animateStripes,
    required this.trackColor,
    required this.primaryColor,
  });

  /// 当前确定进度。
  final double progress;

  /// 斜纹或加载段在单次循环中的平移位置。
  final double animationValue;

  /// 是否使用移动加载段代替确定百分比。
  final bool indeterminate;

  /// 是否绘制强调任务运行状态的斜纹。
  final bool animateStripes;

  /// 未完成轨道颜色。
  final Color trackColor;

  /// 项目主题主色。
  final Color primaryColor;

  /// 绘制当前进度帧。
  @override
  void paint(Canvas canvas, Size size) {
    // 空尺寸没有可绘制区域，提前返回避免无效 Canvas 操作。
    if (size.isEmpty) return;
    // 整条轨道使用高度一半作为圆角，形成紧凑胶囊。
    final trackRect = Offset.zero & size;
    final trackRadius = Radius.circular(size.height / 2);
    final trackRRect = RRect.fromRectAndRadius(trackRect, trackRadius);
    // 先绘制低对比轨道，为亮暗主题提供稳定边界。
    canvas.drawRRect(trackRRect, Paint()..color = trackColor);
    // 加载段会从轨道外进入，所有填充必须先裁剪在圆角轨道内部。
    canvas.save();
    canvas.clipRRect(trackRRect);

    // 解析阶段使用约三分之一宽度的移动加载段。
    final fillRect = indeterminate
        ? _indeterminateRect(size)
        : Rect.fromLTWH(
            0,
            0,
            size.width * progress.clamp(0.0, 1.0),
            size.height,
          );
    // 进度为零时不绘制填充，保留完整轨道即可。
    if (fillRect.width <= 0) {
      canvas.restore();
      return;
    }
    final fillRRect = RRect.fromRectAndRadius(fillRect, trackRadius);
    // 主色底层保证暂停或减少动画时仍能读取实际进度。
    canvas.drawRRect(
      fillRRect,
      Paint()..color = primaryColor.withValues(alpha: 0.42),
    );
    // 暂停阶段不再显示运动感，避免与真实任务状态冲突。
    if (!animateStripes) {
      canvas.restore();
      return;
    }

    // 斜纹只能出现在已完成填充范围内，不能覆盖未完成轨道。
    canvas.clipRRect(fillRRect);
    // 每组斜纹包含 11dp 色带和 8dp 间隔，保持图二的清晰节奏。
    const stripeWidth = 11.0;
    const stripeGap = 8.0;
    const stripeStep = stripeWidth + stripeGap;
    // 循环位移跨越两组色带，首尾连接时不会出现停顿。
    final movingOffset = animationValue * stripeStep * 2;
    final stripePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.78)
      ..isAntiAlias = true;
    // 从填充区左侧外开始绘制，确保圆角边缘没有空洞。
    for (
      var x = fillRect.left - size.height - stripeStep + movingOffset;
      x < fillRect.right + size.height + stripeStep;
      x += stripeStep
    ) {
      // 平行四边形向右上倾斜，运动方向与下载推进一致。
      final stripe = Path()
        ..moveTo(x, fillRect.bottom)
        ..lineTo(x + stripeWidth, fillRect.bottom)
        ..lineTo(x + stripeWidth + size.height, fillRect.top)
        ..lineTo(x + size.height, fillRect.top)
        ..close();
      canvas.drawPath(stripe, stripePaint);
    }
    // 恢复 Canvas，避免轨道和填充裁剪影响同一层其他绘制内容。
    canvas.restore();
  }

  /// 计算解析阶段从左向右循环移动的加载段。
  Rect _indeterminateRect(Size size) {
    // 最窄保持 56dp，宽屏按轨道 32% 显示，避免加载段过短。
    final segmentWidth = (size.width * 0.32).clamp(56.0, size.width);
    // 从轨道左侧外进入并从右侧外离开，循环时没有突然闪现。
    final travelWidth = size.width + segmentWidth;
    final left = (travelWidth * animationValue) - segmentWidth;
    return Rect.fromLTWH(left, 0, segmentWidth, size.height);
  }

  /// 仅参数变化时重绘，静态暂停卡片不会持续消耗绘制资源。
  @override
  bool shouldRepaint(covariant _TaskProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.indeterminate != indeterminate ||
        oldDelegate.animateStripes != animateStripes ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.primaryColor != primaryColor;
  }
}
