import '../../../settings/domain/app_settings.dart';
import '../../domain/download_extra_resource.dart';

/// 批量设置对主任务音视频流的快捷策略。
enum DownloadBatchMediaMode {
  /// 同时保留视频和音频。
  audioVideo,

  /// 只保留视频流，生成无声视频。
  videoOnly,

  /// 只保留音频流，生成音频文件。
  audioOnly,
}

/// 自定义批量弹窗的返回结果基类。
sealed class DownloadCustomBatchResult {
  /// 子类只用于区分批量设置和批量直下两类动作。
  const DownloadCustomBatchResult();
}

/// 批量修改待下载任务本地选择的结果。
final class DownloadBatchSettingsResult extends DownloadCustomBatchResult {
  /// 保存批量设置页签中用户确认的所有选择。
  const DownloadBatchSettingsResult({
    required this.resources,
    required this.audioQuality,
    required this.videoQuality,
    required this.mediaMode,
  });

  /// 要覆盖写入每个待下载主任务的附加资源集合。
  final Set<DownloadExtraResource> resources;

  /// 目标音质；纯视频模式下不会使用。
  final DefaultAudioQuality audioQuality;

  /// 目标画质；纯音频模式下不会使用。
  final DefaultVideoQuality videoQuality;

  /// 决定批量保留音视频、纯视频或纯音频。
  final DownloadBatchMediaMode mediaMode;
}

/// 批量直接导出附加资源的结果。
final class DownloadBatchDirectExportResult extends DownloadCustomBatchResult {
  /// 保存直接下载页签选中的附加资源集合。
  const DownloadBatchDirectExportResult({required this.resources});

  /// 只包含封面、弹幕和字幕等不需要主下载流的资源。
  final Set<DownloadExtraResource> resources;
}
