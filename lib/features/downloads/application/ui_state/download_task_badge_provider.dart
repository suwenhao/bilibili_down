import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/download_task_phase.dart';
import 'download_task_query_providers.dart';

/// 实时统计导航入口需要展示的待下载任务数量。
final queuedDownloadTaskCountProvider = Provider<int>((Ref ref) {
  // 复用共享阶段计数，未收到首份数据库快照前角标保持零。
  final counts = ref.watch(downloadTaskPhaseCountsProvider).value;
  return counts?[DownloadTaskPhase.queued] ?? 0;
});
