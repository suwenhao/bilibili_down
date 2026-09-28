import 'package:flutter/material.dart';

import '../models/onboarding_step.dart';

/// 功能卡片内一条带图标的产品说明。
final class OnboardingItemRow extends StatelessWidget {
  /// 创建单条说明行。
  const OnboardingItemRow({required this.item, this.trailing, super.key});

  /// 当前说明的图标、标题和辅助文字。
  final OnboardingItem item;

  /// 行尾授权按钮或已授权状态；为空时保持普通说明行。
  final Widget? trailing;

  /// 构建具有清晰主次层级的说明行。
  @override
  Widget build(BuildContext context) {
    // 主题语义色负责图标背景和辅助文案对比度。
    final colorScheme = Theme.of(context).colorScheme;
    // 行内布局让图标与两行文字在大字体下仍保持顶部对齐。
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: colorScheme.primary, size: 23),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  item.detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 12),
            // 权限操作放在行尾，保证标题说明不被按钮语义打断。
            trailing!,
          ],
        ],
      ),
    );
  }
}
