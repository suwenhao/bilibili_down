import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/logging/app_debug_log.dart';
import 'media_merge_files.dart';
import 'media_merger.dart';
import 'media_processing_guard.dart';

/// 通过随安装包分发的 FFmpeg 可执行文件执行音视频合并。
final class CliMediaMerger implements MediaMerger {
  /// 使用 FFmpeg 路径和可选平台保活守卫创建合并器。
  CliMediaMerger({
    required this.ffmpegExecutable,
    this.guard = const NoopMediaProcessingGuard(),
  });

  /// FFmpeg 可执行文件绝对路径。
  final String ffmpegExecutable;

  /// 合并期间负责维持后台执行能力的平台守卫。
  final MediaProcessingGuard guard;

  /// 向多个订阅者广播合并进度。
  final StreamController<MediaMergeProgress> _progress =
      StreamController<MediaMergeProgress>.broadcast();

  /// 当前正在执行的 FFmpeg 子进程。
  Process? _process;

  /// 当前合并任务结束信号，供 dispose 等待清理完成。
  Completer<void>? _mergeDone;

  /// 区分用户取消和 FFmpeg 自身失败的标记。
  bool _cancelRequested = false;

  /// 合并器是否已经释放。
  bool _disposed = false;

  /// 最近一次写入日志的进度百分比，限制 Debug 控制台输出频率。
  int _lastLoggedProgressPercent = -10;

  /// 返回合并进度广播流。
  @override
  Stream<MediaMergeProgress> watchProgress() => _progress.stream;

  /// 启动 FFmpeg 子进程并将独立音视频流无损封装到目标文件。
  @override
  Future<void> merge(MediaMergeRequest request) async {
    // 已释放的合并器不能重新使用。
    if (_disposed) throw StateError('CliMediaMerger is disposed.');
    // 单个实例同一时间只允许一个 FFmpeg 进程。
    if (_process != null) {
      throw const MediaMergeException('A media merge is already running.');
    }
    // 只记录文件名和预计时长，不输出用户目录。
    AppDebugLog.ffmpeg(
      'CLI merge started executable=${p.basename(ffmpegExecutable)} '
      'video=${request.videoPath == null ? '-' : p.basename(request.videoPath!)} '
      'audio=${request.audioPath == null ? '-' : p.basename(request.audioPath!)} '
      'output=${p.basename(request.outputPath)} '
      'durationMs=${request.expectedDuration?.inMilliseconds ?? -1}',
    );
    // 创建本次任务的完成信号，供 dispose 等待 finally 清理。
    final mergeDone = Completer<void>();
    _mergeDone = mergeDone;
    // 新任务开始时清除上一次取消状态。
    _cancelRequested = false;
    // 新任务从未记录进度开始，允许首次 0% 快照输出。
    _lastLoggedProgressPercent = -10;
    // 记录临时输出路径，失败时用于清理。
    String? temporaryPath;
    // 只有成功提升最终文件后才视为完成。
    var completed = false;
    // 记录守卫是否启动成功，避免未启动就调用 stop。
    var guardStarted = false;
    try {
      // 先获得平台后台执行能力，再启动可能耗时的合并任务。
      await guard.start();
      guardStarted = true;
      // 平台后台处理守卫已经成功启动。
      AppDebugLog.ffmpeg('CLI processing guard ready.');
      // 校验输入并生成安全的同目录临时路径。
      temporaryPath = await MediaMergeFiles.prepare(request);
      // 临时输出路径只记录文件名。
      AppDebugLog.ffmpeg('CLI temporary output=${p.basename(temporaryPath)}');
      // 使用参数列表启动 FFmpeg，避免 shell 拼接和路径转义问题。
      final process = await Process.start(
        ffmpegExecutable,
        _arguments(request, temporaryPath),
        mode: ProcessStartMode.normal,
      );
      // 保存进程引用，支持取消和并发保护。
      _process = process;
      // 记录子进程 ID，方便与系统任务管理器对应。
      AppDebugLog.ffmpeg('CLI process started pid=${process.pid}');

      // 仅保留最近 80 行错误日志，兼顾诊断能力和内存占用。
      final stderrLines = ListQueue<String>(80);
      // 解码并逐行消费标准错误，避免管道阻塞。
      final stderrDone = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .forEach((line) {
            // 队列满时丢弃最旧日志。
            if (stderrLines.length == 80) stderrLines.removeFirst();
            // 追加最新 FFmpeg 日志。
            stderrLines.addLast(line);
            // Debug 构建实时输出 FFmpeg 原生日志并执行统一脱敏。
            AppDebugLog.ffmpeg('CLI stderr: $line');
          });
      // 标准输出使用 -progress 协议，逐行解析进度键值。
      final stdoutDone = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .forEach((line) => _handleProgressLine(line, request));

      // 等待进程退出，并确保两个输出管道都消费完毕。
      final exitCode = await process.exitCode;
      await Future.wait([stderrDone, stdoutDone]);
      // 输出进程最终返回码，便于快速区分取消和原生失败。
      AppDebugLog.ffmpeg(
        'CLI process exited pid=${process.pid} code=$exitCode',
      );
      // 退出后立即清空进程引用，允许后续任务启动。
      _process = null;
      // 用户取消优先返回专用取消异常，不按退出码报告失败。
      if (_cancelRequested) throw const MediaMergeCanceledException();
      // 非零退出码携带最近日志返回，便于定位编码或文件问题。
      if (exitCode != 0) {
        throw MediaMergeException(
          'FFmpeg exited with code $exitCode.',
          stderrLines.join('\n'),
        );
      }
      // FFmpeg 成功后将临时文件原子提升为最终文件。
      await MediaMergeFiles.promote(temporaryPath, request.outputPath);
      completed = true;
      // 临时文件已经提升为最终输出。
      AppDebugLog.ffmpeg('CLI merge succeeded.');
    } catch (error) {
      // 启动、执行和文件错误均使用统一分类前缀输出。
      AppDebugLog.ffmpeg('CLI merge failed error=$error');
      rethrow;
    } finally {
      // 无论成功、失败或取消都清除进程引用。
      _process = null;
      // 未完成时删除 .part 文件，避免用户误用半成品。
      if (!completed) await MediaMergeFiles.cleanup(temporaryPath);
      // 仅成功启动过守卫时释放平台后台资源。
      if (guardStarted) await guard.stop();
      // 通知 dispose 本次 finally 清理已经完成。
      if (!mergeDone.isCompleted) mergeDone.complete();
      // 只清除当前任务对应的完成信号，避免覆盖后续任务。
      if (identical(_mergeDone, mergeDone)) _mergeDone = null;
      // 最终清理结束，success 表示最终文件是否已经生成。
      AppDebugLog.ffmpeg('CLI cleanup completed success=$completed');
    }
  }

  /// 标记取消并终止当前 FFmpeg 进程。
  @override
  Future<void> cancel() async {
    // 记录用户或生命周期触发的进程取消请求。
    AppDebugLog.ffmpeg('CLI cancel requested.');
    // 标记用户取消，让 merge 将进程退出识别为取消而非失败。
    _cancelRequested = true;
    // 进程存在时发送终止信号。
    _process?.kill();
  }

  /// 取消当前任务、等待清理完成并关闭进度流。
  @override
  Future<void> dispose() async {
    // 重复释放直接返回，避免重复关闭 StreamController。
    if (_disposed) return;
    // 标记 CLI 合并器即将释放。
    AppDebugLog.ffmpeg('CLI dispose requested.');
    // 先阻止新任务进入。
    _disposed = true;
    // 保存当前任务完成信号，避免 cancel 后字段被清理。
    final mergeDone = _mergeDone;
    // 请求取消并等待 merge 的 finally 执行完毕。
    await cancel();
    await mergeDone?.future;
    // 最后关闭进度广播流。
    await _progress.close();
  }

  /// 构造无重新编码、支持进度输出的 FFmpeg 参数列表。
  List<String> _arguments(MediaMergeRequest request, String temporaryPath) {
    // 输入顺序按视频、音频固定组织，单流任务只添加实际存在的一项。
    final arguments = <String>['-hide_banner', '-nostdin', '-y'];
    // 视频输入存在时记录其索引并添加视频映射。
    if (request.videoPath != null) {
      arguments.addAll(<String>['-i', request.videoPath!]);
    }
    // 音频输入在视频之后添加，索引由视频是否存在决定。
    if (request.audioPath != null) {
      arguments.addAll(<String>['-i', request.audioPath!]);
    }
    // 视频始终是第一个实际输入。
    if (request.videoPath != null) {
      arguments.addAll(<String>['-map', '0:v:0']);
    }
    // 双流时音频索引为一，纯音频时索引为零。
    if (request.audioPath != null) {
      arguments.addAll(<String>[
        '-map',
        request.videoPath == null ? '0:a:0' : '1:a:0',
      ]);
    }
    // 三种任务都使用流复制，不发生二次编码。
    arguments.addAll(<String>[
      '-c',
      'copy',
      '-movflags',
      '+faststart',
      '-progress',
      'pipe:1',
      '-nostats',
      temporaryPath,
    ]);
    return arguments;
  }

  /// FFmpeg 最近报告的已处理媒体时长。
  Duration _processed = Duration.zero;

  /// FFmpeg 最近报告的处理倍速。
  double? _speed;

  /// 解析 FFmpeg -progress 输出的一行键值数据。
  void _handleProgressLine(String line, MediaMergeRequest request) {
    // 进度协议使用 key=value，找不到有效分隔符时忽略该行。
    final separator = line.indexOf('=');
    if (separator <= 0) return;
    // 分别提取进度键和值。
    final key = line.substring(0, separator);
    final value = line.substring(separator + 1);
    // out_time_ms 实际表示微秒，转换为 Duration。
    if (key == 'out_time_ms') {
      final microseconds = int.tryParse(value);
      // 无法解析的异常值不覆盖最近有效进度。
      if (microseconds != null) {
        _processed = Duration(microseconds: microseconds);
      }
      // speed 值带 x 后缀，移除后转换成倍速数字。
    } else if (key == 'speed') {
      _speed = double.tryParse(value.replaceFirst('x', ''));
      // progress 标记表示一组数据结束，此时统一广播快照。
    } else if (key == 'progress') {
      _emitProgress(request);
    }
  }

  /// 根据已处理时长和预计总时长广播进度。
  void _emitProgress(MediaMergeRequest request) {
    // 读取业务层提供的媒体总时长。
    final expected = request.expectedDuration;
    // 总时长未知或无效时不伪造比例，否则将结果限制在 0 至 1。
    final ratio = expected == null || expected.inMicroseconds <= 0
        ? null
        : (_processed.inMicroseconds / expected.inMicroseconds).clamp(0.0, 1.0);
    // 可计算比例时每跨越 10% 输出一次，避免 progress 协议逐行刷屏。
    final percent = ratio == null ? null : (ratio * 100).floor();
    if (percent != null && percent >= _lastLoggedProgressPercent + 10) {
      _lastLoggedProgressPercent = percent;
      AppDebugLog.ffmpeg(
        'CLI progress=$percent% processedMs=${_processed.inMilliseconds} '
        'speed=${_speed ?? -1}',
      );
    }
    // 广播本轮处理时长、比例和速度。
    _progress.add(
      MediaMergeProgress(processed: _processed, ratio: ratio, speed: _speed),
    );
  }
}
