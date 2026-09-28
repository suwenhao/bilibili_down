import '../bili_json.dart';

/// B 站内容属于普通投稿还是 PGC 番剧。
enum BiliContentType {
  /// 普通视频、多 P 或 UGC 合集。
  ugc,

  /// 番剧、影视或课程等 PGC 剧集。
  pgc,
}

/// 解析页展示的一条普通视频分 P 或剧集分集。
final class BiliEpisodeInfo {
  /// 创建可进一步请求 DASH 播放流的分集信息。
  const BiliEpisodeInfo({
    required this.contentType,
    required this.bvid,
    required this.cid,
    required this.index,
    required this.title,
    required this.duration,
    this.episodeId,
    this.seasonId,
    this.coverUrl,
    this.width,
    this.height,
    this.publishedAt,
    this.pageNumber,
  });

  /// 普通投稿或 PGC 类型。
  final BiliContentType contentType;

  /// 分集对应的 BVID。
  final String bvid;

  /// 获取播放地址必需的 CID。
  final int cid;

  /// 在当前集合中的一基序号。
  final int index;

  /// 分 P 或剧集标题。
  final String title;

  /// 分集总时长。
  final Duration duration;

  /// PGC 分集 EP ID。
  final int? episodeId;

  /// PGC 季度 SS ID。
  final int? seasonId;

  /// 分集独立封面地址。
  final String? coverUrl;

  /// 视频原始宽度。
  final int? width;

  /// 视频原始高度。
  final int? height;

  /// 分集发布时间。
  final DateTime? publishedAt;

  /// 普通视频同一 BV 内的分 P 编号。
  final int? pageNumber;

  /// 返回“宽x高”分辨率文本，信息缺失时为空。
  String? get resolutionLabel {
    // 宽高必须同时有效才构成分辨率。
    if ((width ?? 0) <= 0 || (height ?? 0) <= 0) return null;
    // 使用截图设计约定的不带空格格式。
    return '${width}x$height';
  }
}

/// 解析页展示的视频或剧集基础信息和分集列表。
final class BiliMediaInfo {
  /// 创建一个已完成基础信息解析的媒体集合。
  const BiliMediaInfo({
    required this.contentType,
    required this.title,
    required this.episodes,
    this.coverUrl,
    this.description,
    this.publisherName,
    this.publisherId,
    this.publishedAt,
    this.seasonId,
  });

  /// 普通投稿或 PGC 类型。
  final BiliContentType contentType;

  /// 视频标题或季度标题。
  final String title;

  /// 集合封面地址。
  final String? coverUrl;

  /// 视频简介或季度评价。
  final String? description;

  /// UP 主或内容发布者名称。
  final String? publisherName;

  /// UP 主数字 ID。
  final int? publisherId;

  /// 视频或季度首发时间。
  final DateTime? publishedAt;

  /// PGC 季度 SS ID。
  final int? seasonId;

  /// 可供用户选择的分 P 或剧集列表。
  final List<BiliEpisodeInfo> episodes;
}

/// 从普通视频 view 接口解析基础信息、多 P 和 UGC 合集。
BiliMediaInfo parseUgcMediaInfo(Map<String, Object?> data) {
  // 读取当前视频公共字段。
  final currentBvid = biliJsonString(data['bvid']);
  final mainTitle = biliJsonString(data['title']);
  final owner = data['owner'] is Map
      ? biliJsonObject(data['owner'], 'owner')
      : const <String, Object?>{};
  // 优先解析 UGC 合集 sections，缺失时退回当前视频 pages。
  final ugcSeason = data['ugc_season'] is Map
      ? biliJsonObject(data['ugc_season'], 'ugc_season')
      : null;
  final collectionEpisodes = <BiliEpisodeInfo>[];
  if (ugcSeason != null) {
    // 按接口 sections 和 episodes 顺序展开合集。
    final sections = biliJsonObjectList(
      ugcSeason['sections'],
      'ugc_season.sections',
    );
    for (final section in sections) {
      final episodes = biliJsonObjectList(
        section['episodes'],
        'ugc_season.sections.episodes',
      );
      for (final episode in episodes) {
        // UGC 合集里的 episode 可能是一个多 P 投稿，真实可下载条目需要继续展开 pages。
        final pages = biliJsonObjectList(episode['pages'], 'episode.pages');
        final arc = episode['arc'] is Map
            ? biliJsonObject(episode['arc'], 'episode.arc')
            : const <String, Object?>{};
        // 老接口或少数合集可能没有 pages，此时退回 episode 自身的单集字段。
        final pageObjects = pages.isNotEmpty
            ? pages
            : <Map<String, Object?>>[
                episode['page'] is Map
                    ? biliJsonObject(episode['page'], 'episode.page')
                    : episode,
              ];
        for (final page in pageObjects) {
          final dimension = page['dimension'] is Map
              ? biliJsonObject(page['dimension'], 'episode.page.dimension')
              : const <String, Object?>{};
          // CID 和 BVID 是后续播放流解析的必需字段。
          final cid = biliJsonInt(page['cid'] ?? episode['cid']);
          final bvid = biliJsonString(episode['bvid']);
          if (cid == null || bvid.isEmpty) continue;
          // 使用集合中的稳定顺序创建分集，标题优先取真实分 P 名称。
          collectionEpisodes.add(
            BiliEpisodeInfo(
              contentType: BiliContentType.ugc,
              bvid: bvid,
              cid: cid,
              index: collectionEpisodes.length + 1,
              title: biliJsonString(
                page['part'] ??
                    page['title'] ??
                    episode['title'] ??
                    arc['title'],
                fallback: '第 ${collectionEpisodes.length + 1} 集',
              ),
              duration: Duration(
                seconds: biliJsonInt(page['duration'] ?? arc['duration']) ?? 0,
              ),
              coverUrl: biliJsonString(arc['pic']).nullIfEmpty,
              width: biliJsonInt(dimension['width']),
              height: biliJsonInt(dimension['height']),
              publishedAt: biliDateTimeFromSeconds(arc['pubdate']),
              pageNumber: biliJsonInt(page['page']) ?? 1,
            ),
          );
        }
      }
    }
  }
  // UGC 合集为空时解析当前 BVID 自身的多 P 页面。
  if (collectionEpisodes.isEmpty) {
    final pages = biliJsonObjectList(data['pages'], 'pages');
    for (final page in pages) {
      // 每一页必须包含 CID。
      final cid = biliJsonInt(page['cid']);
      if (cid == null || currentBvid.isEmpty) continue;
      // 读取每页独立分辨率。
      final dimension = page['dimension'] is Map
          ? biliJsonObject(page['dimension'], 'page.dimension')
          : const <String, Object?>{};
      // 构造与页面顺序一致的分集记录。
      collectionEpisodes.add(
        BiliEpisodeInfo(
          contentType: BiliContentType.ugc,
          bvid: currentBvid,
          cid: cid,
          index: biliJsonInt(page['page']) ?? collectionEpisodes.length + 1,
          title: biliJsonString(page['part'], fallback: mainTitle),
          duration: Duration(seconds: biliJsonInt(page['duration']) ?? 0),
          coverUrl: biliJsonString(data['pic']).nullIfEmpty,
          width: biliJsonInt(dimension['width']),
          height: biliJsonInt(dimension['height']),
          publishedAt: biliDateTimeFromSeconds(data['pubdate']),
          pageNumber:
              biliJsonInt(page['page']) ?? collectionEpisodes.length + 1,
        ),
      );
    }
  }
  // 返回解析页所需的集合级字段。
  return BiliMediaInfo(
    contentType: BiliContentType.ugc,
    title: biliJsonString(ugcSeason?['title'], fallback: mainTitle),
    coverUrl: biliJsonString(ugcSeason?['cover'] ?? data['pic']).nullIfEmpty,
    description: biliJsonString(
      ugcSeason?['intro'] ?? data['desc'],
    ).nullIfEmpty,
    publisherName: biliJsonString(owner['name']).nullIfEmpty,
    publisherId: biliJsonInt(owner['mid']),
    publishedAt: biliDateTimeFromSeconds(data['pubdate']),
    episodes: List<BiliEpisodeInfo>.unmodifiable(collectionEpisodes),
  );
}

/// 从 PGC season 接口解析季度信息和分集。
BiliMediaInfo parsePgcMediaInfo(Map<String, Object?> result) {
  // 读取季度 ID 和公共展示字段。
  final seasonId = biliJsonInt(result['season_id']);
  final collectionEpisodes = <BiliEpisodeInfo>[];
  // 主 episodes 与 section 可能重复，使用 EP ID 去重。
  final seenEpisodeIds = <int>{};
  final episodeObjects = <Map<String, Object?>>[
    ...biliJsonObjectList(result['episodes'], 'episodes'),
  ];
  // 附加篇、预告等分区继续追加到分集选择列表。
  final sections = biliJsonObjectList(result['section'], 'section');
  for (final section in sections) {
    episodeObjects.addAll(
      biliJsonObjectList(section['episodes'], 'section.episodes'),
    );
  }
  for (final episode in episodeObjects) {
    // EP ID 用于去重和 PGC 播放地址请求。
    final episodeId = biliJsonInt(episode['id'] ?? episode['ep_id']);
    final cid = biliJsonInt(episode['cid']);
    final bvid = biliJsonString(episode['bvid']);
    if (episodeId == null || cid == null || bvid.isEmpty) continue;
    // 同一分集在主列表与 section 重复时只保留第一次。
    if (!seenEpisodeIds.add(episodeId)) continue;
    // PGC dimension 位于分集根对象。
    final dimension = episode['dimension'] is Map
        ? biliJsonObject(episode['dimension'], 'episode.dimension')
        : const <String, Object?>{};
    // PGC season 接口的 duration 固定以毫秒表示。
    final rawDuration = biliJsonInt(episode['duration']) ?? 0;
    final duration = Duration(milliseconds: rawDuration);
    // 优先使用完整副标题，缺失时使用集数标题。
    final shortTitle = biliJsonString(episode['title']);
    final longTitle = biliJsonString(episode['long_title']);
    collectionEpisodes.add(
      BiliEpisodeInfo(
        contentType: BiliContentType.pgc,
        bvid: bvid,
        cid: cid,
        episodeId: episodeId,
        seasonId: seasonId,
        index: collectionEpisodes.length + 1,
        title: longTitle.isNotEmpty ? longTitle : shortTitle,
        duration: duration,
        coverUrl: biliJsonString(episode['cover']).nullIfEmpty,
        width: biliJsonInt(dimension['width']),
        height: biliJsonInt(dimension['height']),
        publishedAt: biliDateTimeFromSeconds(episode['pub_time']),
      ),
    );
  }
  // 返回解析页所需的季度级信息。
  return BiliMediaInfo(
    contentType: BiliContentType.pgc,
    title: biliJsonString(
      result['season_title'] ?? result['title'],
      fallback: '未命名剧集',
    ),
    coverUrl: biliJsonString(result['cover']).nullIfEmpty,
    description: biliJsonString(result['evaluate']).nullIfEmpty,
    publishedAt: collectionEpisodes.isEmpty
        ? null
        : collectionEpisodes.first.publishedAt,
    seasonId: seasonId,
    episodes: List<BiliEpisodeInfo>.unmodifiable(collectionEpisodes),
  );
}

/// 为 JSON 解析提供空字符串转空值能力。
extension _EmptyStringExtension on String {
  /// 空字符串返回 null，非空字符串保持原值。
  String? get nullIfEmpty => isEmpty ? null : this;
}
