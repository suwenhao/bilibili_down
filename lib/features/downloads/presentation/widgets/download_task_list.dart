import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../domain/download_extra_resource.dart';
import '../../domain/download_task_phase.dart';
import '../../domain/stored_dash_options.dart';
import 'download_task_item.dart';

/// 当前筛选下的任务列表或空状态。
final class DownloadTaskList extends StatelessWidget {
  /// 回顶部按钮占用的 40dp 高度与 20dp 底部偏移之和。
  static const double _scrollToTopClearanceHeight = 60;

  /// 创建响应式任务列表。
  const DownloadTaskList({
    required this.tasks,
    required this.compact,
    required this.scrollController,
    required this.showScrollToTopClearance,
    required this.storageKey,
    required this.storagePath,
    required this.startingTaskIds,
    required this.togglingTaskIds,
    required this.pauseControlsDisabled,
    required this.onStart,
    required this.onTogglePause,
    required this.onDelete,
    required this.onSelectAudio,
    required this.onSelectVideo,
    required this.onClearAudio,
    required this.onClearVideo,
    required this.availableExtraResources,
    required this.onExtraResourcesChanged,
    super.key,
  });

  /// 当前筛选任务。
  final List<DownloadTaskRecord> tasks;

  /// 是否使用手机卡片。
  final bool compact;

  /// 当前任务页签独立持有的滚动控制器。
  final ScrollController scrollController;

  /// 桌面回顶部按钮显示时，是否在列表末尾追加避让空白。
  final bool showScrollToTopClearance;

  /// 当前任务页签在页面存储中的稳定标识。
  final PageStorageKey<String> storageKey;

  /// 系统文件管理器应打开的真实下载根目录。
  final String storagePath;

  /// 正在启动的任务 ID。
  final Set<String> startingTaskIds;

  /// 正在等待暂停或继续操作完整结束的任务 ID。
  final Set<String> togglingTaskIds;

  /// 批量暂停或继续运行时禁用行内按钮，但不显示单项 loading。
  final bool pauseControlsDisabled;

  /// 单项启动回调。
  final ValueChanged<DownloadTaskRecord> onStart;

  /// 暂停或恢复任务回调。
  final ValueChanged<DownloadTaskRecord> onTogglePause;

  /// 单项删除回调。
  final ValueChanged<DownloadTaskRecord> onDelete;

  /// 保存任务音频候选回调。
  final void Function(DownloadTaskRecord task, StoredAudioOption option)
  onSelectAudio;

  /// 保存任务视频候选回调。
  final void Function(DownloadTaskRecord task, StoredVideoOption option)
  onSelectVideo;

  /// 把任务音频选择设为无。
  final ValueChanged<DownloadTaskRecord> onClearAudio;

  /// 把任务视频选择设为无。
  final ValueChanged<DownloadTaskRecord> onClearVideo;

  /// 设置中心当前允许在卡片菜单展示的附加资源。
  final Set<DownloadExtraResource> availableExtraResources;

  /// 保存一条主任务最新附加资源复选集合。
  final void Function(
    DownloadTaskRecord task,
    Set<DownloadExtraResource> resources,
  )
  onExtraResourcesChanged;

  /// 构建列表、桌面表头或空状态。
  @override
  Widget build(BuildContext context) {
    // 空状态提供返回解析页操作。
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.download_done_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text('当前没有任务'),
            const SizedBox(height: 12),
            AppActionButton(
              variant: AppActionButtonVariant.filled,
              onPressed: () {
                // 返回解析页添加新任务。
                context.go('/parse');
              },
              icon: Icons.add_link_rounded,
              label: '去解析视频',
            ),
          ],
        ),
      );
    }
    // 列表体按平台布局并保留滚动。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ListView.separated(
            key: storageKey,
            controller: scrollController,
            itemCount: tasks.length + (showScrollToTopClearance ? 1 : 0),
            separatorBuilder: (BuildContext context, int index) {
              // 桌面和手机任务都使用独立卡片，卡片之间保留固定间距。
              return const SizedBox(height: 12);
            },
            itemBuilder: (BuildContext context, int index) {
              // 最后一项为空白避让区，防止悬浮回顶部按钮覆盖任务卡片操作。
              if (index == tasks.length) {
                return const SizedBox(height: _scrollToTopClearanceHeight);
              }
              // 当前任务快照用于构建对应行或卡片。
              final task = tasks[index];
              // 构建自适应任务项。
              final taskItem = DownloadTaskItem(
                task: task,
                compact: compact,
                storagePath: storagePath,
                starting: startingTaskIds.contains(task.taskId),
                togglingPause: togglingTaskIds.contains(task.taskId),
                pauseControlDisabled: pauseControlsDisabled,
                onStart: () => onStart(task),
                onTogglePause: () => onTogglePause(task),
                onDelete: () => onDelete(task),
                onSelectAudio: (StoredAudioOption option) =>
                    onSelectAudio(task, option),
                onSelectVideo: (StoredVideoOption option) =>
                    onSelectVideo(task, option),
                onClearAudio: () => onClearAudio(task),
                onClearVideo: () => onClearVideo(task),
                availableExtraResources: availableExtraResources,
                onExtraResourcesChanged:
                    (Set<DownloadExtraResource> resources) =>
                        onExtraResourcesChanged(task, resources),
                onOpenDetails: task.phase == DownloadTaskPhase.completed
                    ? () {
                        // 已下载任务详情使用独立路由，便于浏览器或深链直接定位。
                        context.push(
                          '/tasks/${Uri.encodeComponent(task.taskId)}',
                        );
                      }
                    : null,
              );
              return taskItem;
            },
          ),
        ),
      ],
    );
  }
}
