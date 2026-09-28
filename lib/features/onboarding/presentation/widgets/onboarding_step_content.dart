import 'package:flutter/material.dart';

import '../../../../core/widgets/app_action_button.dart';
import '../models/onboarding_step.dart';
import 'onboarding_hero.dart';
import 'onboarding_item_row.dart';

/// 单个引导步骤的视觉、标题和说明卡片。
final class OnboardingStepContent extends StatelessWidget {
  /// 创建一页完整引导内容。
  const OnboardingStepContent({
    required this.step,
    required this.compactHeight,
    required this.fileManagementGranted,
    required this.notificationGranted,
    required this.requestingFileManagement,
    required this.requestingNotification,
    required this.onRequestFileManagement,
    required this.onRequestNotification,
    super.key,
  });

  /// 当前页使用的稳定产品内容。
  final OnboardingStep step;

  /// 是否压缩视觉区域高度以适配横屏或小屏。
  final bool compactHeight;

  /// 文件管理授权是否已满足。
  final bool fileManagementGranted;

  /// 通知授权是否已满足。
  final bool notificationGranted;

  /// 文件管理授权按钮是否正在等待系统流程。
  final bool requestingFileManagement;

  /// 通知授权按钮是否正在等待系统流程。
  final bool requestingNotification;

  /// 点击文件管理授权按钮后的页面动作。
  final VoidCallback? onRequestFileManagement;

  /// 点击通知授权按钮后的页面动作。
  final VoidCallback? onRequestNotification;

  /// 按视觉目标构建居中主视觉与功能卡片。
  @override
  Widget build(BuildContext context) {
    // 小高度设备缩小主视觉，给大字体正文留出滚动前的可见空间。
    final heroHeight = compactHeight ? 116.0 : 154.0;
    // 卡片表面颜色沿用当前亮暗主题。
    final colorScheme = Theme.of(context).colorScheme;
    // 内容按主视觉、标题和功能卡片顺序形成稳定阅读路径。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: heroHeight,
          child: OnboardingHero(visual: step.visual),
        ),
        SizedBox(height: compactHeight ? 18 : 28),
        Text(
          step.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          step.subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        SizedBox(height: compactHeight ? 18 : 26),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              for (
                int index = 0;
                index < step.items.length;
                index++
              ) ...<Widget>[
                OnboardingItemRow(
                  item: step.items[index],
                  trailing: _buildPermissionTrailing(
                    context,
                    step.items[index],
                  ),
                ),
                // 最后一项之后不绘制多余分隔线，保持卡片圆角边缘干净。
                if (index < step.items.length - 1)
                  Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: colorScheme.outlineVariant,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 根据说明项绑定的权限类型构建授权按钮或已授权文字。
  Widget? _buildPermissionTrailing(BuildContext context, OnboardingItem item) {
    // 普通说明项没有授权动作，保持原来的纯文本布局。
    final permissionKind = item.permissionKind;
    if (permissionKind == null) return null;

    // 主题色用于“已授权”状态，和进度条及主按钮保持同一视觉语义。
    final colorScheme = Theme.of(context).colorScheme;
    // 不同权限行读取各自状态和点击动作，避免按钮之间互相影响。
    final granted = switch (permissionKind) {
      OnboardingPermissionKind.fileManagement => fileManagementGranted,
      OnboardingPermissionKind.notification => notificationGranted,
    };
    if (granted) {
      return Text(
        '已授权',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    // 未授权时显示明确按钮；授权成功后会替换为普通文字。
    final loading = switch (permissionKind) {
      OnboardingPermissionKind.fileManagement => requestingFileManagement,
      OnboardingPermissionKind.notification => requestingNotification,
    };
    final onPressed = switch (permissionKind) {
      OnboardingPermissionKind.fileManagement => onRequestFileManagement,
      OnboardingPermissionKind.notification => onRequestNotification,
    };
    return SizedBox(
      width: 76,
      child: AppActionButton(
        label: '授权',
        loadingLabel: '授权中',
        loading: loading,
        onPressed: onPressed,
        variant: AppActionButtonVariant.plain,
        size: AppActionButtonSize.small,
        height: 34,
      ),
    );
  }
}
