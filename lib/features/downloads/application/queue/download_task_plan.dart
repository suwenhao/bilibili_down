import '../../domain/download_task_phase.dart';

/// 一条已经解析完成、可以提交下载引擎的媒体分流。
final class ResolvedMediaSource {
  /// 创建视频或音频分流下载参数。
  const ResolvedMediaSource({
    required this.kind,
    required this.url,
    required this.temporaryPath,
    this.backupUrls = const <Uri>[],
    this.codec,
    this.headers = const <String, String>{},
  });

  /// 当前来源是视频流还是音频流。
  final DownloadStreamKind kind;

  /// B 站接口返回的临时媒体地址。
  final Uri url;

  /// 主 CDN 连接失败时可按顺序尝试的 B 站备用地址。
  final List<Uri> backupUrls;

  /// 分流下载完成后的本地临时路径。
  final String temporaryPath;

  /// 媒体编码或音质名称。
  final String? codec;

  /// CDN 请求所需的 User-Agent、Referer 和可选 Cookie。
  final Map<String, String> headers;
}

/// 一个业务任务对应的一条或两条媒体分流下载计划。
final class ResolvedDownloadPlan {
  /// 创建音频、视频或有声视频下载计划。
  ResolvedDownloadPlan({
    required this.taskId,
    this.video,
    this.audio,
    this.resource,
  }) {
    // 三类来源至少选择一项，空计划无法产生下载结果。
    if (video == null && audio == null && resource == null) {
      throw ArgumentError('下载计划至少需要一个来源。');
    }
    // 视频参数必须明确标记为 video，防止合并时交换输入。
    if (video != null && video!.kind != DownloadStreamKind.video) {
      throw ArgumentError.value(video!.kind, 'video', '必须是视频流');
    }
    // 音频参数必须明确标记为 audio。
    if (audio != null && audio!.kind != DownloadStreamKind.audio) {
      throw ArgumentError.value(audio!.kind, 'audio', '必须是音频流');
    }
    // 附加资源必须明确标记为 resource。
    if (resource != null && resource!.kind != DownloadStreamKind.resource) {
      throw ArgumentError.value(resource!.kind, 'resource', '必须是附加资源');
    }
    // 附加资源是独立任务，不能和音视频分流混合提交。
    if (resource != null && (video != null || audio != null)) {
      throw ArgumentError('附加资源不能与音视频分流放在同一任务。');
    }
    // 两条分流不能写入同一临时文件。
    if (video != null &&
        audio != null &&
        video!.temporaryPath == audio!.temporaryPath) {
      throw ArgumentError('视频流和音频流不能使用同一临时路径。');
    }
  }

  /// 已经存在于 Drift 主表中的业务任务 ID。
  final String taskId;

  /// DASH 视频分流参数。
  final ResolvedMediaSource? video;

  /// DASH 音频分流参数。
  final ResolvedMediaSource? audio;

  /// 封面、弹幕或字幕的独立下载来源。
  final ResolvedMediaSource? resource;

  /// 按固定视频、音频、附加资源顺序返回当前实际来源。
  List<ResolvedMediaSource> get sources => <ResolvedMediaSource>[
    ?video,
    ?audio,
    ?resource,
  ];
}
