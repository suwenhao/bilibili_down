import 'dart:async';

import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:path/path.dart' as p;

import '../../core/logging/app_debug_log.dart';
import 'media_merge_files.dart';
import 'media_merger.dart';
import 'media_processing_guard.dart';

/// 使用 FFmpegKit 插件执行跨平台音视频合并。
final class FfmpegKitMediaMerger implements MediaMerger {
  /// 使用可选平台后台保活守卫创建合并器。
  FfmpegKitMediaMerger({this.guard = const NoopMediaProcessingGuard()});

  /// 合并期间负责维持后台执行能力的平台守卫。
  final MediaProcessingGuard guard;

  /// 向多个订阅者广播 FFmpegKit 统计进度。
  final StreamController<MediaMergeProgress> _progress =
      StreamController<MediaMergeProgress>.broadcast();

  /// 当前正在执行的 FFmpegKit 会话。
  FFmpegSession? _session;

  /// 当前任务完成信号，供 dispose 等待 finally 清理。
  Completer<void>? _mergeDone;

  /// 标记取消是否由用户主动请求。
  bool _cancelRequested = false;

  /// 合并器是否已经释放。
  bool _disposed = false;

  /// 返回媒体合并进度广播流。
  @override
  Stream<MediaMergeProgress> watchProgress() => _progress.stream;

  /// 使用 FFmpegKit 将独立音视频流无损封装为一个文件。
  @override
  Future<void> merge(MediaMergeRequest request) async {
    // 已释放的合并器不能重新使用。
    if (_disposed) throw StateError('FfmpegKitMediaMerger is disposed.');
    // 单个实例同一时间只允许一个 FFmpegKit 会话。
    if (_session != null) {
      throw const MediaMergeException('A media merge is already running.');
    }
    // 只记录文件名和预计时长，不输出用户目录或完整命令路径。
    AppDebugLog.ffmpeg(
      'FFmpegKit merge started video=${request.videoPath == null ? '-' : p.basename(request.videoPath!)} '
      'audio=${request.audioPath == null ? '-' : p.basename(request.audioPath!)} '
      'output=${p.basename(request.outputPath)} '
      'durationMs=${request.expectedDuration?.inMilliseconds ?? -1}',
    );
    // 创建本次任务完成信号并清除旧取消状态。
    final mergeDone = Completer<void>();
    _mergeDone = mergeDone;
    _cancelRequested = false;
    // 临时路径用于失败和取消后的文件清理。
    String? temporaryPath;
    // 只有成功提升最终文件后才标记完成。
    var completed = false;
    // 记录守卫是否已经成功启动。
    var guardStarted = false;
    // 保存最近一次打印的进度百分比，每跨越 10% 才输出一次。
    var lastLoggedPercent = -10;
    try {
      // 先获取 Android 等平台需要的后台执行能力。
      await guard.start();
      guardStarted = true;
      // 平台后台执行守卫已经就绪。
      AppDebugLog.ffmpeg('FFmpegKit processing guard ready.');
      // 校验输入并创建不会覆盖用户文件的临时路径。
      temporaryPath = await MediaMergeFiles.prepare(request);
      // 临时输出已经创建，只记录文件名避免暴露完整用户目录。
      AppDebugLog.ffmpeg(
        'FFmpegKit temporary output=${p.basename(temporaryPath)}',
      );
      // 初始化插件原生库，确保当前平台 FFmpeg 能被调用。
      await FFmpegKitExtended.initialize();
      // 原生库加载完成后才能创建会话。
      AppDebugLog.ffmpeg('FFmpegKit native runtime initialized.');
      // 通过参数数组创建会话，避免命令字符串转义问题。
      final session = FFmpegKit.createSessionFromArguments(
        _arguments(request, temporaryPath),
      );
      // 保存会话引用，支持取消和并发保护。
      _session = session;
      // 会话创建成功，下一步进入原生异步执行。
      AppDebugLog.ffmpeg('FFmpegKit session executing.');
      // 异步执行并接收原生层统计回调。
      await session.executeAsync(
        statisticsCallback: (statistics) {
          // FFmpegKit 的 time 字段以毫秒表示已处理时长。
          final processed = Duration(milliseconds: statistics.time);
          // 读取业务层提供的预计总时长作为比例回退依据。
          final expected = request.expectedDuration;
          // 优先使用插件比例，否则按时长计算并限制到 0 至 1。
          final ratio =
              statistics.transcodingProgress ??
              (expected == null || expected.inMilliseconds <= 0
                  ? null
                  : (processed.inMilliseconds / expected.inMilliseconds).clamp(
                      0.0,
                      1.0,
                    ));
          // 有可计算比例时每跨越 10% 输出一次，避免统计回调刷屏。
          final percent = ratio == null ? null : (ratio * 100).floor();
          if (percent != null && percent >= lastLoggedPercent + 10) {
            lastLoggedPercent = percent;
            AppDebugLog.ffmpeg(
              'FFmpegKit progress=$percent% processedMs=${processed.inMilliseconds} '
              'speed=${statistics.speed}',
            );
          }
          // 广播处理时长、比例和实时倍速。
          _progress.add(
            MediaMergeProgress(
              processed: processed,
              ratio: ratio,
              speed: statistics.speed,
            ),
          );
        },
      );
      // 会话执行结束后清除活动引用。
      _session = null;
      // 获取原生 FFmpeg 返回码判断成功、取消或失败。
      final returnCode = session.getReturnCode();
      // 返回码是判断成功、取消和失败的首要依据。
      AppDebugLog.ffmpeg('FFmpegKit session completed code=$returnCode');
      // 用户标记或原生取消码均转换成专用取消异常。
      if (_cancelRequested || ReturnCode.isCancel(returnCode)) {
        throw const MediaMergeCanceledException();
      }
      // 非成功返回码附加完整日志或失败堆栈。
      if (!ReturnCode.isSuccess(returnCode)) {
        // 失败时把原生日志交给统一脱敏输出，方便用户直接截图。
        AppDebugLog.ffmpeg(
          'FFmpegKit native logs: '
          '${session.getLogsAsString() ?? session.getFailStackTrace()}',
        );
        throw MediaMergeException(
          'FFmpegKit exited with code $returnCode.',
          session.getLogsAsString() ?? session.getFailStackTrace(),
        );
      }
      // 成功后把完整临时文件原子提升为目标文件。
      await MediaMergeFiles.promote(temporaryPath, request.outputPath);
      completed = true;
      // 临时文件已经安全提升为最终输出。
      AppDebugLog.ffmpeg('FFmpegKit merge succeeded.');
    } catch (error) {
      // 所有初始化、执行和文件错误都使用同一前缀输出。
      AppDebugLog.ffmpeg('FFmpegKit merge failed error=$error');
      rethrow;
    } finally {
      // 无论结果如何都清除活动会话引用。
      _session = null;
      // 未完成时删除可能存在的 .part 文件。
      if (!completed) await MediaMergeFiles.cleanup(temporaryPath);
      // 仅成功启动过守卫时释放平台资源。
      if (guardStarted) await guard.stop();
      // 通知 dispose 本次清理已经完成。
      if (!mergeDone.isCompleted) mergeDone.complete();
      // 只清除当前任务的完成信号，避免覆盖后续任务。
      if (identical(_mergeDone, mergeDone)) _mergeDone = null;
      // 最终清理完成，completed 表示是否已经生成最终文件。
      AppDebugLog.ffmpeg('FFmpegKit cleanup completed success=$completed');
    }
  }

  /// 标记取消并通知 FFmpegKit 终止当前会话。
  @override
  Future<void> cancel() async {
    // 记录用户或生命周期触发的取消请求。
    AppDebugLog.ffmpeg('FFmpegKit cancel requested.');
    // 标记由用户发起的取消，供 merge 正确分类结果。
    _cancelRequested = true;
    // 复制会话引用便于空安全判断。
    final session = _session;
    // 会话存在时调用 FFmpegKit 原生取消接口。
    if (session != null) FFmpegKit.cancel(session);
  }

  /// 取消当前任务、等待清理完成并关闭进度流。
  @override
  Future<void> dispose() async {
    // 重复释放直接返回，避免重复关闭进度流。
    if (_disposed) return;
    // 标记合并器生命周期结束。
    AppDebugLog.ffmpeg('FFmpegKit dispose requested.');
    // 先阻止新任务进入。
    _disposed = true;
    // 保存当前完成信号，随后发起取消。
    final mergeDone = _mergeDone;
    await cancel();
    // 等待 merge 的 finally 清理临时文件与守卫。
    await mergeDone?.future;
    // 最后关闭进度广播流。
    await _progress.close();
  }

  /// 构造使用流复制、无需重新编码的 FFmpeg 参数列表。
  List<String> _arguments(MediaMergeRequest request, String temporaryPath) {
    // FFmpegKit 与桌面 CLI 使用完全一致的单流或双流输入顺序。
    final arguments = <String>['-hide_banner', '-nostdin', '-y'];
    // 有视频时先添加视频输入。
    if (request.videoPath != null) {
      arguments.addAll(<String>['-i', request.videoPath!]);
    }
    // 有音频时再添加音频输入。
    if (request.audioPath != null) {
      arguments.addAll(<String>['-i', request.audioPath!]);
    }
    // 视频实际存在时映射第一个输入的视频流。
    if (request.videoPath != null) {
      arguments.addAll(<String>['-map', '0:v:0']);
    }
    // 音频映射根据是否存在视频选择正确输入索引。
    if (request.audioPath != null) {
      arguments.addAll(<String>[
        '-map',
        request.videoPath == null ? '0:a:0' : '1:a:0',
      ]);
    }
    // 所有类型都无损复制媒体流并保留快速启动标记。
    arguments.addAll(<String>[
      '-c',
      'copy',
      '-movflags',
      '+faststart',
      temporaryPath,
    ]);
    return arguments;
  }
}
