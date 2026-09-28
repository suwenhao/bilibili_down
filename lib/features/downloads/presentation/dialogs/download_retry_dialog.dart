import 'package:flutter/material.dart';

import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/app_dialog.dart';

/// 失败任务由用户在每次重试时选择的执行策略。
enum DownloadManualRetryStrategy {
  /// 重新进入等待队列并遵守全局并发数。
  queued,

  /// 立即重新解析地址并启动，不等待当前并发槽位。
  immediate,
}

/// 展示失败任务的重试策略弹窗。
Future<DownloadManualRetryStrategy?> showDownloadRetryDialog({
  required BuildContext context,
  required String? errorCode,
}) {
  // 错误码用于解释智能换线行为，不暴露临时媒体 URL。
  final retryHint = switch (errorCode) {
    '401' || '403' => '将清除失效凭据并重新获取游客可用的播放地址。',
    'protocol_error' || 'network_error' => '将重新获取地址并优先轮换备用 CDN。',
    _ => '将重新解析当前资源并保留已有任务设置。',
  };
  return showDialog<DownloadManualRetryStrategy>(
    context: context,
    builder: (BuildContext dialogContext) => AppAlertDialog(
      title: const Text('选择重试方式'),
      content: Text('$retryHint\n\n排队重试会遵守全局并发数；立即重试会立刻占用网络。'),
      actions: <Widget>[
        AppActionButton(
          variant: AppActionButtonVariant.text,
          onPressed: () => Navigator.of(dialogContext).pop(),
          label: '取消',
        ),
        AppActionButton(
          variant: AppActionButtonVariant.outlined,
          onPressed: () => Navigator.of(
            dialogContext,
          ).pop(DownloadManualRetryStrategy.immediate),
          label: '立即重试',
        ),
        AppActionButton(
          variant: AppActionButtonVariant.filled,
          onPressed: () => Navigator.of(
            dialogContext,
          ).pop(DownloadManualRetryStrategy.queued),
          label: '排队重试',
        ),
      ],
    ),
  );
}
