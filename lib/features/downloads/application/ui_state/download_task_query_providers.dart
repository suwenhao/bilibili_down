import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_providers.dart';
import '../../data/download_task_repository.dart';
import '../../domain/download_task_phase.dart';
import 'download_task_tab_controller.dart';

/// 任务中心三个一级筛选。
enum TaskFilter { pending, active, completed }

/// 共享按阶段聚合的任务数量，页签和导航角标只建立一条轻量 Drift 查询。
final downloadTaskPhaseCountsProvider =
    StreamProvider<Map<DownloadTaskPhase, int>>((Ref ref) {
      // 仓库查询只返回阶段与数量，不会把完整历史任务复制到导航组件。
      return ref.watch(downloadTaskRepositoryProvider).watchTaskPhaseCounts();
    });

/// 共享任务 ID 与阶段轻量快照，供任务页判断本轮下载是否全部完成。
final downloadTaskPhaseSnapshotsProvider =
    StreamProvider<List<DownloadTaskPhaseSnapshot>>((Ref ref) {
      // 查询不读取标题、封面和候选清单，频繁进度更新不会放大内存占用。
      return ref
          .watch(downloadTaskRepositoryProvider)
          .watchTaskPhaseSnapshots();
    });

/// 监听 Drift 中按更新时间排序的全部下载任务。
final downloadTaskListProvider = StreamProvider.autoDispose
    .family<List<DownloadTaskRecord>, ({TaskFilter filter, int? limit})>((
      Ref ref,
      ({TaskFilter filter, int? limit}) query,
    ) {
      // 当前页签只物化自己需要的完整任务，离开页签后自动释放 Drift 订阅。
      return ref
          .watch(downloadTaskRepositoryProvider)
          .watchTasksByPhases(
            taskPhasesForFilter(query.filter),
            limit: query.limit,
            sortOrder: switch (query.filter) {
              TaskFilter.pending ||
              TaskFilter.active => DownloadTaskSortOrder.oldestCreated,
              TaskFilter.completed => DownloadTaskSortOrder.newestCompleted,
            },
          );
    });

/// 把界面页签映射为数据库阶段集合，保持与原卡片筛选语义一致。
List<DownloadTaskPhase> taskPhasesForFilter(TaskFilter filter) {
  return switch (filter) {
    TaskFilter.pending => const <DownloadTaskPhase>[
      DownloadTaskPhase.queued,
      DownloadTaskPhase.failed,
    ],
    TaskFilter.active => const <DownloadTaskPhase>[
      DownloadTaskPhase.waitingToStart,
      DownloadTaskPhase.resolving,
      DownloadTaskPhase.downloading,
      DownloadTaskPhase.waitingForMerge,
      DownloadTaskPhase.merging,
      DownloadTaskPhase.paused,
    ],
    TaskFilter.completed => const <DownloadTaskPhase>[
      DownloadTaskPhase.completed,
    ],
  };
}

/// 把跨页面业务页签请求映射为任务页现有筛选枚举。
TaskFilter taskFilterForTab(DownloadTaskTab tab) {
  return switch (tab) {
    DownloadTaskTab.pending => TaskFilter.pending,
    DownloadTaskTab.active => TaskFilter.active,
    DownloadTaskTab.completed => TaskFilter.completed,
  };
}
