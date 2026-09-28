import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../settings/application/app_settings_controller.dart';
import '../application/lifecycle/automatic_shutdown_controller.dart';
import '../application/queue/download_queue_policy.dart';
import '../application/ui_state/download_task_query_providers.dart';
import '../application/ui_state/download_task_tab_controller.dart';
import '../application/ui_state/download_tasks_scroll_controller.dart';
import '../data/download_task_repository.dart';
import 'controllers/download_tasks_page_controller.dart';
import 'utils/download_task_page_utils.dart';
import 'widgets/download_task_tab_content.dart';

/// 展示待下载、下载中和已下载任务的 v2 响应式页面。
final class DownloadTasksPage extends ConsumerStatefulWidget {
  /// 创建任务中心。
  const DownloadTasksPage({super.key});

  /// 创建本地页签和批量选择状态。
  @override
  ConsumerState<DownloadTasksPage> createState() => _DownloadTasksPageState();
}

/// 管理任务页筛选和下载操作。
final class _DownloadTasksPageState extends ConsumerState<DownloadTasksPage> {
  /// 已下载历史首次只加载一百条，用户明确请求时再按页扩大窗口。
  static const int _completedPageSize = 100;

  /// 默认展示待下载任务。
  TaskFilter _filter = TaskFilter.pending;

  /// 三个任务页签各自持有滚动控制器，切换时互不覆盖滚动位置。
  late final Map<TaskFilter, ScrollController> _scrollControllers;

  /// 外部页面重复请求同一任务页签时仍能触发的 Riverpod 订阅。
  late final ProviderSubscription<DownloadTaskTabRequest>
  _tabRequestSubscription;

  /// 监听任务 ID 与阶段轻量快照，用于判断本轮下载是否全部完成。
  late final ProviderSubscription<AsyncValue<List<DownloadTaskPhaseSnapshot>>>
  _phaseSnapshotSubscription;

  /// 当前一轮需要全部完成后才自动跳转的主任务 ID。
  final Set<String> _completionWatchTaskIds = <String>{};

  /// 当前允许物化的已下载历史数量，其他页签不使用该上限。
  int _completedTaskLimit = _completedPageSize;

  /// 初始化保留页签状态所需的外部请求和任务阶段监听。
  @override
  void initState() {
    super.initState();
    // 每个任务页签建立独立控制器，用于保留位置并在重新挂载时恢复回顶状态。
    _scrollControllers = <TaskFilter, ScrollController>{
      for (final filter in TaskFilter.values)
        filter: _createTaskScrollController(filter),
    };
    // 页面首次创建时读取最近一次外部请求，解析页先发请求再跳转也不会丢失。
    final initialRequest = ref.read(downloadTaskTabControllerProvider);
    _filter = taskFilterForTab(initialRequest.tab);
    // IndexedStack 隐藏页面仍保持监听，重复进入任务分支时能够切换到明确页签。
    _tabRequestSubscription = ref.listenManual<DownloadTaskTabRequest>(
      downloadTaskTabControllerProvider,
      (DownloadTaskTabRequest? previous, DownloadTaskTabRequest next) {
        // 页面销毁后不再响应导航请求。
        if (!mounted) return;
        final nextFilter = taskFilterForTab(next.tab);
        // 相同页签无需重建列表，但请求序号仍已由控制器消费。
        if (_filter == nextFilter) return;
        _selectFilter(nextFilter);
      },
    );
    // 阶段快照只含任务 ID 和阶段，不会为自动跳转加载完整历史任务。
    _phaseSnapshotSubscription = ref
        .listenManual<AsyncValue<List<DownloadTaskPhaseSnapshot>>>(
          downloadTaskPhaseSnapshotsProvider,
          (
            AsyncValue<List<DownloadTaskPhaseSnapshot>>? previous,
            AsyncValue<List<DownloadTaskPhaseSnapshot>> next,
          ) {
            // 加载和错误状态不改变当前页签，等待下一份有效数据库快照。
            final snapshots = next.value;
            if (snapshots == null) return;
            _handleTrackedTaskPhases(snapshots);
          },
        );
  }

  /// 释放手动 Riverpod 订阅，避免页面真正销毁后继续接收回调。
  @override
  void dispose() {
    _tabRequestSubscription.close();
    _phaseSnapshotSubscription.close();
    // 控制器保存各页签位置并持有监听器，页面销毁时统一释放。
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// 返回当前任务页签的滚动控制器。
  ScrollController get _activeScrollController => _scrollControllers[_filter]!;

  /// 创建指定页签的滚动控制器，并在列表重新挂载后恢复该页签的回顶状态。
  ScrollController _createTaskScrollController(TaskFilter filter) {
    // 切换页签时任务流可能短暂进入加载态，必须等新列表真正挂载后再读取恢复位置。
    late final ScrollController controller;
    controller = ScrollController(
      onAttach: (ScrollPosition position) {
        // PageStorage 会在挂载阶段恢复滚动位置，延后一帧读取才能得到最终偏移。
        _scheduleTaskScrollFlagSync(filter: filter);
      },
    );
    // 监听器携带所属页签，非当前页签不能污染 Shell 的回顶状态。
    controller.addListener(() => _handleTaskScroll(filter));
    return controller;
  }

  /// 切换任务页签并在布局完成后同步该页签的回顶状态。
  void _selectFilter(TaskFilter filter) {
    // 相同页签不重建列表，但仍同步现有滚动状态。
    if (_filter == filter) {
      _scheduleTaskScrollFlagSync(filter: filter);
      return;
    }
    setState(() => _filter = filter);
    _scheduleTaskScrollFlagSync(filter: filter);
  }

  /// 处理指定任务页签的滚动，只允许当前页签更新 Shell。
  void _handleTaskScroll(TaskFilter filter) {
    // 非当前页签的控制器仍保留位置，但不能改变当前导航状态。
    if (filter != _filter) return;
    _syncTaskScrollFlag(_scrollControllers[filter]!);
  }

  /// 同步当前列表是否超过回顶部阈值。
  void _syncTaskScrollFlag(ScrollController controller) {
    // 空列表没有挂载滚动位置，必须明确清除旧页签遗留的回顶状态。
    final beyondTop = controller.hasClients && controller.offset > 300;
    ref
        .read(downloadTasksScrolledBeyondTopProvider.notifier)
        .setBeyondTop(beyondTop);
  }

  /// 等待页签列表挂载完成后同步当前滚动位置。
  void _scheduleTaskScrollFlagSync({required TaskFilter filter}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 快速连续切换页签时，旧页签延迟回调不能覆盖当前页签状态。
      if (!mounted || _filter != filter) return;
      _syncTaskScrollFlag(_scrollControllers[filter]!);
    });
  }

  /// 响应 Shell 的回顶部请求，滚动当前任务页签而不影响另外两个页签。
  void _scrollCurrentTaskToTop() {
    final controller = _activeScrollController;
    // 空任务列表没有可滚动位置，直接清理导航状态。
    if (!controller.hasClients) {
      _syncTaskScrollFlag(controller);
      return;
    }
    controller
        .animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        )
        .then((_) {
          if (!mounted) return;
          _syncTaskScrollFlag(controller);
        });
  }

  /// 切到下载中页签，并记录本轮需要全部完成的任务集合。
  void _showActiveAndTrack(
    Iterable<String> taskIds, {
    required bool trackSubmittedTasks,
  }) {
    // 当前数据库快照用于同时纳入此前仍在运行的任务，不能只跟踪最新点击的一批。
    final snapshots = ref.read(downloadTaskPhaseSnapshotsProvider).value;
    final activePhases = taskPhasesForFilter(TaskFilter.active).toSet();
    _completionWatchTaskIds
      ..clear()
      ..addAll(
        snapshots
                ?.where(
                  (DownloadTaskPhaseSnapshot snapshot) =>
                      activePhases.contains(snapshot.phase),
                )
                .map((DownloadTaskPhaseSnapshot snapshot) => snapshot.taskId) ??
            const <String>[],
      );
    // 批量事务全部成功时纳入提交 ID；部分成功无法可靠映射具体 ID，等待下一次显式操作。
    if (trackSubmittedTasks) _completionWatchTaskIds.addAll(taskIds);
    // 成功提交后立即展示下载中，用户无需再手动切换页签。
    if (mounted) _selectFilter(TaskFilter.active);
    // 极短任务可能在提交返回前已经完成，立即用现有快照补做一次判断。
    if (snapshots != null) _handleTrackedTaskPhases(snapshots);
  }

  /// 本轮全部任务成功完成时请求切换到已下载页签。
  void _handleTrackedTaskPhases(List<DownloadTaskPhaseSnapshot> snapshots) {
    // 暂停、失败、取消、缺失或仍在运行时保持当前页签，不伪造“全部完成”。
    if (!areTrackedDownloadTasksCompleted(
      taskIds: _completionWatchTaskIds,
      snapshots: snapshots,
    )) {
      return;
    }
    // 清空本轮集合，后续无关数据库更新不能重复抢占用户手动选择的页签。
    _completionWatchTaskIds.clear();
    // 使用统一请求通道更新保留页面和最近页签状态。
    ref
        .read(downloadTaskTabControllerProvider.notifier)
        .select(DownloadTaskTab.completed);
  }

  /// 构建与 v2 设计稿一致的桌面表格和手机卡片布局。
  @override
  Widget build(BuildContext context) {
    // Shell 发出请求后，只让当前任务页签回到顶部。
    ref.listen<int>(downloadTasksScrollTopRequestProvider, (
      int? previous,
      int next,
    ) {
      if (previous == next) return;
      _scrollCurrentTaskToTop();
    });
    // 控制器提交任务后，由页面保留的页签和完成跟踪逻辑统一处理跳转。
    ref.listen<DownloadTasksSubmittedBatch?>(
      downloadTasksPageControllerProvider.select(
        (DownloadTasksPageState state) => state.submittedBatch,
      ),
      (
        DownloadTasksSubmittedBatch? previous,
        DownloadTasksSubmittedBatch? next,
      ) {
        // 相同事件对象无需重复处理，空状态也没有业务含义。
        if (next == null || previous?.revision == next.revision) return;
        _showActiveAndTrack(
          next.taskIds,
          trackSubmittedTasks: next.trackSubmittedTasks,
        );
      },
    );
    // 监听数据库任务流，下载阶段和进度会实时刷新界面。
    final tasksValue = ref.watch(
      downloadTaskListProvider((
        filter: _filter,
        limit: _filter == TaskFilter.completed ? _completedTaskLimit : null,
      )),
    );
    // 页签数量使用共享聚合查询，避免为了三个数字加载全部历史任务。
    final phaseCounts = ref.watch(downloadTaskPhaseCountsProvider).value;
    // 读取设置中心当前实际下载目录，空列表也能展示真实路径。
    final defaultStoragePath = ref
        .watch(effectiveDownloadDirectoryProvider)
        .value;
    // 自动关机计划只存在于当前进程，并且只能由本页下载中列表创建。
    final automaticShutdownPlan = ref.watch(automaticShutdownPlanProvider);
    // 卡片“更多”只展示设置中心已启用的资源，未启用项不能在任务页重新出现。
    final availableExtraResources = automaticExtraResources(
      ref.watch(appSettingsControllerProvider).downloadContents,
    );
    // 移动端系统不允许第三方应用关机，因此任务栏不展示无效入口。
    final supportsAutomaticShutdown =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    // Shell 的桌面回顶部按钮显示时，任务列表需要同步预留底部操作空间。
    final tasksScrolledBeyondTop = ref.watch(
      downloadTasksScrolledBeyondTopProvider,
    );
    // 根据页面可用宽度切换桌面和手机信息密度。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 导航栏形态由应用总宽度决定，任务列表必须与外壳使用相同断点。
        final usesNavigationRail =
            MediaQuery.sizeOf(context).width >= AppBreakpoints.navigationRail;
        // 只有底部导航形态使用手机卡片，显示侧栏时始终使用桌面长条列表。
        final useMobileCards = !usesNavigationRail;
        // 页面主体保持最大宽度，超宽桌面不拉散任务信息。
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  tasksValue.when(
                    data: (List<DownloadTaskRecord> tasks) {
                      // 把数据库阶段计数汇总为三个产品页签数量。
                      final counts = taskFilterCounts(phaseCounts);
                      // 旧版独立资源记录不再展示；新模型只保留一条主任务记录。
                      final visibleTasks = visiblePrimaryDownloadTasks(tasks);
                      // 当前页签清空后列表会解除控制器挂载，下一帧主动清除旧的回顶状态。
                      if (visibleTasks.isEmpty) {
                        _scheduleTaskScrollFlagSync(filter: _filter);
                      }
                      // 页面先展示下划线页签，再按当前页签组织内容。
                      return Expanded(
                        child: DownloadTaskTabsSection(
                          filter: _filter,
                          counts: counts,
                          tasks: visibleTasks,
                          compact: useMobileCards,
                          usesNavigationRail: usesNavigationRail,
                          tasksScrolledBeyondTop: tasksScrolledBeyondTop,
                          scrollController: _activeScrollController,
                          defaultStoragePath: defaultStoragePath,
                          automaticShutdownPlan: automaticShutdownPlan,
                          supportsAutomaticShutdown: supportsAutomaticShutdown,
                          storageChangeEnabled: !Platform.isIOS,
                          availableExtraResources: availableExtraResources,
                          onFilterSelected: (TaskFilter filter) {
                            // 页签切换只改变视图，不修改数据库任务。
                            _selectFilter(filter);
                          },
                          onLoadMoreCompleted: () {
                            // 每次只扩大一页，避免一次点击重新加载全部历史。
                            setState(
                              () => _completedTaskLimit += _completedPageSize,
                            );
                          },
                        ),
                      );
                    },
                    loading: () {
                      // 数据库首次查询期间显示居中进度。
                      return const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    error: (Object error, StackTrace stackTrace) {
                      // 数据库错误显示明确文本，不让页面保持空白。
                      return Expanded(
                        child: Center(child: Text('任务读取失败：$error')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
