import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/logging/app_debug_log.dart';
import '../../../../services/bilibili/models/bili_dash_manifest.dart';
import '../../../settings/domain/app_settings.dart';
import '../../data/download_task_repository.dart';
import '../../domain/download_extra_resource.dart';
import '../../domain/download_task_phase.dart';
import '../../domain/stored_dash_options.dart';

/// 提供账号降级后待下载任务 DASH 候选的本地裁剪能力。
final pendingDashOptionDowngradeServiceProvider =
    Provider<PendingDashOptionDowngradeService>((Ref ref) {
      // 只依赖下载任务仓库，账号模块不需要理解任务表和 DASH JSON 结构。
      return PendingDashOptionDowngradeService(
        ref.watch(downloadTaskRepositoryProvider),
      );
    });

/// 按游客权限修正待下载任务的本地 DASH 候选与当前选择。
final class PendingDashOptionDowngradeService {
  /// 创建待下载 DASH 候选维护服务。
  const PendingDashOptionDowngradeService(this._repository);

  /// 负责读取和批量写入待下载任务。
  final DownloadTaskRepository _repository;

  /// 游客状态默认选中的音频质量。
  static const DefaultAudioQuality _guestDefaultAudioQuality =
      DefaultAudioQuality.low64;

  /// 游客状态最高仍允许展示和选择的音频质量。
  static const DefaultAudioQuality _guestMaximumAudioQuality =
      DefaultAudioQuality.high192;

  /// 游客状态默认选中的视频画质。
  static const DefaultVideoQuality _guestDefaultVideoQuality =
      DefaultVideoQuality.p360;

  /// 游客状态最高仍允许展示和选择的视频画质。
  static const DefaultVideoQuality _guestMaximumVideoQuality =
      DefaultVideoQuality.p480;

  /// 将仍未开始的音视频任务候选裁剪到未登录账号可用范围。
  Future<int> downgradeQueuedTasksForLoggedOut() async {
    // 只读取待下载和失败待重试任务，活动任务正在使用真实 URL，不能中途改写计划。
    final tasks = await _repository.loadTasksByPhases(const <DownloadTaskPhase>[
      DownloadTaskPhase.queued,
      DownloadTaskPhase.failed,
    ]);
    // 维护服务先在内存完成全部解析和筛选，再交给仓库执行单次事务写入。
    final updates = <DownloadTaskDashSelectionUpdate>[];
    // 记录无法修正的损坏或异常任务数量，便于导出日志时定位。
    var skipped = 0;
    for (final task in tasks) {
      // 旧版独立附加资源任务不参与普通 DASH 质量候选修正。
      if (downloadExtraResourceFromCode(task.contentType) != null) continue;
      // 没有本地候选清单的旧任务无法可靠裁剪，保持原样等待重新解析。
      final source = task.dashOptionsJson;
      if (source == null || source.trim().isEmpty) continue;
      try {
        // 从数据库 JSON 恢复解析时保存的候选元数据。
        final options = StoredDashOptions.decode(source);
        // 移除登录或大会员才会出现的高质量候选。
        final downgradedOptions = _guestOptions(options);
        // 当前任务是否仍然需要视频流。
        final includeVideo = task.qualityId != null;
        // 当前任务是否仍然需要音频流。
        final includeAudio = task.audioQualityId != null;
        // 两种流都为空代表旧数据损坏，不能写入空下载计划。
        if (!includeVideo && !includeAudio) {
          skipped++;
          continue;
        }
        // 选择游客默认视频画质；纯音频任务保持无视频。
        final selectedVideo = includeVideo
            ? downgradedOptions.selectVideo(
                qualityId: _guestDefaultVideoQuality.qualityId,
                preferredCodec: _videoCodecFromName(task.videoCodec),
              )
            : null;
        // 选择游客默认音质；无声视频任务保持无音频。
        final selectedAudio = includeAudio
            ? downgradedOptions.selectAudio(
                qualityId: _guestDefaultAudioQuality.dashId,
              )
            : null;
        // 序列化裁剪后的候选，后续任务卡下拉菜单只会看到游客可用范围。
        final dashOptionsJson = downgradedOptions.encode();
        // 本地选择没有发生变化时跳过写库，减少退出登录时的列表刷新。
        if (!_hasTaskChanged(
          task: task,
          dashOptionsJson: dashOptionsJson,
          selectedVideo: selectedVideo,
          selectedAudio: selectedAudio,
          durationMilliseconds: downgradedOptions.durationMilliseconds,
        )) {
          continue;
        }
        // 构造一次性更新记录，真正写库由仓库统一事务完成。
        updates.add((
          taskId: task.taskId,
          dashOptionsJson: dashOptionsJson,
          qualityId: selectedVideo?.qualityId,
          qualityLabel: selectedVideo?.qualityLabel,
          videoCodec: selectedVideo?.codec.name,
          audioCodec: selectedAudio == null
              ? null
              : '${selectedAudio.qualityLabel} | ${selectedAudio.codec}',
          audioQualityId: selectedAudio?.qualityId,
          estimatedVideoSizeBytes: selectedVideo?.estimatedSizeBytes,
          estimatedAudioSizeBytes: selectedAudio?.estimatedSizeBytes,
          durationMilliseconds: downgradedOptions.durationMilliseconds > 0
              ? downgradedOptions.durationMilliseconds
              : task.durationMilliseconds,
        ));
      } on Object catch (error) {
        // 单条候选损坏不能阻止其他任务降级，保留日志给诊断导出。
        skipped++;
        AppDebugLog.download(
          'Guest DASH downgrade skipped task=${task.taskId} error=$error',
        );
      }
    }
    // 统一写入所有需要修正的任务，避免一条条写库造成额外刷新。
    final updated = await _repository.updateQueuedDashSelections(updates);
    AppDebugLog.download(
      'Guest DASH downgrade completed updated=$updated skipped=$skipped',
    );
    // 返回真实更新数量，账号流程可用于补充日志。
    return updated;
  }

  /// 根据游客权限裁剪完整 DASH 候选清单。
  StoredDashOptions _guestOptions(StoredDashOptions options) {
    // 视频保留 360P 和 480P，720P 及以上登录档位从本地候选中移除。
    final videos = options.videos
        .where(_isGuestVideoOption)
        .toList(growable: false);
    // 音频保留 64K、132K 和 192K，杜比与 Hi-Res 从本地候选中移除。
    final audios = options.audios
        .where(_isGuestAudioOption)
        .toList(growable: false);
    // 至少保留裁剪后的候选和原始时长，后续选择仍复用领域对象能力。
    return StoredDashOptions(
      durationMilliseconds: options.durationMilliseconds,
      videos: videos,
      audios: audios,
    );
  }

  /// 判断视频候选是否属于未登录账号仍可使用的范围。
  bool _isGuestVideoOption(StoredVideoOption option) {
    // 未识别质量 ID 不写入游客候选，避免未来新增高档位漏过裁剪。
    final quality = _videoQualityFromId(option.qualityId);
    if (quality == null) return false;
    // 游客最高只保留到 480P。
    return quality.rank <= _guestMaximumVideoQuality.rank;
  }

  /// 判断音频候选是否属于未登录账号仍可使用的范围。
  bool _isGuestAudioOption(StoredAudioOption option) {
    // 未识别音质 ID 不写入游客候选，避免特殊会员音轨继续显示。
    final quality = _audioQualityFromId(option.qualityId);
    if (quality == null) return false;
    // 游客最高保留到 192K。
    return quality.rank <= _guestMaximumAudioQuality.rank;
  }

  /// 判断一条任务的候选或当前选择是否需要重新写库。
  bool _hasTaskChanged({
    required DownloadTaskRecord task,
    required String dashOptionsJson,
    required StoredVideoOption? selectedVideo,
    required StoredAudioOption? selectedAudio,
    required int durationMilliseconds,
  }) {
    // 候选清单变化会直接影响任务卡下拉菜单，需要写库。
    if (task.dashOptionsJson != dashOptionsJson) return true;
    // 视频质量或编码变化会影响后续启动下载时请求的 DASH 流。
    if (task.qualityId != selectedVideo?.qualityId ||
        task.qualityLabel != selectedVideo?.qualityLabel ||
        task.videoCodec != selectedVideo?.codec.name ||
        task.estimatedVideoSizeBytes != selectedVideo?.estimatedSizeBytes) {
      return true;
    }
    // 音频质量变化同样需要同步到后续下载计划。
    final selectedAudioCodec = selectedAudio == null
        ? null
        : '${selectedAudio.qualityLabel} | ${selectedAudio.codec}';
    if (task.audioQualityId != selectedAudio?.qualityId ||
        task.audioCodec != selectedAudioCodec ||
        task.estimatedAudioSizeBytes != selectedAudio?.estimatedSizeBytes) {
      return true;
    }
    // 原清单时长缺失或变化时一并同步，保持合并进度估算准确。
    if (durationMilliseconds > 0 &&
        task.durationMilliseconds != durationMilliseconds) {
      return true;
    }
    // 没有任何差异时跳过数据库写入。
    return false;
  }

  /// 将数据库保存的编码名称恢复成稳定枚举。
  BiliVideoCodec? _videoCodecFromName(String? name) {
    // 空值代表自动选择，交给 StoredDashOptions 使用兼容优先级。
    if (name == null || name.isEmpty) return null;
    // 枚举名称由入队流程写入，逐项比较可以兼容未来新增编码。
    for (final codec in BiliVideoCodec.values) {
      if (codec.name == name.toLowerCase()) return codec;
    }
    // 未知旧值回退自动选择，不能阻止退出登录。
    return null;
  }

  /// 按 B 站视频质量 ID 查找设置枚举。
  DefaultVideoQuality? _videoQualityFromId(int qualityId) {
    // 设置枚举是当前应用认识的质量白名单。
    for (final quality in DefaultVideoQuality.values) {
      if (quality.qualityId == qualityId) return quality;
    }
    // 未知质量由调用方按高风险候选处理。
    return null;
  }

  /// 按 B 站音频质量 ID 查找设置枚举。
  DefaultAudioQuality? _audioQualityFromId(int qualityId) {
    // 设置枚举是当前应用认识的音质白名单。
    for (final quality in DefaultAudioQuality.values) {
      if (quality.dashId == qualityId) return quality;
    }
    // 未知音质由调用方按高风险候选处理。
    return null;
  }
}
