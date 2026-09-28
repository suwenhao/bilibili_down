import '../../domain/download_task_phase.dart';

/// 合并规划只需要的分流类型、阶段和临时文件路径。
typedef DownloadMergeStream = ({
  DownloadStreamKind kind,
  DownloadStreamPhase phase,
  String temporaryPath,
});

/// 已校验且每种类型最多一条的媒体合并输入。
final class DownloadMergeInputs {
  /// 创建视频或音频至少存在一项的输入快照。
  const DownloadMergeInputs({this.videoPath, this.audioPath});

  /// 可选视频临时文件路径。
  final String? videoPath;

  /// 可选音频临时文件路径。
  final String? audioPath;
}

/// 校验分流完成状态并选择唯一的视频与音频输入。
DownloadMergeInputs resolveCompletedMediaInputs({
  required String taskId,
  required Iterable<DownloadMergeStream> streams,
}) {
  // 固化一次查询快照，后续数量和类型判断必须基于同一组记录。
  final values = streams.toList(growable: false);
  // 当前实际选择的一条或两条分流都必须完成后才能启动 FFmpeg。
  if (values.isEmpty ||
      values.length > 2 ||
      values.any((stream) => stream.phase != DownloadStreamPhase.completed)) {
    throw StateError('Task $taskId does not have completed media streams.');
  }
  // 按分流类型查找视频和音频输入。
  final video = values.where(
    (stream) => stream.kind == DownloadStreamKind.video,
  );
  final audio = values.where(
    (stream) => stream.kind == DownloadStreamKind.audio,
  );
  // 每种分流最多一条，并且至少存在一条媒体来源。
  if (video.length > 1 ||
      audio.length > 1 ||
      (video.isEmpty && audio.isEmpty)) {
    throw StateError('Task $taskId has invalid stream kinds.');
  }
  // 返回经过唯一性校验的可选视频和音频路径。
  return DownloadMergeInputs(
    videoPath: video.isEmpty ? null : video.single.temporaryPath,
    audioPath: audio.isEmpty ? null : audio.single.temporaryPath,
  );
}
