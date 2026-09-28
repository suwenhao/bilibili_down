import '../../core/platform/native_tool_resolver.dart';
import '../../core/platform/runtime_platform.dart';

/// 一次音视频无损封装任务所需的输入与输出参数。
final class MediaMergeRequest {
  /// 创建视频、音频、输出路径和可选时长组成的合并请求。
  const MediaMergeRequest({
    this.videoPath,
    this.audioPath,
    required this.outputPath,
    this.expectedDuration,
  }) : assert(videoPath != null || audioPath != null, '至少需要一个媒体输入');

  /// 已下载的视频流文件路径。
  final String? videoPath;

  /// 已下载的音频流文件路径。
  final String? audioPath;

  /// 合并成功后的最终文件路径。
  final String outputPath;

  /// 用于估算进度比例的媒体总时长。
  final Duration? expectedDuration;
}

/// 媒体合并过程的进度快照。
final class MediaMergeProgress {
  /// 创建已处理时长、比例和可选速度组成的进度事件。
  const MediaMergeProgress({
    required this.processed,
    required this.ratio,
    this.speed,
  });

  /// FFmpeg 已处理的媒体时长。
  final Duration processed;

  /// 归一化到 0 至 1 的进度，无法估算时为空。
  final double? ratio;

  /// FFmpeg 报告的实时处理倍速。
  final double? speed;
}

/// FFmpegKit 与独立 FFmpeg 共同遵循的合并接口。
abstract interface class MediaMerger {
  /// 监听合并进度。
  Stream<MediaMergeProgress> watchProgress();

  /// 执行一次音视频合并。
  Future<void> merge(MediaMergeRequest request);

  /// 取消当前合并任务。
  Future<void> cancel();

  /// 取消任务并释放会话与进度流。
  Future<void> dispose();
}

/// 使用已解析工具路径创建合并器的函数签名。
typedef MediaMergerBuilder = MediaMerger Function(NativeToolPaths paths);

/// 按平台能力选择 FFmpegKit 或独立 FFmpeg 合并器。
final class MediaMergerFactory {
  /// 注入两种合并后端的构造器。
  const MediaMergerFactory({
    required this.ffmpegKitBuilder,
    required this.bundledFfmpegBuilder,
  });

  /// FFmpegKit 合并器构造器。
  final MediaMergerBuilder ffmpegKitBuilder;

  /// 随包独立 FFmpeg 合并器构造器。
  final MediaMergerBuilder bundledFfmpegBuilder;

  /// 根据平台预先计算的后端类型创建合并器。
  MediaMerger create(NativeToolPaths paths) {
    // 仅做实现分派，平台差异集中在 RuntimePlatform 中维护。
    return switch (paths.mediaMergeBackend) {
      MediaMergeBackendKind.ffmpegKit => ffmpegKitBuilder(paths),
      MediaMergeBackendKind.bundledFfmpeg => bundledFfmpegBuilder(paths),
    };
  }
}
