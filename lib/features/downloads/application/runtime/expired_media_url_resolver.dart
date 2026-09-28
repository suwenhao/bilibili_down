import '../../domain/download_task_phase.dart';
import '../queue/download_task_plan.dart';

/// 重新解析一条已经过期的 B 站媒体分流地址。
abstract interface class ExpiredMediaUrlResolver {
  /// 根据持久化任务信息只刷新发生鉴权错误的视频或音频分流。
  Future<ResolvedMediaSource> refresh({
    required String taskId,
    required DownloadStreamKind kind,
  });
}
