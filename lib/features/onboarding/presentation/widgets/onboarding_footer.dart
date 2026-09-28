import 'package:flutter/material.dart';

import '../../../../core/widgets/app_action_button.dart';

/// 引导页底部固定操作栏。
final class OnboardingFooter extends StatelessWidget {
  /// 创建引导页底部按钮区。
  const OnboardingFooter({
    required this.colorScheme,
    required this.completing,
    required this.isFirstPage,
    required this.isLastPage,
    required this.onBack,
    required this.onPrimary,
    super.key,
  });

  /// 当前主题色，用于绘制半透明底栏和分隔线。
  final ColorScheme colorScheme;

  /// 当前是否正在保存完成状态。
  final bool completing;

  /// 当前是否在第一页，决定左侧按钮文案。
  final bool isFirstPage;

  /// 当前是否在最后一页，决定主按钮文案。
  final bool isLastPage;

  /// 左侧跳过或上一步动作。
  final VoidCallback? onBack;

  /// 右侧下一步或开始使用动作。
  final VoidCallback? onPrimary;

  /// 构建固定高度的底部操作栏。
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.94),
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 104,
            child: AppActionButton(
              variant: AppActionButtonVariant.text,
              onPressed: onBack,
              label: isFirstPage ? '跳过' : '上一步',
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 144,
            child: AppActionButton(
              variant: AppActionButtonVariant.filled,
              onPressed: onPrimary,
              loading: completing,
              label: isLastPage ? '开始使用' : '下一步',
            ),
          ),
        ],
      ),
    );
  }
}
