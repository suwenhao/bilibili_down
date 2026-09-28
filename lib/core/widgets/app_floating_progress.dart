import 'package:flutter/material.dart';

/// 页面或 Shell 顶层使用的非阻断浮动进度提示。
final class AppFloatingProgress extends StatelessWidget {
  /// 创建带旋转进度和当前序号的浮动提示。
  const AppFloatingProgress({
    required this.message,
    required this.current,
    required this.total,
    super.key,
  });

  /// 当前任务说明文案。
  final String message;

  /// 当前正在处理的一基序号。
  final int current;

  /// 本轮需要处理的总数。
  final int total;

  /// 构建与应用提示体系一致的居中浮层。
  @override
  Widget build(BuildContext context) {
    // 高层级表面色在亮暗主题下都能与页面背景形成清晰区分。
    final colorScheme = Theme.of(context).colorScheme;
    // 序号限制在合法范围内，避免异步状态切换时出现 0/总数。
    final safeTotal = total <= 0 ? 1 : total;
    // 当前序号最小显示为一，保持用户理解中的处理进度。
    final safeCurrent = current.clamp(1, safeTotal);
    return Material(
      color: colorScheme.surfaceContainerHigh,
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              // 顶部浮层沿用解析页原始文案格式，避免不同入口出现两套进度写法。
              '$message $safeCurrent / $safeTotal 的数据…',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}
