import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../application/lifecycle/automatic_shutdown_controller.dart';
import '../../application/ui_state/download_task_query_providers.dart';
import '../../domain/download_extra_resource.dart';
import '../../domain/stored_dash_options.dart';
import '../controllers/download_tasks_page_controller.dart';
import '../utils/download_task_page_utils.dart';
import 'download_task_tab_scaffold.dart';
import 'download_task_toolbars.dart';

/// 任务页三种页签的顶部页签、工具栏和列表容器。
final class DownloadTaskTabsSection extends ConsumerWidget {
  /// 创建任务页签区。
  const DownloadTaskTabsSection({
    required this.filter,
    required this.counts,
    required this.tasks,
    required this.compact,
    required this.usesNavigationRail,
    required this.tasksScrolledBeyondTop,
    required this.scrollController,
    required this.defaultStoragePath,
    required this.automaticShutdownPlan,
    required this.supportsAutomaticShutdown,
    required this.storageChangeEnabled,
    required this.availableExtraResources,
    required this.onFilterSelected,
    required this.onLoadMoreCompleted,
    super.key,
  });

  /// 当前选中的任务页签。
  final TaskFilter filter;

  /// 三个页签对应的任务总数。
  final Map<TaskFilter, int> counts;

  /// 当前页签经过页面过滤后的主任务列表。
  final List<DownloadTaskRecord> tasks;

  /// 是否使用手机卡片和紧凑工具栏。
  final bool compact;

  /// 当前外壳是否使用桌面导航栏。
  final bool usesNavigationRail;

  /// 桌面回顶部按钮显示时列表是否需要底部避让。
  final bool tasksScrolledBeyondTop;

  /// 当前页签持有的滚动控制器。
  final ScrollController scrollController;

  /// 设置中心当前下载根目录，未加载时为空。
  final String? defaultStoragePath;

  /// 当前进程内的一次性自动关机计划。
  final AutomaticShutdownPlan? automaticShutdownPlan;

  /// 当前平台是否允许展示自动关机入口。
  final bool supportsAutomaticShutdown;

  /// 当前平台是否允许修改下载根目录。
  final bool storageChangeEnabled;

  /// 设置中心当前允许展示的附加资源。
  final Set<DownloadExtraResource> availableExtraResources;

  /// 切换任务页签。
  final ValueChanged<TaskFilter> onFilterSelected;

  /// 扩大已下载历史加载窗口。
  final VoidCallback onLoadMoreCompleted;

  /// 构建顶部页签和当前页签内容。
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 页面级控制器集中提供启动、暂停、删除等动作和 busy 状态。
    final controllerState = ref.watch(downloadTasksPageControllerProvider);
    // 点击回调读取 notifier，不让状态更新触发闭包重新创建业务对象。
    final controller = ref.read(downloadTasksPageControllerProvider.notifier);
    // 三个页签共用同一套列表操作回调，只有顶部工具栏随页签切换。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TaskFilterTabs(
          compact: compact,
          selected: filter,
          counts: counts,
          onSelected: onFilterSelected,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: switch (filter) {
            TaskFilter.pending => PendingDownloadTasksTab(
              tasks: tasks,
              compact: compact,
              usesNavigationRail: usesNavigationRail,
              tasksScrolledBeyondTop: tasksScrolledBeyondTop,
              scrollController: scrollController,
              defaultStoragePath: defaultStoragePath,
              starting:
                  controllerState.startingAll ||
                  controllerState.startingTaskIds.isNotEmpty,
              startingTaskIds: controllerState.startingTaskIds,
              togglingTaskIds: controllerState.togglingTaskIds,
              pauseControlsDisabled: controllerState.togglingActiveTasks,
              availableExtraResources: availableExtraResources,
              onChangeStorage: storageChangeEnabled
                  ? () => controller.changeStorage(context)
                  : null,
              onCustomBatch: (List<DownloadTaskRecord> sourceTasks) {
                // 自定义批量直接复用当前待下载主任务快照。
                controller.startCustomBatch(context, sourceTasks);
              },
              onStartAll: (List<DownloadTaskRecord> startTasks) {
                // 批量启动只处理当前可见待下载任务。
                controller.startAll(context, startTasks);
              },
              onClearQueued: () => controller.clearQueuedTasks(context),
              onStart: (DownloadTaskRecord task) =>
                  controller.startTask(context, task),
              onTogglePause: (DownloadTaskRecord task) =>
                  controller.toggleTaskPause(context, task),
              onDelete: (DownloadTaskRecord task) =>
                  controller.deleteTaskRecord(context, task),
              onSelectAudio:
                  (DownloadTaskRecord task, StoredAudioOption option) =>
                      controller.selectAudioQuality(context, task, option),
              onSelectVideo:
                  (DownloadTaskRecord task, StoredVideoOption option) =>
                      controller.selectVideoQuality(context, task, option),
              onClearAudio: (DownloadTaskRecord task) =>
                  controller.clearAudioQuality(context, task),
              onClearVideo: (DownloadTaskRecord task) =>
                  controller.clearVideoQuality(context, task),
              onExtraResourcesChanged:
                  (
                    DownloadTaskRecord task,
                    Set<DownloadExtraResource> resources,
                  ) =>
                      controller.updateExtraResources(context, task, resources),
            ),
            TaskFilter.active => ActiveDownloadTasksTab(
              tasks: tasks,
              compact: compact,
              usesNavigationRail: usesNavigationRail,
              tasksScrolledBeyondTop: tasksScrolledBeyondTop,
              scrollController: scrollController,
              defaultStoragePath: defaultStoragePath,
              togglingActiveTasks: controllerState.togglingActiveTasks,
              clearingActiveTasks: controllerState.clearingActiveTasks,
              startingTaskIds: controllerState.startingTaskIds,
              togglingTaskIds: controllerState.togglingTaskIds,
              automaticShutdownPlan: automaticShutdownPlan,
              supportsAutomaticShutdown: supportsAutomaticShutdown,
              availableExtraResources: availableExtraResources,
              onToggleAllActive: (List<DownloadTaskRecord> activeTasks) {
                // 批量暂停或继续只处理子组件筛出的可切换任务。
                controller.toggleAllActiveTasks(context, activeTasks);
              },
              onClearActive: (List<DownloadTaskRecord> activeTasks) {
                // 清空下载中任务使用当前列表快照。
                controller.clearActiveTasks(context, activeTasks);
              },
              onConfigureAutomaticShutdown:
                  (List<DownloadTaskRecord> activeTasks) {
                    // 自动关机计划绑定用户点击时的下载中任务集合。
                    controller.configureAutomaticShutdown(context, activeTasks);
                  },
              onDisableAutomaticShutdown: () =>
                  controller.disableAutomaticShutdown(context),
              onStart: (DownloadTaskRecord task) =>
                  controller.startTask(context, task),
              onTogglePause: (DownloadTaskRecord task) =>
                  controller.toggleTaskPause(context, task),
              onDelete: (DownloadTaskRecord task) =>
                  controller.deleteTaskRecord(context, task),
              onSelectAudio:
                  (DownloadTaskRecord task, StoredAudioOption option) =>
                      controller.selectAudioQuality(context, task, option),
              onSelectVideo:
                  (DownloadTaskRecord task, StoredVideoOption option) =>
                      controller.selectVideoQuality(context, task, option),
              onClearAudio: (DownloadTaskRecord task) =>
                  controller.clearAudioQuality(context, task),
              onClearVideo: (DownloadTaskRecord task) =>
                  controller.clearVideoQuality(context, task),
              onExtraResourcesChanged:
                  (
                    DownloadTaskRecord task,
                    Set<DownloadExtraResource> resources,
                  ) =>
                      controller.updateExtraResources(context, task, resources),
            ),
            TaskFilter.completed => CompletedDownloadTasksTab(
              tasks: tasks,
              compact: compact,
              usesNavigationRail: usesNavigationRail,
              tasksScrolledBeyondTop: tasksScrolledBeyondTop,
              scrollController: scrollController,
              defaultStoragePath: defaultStoragePath,
              totalCount: counts[TaskFilter.completed] ?? 0,
              clearing: controllerState.clearingCompletedTasks,
              processed: controllerState.completedDeletionProcessed,
              total: controllerState.completedDeletionTotal,
              startingTaskIds: controllerState.startingTaskIds,
              togglingTaskIds: controllerState.togglingTaskIds,
              pauseControlsDisabled: controllerState.togglingActiveTasks,
              availableExtraResources: availableExtraResources,
              onClearCompleted: (int totalCount) {
                // 已下载清空弹窗使用数据库聚合总数展示影响范围。
                controller.clearCompletedTasks(context, totalCount);
              },
              onLoadMoreCompleted: onLoadMoreCompleted,
              onStart: (DownloadTaskRecord task) =>
                  controller.startTask(context, task),
              onTogglePause: (DownloadTaskRecord task) =>
                  controller.toggleTaskPause(context, task),
              onDelete: (DownloadTaskRecord task) =>
                  controller.deleteTaskRecord(context, task),
              onSelectAudio:
                  (DownloadTaskRecord task, StoredAudioOption option) =>
                      controller.selectAudioQuality(context, task, option),
              onSelectVideo:
                  (DownloadTaskRecord task, StoredVideoOption option) =>
                      controller.selectVideoQuality(context, task, option),
              onClearAudio: (DownloadTaskRecord task) =>
                  controller.clearAudioQuality(context, task),
              onClearVideo: (DownloadTaskRecord task) =>
                  controller.clearVideoQuality(context, task),
              onExtraResourcesChanged:
                  (
                    DownloadTaskRecord task,
                    Set<DownloadExtraResource> resources,
                  ) =>
                      controller.updateExtraResources(context, task, resources),
            ),
          },
        ),
      ],
    );
  }
}

/// 待下载页签内容。
final class PendingDownloadTasksTab extends StatelessWidget {
  /// 创建待下载工具栏和列表。
  const PendingDownloadTasksTab({
    required this.tasks,
    required this.compact,
    required this.usesNavigationRail,
    required this.tasksScrolledBeyondTop,
    required this.scrollController,
    required this.defaultStoragePath,
    required this.starting,
    required this.startingTaskIds,
    required this.togglingTaskIds,
    required this.pauseControlsDisabled,
    required this.availableExtraResources,
    required this.onChangeStorage,
    required this.onCustomBatch,
    required this.onStartAll,
    required this.onClearQueued,
    required this.onStart,
    required this.onTogglePause,
    required this.onDelete,
    required this.onSelectAudio,
    required this.onSelectVideo,
    required this.onClearAudio,
    required this.onClearVideo,
    required this.onExtraResourcesChanged,
    super.key,
  });

  /// 当前待下载主任务。
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

  /// 是否正在批量启动。
  final bool starting;

  /// 正在启动的单项任务 ID。
  final Set<String> startingTaskIds;

  /// 正在切换暂停或继续状态的单项任务 ID。
  final Set<String> togglingTaskIds;

  /// 批量暂停或继续运行时是否禁用行内按钮。
  final bool pauseControlsDisabled;

  /// 设置中心当前允许展示的附加资源。
  final Set<DownloadExtraResource> availableExtraResources;

  /// 修改待下载任务根目录。
  final VoidCallback? onChangeStorage;

  /// 使用当前任务创建自定义批量。
  final ValueChanged<List<DownloadTaskRecord>> onCustomBatch;

  /// 启动当前待下载任务。
  final ValueChanged<List<DownloadTaskRecord>> onStartAll;

  /// 清空当前待下载排队任务。
  final VoidCallback? onClearQueued;

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

  /// 构建待下载工具栏和任务列表。
  @override
  Widget build(BuildContext context) {
    // 待下载页只面向主视频任务，自定义批量不处理独立资源。
    final sourceTasks = visiblePrimaryDownloadTasks(tasks);
    return DownloadTaskTabScaffold(
      toolbar: PendingToolbar(
        mobile: compact,
        storagePath: toolbarStoragePath(tasks, defaultStoragePath),
        starting: starting,
        onChangeStorage: onChangeStorage,
        onCustomBatch: sourceTasks.isEmpty
            ? null
            : () => onCustomBatch(sourceTasks),
        onStart: tasks.isEmpty || startingTaskIds.isNotEmpty
            ? null
            : () => onStartAll(tasks),
        onClear: hasQueuedDownloadTask(tasks) ? onClearQueued : null,
      ),
      filter: TaskFilter.pending,
      tasks: tasks,
      compact: compact,
      usesNavigationRail: usesNavigationRail,
      tasksScrolledBeyondTop: tasksScrolledBeyondTop,
      scrollController: scrollController,
      defaultStoragePath: defaultStoragePath,
      startingTaskIds: startingTaskIds,
      togglingTaskIds: togglingTaskIds,
      pauseControlsDisabled: pauseControlsDisabled,
      availableExtraResources: availableExtraResources,
      onStart: onStart,
      onTogglePause: onTogglePause,
      onDelete: onDelete,
      onSelectAudio: onSelectAudio,
      onSelectVideo: onSelectVideo,
      onClearAudio: onClearAudio,
      onClearVideo: onClearVideo,
      onExtraResourcesChanged: onExtraResourcesChanged,
    );
  }
}

/// 下载中页签内容。
final class ActiveDownloadTasksTab extends StatelessWidget {
  /// 创建下载中工具栏和列表。
  const ActiveDownloadTasksTab({
    required this.tasks,
    required this.compact,
    required this.usesNavigationRail,
    required this.tasksScrolledBeyondTop,
    required this.scrollController,
    required this.defaultStoragePath,
    required this.togglingActiveTasks,
    required this.clearingActiveTasks,
    required this.startingTaskIds,
    required this.togglingTaskIds,
    required this.automaticShutdownPlan,
    required this.supportsAutomaticShutdown,
    required this.availableExtraResources,
    required this.onToggleAllActive,
    required this.onClearActive,
    required this.onConfigureAutomaticShutdown,
    required this.onDisableAutomaticShutdown,
    required this.onStart,
    required this.onTogglePause,
    required this.onDelete,
    required this.onSelectAudio,
    required this.onSelectVideo,
    required this.onClearAudio,
    required this.onClearVideo,
    required this.onExtraResourcesChanged,
    super.key,
  });

  /// 当前下载中主任务。
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

  /// 是否正在批量暂停或继续。
  final bool togglingActiveTasks;

  /// 是否正在批量清空。
  final bool clearingActiveTasks;

  /// 正在启动的单项任务 ID。
  final Set<String> startingTaskIds;

  /// 正在切换暂停或继续状态的单项任务 ID。
  final Set<String> togglingTaskIds;

  /// 当前进程内的一次性自动关机计划。
  final AutomaticShutdownPlan? automaticShutdownPlan;

  /// 当前平台是否允许展示自动关机入口。
  final bool supportsAutomaticShutdown;

  /// 设置中心当前允许展示的附加资源。
  final Set<DownloadExtraResource> availableExtraResources;

  /// 批量暂停或继续下载中任务。
  final ValueChanged<List<DownloadTaskRecord>> onToggleAllActive;

  /// 清空当前下载中任务。
  final ValueChanged<List<DownloadTaskRecord>> onClearActive;

  /// 为当前下载中任务创建自动关机计划。
  final ValueChanged<List<DownloadTaskRecord>> onConfigureAutomaticShutdown;

  /// 解除当前自动关机计划。
  final VoidCallback onDisableAutomaticShutdown;

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

  /// 构建下载中工具栏和任务列表。
  @override
  Widget build(BuildContext context) {
    // 合并和解析阶段不提供暂停入口，批量操作只处理可切换任务。
    final toggleableTasks = toggleableDownloadTasks(tasks);
    return DownloadTaskTabScaffold(
      toolbar: ActiveToolbar(
        mobile: compact,
        allPaused: allToggleableTasksPaused(toggleableTasks),
        showToggle: toggleableTasks.isNotEmpty,
        toggling: togglingActiveTasks,
        clearing: clearingActiveTasks,
        automaticShutdownLabel: automaticShutdownPlan == null
            ? '自动关机'
            : '${automaticShutdownPlan!.delay.inMinutes}分钟后关机',
        automaticShutdownArmed: automaticShutdownPlan != null,
        showAutomaticShutdown: supportsAutomaticShutdown,
        onToggle: toggleableTasks.isEmpty
            ? null
            : () => onToggleAllActive(toggleableTasks),
        onClear: tasks.isEmpty ? null : () => onClearActive(tasks),
        onAutomaticShutdown: _automaticShutdownAction(
          tasks: tasks,
          automaticShutdownPlan: automaticShutdownPlan,
          onDisableAutomaticShutdown: onDisableAutomaticShutdown,
          onConfigureAutomaticShutdown: onConfigureAutomaticShutdown,
        ),
      ),
      filter: TaskFilter.active,
      tasks: tasks,
      compact: compact,
      usesNavigationRail: usesNavigationRail,
      tasksScrolledBeyondTop: tasksScrolledBeyondTop,
      scrollController: scrollController,
      defaultStoragePath: defaultStoragePath,
      startingTaskIds: startingTaskIds,
      togglingTaskIds: togglingTaskIds,
      pauseControlsDisabled: togglingActiveTasks,
      availableExtraResources: availableExtraResources,
      onStart: onStart,
      onTogglePause: onTogglePause,
      onDelete: onDelete,
      onSelectAudio: onSelectAudio,
      onSelectVideo: onSelectVideo,
      onClearAudio: onClearAudio,
      onClearVideo: onClearVideo,
      onExtraResourcesChanged: onExtraResourcesChanged,
    );
  }

  /// 返回自动关机按钮当前应执行的动作。
  VoidCallback? _automaticShutdownAction({
    required List<DownloadTaskRecord> tasks,
    required AutomaticShutdownPlan? automaticShutdownPlan,
    required VoidCallback onDisableAutomaticShutdown,
    required ValueChanged<List<DownloadTaskRecord>>
    onConfigureAutomaticShutdown,
  }) {
    // 已配置时按钮语义为取消自动关机。
    if (automaticShutdownPlan != null) return onDisableAutomaticShutdown;
    // 有运行任务时才允许配置自动关机。
    if (hasRunningTaskForShutdown(tasks)) {
      return () => onConfigureAutomaticShutdown(tasks);
    }
    // 无运行任务时禁用入口。
    return null;
  }
}

/// 已下载页签内容。
final class CompletedDownloadTasksTab extends StatelessWidget {
  /// 创建已下载工具栏和列表。
  const CompletedDownloadTasksTab({
    required this.tasks,
    required this.compact,
    required this.usesNavigationRail,
    required this.tasksScrolledBeyondTop,
    required this.scrollController,
    required this.defaultStoragePath,
    required this.totalCount,
    required this.clearing,
    required this.processed,
    required this.total,
    required this.startingTaskIds,
    required this.togglingTaskIds,
    required this.pauseControlsDisabled,
    required this.availableExtraResources,
    required this.onClearCompleted,
    required this.onLoadMoreCompleted,
    required this.onStart,
    required this.onTogglePause,
    required this.onDelete,
    required this.onSelectAudio,
    required this.onSelectVideo,
    required this.onClearAudio,
    required this.onClearVideo,
    required this.onExtraResourcesChanged,
    super.key,
  });

  /// 当前已下载主任务。
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

  /// 已下载页签数据库总数。
  final int totalCount;

  /// 是否正在批量清空。
  final bool clearing;

  /// 已下载页清理进度中的已处理任务数量。
  final int processed;

  /// 已下载页清理进度中的总任务数量。
  final int total;

  /// 正在启动的单项任务 ID。
  final Set<String> startingTaskIds;

  /// 正在切换暂停或继续状态的单项任务 ID。
  final Set<String> togglingTaskIds;

  /// 批量暂停或继续运行时是否禁用行内按钮。
  final bool pauseControlsDisabled;

  /// 设置中心当前允许展示的附加资源。
  final Set<DownloadExtraResource> availableExtraResources;

  /// 清空当前已下载任务。
  final ValueChanged<int> onClearCompleted;

  /// 扩大已下载历史加载窗口。
  final VoidCallback onLoadMoreCompleted;

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

  /// 构建已下载工具栏和任务列表。
  @override
  Widget build(BuildContext context) {
    return DownloadTaskTabScaffold(
      toolbar: CompletedToolbar(
        mobile: compact,
        clearing: clearing,
        processed: processed,
        total: total,
        onClear: tasks.isEmpty ? null : () => onClearCompleted(totalCount),
      ),
      filter: TaskFilter.completed,
      tasks: tasks,
      compact: compact,
      usesNavigationRail: usesNavigationRail,
      tasksScrolledBeyondTop: tasksScrolledBeyondTop,
      scrollController: scrollController,
      defaultStoragePath: defaultStoragePath,
      startingTaskIds: startingTaskIds,
      togglingTaskIds: togglingTaskIds,
      pauseControlsDisabled: pauseControlsDisabled,
      availableExtraResources: availableExtraResources,
      hasMore: hasMoreCompletedTasks(
        filter: TaskFilter.completed,
        visibleCount: tasks.length,
        totalCount: totalCount,
      ),
      onLoadMore: onLoadMoreCompleted,
      onStart: onStart,
      onTogglePause: onTogglePause,
      onDelete: onDelete,
      onSelectAudio: onSelectAudio,
      onSelectVideo: onSelectVideo,
      onClearAudio: onClearAudio,
      onClearVideo: onClearVideo,
      onExtraResourcesChanged: onExtraResourcesChanged,
    );
  }
}
