import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/download_task_repository.dart';
import '../../domain/download_task_phase.dart';

/// 任务中心三个产品页签的稳定业务名称。
enum DownloadTaskTab {
  /// 尚未启动和启动失败的任务。
  pending,

  /// 等待、下载、合并和暂停中的任务。
  active,

  /// 已经成功完成的任务。
  completed,
}

/// 一次外部页签选择请求；序号保证重复请求同一页签仍能触发。
final class DownloadTaskTabRequest {
  /// 保存目标页签和单调递增请求序号。
  const DownloadTaskTabRequest({required this.tab, required this.revision});

  /// 本次导航需要选中的任务页签。
  final DownloadTaskTab tab;

  /// 每次外部跳转递增的序号，不能使用页签值本身去重。
  final int revision;
}

/// 提供跨一级页面的一次性任务页签导航请求。
final downloadTaskTabControllerProvider =
    NotifierProvider<DownloadTaskTabController, DownloadTaskTabRequest>(
      DownloadTaskTabController.new,
    );

/// 接收解析页等外部页面发出的任务页签选择请求。
final class DownloadTaskTabController extends Notifier<DownloadTaskTabRequest> {
  /// 应用首次进入任务中心默认展示待下载页签。
  @override
  DownloadTaskTabRequest build() {
    return const DownloadTaskTabRequest(
      tab: DownloadTaskTab.pending,
      revision: 0,
    );
  }

  /// 发出一次新请求；即使目标页签相同也必须提高序号。
  void select(DownloadTaskTab tab) {
    // 新对象和新序号确保 IndexedStack 中已经存活的任务页也能收到请求。
    state = DownloadTaskTabRequest(tab: tab, revision: state.revision + 1);
  }
}

/// 判断本轮跟踪的全部任务是否都已经成功完成。
bool areTrackedDownloadTasksCompleted({
  required Set<String> taskIds,
  required Iterable<DownloadTaskPhaseSnapshot> snapshots,
}) {
  // 空集合不代表发生过下载，不能触发自动跳转。
  if (taskIds.isEmpty) return false;
  // 轻量快照按 ID 建索引，避免每个任务重复遍历数据库结果。
  final phaseByTaskId = <String, DownloadTaskPhase>{
    for (final snapshot in snapshots) snapshot.taskId: snapshot.phase,
  };
  for (final taskId in taskIds) {
    // 被删除、失败、暂停或仍在运行的任务都不满足“全部下载完成”。
    if (phaseByTaskId[taskId] != DownloadTaskPhase.completed) return false;
  }
  return true;
}
