import 'package:flutter/material.dart';

import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../application/resources/batch_extra_resource_export_service.dart';

/// 批量附加资源导出弹窗需要执行的异步任务。
typedef DownloadBatchExportRunner =
    Future<BatchExtraResourceExportResult> Function(
      ValueChanged<BatchExtraResourceExportProgress> onProgress,
    );

/// 批量附加资源导出弹窗关闭后的结果。
final class DownloadBatchExportDialogOutcome {
  /// 保存成功结果或失败对象，二者最多只有一个非空。
  const DownloadBatchExportDialogOutcome({this.result, this.failure});

  /// 导出完成后的统计结果。
  final BatchExtraResourceExportResult? result;

  /// 导出过程中捕获的异常。
  final Object? failure;
}

/// 展示不可中途关闭的批量附加资源导出进度弹窗。
Future<DownloadBatchExportDialogOutcome> showDownloadBatchExportDialog({
  required BuildContext context,
  required DownloadBatchExportRunner runExport,
  required String Function(Object error) errorMessageBuilder,
}) async {
  BatchExtraResourceExportProgress? progress;
  BatchExtraResourceExportResult? result;
  Object? failure;
  var started = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setDialogState) {
        if (!started) {
          // 首次构建后异步启动，避免在 build 过程中直接触发状态变化。
          started = true;
          Future<void>.microtask(() async {
            try {
              final exportResult = await runExport((
                BatchExtraResourceExportProgress nextProgress,
              ) {
                // 弹窗存在时刷新进度；关闭后不再访问局部状态。
                if (dialogContext.mounted) {
                  setDialogState(() => progress = nextProgress);
                }
              });
              if (dialogContext.mounted) {
                setDialogState(() => result = exportResult);
              }
            } catch (error) {
              if (dialogContext.mounted) {
                setDialogState(() => failure = error);
              }
            }
          });
        }
        final theme = Theme.of(context);
        final currentProgress = progress;
        final completed = result != null || failure != null;
        return AppAlertDialog(
          width: 520,
          title: const Text('批量下载附加资源'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (failure != null)
                Text(
                  '下载失败：${errorMessageBuilder(failure!)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                )
              else if (result != null)
                Text(
                  result!.failedResources == 0
                      ? '已下载 ${result!.exportedFiles} 个文件。'
                      : '已下载 ${result!.exportedFiles} 个文件，${result!.failedResources} 项失败。',
                )
              else
                Text(currentProgress?.currentLabel ?? '准备下载附加资源…'),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: currentProgress?.ratio),
              const SizedBox(height: 8),
              Text(
                currentProgress == null
                    ? '正在初始化…'
                    : '${currentProgress.completed} / ${currentProgress.total}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (result != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  '目录：${result!.outputDirectory}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
          actions: <Widget>[
            AppActionButton(
              variant: AppActionButtonVariant.text,
              onPressed: completed
                  ? () {
                      // 只有结束后才允许关闭，避免后台仍在写文件时弹窗消失。
                      Navigator.of(dialogContext).pop();
                    }
                  : null,
              label: '关闭',
            ),
          ],
        );
      },
    ),
  );
  return DownloadBatchExportDialogOutcome(result: result, failure: failure);
}
