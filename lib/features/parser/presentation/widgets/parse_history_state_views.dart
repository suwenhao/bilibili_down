part of '../parse_history_page.dart';

/// 解析历史加载态。
final class ParseHistoryLoadingState extends StatelessWidget {
  /// 创建居中加载状态。
  const ParseHistoryLoadingState({super.key});

  /// 构建加载进度。
  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// 解析历史错误态。
final class ParseHistoryErrorState extends StatelessWidget {
  /// 创建错误态。
  const ParseHistoryErrorState({super.key, required this.onRetry});

  /// 重新订阅历史列表回调。
  final VoidCallback onRetry;

  /// 构建错误提示和重试按钮。
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 10),
            const Text('解析历史读取失败。', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            AppActionButton(
              variant: AppActionButtonVariant.outlined,
              onPressed: onRetry,
              icon: Icons.refresh_rounded,
              label: '重试',
            ),
          ],
        ),
      ),
    );
  }
}

/// 解析历史空态。
final class ParseHistoryEmptyState extends StatelessWidget {
  /// 创建空态。
  const ParseHistoryEmptyState({super.key});

  /// 构建空态提示。
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.history_rounded, size: 46, color: colorScheme.primary),
            const SizedBox(height: 12),
            Text('暂无解析历史', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '成功解析过的视频会保存在这里，之后可直接恢复到解析页。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
