import 'dart:io';

import 'package:path/path.dart' as p;

import 'media_merger.dart';

/// 负责校验输入、创建临时输出及原子提升合并结果。
final class MediaMergeFiles {
  /// 工具类不允许实例化。
  const MediaMergeFiles._();

  /// 校验任务文件并返回同目录下的临时输出路径。
  static Future<String> prepare(MediaMergeRequest request) async {
    // 可选音视频路径分别转换为文件，支持单流和双流任务。
    final video = request.videoPath == null ? null : File(request.videoPath!);
    final audio = request.audioPath == null ? null : File(request.audioPath!);
    final output = File(request.outputPath);
    // 视频输入缺失时不启动 FFmpeg，避免产生空输出。
    if (video != null && !await video.exists()) {
      throw MediaMergeException('Video input is missing: ${video.path}');
    }
    // 音频输入缺失时不启动 FFmpeg。
    if (audio != null && !await audio.exists()) {
      throw MediaMergeException('Audio input is missing: ${audio.path}');
    }
    // 为保护用户文件，目标已存在时拒绝覆盖。
    if (await output.exists()) {
      throw MediaMergeException('Output already exists: ${output.path}');
    }
    // 确保最终输出目录已经创建。
    await output.parent.create(recursive: true);

    // 保留最终扩展名，使 FFmpeg 能正确推断封装格式。
    final extension = p.extension(output.path);
    // 使用隐藏的 .part 文件名标识未完成结果。
    final temporaryName =
        '.${p.basenameWithoutExtension(output.path)}.bilidown.part$extension';
    // 临时文件与最终文件同目录，成功后可以原子重命名。
    final temporaryPath = p.join(output.parent.path, temporaryName);
    // 清理上次异常退出可能遗留的临时文件。
    final temporary = File(temporaryPath);
    if (await temporary.exists()) await temporary.delete();
    return temporaryPath;
  }

  /// 将完整临时文件重命名为用户指定的最终文件。
  static Future<void> promote(String temporaryPath, String outputPath) async {
    // 获取合并器应该生成的临时文件。
    final temporary = File(temporaryPath);
    // FFmpeg 成功但没有文件属于异常结果，不能伪装成完成。
    if (!await temporary.exists()) {
      throw MediaMergeException('Merge output was not created: $temporaryPath');
    }
    // 同目录重命名，避免用户看到半成品文件。
    await temporary.rename(outputPath);
  }

  /// 在取消或失败时删除可能存在的临时输出。
  static Future<void> cleanup(String? temporaryPath) async {
    // 尚未创建临时路径时无需处理。
    if (temporaryPath == null) return;
    // 文件存在时才删除，避免无意义异常。
    final file = File(temporaryPath);
    if (await file.exists()) await file.delete();
  }
}

/// 媒体文件校验或 FFmpeg 执行失败异常。
class MediaMergeException implements Exception {
  /// 保存可读消息和可选底层原因。
  const MediaMergeException(this.message, [this.cause]);

  /// 错误说明。
  final String message;

  /// FFmpeg 日志或底层异常。
  final Object? cause;

  /// 输出带异常类型的诊断文本。
  @override
  String toString() => 'MediaMergeException: $message';
}

/// 用户主动取消媒体合并时使用的专用异常。
final class MediaMergeCanceledException extends MediaMergeException {
  /// 使用固定取消消息创建异常。
  const MediaMergeCanceledException() : super('Media merge was canceled.');
}
