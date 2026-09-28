import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../data/download_task_repository.dart';
import '../../domain/stored_dash_options.dart';

/// 保存任务卡从本地候选下拉菜单改选的音质和画质。
final downloadTaskQualityServiceProvider = Provider<DownloadTaskQualityService>(
  (Ref ref) {
    // 质量候选已随任务流到达页面，服务只负责持久化用户选择。
    return DownloadTaskQualityService(
      ref.watch(downloadTaskRepositoryProvider),
    );
  },
);

/// 持久化任务卡本地质量选择。
final class DownloadTaskQualityService {
  /// 创建任务质量保存服务。
  const DownloadTaskQualityService(this._repository);

  /// 负责更新任务快照。
  final DownloadTaskRepository _repository;

  /// 保存任务选中的视频画质、编码和预计大小。
  Future<void> selectVideo(String taskId, StoredVideoOption option) {
    // 选项直接来自任务入库清单，无需再次查询或请求网络。
    return _repository.updateVideoSelection(
      taskId,
      qualityId: option.qualityId,
      qualityLabel: option.qualityLabel,
      videoCodec: option.codec.name,
      estimatedVideoSizeBytes: option.estimatedSizeBytes,
    );
  }

  /// 取消任务视频流并把任务切换为纯音频。
  Future<void> clearVideo(String taskId) {
    // 仓库会原子校验音频仍然存在，并同步调整输出扩展名。
    return _repository.updateVideoSelection(
      taskId,
      qualityId: null,
      qualityLabel: null,
      videoCodec: null,
      estimatedVideoSizeBytes: null,
    );
  }

  /// 保存任务选中的音频质量、编码和预计大小。
  Future<void> selectAudio(String taskId, StoredAudioOption option) {
    // 组合任务卡使用的音质和编码文案后一次写入数据库。
    return _repository.updateAudioSelection(
      taskId,
      audioQualityId: option.qualityId,
      audioCodec: '${option.qualityLabel} | ${option.codec}',
      estimatedAudioSizeBytes: option.estimatedSizeBytes,
    );
  }

  /// 取消任务音频流并把任务切换为无声视频。
  Future<void> clearAudio(String taskId) {
    // 仓库会原子校验视频仍然存在，避免创建空下载任务。
    return _repository.updateAudioSelection(
      taskId,
      audioQualityId: null,
      audioCodec: null,
      estimatedAudioSizeBytes: null,
    );
  }
}
