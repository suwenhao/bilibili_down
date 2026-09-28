import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/logging/app_debug_log.dart';
import '../../../../services/bilibili/bilibili_parser_service.dart';
import '../../../../services/bilibili/bilibili_providers.dart';
import '../../../../services/bilibili/models/bili_media_info.dart';
import '../../../settings/application/app_settings_controller.dart';
import '../../../settings/domain/app_settings.dart';
import '../../data/download_task_repository.dart';
import '../../domain/download_extra_resource.dart';
import '../../domain/download_task_phase.dart';
import '../../domain/stored_dash_options.dart';

/// 登录后待下载任务 DASH 重新解析进度。
final class PendingDashRefreshProgress {
  /// 创建一份当前处理进度快照。
  const PendingDashRefreshProgress({
    required this.current,
    required this.total,
  });

  /// 当前正在重新解析的一基序号。
  final int current;

  /// 本轮需要重新解析的待下载任务总数。
  final int total;
}

/// 暴露登录后待下载任务重新解析进度，Shell 用它展示全局 loading。
final pendingDashRefreshProgressProvider =
    NotifierProvider<
      PendingDashRefreshProgressController,
      PendingDashRefreshProgress?
    >(PendingDashRefreshProgressController.new);

/// 管理登录后待下载任务重新解析的全局进度状态。
final class PendingDashRefreshProgressController
    extends Notifier<PendingDashRefreshProgress?> {
  /// 初始状态没有正在运行的重新解析任务。
  @override
  PendingDashRefreshProgress? build() => null;

  /// 发布当前处理进度。
  void show({required int current, required int total}) {
    // 进度只保存序号，不携带视频标题，避免全局日志和界面暴露用户内容。
    state = PendingDashRefreshProgress(current: current, total: total);
  }

  /// 清除当前进度浮层。
  void clear() {
    // 服务结束或失败后立即收起浮层，避免下次登录看到旧状态。
    state = null;
  }
}

/// 提供登录后重新解析待下载 DASH 候选的应用服务。
final pendingDashOptionRefreshServiceProvider =
    Provider<PendingDashOptionRefreshService>((Ref ref) {
      // 登录成功后使用最新账号态重新请求播放清单，并把进度发布到 Shell。
      return PendingDashOptionRefreshService(
        ref.watch(downloadTaskRepositoryProvider),
        ref.watch(bilibiliParserServiceProvider),
        ref.read(appSettingsControllerProvider.notifier).loadReadySettings,
        ref.read(pendingDashRefreshProgressProvider.notifier),
      );
    });

/// 登录后刷新 queued/failed 任务保存的 DASH 候选与当前选择。
final class PendingDashOptionRefreshService {
  /// 创建待下载 DASH 刷新服务。
  PendingDashOptionRefreshService(
    this._repository,
    this._parser,
    this._settingsLoader,
    this._progressController,
  );

  /// 负责查询和批量写入待下载任务。
  final DownloadTaskRepository _repository;

  /// 负责按当前登录态重新请求 DASH 清单。
  final BilibiliParserService _parser;

  /// 等待本地设置恢复后返回最新默认音画质。
  final Future<AppSettings> Function() _settingsLoader;

  /// 发布全局重新解析进度。
  final PendingDashRefreshProgressController _progressController;

  /// 串行保护登录刷新，避免扫码成功和账号检查并发重复请求同一批任务。
  Future<int>? _runningRefresh;

  /// 使用当前账号权限重新解析待下载任务的 DASH 候选。
  Future<int> refreshQueuedTasksAfterLogin() {
    // 如果上一轮还在进行，复用同一个 Future，避免重复刷新和进度互相覆盖。
    final running = _runningRefresh;
    if (running != null) return running;
    // 创建本轮刷新任务，并在完成后释放并发保护。
    final operation = _performRefreshQueuedTasksAfterLogin();
    _runningRefresh = operation;
    return operation.whenComplete(() {
      // 只释放当前轮，避免极端情况下后发任务被前一轮 finally 清空。
      if (identical(_runningRefresh, operation)) _runningRefresh = null;
    });
  }

  /// 执行一次实际的待下载 DASH 重新解析。
  Future<int> _performRefreshQueuedTasksAfterLogin() async {
    // 先加载设置，登录成功后账号控制器已把默认档位切到登录态。
    final settings = await _settingsLoader();
    // 读取仍未开始或失败待重试的任务，活动任务不能中途替换下载计划。
    final tasks = await _repository.loadTasksByPhases(const <DownloadTaskPhase>[
      DownloadTaskPhase.queued,
      DownloadTaskPhase.failed,
    ]);
    // 只处理普通音视频主任务，独立附加资源没有 DASH 候选需要刷新。
    final refreshableTasks = tasks
        .where(_isRefreshableMediaTask)
        .toList(growable: false);
    if (refreshableTasks.isEmpty) return 0;
    AppDebugLog.download(
      'Login DASH refresh started count=${refreshableTasks.length}',
    );
    // 所有网络解析先写入内存列表，结束后再批量落库。
    final updates = <DownloadTaskDashSelectionUpdate>[];
    // 单条失败只跳过该任务，避免一次接口异常阻断整批刷新。
    var failed = 0;
    try {
      for (var index = 0; index < refreshableTasks.length; index++) {
        // 当前序号从一开始，和界面显示保持一致。
        final current = index + 1;
        // 先显示进度再发起网络请求，让首项等待也有明确 loading。
        _progressController.show(
          current: current,
          total: refreshableTasks.length,
        );
        final task = refreshableTasks[index];
        try {
          // 从任务永久字段重建播放接口所需分集对象。
          final episode = _episodeFromTask(task);
          // 登录成功后重新请求 DASH，接口会返回当前账号可用的更完整候选。
          final manifest = await _parser.loadDashManifest(episode);
          // 将短期 URL 剥离，只保存长期候选元数据。
          final storedOptions = StoredDashOptions.fromManifest(manifest);
          // 当前任务是否保留视频流。
          final includeVideo = task.qualityId != null;
          // 当前任务是否保留音频流。
          final includeAudio = task.audioQualityId != null;
          if (!includeVideo && !includeAudio) {
            failed++;
            continue;
          }
          // 按登录后的默认画质重新选择，目标不可用时由本地候选向下降级。
          final selectedVideo = includeVideo
              ? storedOptions.selectVideo(
                  qualityId: settings.defaultVideoQuality.qualityId,
                  preferredCodec: settings.preferredVideoCodec,
                )
              : null;
          // 按登录后的默认音质重新选择。
          final selectedAudio = includeAudio
              ? storedOptions.selectAudio(
                  qualityId: settings.defaultAudioQuality.dashId,
                )
              : null;
          // 构造待批量提交的任务更新。
          updates.add((
            taskId: task.taskId,
            dashOptionsJson: storedOptions.encode(),
            qualityId: selectedVideo?.qualityId,
            qualityLabel: selectedVideo?.qualityLabel,
            videoCodec: selectedVideo?.codec.name,
            audioCodec: selectedAudio == null
                ? null
                : '${selectedAudio.qualityLabel} | ${selectedAudio.codec}',
            audioQualityId: selectedAudio?.qualityId,
            estimatedVideoSizeBytes: selectedVideo?.estimatedSizeBytes,
            estimatedAudioSizeBytes: selectedAudio?.estimatedSizeBytes,
            durationMilliseconds: storedOptions.durationMilliseconds > 0
                ? storedOptions.durationMilliseconds
                : task.durationMilliseconds,
          ));
        } on Object catch (error) {
          failed++;
          AppDebugLog.download(
            'Login DASH refresh skipped task=${task.taskId} error=$error',
          );
        }
      }
      // 一次事务提交全部成功解析出的候选，避免一条条写库造成列表频繁刷新。
      final updated = await _repository.updateQueuedDashSelections(updates);
      AppDebugLog.download(
        'Login DASH refresh completed updated=$updated failed=$failed',
      );
      // 返回真实更新数量，账号流程用于诊断日志。
      return updated;
    } finally {
      // 无论成功、失败还是中途异常，进度浮层都必须收起。
      _progressController.clear();
    }
  }

  /// 判断任务是否可以在登录后重新解析 DASH 候选。
  bool _isRefreshableMediaTask(DownloadTaskRecord task) {
    // 独立附加资源任务没有普通音视频 DASH 候选。
    if (downloadExtraResourceFromCode(task.contentType) != null) return false;
    // 普通媒体任务必须带有 BVID 和 CID 才能重新请求播放清单。
    final bvid = task.bvid;
    if (bvid == null || bvid.isEmpty || task.cid == null) return false;
    // 当前选择至少保留一种媒体流，损坏任务不能生成安全更新。
    return task.qualityId != null || task.audioQualityId != null;
  }

  /// 从任务永久字段重建一条分集上下文。
  BiliEpisodeInfo _episodeFromTask(DownloadTaskRecord task) {
    // BVID 与 CID 是重新请求播放清单的必要标识。
    final bvid = task.bvid;
    // CID 对应当前分集的视频轨道。
    final cid = task.cid;
    if (bvid == null || bvid.isEmpty || cid == null) {
      throw StateError('任务缺少 BVID 或 CID：${task.taskId}');
    }
    // 优先使用解析时保存的内容类型，旧任务按 EP ID 推断。
    final contentType =
        task.contentType == BiliContentType.pgc.name || task.epid != null
        ? BiliContentType.pgc
        : BiliContentType.ugc;
    // 返回不依赖网络的分集上下文。
    return BiliEpisodeInfo(
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
  }
}
