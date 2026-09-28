import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/database/database_providers.dart';
import '../../../../core/logging/app_debug_log.dart';
import '../../../../core/platform/default_download_directory.dart';
import '../../../../services/bilibili/bilibili_parser_service.dart';
import '../../../../services/bilibili/bilibili_providers.dart';
import '../../../../services/bilibili/models/bili_dash_manifest.dart';
import '../../../../services/bilibili/models/bili_media_info.dart';
import '../../data/download_task_repository.dart';
import '../../domain/download_task_phase.dart';
import '../../domain/download_extra_resource.dart';
import 'download_task_coordinator.dart';
import 'download_task_coordinator_provider.dart';
import '../queue/download_disk_space_guard.dart';
import '../queue/download_task_plan.dart';

/// 提供待下载任务重新解析最新地址并启动协调器的应用服务。
final downloadTaskLaunchServiceProvider = Provider<DownloadTaskLaunchService>((
  Ref ref,
) {
  // 协调器为异步 Provider，因此通过回调在用户真正点击下载时再等待初始化。
  return DownloadTaskLaunchService(
    ref.watch(bilibiliParserServiceProvider),
    ref.watch(downloadTaskRepositoryProvider),
    () => ref.read(downloadTaskCoordinatorProvider.future),
    ref.watch(downloadDiskSpaceGuardProvider),
  );
});

/// 将 Drift 待下载记录转换为可执行双流计划。
final class DownloadTaskLaunchService {
  /// 创建任务启动服务。
  const DownloadTaskLaunchService(
    this._parser,
    this._repository,
    this._coordinatorLoader,
    this._diskSpaceGuard,
  );

  /// 负责重新请求短期 DASH 地址的解析器。
  final BilibiliParserService _parser;

  /// 负责读取持久化分集、质量和路径选择的仓库。
  final DownloadTaskRepository _repository;

  /// 延迟获取当前平台双流下载协调器。
  final Future<DownloadTaskCoordinator> Function() _coordinatorLoader;

  /// 下载前按目标卷检查分流、成品和合并工作空间。
  final DownloadDiskSpaceGuard _diskSpaceGuard;

  /// 重新请求最新 DASH 清单并启动一条待下载或失败任务。
  Future<void> start(String taskId) async {
    // 标记用户启动入口，后续阶段日志均使用同一个业务任务 ID。
    AppDebugLog.aria2('Launch started task=$taskId');
    // 读取用户在待下载页看到的最新任务快照。
    final task = await _repository.findTask(taskId);
    if (task == null) throw StateError('Unknown download task: $taskId');
    // 只允许待下载、失败或已由调度器认领的等待任务开始解析。
    if (task.phase != DownloadTaskPhase.queued &&
        task.phase != DownloadTaskPhase.failed &&
        task.phase != DownloadTaskPhase.waitingToStart) {
      throw StateError('Task $taskId cannot start from ${task.phase.name}.');
    }
    // BVID、CID 和临时目录是恢复播放地址与分流文件的最低必要字段。
    final bvid = task.bvid;
    final cid = task.cid;
    final temporaryDirectory = task.temporaryDirectory;
    if (bvid == null ||
        bvid.isEmpty ||
        cid == null ||
        temporaryDirectory == null ||
        temporaryDirectory.isEmpty) {
      throw StateError('Task $taskId is missing media identifiers or paths.');
    }
    // 按 EP ID 判断普通投稿或 PGC 分集。
    final contentType = task.epid == null
        ? BiliContentType.ugc
        : BiliContentType.pgc;
    // 从 Drift 永久字段重建播放接口所需分集对象。
    final episode = BiliEpisodeInfo(
      contentType: contentType,
      bvid: bvid,
      cid: cid,
      index: task.partIndex,
      title: task.title,
      duration: Duration(milliseconds: task.durationMilliseconds ?? 0),
      episodeId: task.epid,
      coverUrl: task.coverUrl,
      publishedAt: task.publishedAt,
    );
    // “更多”菜单中的非音频资源不请求 DASH，直接解析单一资源地址。
    final extraResource = downloadExtraResourceFromCode(task.contentType);
    // 多语言字幕任务从内容类型恢复稳定语言代码，重新解析时选择同一轨道。
    final extraResourceVariant = downloadExtraResourceVariantFromCode(
      task.contentType,
    );
    // 最终输出路径用于选择真实目标卷，缺失时不能执行空间保护或发布。
    final outputPath = task.outputPath;
    if (outputPath == null || outputPath.isEmpty) {
      throw StateError('Task $taskId is missing output path.');
    }
    // 下载启动时重新创建最终父目录，兼容解析后目录被清理以及附加资源标题子目录。
    await Directory(p.dirname(outputPath)).create(recursive: true);
    // 普通音视频同时存在时需要额外预留最终合并成品大小。
    final requiresMerge =
        extraResource == null &&
        task.qualityId != null &&
        task.audioQualityId != null;
    // 在任何网络请求或临时文件创建前验证目标卷剩余空间。
    await _diskSpaceGuard.ensureAvailable(
      outputPath: outputPath,
      estimatedVideoBytes: task.estimatedVideoSizeBytes,
      estimatedAudioBytes: task.estimatedAudioSizeBytes,
      requiresMerge: requiresMerge,
    );
    if (!await _shouldContinueLaunch(taskId, originalPhase: task.phase)) {
      return;
    }
    if (extraResource != null && extraResource != DownloadExtraResource.audio) {
      // 独立资源仍写入任务专属临时目录，便于取消和失败清理。
      await _ensureTemporaryDirectory(temporaryDirectory);
      final plan = await _parser.createExtraResourcePlan(
        taskId: taskId,
        episode: episode,
        resource: extraResource,
        temporaryPath: p.join(temporaryDirectory, 'resource.download'),
        resourceVariant: extraResourceVariant,
      );
      if (!await _shouldContinueLaunch(taskId, originalPhase: task.phase)) {
        return;
      }
      // 资源地址解析完成后交给同一下载协调器持久化进度。
      final coordinator = await _coordinatorLoader();
      if (!await _shouldContinueLaunch(taskId, originalPhase: task.phase)) {
        return;
      }
      if (extraResource == DownloadExtraResource.danmakuXml ||
          extraResource == DownloadExtraResource.danmakuAss) {
        // B 站弹幕使用 raw deflate，应用内解码以避开 aria2 的 zlib 头兼容错误。
        await coordinator.startPreparedResource(
          plan,
          prepare: (ResolvedMediaSource source) async {
            final bytes = await _parser.fetchDanmakuXmlBytes(source);
            // XML 与 ASS 共用原始 XML 临时文件，ASS 在完成阶段再转换。
            final file = File(source.temporaryPath);
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes, flush: true);
            return bytes.length;
          },
        );
      } else {
        // 封面和字幕正文没有 raw deflate 问题，继续交给统一下载引擎。
        await coordinator.startResolvedTask(plan);
      }
      AppDebugLog.aria2('Extra resource submitted task=$taskId');
      return;
    }
    // 在用户点击下载时请求最新地址，避免待下载列表停留过久导致 URL 失效。
    AppDebugLog.aria2('Refreshing DASH manifest task=$taskId');
    final manifest = await _parser.loadDashManifest(episode);
    if (!await _shouldContinueLaunch(taskId, originalPhase: task.phase)) {
      return;
    }
    // 播放清单成功后记录候选数量，不输出任何短期媒体地址。
    AppDebugLog.aria2(
      'DASH manifest ready task=$taskId '
      'video=${manifest.videoStreams.length} audio=${manifest.audioStreams.length}',
    );
    // 恢复待下载阶段保存的视频编码偏好。
    final preferredCodec = _videoCodecFromName(task.videoCodec);
    // 质量 ID 是否存在直接决定本次需要下载的视频和音频分流。
    final includeVideo = extraResource == DownloadExtraResource.audio
        ? false
        : task.qualityId != null;
    // 独立音频不携带固定质量 ID，由最新清单直接选择当前账号最高档。
    final includeAudio = extraResource == DownloadExtraResource.audio
        ? true
        : task.audioQualityId != null;
    // 两项都为空属于损坏或非法任务，不能提交空下载计划。
    if (!includeVideo && !includeAudio) {
      throw StateError('任务必须至少选择音质或画质。');
    }
    // 下载引擎启动前创建任务独立临时目录。
    await _ensureTemporaryDirectory(temporaryDirectory);
    // 使用固定临时文件名，任务 UUID 目录已经提供隔离。
    final plan = await _parser.createDownloadPlan(
      taskId: taskId,
      episode: episode,
      manifest: manifest,
      videoTemporaryPath: p.join(temporaryDirectory, 'video.m4s'),
      audioTemporaryPath: p.join(temporaryDirectory, 'audio.m4s'),
      includeVideo: includeVideo,
      includeAudio: includeAudio,
      qualityId: task.qualityId,
      audioQualityId: extraResource == DownloadExtraResource.audio
          ? null
          : task.audioQualityId,
      preferredCodec: preferredCodec,
    );
    if (!await _shouldContinueLaunch(taskId, originalPhase: task.phase)) {
      return;
    }
    // 分流计划只记录流数量和质量，不输出 URL 或请求头。
    AppDebugLog.aria2(
      'Download plan ready task=$taskId sources=${plan.sources.length}',
    );
    // 等待当前平台下载引擎和合并器初始化完成。
    AppDebugLog.aria2('Coordinator loading task=$taskId');
    final coordinator = await _coordinatorLoader();
    if (!await _shouldContinueLaunch(taskId, originalPhase: task.phase)) {
      return;
    }
    // 协调器就绪后即可正式提交两条分流。
    AppDebugLog.aria2('Coordinator ready task=$taskId');
    // 把音频、无声视频或有声视频计划提交持久化协调器。
    await coordinator.startResolvedTask(plan);
    // 两条分流都被下载引擎接受后结束按钮加载状态。
    AppDebugLog.aria2('Launch submitted task=$taskId');
  }

  /// 确认长异步步骤之后任务仍应继续启动。
  Future<bool> _shouldContinueLaunch(
    String taskId, {
    required DownloadTaskPhase originalPhase,
  }) async {
    // 重新读取数据库阶段，用户暂停、取消或清理后旧启动流程必须安静退出。
    final current = await _repository.findTask(taskId);
    if (current == null) return false;
    // 按启动来源限制仍可继续的阶段，避免回退到待下载的旧启动继续提交。
    final allowedBeforeCoordinator = switch (originalPhase) {
      DownloadTaskPhase.failed => const <DownloadTaskPhase>{
        DownloadTaskPhase.failed,
        DownloadTaskPhase.resolving,
      },
      DownloadTaskPhase.queued => const <DownloadTaskPhase>{
        DownloadTaskPhase.queued,
        DownloadTaskPhase.resolving,
      },
      DownloadTaskPhase.waitingToStart => const <DownloadTaskPhase>{
        DownloadTaskPhase.waitingToStart,
        DownloadTaskPhase.resolving,
      },
      _ => const <DownloadTaskPhase>{},
    };
    if (allowedBeforeCoordinator.contains(current.phase)) return true;
    // 暂停属于用户明确操作，不应被旧启动流程记录为失败。
    AppDebugLog.aria2(
      'Launch stopped after phase changed task=$taskId phase=${current.phase.name}',
    );
    return false;
  }

  /// 把数据库编码名称转换为稳定枚举。
  BiliVideoCodec? _videoCodecFromName(String? name) {
    // 没有保存偏好时让 DASH 清单自动选择。
    if (name == null || name.isEmpty) return null;
    // 名称由入队流程使用 enum.name 写入，逐项匹配可兼容未来新增值。
    for (final codec in BiliVideoCodec.values) {
      if (codec.name == name.toLowerCase()) return codec;
    }
    // 旧数据无法识别时安全回退自动选择。
    return null;
  }

  /// 创建任务临时目录，并在 Android 上写入 .nomedia 防止分流被相册扫描。
  Future<void> _ensureTemporaryDirectory(String path) async {
    final directory = Directory(path);
    await directory.create(recursive: true);
    await ensureAndroidNoMediaMarker(directory);
  }
}
