import 'package:path/path.dart' as p;

import '../../../../core/database/app_database.dart';
import '../../../../core/platform/default_download_directory.dart';
import '../../application/ui_state/download_task_query_providers.dart';
import '../../domain/download_extra_resource.dart';
import '../../domain/download_task_phase.dart';

/// 把数据库阶段计数汇总为任务中心三个产品页签数量。
Map<TaskFilter, int> taskFilterCounts(
  Map<DownloadTaskPhase, int>? phaseCounts,
) {
  return <TaskFilter, int>{
    for (final filter in TaskFilter.values)
      filter: taskPhasesForFilter(filter).fold<int>(
        0,
        (int total, DownloadTaskPhase phase) =>
            total + (phaseCounts?[phase] ?? 0),
      ),
  };
}

/// 返回任务页可直接展示的主任务，旧版独立资源记录不再作为卡片出现。
List<DownloadTaskRecord> visiblePrimaryDownloadTasks(
  List<DownloadTaskRecord> tasks,
) {
  return tasks
      .where(
        (DownloadTaskRecord task) =>
            downloadExtraResourceFromCode(task.contentType) == null,
      )
      .toList(growable: false);
}

/// 返回当前列表中允许批量暂停或继续的任务。
List<DownloadTaskRecord> toggleableDownloadTasks(
  List<DownloadTaskRecord> tasks,
) {
  return tasks
      .where(
        (DownloadTaskRecord task) => canToggleDownloadTaskPause(task.phase),
      )
      .toList(growable: false);
}

/// 判断待下载页是否仍有可清空的排队任务。
bool hasQueuedDownloadTask(List<DownloadTaskRecord> tasks) {
  return tasks.any(
    (DownloadTaskRecord task) => task.phase == DownloadTaskPhase.queued,
  );
}

/// 判断下载中页当前可切换任务是否全部暂停。
bool allToggleableTasksPaused(List<DownloadTaskRecord> tasks) {
  return tasks.isNotEmpty &&
      tasks.every(
        (DownloadTaskRecord task) => task.phase == DownloadTaskPhase.paused,
      );
}

/// 判断当前下载中列表是否包含可绑定自动关机的非暂停任务。
bool hasRunningTaskForShutdown(List<DownloadTaskRecord> tasks) {
  return tasks.any(
    (DownloadTaskRecord task) => task.phase != DownloadTaskPhase.paused,
  );
}

/// 判断已下载页是否需要展示加载更多入口。
bool hasMoreCompletedTasks({
  required TaskFilter filter,
  required int visibleCount,
  required int totalCount,
}) {
  return filter == TaskFilter.completed && visibleCount < totalCount;
}

/// 从任务输出文件推导工具栏显示的存储目录。
String toolbarStoragePath(
  List<DownloadTaskRecord> tasks,
  String? defaultStoragePath,
) {
  // 工具栏表达的是设置中心的下载根目录，高级规则生成的任务子目录不能替代根目录。
  if (defaultStoragePath != null && defaultStoragePath.isNotEmpty) {
    // 根目录加载完成后始终优先展示它，点击修改也会更新同一项设置。
    return defaultStoragePath;
  }
  // 设置首次读取期间，暂时从当前任务输出路径推导一个可理解的目录。
  for (final task in tasks) {
    // 空路径不能参与 dirname 计算。
    if (task.outputPath != null && task.outputPath!.isNotEmpty) {
      // 只作为加载期间回退，不在工具栏暴露最终文件名。
      return p.dirname(task.outputPath!);
    }
  }
  // 没有任务时使用简洁占位文案。
  return defaultStoragePath ?? '正在读取默认下载目录…';
}

/// 返回任务卡片打开文件管理器时使用的下载根目录显示路径。
String taskListStoragePath(String? defaultStoragePath) {
  // 设置尚未加载完成时使用平台默认产品目录，避免列表拿到空路径。
  return defaultStoragePath ??
      p.join('Download', defaultDownloadProductDirectoryName);
}
