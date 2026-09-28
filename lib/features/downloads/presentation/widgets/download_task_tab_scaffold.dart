import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/app_list_footer.dart';
import '../../application/ui_state/download_task_query_providers.dart';
import '../../domain/download_extra_resource.dart';
import '../../domain/stored_dash_options.dart';
import '../utils/download_task_page_utils.dart';
import 'download_task_list.dart';

/// 三个页签共用的工具栏下方列表区。
final class DownloadTaskTabScaffold extends StatelessWidget {
  /// 创建工具栏和列表组合。
  const DownloadTaskTabScaffold({
    required this.toolbar,
    required this.filter,
    required this.tasks,
    required this.compact,
    required this.usesNavigationRail,
    required this.tasksScrolledBeyondTop,
    required this.scrollController,
    required this.defaultStoragePath,
    required this.startingTaskIds,
    required this.togglingTaskIds,
    required this.pauseControlsDisabled,
    required this.availableExtraResources,
    required this.onStart,
    required this.onTogglePause,
    required this.onDelete,
    required this.onSelectAudio,
    required this.onSelectVideo,
    required this.onClearAudio,
    required this.onClearVideo,
    required this.onExtraResourcesChanged,
    this.hasMore = false,
    this.onLoadMore,
    super.key,
  });

  /// 当前页签顶部工具栏。
  final Widget toolbar;

  /// 当前页签，用于生成列表 PageStorageKey。
  final TaskFilter filter;

  /// 当前页签任务。
  final List<DownloadTaskRecord> tasks;

  /// 是否使用手机布局。
  final bool compact;

  /// 当前外壳是否使用桌面导航栏。
  final bool usesNavigationRail;

  /// 桌面回顶部按钮显示时列表是否需要底部避让。
  final bool tasksScrolledBeyondTop;

  /// 当前列表滚动控制器。
  final ScrollController scrollController;

  /// 设置中心当前下载根目录，未加载时为空。
  final String? defaultStoragePath;

  /// 正在启动的单项任务 ID。
  final Set<String> startingTaskIds;

  /// 正在切换暂停或继续状态的单项任务 ID。
  final Set<String> togglingTaskIds;

  /// 批量暂停或继续运行时是否禁用行内按钮。
  final bool pauseControlsDisabled;

  /// 设置中心当前允许展示的附加资源。
  final Set<DownloadExtraResource> availableExtraResources;

  /// 是否展示加载更多。
  final bool hasMore;

  /// 加载更多回调。
  final VoidCallback? onLoadMore;

  /// 单项启动回调。
  final ValueChanged<DownloadTaskRecord> onStart;

  /// 单项暂停或继续回调。
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

  /// 保存一条主任务最新附加资源复选集合。
  final void Function(
    DownloadTaskRecord task,
    Set<DownloadExtraResource> resources,
  )
  onExtraResourcesChanged;

  /// 构建工具栏、任务列表和可选加载更多入口。
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        toolbar,
        const SizedBox(height: 14),
        Expanded(
          child: Column(
            children: <Widget>[
              Expanded(
                child: DownloadTaskList(
                  tasks: tasks,
                  compact: compact,
                  scrollController: scrollController,
                  showScrollToTopClearance:
                      usesNavigationRail && tasksScrolledBeyondTop,
                  storageKey: PageStorageKey<String>(
                    'download-task-list-${filter.name}',
                  ),
                  storagePath: taskListStoragePath(defaultStoragePath),
                  startingTaskIds: startingTaskIds,
                  togglingTaskIds: togglingTaskIds,
                  pauseControlsDisabled: pauseControlsDisabled,
                  onStart: onStart,
                  onTogglePause: onTogglePause,
                  onDelete: onDelete,
                  onSelectAudio: onSelectAudio,
                  onSelectVideo: onSelectVideo,
                  onClearAudio: onClearAudio,
                  onClearVideo: onClearVideo,
                  availableExtraResources: availableExtraResources,
                  onExtraResourcesChanged: onExtraResourcesChanged,
                ),
              ),
              if (hasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: AppListFooter.action(
                    label: '加载更多',
                    icon: Icons.expand_more_rounded,
                    onPressed: onLoadMore,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
