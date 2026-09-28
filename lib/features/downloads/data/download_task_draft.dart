import '../domain/download_task_phase.dart';

/// 创建下载任务时使用的业务参数，避免界面直接依赖 Drift Companion。
final class DownloadTaskDraft {
  /// 创建一条尚未完成解析的下载任务。
  const DownloadTaskDraft({
    required this.taskId,
    required this.sourceInput,
    required this.title,
    this.publisherName,
    this.publisherId,
    this.collectionTitle,
    this.contentType,
    this.description,
    this.resolutionLabel,
    this.publishedAt,
    this.bvid,
    this.cid,
    this.epid,
    this.coverUrl,
    this.partIndex = 1,
    this.qualityId,
    this.qualityLabel,
    this.videoCodec,
    this.audioCodec,
    this.audioQualityId,
    this.estimatedVideoSizeBytes,
    this.estimatedAudioSizeBytes,
    this.dashOptionsJson,
    this.extraResourcesJson = '[]',
    this.durationMilliseconds,
    this.temporaryDirectory,
    this.outputPath,
    this.downloadBackend,
    this.phase = DownloadTaskPhase.queued,
  });

  /// 业务任务稳定 ID。
  final String taskId;

  /// 用户输入的原始链接或编号。
  final String sourceInput;

  /// 当前已知的视频或分集标题。
  final String title;

  /// UP 主或内容发布者名称。
  final String? publisherName;

  /// UP 主数字 ID。
  final int? publisherId;

  /// 合集、季度或视频主标题。
  final String? collectionTitle;

  /// 普通投稿或 PGC 内容类型名称。
  final String? contentType;

  /// 视频或合集简介。
  final String? description;

  /// 原始分辨率文本。
  final String? resolutionLabel;

  /// 视频或分集发布时间。
  final DateTime? publishedAt;

  /// 普通视频 BVID。
  final String? bvid;

  /// 选中分集 CID。
  final int? cid;

  /// 番剧分集 EP ID。
  final int? epid;

  /// 封面远程地址。
  final String? coverUrl;

  /// 多 P 或合集中的显示顺序。
  final int partIndex;

  /// B 站清晰度代码。
  final int? qualityId;

  /// 清晰度显示名称。
  final String? qualityLabel;

  /// 视频编码名称。
  final String? videoCodec;

  /// 音频编码或音质名称。
  final String? audioCodec;

  /// 实际选中的 B 站 DASH 音频质量代码。
  final int? audioQualityId;

  /// 选中视频流在解析时计算的预计字节数。
  final int? estimatedVideoSizeBytes;

  /// 选中音频流在解析时计算的预计字节数。
  final int? estimatedAudioSizeBytes;

  /// 不含临时 URL 的完整 DASH 候选流 JSON。
  final String? dashOptionsJson;

  /// 随主视频任务保存的附加资源 JSON 字符串数组。
  final String extraResourcesJson;

  /// 视频总时长毫秒数。
  final int? durationMilliseconds;

  /// 当前任务临时目录。
  final String? temporaryDirectory;

  /// 最终输出文件路径。
  final String? outputPath;

  /// 当前任务选用的下载后端。
  final PersistedDownloadBackend? downloadBackend;

  /// 任务初始阶段。
  final DownloadTaskPhase phase;
}

/// 保存一条 DASH 视频或音频分流时使用的参数。
final class DownloadStreamDraft {
  /// 创建媒体分流记录。
  const DownloadStreamDraft({
    required this.streamId,
    required this.taskId,
    required this.kind,
    required this.remoteUrl,
    required this.temporaryPath,
    this.codec,
    this.engineTaskId,
    this.phase = DownloadStreamPhase.pending,
  });

  /// 内部稳定分流 ID。
  final String streamId;

  /// 所属业务任务 ID。
  final String taskId;

  /// 视频或音频分流类型。
  final DownloadStreamKind kind;

  /// 当前有效的媒体下载地址。
  final String remoteUrl;

  /// 媒体编码或音质名称。
  final String? codec;

  /// 分流本地临时路径。
  final String temporaryPath;

  /// aria2 GID 或系统下载任务 ID。
  final String? engineTaskId;

  /// 分流初始状态。
  final DownloadStreamPhase phase;
}

/// 注册任务本地文件产物时使用的参数。
final class DownloadArtifactDraft {
  /// 创建文件产物记录。
  const DownloadArtifactDraft({
    required this.taskId,
    required this.kind,
    required this.path,
    this.sizeBytes,
    this.checksum,
    this.retained = false,
  });

  /// 所属业务任务 ID。
  final String taskId;

  /// 文件产物类型。
  final DownloadArtifactKind kind;

  /// 文件绝对路径。
  final String path;

  /// 文件大小。
  final int? sizeBytes;

  /// 可选完整性摘要。
  final String? checksum;

  /// 任务完成后是否保留文件。
  final bool retained;
}
