import 'package:flutter/material.dart';

import '../../../../core/widgets/app_action_button.dart';
import '../models/onboarding_step.dart';

/// 引导页顶部主视觉，复用应用图标与 Material 图标避免伪造品牌资产。
final class OnboardingHero extends StatelessWidget {
  /// 创建当前步骤对应的主视觉。
  const OnboardingHero({required this.visual, super.key});

  /// 当前需要展示的主视觉类型。
  final OnboardingVisual visual;

  /// 根据步骤类型构建品牌图标、下载示意、平台位置或安全图标。
  @override
  Widget build(BuildContext context) {
    // 主题颜色让图标背景与用户选择的品牌色一致。
    final colorScheme = Theme.of(context).colorScheme;
    // 每种视觉只表达当前步骤的一个核心概念。
    return switch (visual) {
      OnboardingVisual.welcome => Center(
        child: Image.asset(
          'assets/images/app_icon.png',
          width: 126,
          height: 126,
          filterQuality: FilterQuality.high,
        ),
      ),
      OnboardingVisual.download => Center(
        child: Container(
          width: 292,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.link_rounded, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'bilibili.com/video/BV1…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: AppActionButton(
                  variant: AppActionButtonVariant.filled,
                  onPressed: null,
                  icon: Icons.download_rounded,
                  label: '加入下载队列',
                ),
              ),
            ],
          ),
        ),
      ),
      OnboardingVisual.storage => Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            OnboardingHeroIcon(
              icon: Icons.android_rounded,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 18),
            OnboardingHeroIcon(
              icon: Icons.folder_copy_outlined,
              color: colorScheme.primary,
              emphasized: true,
            ),
            const SizedBox(width: 18),
            OnboardingHeroIcon(
              icon: Icons.apple_rounded,
              color: colorScheme.primary,
            ),
          ],
        ),
      ),
      OnboardingVisual.ready => Center(
        child: OnboardingHeroIcon(
          icon: Icons.verified_user_rounded,
          color: colorScheme.primary,
          emphasized: true,
        ),
      ),
    };
  }
}

/// 主视觉中的主题化图标容器。
final class OnboardingHeroIcon extends StatelessWidget {
  /// 创建普通或强调尺寸的图标容器。
  const OnboardingHeroIcon({
    required this.icon,
    required this.color,
    this.emphasized = false,
    super.key,
  });

  /// Material 图标数据，表达平台、目录或安全语义。
  final IconData icon;

  /// 当前主题主色，用于图标和浅色背景。
  final Color color;

  /// 是否使用中心主视觉的大尺寸规格。
  final bool emphasized;

  /// 构建带圆角和细边框的图标表面。
  @override
  Widget build(BuildContext context) {
    // 强调图标比两侧平台图标更大，形成保存位置或安全核心焦点。
    final size = emphasized ? 88.0 : 58.0;
    // 图标字号随容器规格同步变化。
    final iconSize = emphasized ? 48.0 : 30.0;
    // 主题表面与主色透明背景在亮暗模式下都保持层级。
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(emphasized ? 24 : 18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}
