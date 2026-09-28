import '../../features/downloads/application/queue/download_task_plan.dart';
import '../../features/downloads/application/runtime/expired_media_url_resolver.dart';
import '../../features/downloads/data/download_task_repository.dart';
import '../../features/downloads/domain/download_task_phase.dart';
import 'bilibili_parser_service.dart';
import 'models/bili_dash_manifest.dart';
import 'models/bili_media_info.dart';

/// 使用持久化 BVID、CID 和清晰度重新请求过期 DASH 地址。
final class BiliExpiredMediaUrlResolver implements ExpiredMediaUrlResolver {
  /// 注入解析服务和下载任务仓库。
  const BiliExpiredMediaUrlResolver(this._parser, this._repository);

  /// 负责重新请求最新 DASH 清单和 CDN 请求头。
  final BilibiliParserService _parser;

  /// 负责读取任务选择和失败分流临时路径。
  final DownloadTaskRepository _repository;

  /// 只重新创建指定视频或音频分流。
  @override
  Future<ResolvedMediaSource> refresh({
    required String taskId,
    required DownloadStreamKind kind,
  }) async {
    // 主任务保存了重新请求播放地址所需的内容标识和用户选择。
    final task = await _repository.findTask(taskId);
    if (task == null) throw StateError('Unknown download task: $taskId');
    // BVID 和 CID 缺失时无法安全推断原始分集。
    final bvid = task.bvid;
    final cid = task.cid;
    if (bvid == null || bvid.isEmpty || cid == null) {
      throw StateError('Task $taskId has no BVID or CID for URL refresh.');
    }
    // 查找失败分流以复用原临时文件路径。
    final streams = await _repository.loadStreams(taskId);
    // 每个任务的同类型分流理论上仅有一条。
    final matchingStreams = streams.where((stream) => stream.kind == kind);
    if (matchingStreams.length != 1) {
      throw StateError('Task $taskId has invalid ${kind.name} stream count.');
    }
    // PGC 任务持久化 EP ID，普通投稿没有 EP ID。
    final contentType = task.epid == null
        ? BiliContentType.ugc
        : BiliContentType.pgc;
    // 从任务快照重建加载 DASH 清单所需的最小分集对象。
    final episode = BiliEpisodeInfo(
      contentType: contentType,
      bvid: bvid,
      cid: cid,
      index: task.partIndex,
      title: task.title,
      duration: Duration(milliseconds: task.durationMilliseconds ?? 0),
      episodeId: task.epid,
    );
    // 重新请求播放接口获得新的短期 CDN 地址。
    final manifest = await _parser.loadDashManifest(episode);
    // 仅视频分流需要恢复用户原编码偏好。
    final preferredCodec = kind == DownloadStreamKind.video
        ? _videoCodecFromName(task.videoCodec ?? matchingStreams.single.codec)
        : null;
    // 创建同路径、同类型但使用新 URL 和新 Cookie 请求头的分流。
    return _parser.createMediaSource(
      episode: episode,
      manifest: manifest,
      kind: kind,
      temporaryPath: matchingStreams.single.temporaryPath,
      qualityId: task.qualityId,
      audioQualityId: task.audioQualityId,
      preferredCodec: preferredCodec,
    );
  }

  /// 把数据库中的编码名称转换为解析器枚举。
  BiliVideoCodec? _videoCodecFromName(String? name) {
    // 未保存编码偏好时让清单选择当前质量的最佳兼容流。
    if (name == null || name.isEmpty) return null;
    // 枚举名称由创建下载计划时写入，未知旧值安全回退为空偏好。
    for (final codec in BiliVideoCodec.values) {
      if (codec.name == name.toLowerCase()) return codec;
    }
    // 旧数据或未来编码名称不应阻止地址刷新。
    return null;
  }
}
