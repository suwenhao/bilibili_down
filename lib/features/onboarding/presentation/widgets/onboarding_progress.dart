import 'package:flutter/material.dart';

/// 顶部数字步骤和线性进度条。
final class OnboardingProgress extends StatelessWidget {
  /// 创建当前步骤进度指示器。
  const OnboardingProgress({
    required this.currentIndex,
    required this.total,
    super.key,
  });

  /// 从零开始的当前页索引。
  final int currentIndex;

  /// 引导总步骤数。
  final int total;

  /// 根据当前页计算动画进度。
  @override
  Widget build(BuildContext context) {
    // 当前可读步骤从一开始，与设计稿的“1/4”一致。
    final displayIndex = currentIndex + 1;
    // 线性进度值限制在 0 到 1，避免异常总数造成组件断言。
    final progress = total <= 0 ? 0.0 : displayIndex / total;
    // 主题主色用于数字和已完成进度。
    final colorScheme = Theme.of(context).colorScheme;
    // 数字与进度条纵向排列，保持功能向导的清晰层级。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$displayIndex/$total',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}
