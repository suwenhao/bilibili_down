import 'package:flutter/material.dart';

import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/app_checkbox_description_tile.dart';
import '../../../../core/widgets/app_dialog.dart';

/// 下载记录删除弹窗确认后的选择。
final class DownloadDeletionDialogResult {
  /// 保存是否同时处理本地成品文件。
  const DownloadDeletionDialogResult({required this.deleteFiles});

  /// 是否同时把本地文件移入回收站或永久删除。
  final bool deleteFiles;
}

/// 展示批量清空已下载记录的范围确认弹窗。
Future<DownloadDeletionDialogResult?> showClearCompletedDownloadsDialog({
  required BuildContext context,
  required int taskCount,
  required int fileCount,
  required int directoryCount,
  required String totalSizeLabel,
  required List<String> visibleScopes,
  required int hiddenScopeCount,
  required bool canDeleteFiles,
  required bool usesSystemTrash,
}) {
  // 默认只清理数据库记录，避免批量操作误删用户成品。
  var deleteFiles = false;
  return showDialog<DownloadDeletionDialogResult>(
    context: context,
    builder: (BuildContext dialogContext) => AppAlertDialog(
      title: const Text('清空已下载记录？'),
      content: StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          // StatefulBuilder 只维护本次确认中的文件删除选择。
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('任务记录：$taskCount 条'),
              const SizedBox(height: 6),
              Text(
                '本地内容：$fileCount 个文件'
                '${directoryCount > 0 ? '，$directoryCount 个目录' : ''}',
              ),
              const SizedBox(height: 6),
              Text('占用空间：$totalSizeLabel'),
              const SizedBox(height: 10),
              Text('删除范围：', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              if (visibleScopes.isEmpty)
                const Text('未找到仍存在的本地成品')
              else
                ...visibleScopes.map(
                  (String scope) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      scope,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              if (hiddenScopeCount > 0) Text('另有 $hiddenScopeCount 个目录或存储位置'),
              const SizedBox(height: 8),
              AppCheckboxDescriptionTile(
                value: deleteFiles,
                onChanged: canDeleteFiles
                    ? (bool? selected) {
                        // 空值按未选中处理，防止三态输入产生不明确删除语义。
                        setDialogState(() => deleteFiles = selected ?? false);
                      }
                    : null,
                title: usesSystemTrash ? '同时移入回收站' : '同时永久删除已下载文件',
                subtitle: usesSystemTrash
                    ? '勾选后作为一个批次移入系统回收站，可从回收站恢复。'
                    : '勾选后将删除全部本地成品，此操作无法撤销。',
              ),
            ],
          );
        },
      ),
      actions: <Widget>[
        AppActionButton(
          variant: AppActionButtonVariant.text,
          onPressed: () => Navigator.of(dialogContext).pop(),
          label: '取消',
        ),
        AppActionButton(
          variant: AppActionButtonVariant.filled,
          onPressed: () => Navigator.of(
            dialogContext,
          ).pop(DownloadDeletionDialogResult(deleteFiles: deleteFiles)),
          label: '清空',
        ),
      ],
    ),
  );
}

/// 展示单条任务记录的删除确认弹窗。
Future<DownloadDeletionDialogResult?> showDeleteDownloadTaskDialog({
  required BuildContext context,
  required String taskTitle,
  required bool completed,
  required bool usesSystemTrash,
}) {
  // 已完成记录默认保留成品文件，避免用户误删已经下载的内容。
  var deleteFiles = false;
  return showDialog<DownloadDeletionDialogResult>(
    context: context,
    builder: (BuildContext dialogContext) => AppAlertDialog(
      title: Text(completed ? '删除下载记录？' : '停止并删除任务？'),
      content: completed
          ? StatefulBuilder(
              builder: (BuildContext context, StateSetter setDialogState) {
                // StatefulBuilder 只刷新当前确认弹窗，不触发任务列表重建。
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('将删除“$taskTitle”的任务记录。'),
                    const SizedBox(height: 8),
                    AppCheckboxDescriptionTile(
                      value: deleteFiles,
                      onChanged: (bool? selected) {
                        // 空值按未选中处理，保存本次确认操作的文件删除选择。
                        setDialogState(() => deleteFiles = selected ?? false);
                      },
                      title: usesSystemTrash ? '同时移入回收站' : '同时永久删除已下载文件',
                      subtitle: usesSystemTrash
                          ? '勾选后将把本地成品移入系统回收站，可从回收站恢复。'
                          : '勾选后将删除本地成品，此操作无法撤销。',
                    ),
                  ],
                );
              },
            )
          : Text('将停止“$taskTitle”，并删除任务记录、未完成的下载分流和未合并完成的文件。'),
      actions: <Widget>[
        AppActionButton(
          variant: AppActionButtonVariant.text,
          onPressed: () => Navigator.of(dialogContext).pop(),
          label: '取消',
        ),
        AppActionButton(
          variant: AppActionButtonVariant.filled,
          onPressed: () => Navigator.of(
            dialogContext,
          ).pop(DownloadDeletionDialogResult(deleteFiles: deleteFiles)),
          label: '删除',
        ),
      ],
    ),
  );
}
