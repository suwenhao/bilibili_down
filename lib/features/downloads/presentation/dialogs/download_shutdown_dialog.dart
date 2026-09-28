import 'package:flutter/material.dart';

import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_selection_controls.dart';

/// 展示当前批次任务完成后的自动关机延迟选择弹窗。
Future<Duration?> showDownloadShutdownDialog({
  required BuildContext context,
  required int activeTaskCount,
}) {
  // 提供常用且不少于五分钟的安全延迟，用户必须明确选择后才能启用。
  const delayOptions = <Duration>[
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 30),
    Duration(hours: 1),
  ];
  // 弹窗初始不预选，防止用户误点确认沿用隐含默认时间。
  Duration? selectedDelay;
  return showDialog<Duration>(
    context: context,
    builder: (BuildContext dialogContext) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setDialogState) {
        return AppAlertDialog(
          width: 440,
          title: const Text('自动关机'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('请选择当前这批任务全部完成后，等待多长时间自动关机。'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: delayOptions
                    .map(
                      (Duration delay) => AppSelectionChip(
                        label: delay.inMinutes == 60
                            ? '1 小时'
                            : '${delay.inMinutes} 分钟',
                        selected: selectedDelay == delay,
                        onSelected: (bool selected) {
                          // 选中时保存明确时间，取消选中则恢复未选择状态。
                          setDialogState(
                            () => selectedDelay = selected ? delay : null,
                          );
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 14),
              Text(
                '仅对当前下载中列表的 $activeTaskCount 个任务生效；'
                '任务失败、取消、列表变化或重启软件都会自动关闭。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: <Widget>[
            AppActionButton(
              variant: AppActionButtonVariant.text,
              onPressed: () => Navigator.of(dialogContext).pop(),
              label: '取消',
            ),
            AppActionButton(
              variant: AppActionButtonVariant.filled,
              onPressed: selectedDelay == null
                  ? null
                  : () => Navigator.of(dialogContext).pop(selectedDelay),
              label: '确认启用',
            ),
          ],
        );
      },
    ),
  );
}
