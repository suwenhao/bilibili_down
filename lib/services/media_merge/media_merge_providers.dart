import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_debug_log.dart';
import '../../core/platform/platform_providers.dart';
import '../../core/platform/runtime_platform.dart';
import 'cli_media_merger.dart';
import 'ffmpeg_kit_media_merger.dart';
import 'media_merger.dart';
import 'media_processing_guard.dart';

/// 根据当前平台创建媒体合并器并管理其生命周期。
final mediaMergerProvider = FutureProvider<MediaMerger>((ref) async {
  // 等待原生工具路径和后端选择结果完成。
  final paths = await ref.watch(nativeToolPathsProvider.future);
  // 输出平台最终选择的合并后端，便于截图确认是否走 FFmpegKit 或 CLI。
  AppDebugLog.ffmpeg(
    'Merger backend selected=${paths.mediaMergeBackend.name} '
    'platform=${paths.platform.operatingSystem.name} '
    'arch=${paths.platform.architecture.name}',
  );
  // Android 合并时需要前台服务保活，其他平台使用空守卫。
  final guard = paths.platform.operatingSystem == HostOperatingSystem.android
      ? AndroidMediaProcessingGuard()
      : const NoopMediaProcessingGuard();
  // 注入两种后端构造逻辑，由工厂按平台选择。
  final factory = MediaMergerFactory(
    ffmpegKitBuilder: (_) => FfmpegKitMediaMerger(guard: guard),
    bundledFfmpegBuilder: (toolPaths) {
      // CLI 后端必须获得随包 FFmpeg 的绝对路径。
      final executable = toolPaths.ffmpegExecutable;
      // 已选择 CLI 却缺少路径说明安装包资源不完整。
      if (executable == null) {
        throw StateError('Bundled FFmpeg was selected but is unavailable.');
      }
      // 创建会执行独立 FFmpeg 子进程的合并器。
      return CliMediaMerger(ffmpegExecutable: executable, guard: guard);
    },
  );
  // 按当前平台选择最终合并实现。
  final merger = factory.create(paths);
  // Provider 销毁时取消任务并关闭进度流。
  ref.onDispose(() => unawaited(merger.dispose()));
  return merger;
});
