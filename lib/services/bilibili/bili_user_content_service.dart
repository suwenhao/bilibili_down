import 'package:dio/dio.dart';

import '../../core/network/bili_network_client.dart';
import 'bili_api_exception.dart';
import 'bili_json.dart';
import 'wbi_signer.dart';

/// 用户中心中展示的视频来源类型。
enum BiliUserVideoSource {
  /// 当前登录账号的观看历史。
  history,

  /// 指定用户空间的投稿。
  upload,

  /// 指定收藏夹中的视频。
  favorite,

  /// 指定 UP 主合集中的视频。
  collection,

  /// 已展开到某个稿件的单个分 P。
  episode,

  /// 用户公开的最近点赞视频。
  liked,
}

/// 观看历史搜索的时间范围。
enum BiliHistorySearchTimeRange {
  /// 不限制观看时间。
  all,

  /// 今天零点之后。
  today,

  /// 昨天零点到今天零点前。
  yesterday,

  /// 近七天。
  week,
}

/// 观看历史搜索的视频时长范围。
enum BiliHistorySearchDurationRange {
  /// 不限制视频时长。
  all,

  /// 十分钟以下。
  underTenMinutes,

  /// 十到三十分钟。
  tenToThirtyMinutes,

  /// 三十到六十分钟。
  thirtyToSixtyMinutes,

  /// 六十分钟以上。
  overSixtyMinutes,
}

/// 观看历史搜索的播放设备来源。
enum BiliHistorySearchDevice {
  /// 全部设备。
  all,

  /// PC 网页端。
  pc,

  /// 手机端。
  phone,

  /// 平板端。
  tablet,

  /// TV 端。
  tv,
}

/// 视频分 P 元信息预取进度回调。
typedef BiliVideoResolveProgress = void Function(int current, int total);

/// 用户中心里可以进入解析流程的一条视频。
final class BiliUserVideoItem {
  /// 创建一个已经归一化的用户视频条目。
  const BiliUserVideoItem({
    required this.source,
    required this.title,
    required this.coverUrl,
    required this.authorName,
    required this.duration,
    required this.publishedAt,
    this.bvid,
    this.aid,
    this.description,
    this.pageCount,
    this.targetCid,
    this.targetPageNumber,
    this.requiresDetailExpansion = false,
    this.resolvedPages,
    this.historyKey,
  });

  /// 条目来自历史、稿件、收藏或点赞。
  final BiliUserVideoSource source;

  /// 普通稿件的 BV 号，缺失时只能用 AV 回退。
  final String? bvid;

  /// 普通稿件的 AV 号，点赞 APP 兼容数据可能只提供该值。
  final int? aid;

  /// 视频标题。
  final String title;

  /// 视频封面地址。
  final String? coverUrl;

  /// UP 主昵称。
  final String? authorName;

  /// 视频简介，列表中只展示一行。
  final String? description;

  /// 同一稿件中的分 P 数量；为空表示当前接口没有提供。
  final int? pageCount;

  /// 分 P 详情页中用于精确匹配下载条目的 CID。
  final int? targetCid;

  /// 分 P 详情页中用于展示和匹配的一基 P 号。
  final int? targetPageNumber;

  /// 列表接口明确标记该稿件需要展开详情才能看到完整分 P。
  final bool requiresDetailExpansion;

  /// 预取 view 接口后得到的分 P 明细，进入详情页时可直接复用。
  final List<BiliUserVideoItem>? resolvedPages;

  /// B 站观看历史删除接口需要的条目标识，例如 `archive_123`。
  final String? historyKey;

  /// 视频总时长。
  final Duration duration;

  /// 发布时间或观看时间。
  final DateTime? publishedAt;

  /// B 站接口用固定标题标记已失效内容，这类条目需要展示但不能继续解析。
  bool get isUnavailable => title.trim() == '已失效视频';

  /// 当前条目是否允许进入解析或批量下载流程。
  bool get canParse => !isUnavailable && parseInput != null;

  /// 是否需要进入解析页查看分 P 或合集明细，不能作为单集直接批量入队。
  bool get requiresDetailNavigation {
    if (!canParse) return false;
    final resolvedPageCount = pageCount;
    // 已经展开到分 P 级别的条目可以直接入队。
    if (source == BiliUserVideoSource.episode) return false;
    // 页数未知或列表标记需要展开时，先进入详情页确认分 P，避免误下第一 P。
    if (requiresDetailExpansion) return true;
    return resolvedPageCount != null && resolvedPageCount > 1;
  }

  /// 当前条目是否可以被列表批量下载直接处理。
  bool get canQueueDirectly => canParse && !requiresDetailNavigation;

  /// 用 view 接口补齐后的页数和总时长创建新条目。
  BiliUserVideoItem withResolvedPageMetadata({
    required int pageCount,
    required Duration duration,
    List<BiliUserVideoItem>? resolvedPages,
  }) {
    // 只有页数已知后才允许单 P 直接入队；多 P 继续保持详情入口。
    final resolvedDuration = duration.inSeconds > 0 ? duration : this.duration;
    // 分 P 明细来自 view 接口，挂在父条目上供详情页复用。
    final resolvedPageItems = resolvedPages == null
        ? this.resolvedPages
        : List<BiliUserVideoItem>.unmodifiable(resolvedPages);
    return BiliUserVideoItem(
      source: source,
      bvid: bvid,
      aid: aid,
      title: title,
      coverUrl: coverUrl,
      authorName: authorName,
      description: description,
      pageCount: pageCount,
      targetCid: targetCid,
      targetPageNumber: targetPageNumber,
      requiresDetailExpansion: pageCount > 1,
      resolvedPages: resolvedPageItems,
      historyKey: historyKey,
      duration: resolvedDuration,
      publishedAt: publishedAt,
    );
  }

  /// 构造可交给解析页的标准输入。
  String? get parseInput {
    // BV 是最稳定入口，优先使用；旧数据缺失 BV 时才回退 AV。
    final resolvedBvid = bvid?.trim();
    if (resolvedBvid != null && resolvedBvid.isNotEmpty) {
      return 'https://www.bilibili.com/video/$resolvedBvid';
    }
    // 部分旧收藏或点赞响应只给 aid，解析器已经支持 AV 输入。
    final resolvedAid = aid;
    if (resolvedAid != null && resolvedAid > 0) return 'av$resolvedAid';
    // 无法定位的视频不提供解析入口。
    return null;
  }
}

/// 为用户内容 JSON 解析提供空字符串转空值能力。
extension _EmptyStringExtension on String {
  /// 空字符串返回 null，非空字符串保持原值。
  String? get nullIfEmpty => isEmpty ? null : this;
}

/// 用户视频列表的一页结果。
final class BiliUserVideoPage {
  /// 创建包含列表、总量和分页游标的一页结果。
  const BiliUserVideoPage({
    required this.items,
    this.total,
    this.nextPage,
    this.nextOffset,
    this.historyCursor,
  });

  /// 当前页解析出的可展示视频。
  final List<BiliUserVideoItem> items;

  /// 服务端返回的总数；历史和点赞可能没有稳定总数。
  final int? total;

  /// 下一页页码；为空表示当前接口没有页码式分页。
  final int? nextPage;

  /// 动态搜索接口使用的下一页偏移游标。
  final String? nextOffset;

  /// 历史记录接口使用的下一页游标。
  final BiliHistoryCursor? historyCursor;
}

/// 历史记录游标，用于继续加载下一段历史。
final class BiliHistoryCursor {
  /// 创建历史记录接口返回的分页游标。
  const BiliHistoryCursor({required this.max, required this.viewAt});

  /// 下一页起点记录 ID。
  final int max;

  /// 下一页起点观看时间。
  final int viewAt;
}

/// 用户收藏夹概览。
final class BiliFavoriteFolder {
  /// 创建可进入详情的收藏夹条目。
  const BiliFavoriteFolder({
    required this.id,
    required this.title,
    required this.mediaCount,
    this.coverUrl,
  });

  /// 收藏夹完整 media_id。
  final int id;

  /// 收藏夹标题。
  final String title;

  /// 收藏夹内资源数量。
  final int mediaCount;

  /// 收藏夹封面。
  final String? coverUrl;

  /// 用服务端详情补齐收藏夹封面后创建新的不可变对象。
  BiliFavoriteFolder copyWithCover(String? resolvedCoverUrl) {
    // 收藏夹列表接口有时不返回 cover，此处只在详情页成功拿到封面时覆盖。
    return BiliFavoriteFolder(
      id: id,
      title: title,
      mediaCount: mediaCount,
      coverUrl: resolvedCoverUrl ?? coverUrl,
    );
  }
}

/// UP 空间“合集和系列”条目的实际类型。
enum BiliUserCollectionType {
  /// 手动创建的合集，详情使用 season_id。
  season,

  /// 自动或手动归类的系列，详情使用 series_id。
  series,
}

/// UP 主公开合集或系列概览。
final class BiliUserCollection {
  /// 创建可进入详情的 UP 合集条目。
  const BiliUserCollection({
    required this.id,
    required this.type,
    required this.title,
    required this.mediaCount,
    this.coverUrl,
    this.description,
  });

  /// 合集 season_id 或系列 series_id。
  final int id;

  /// 当前条目的服务端类型，决定详情接口参数。
  final BiliUserCollectionType type;

  /// 合集标题。
  final String title;

  /// 合集内视频数量。
  final int mediaCount;

  /// 合集封面。
  final String? coverUrl;

  /// 合集简介。
  final String? description;
}

/// UP 主合集列表的一页结果。
final class BiliUserCollectionPage {
  /// 创建包含合集条目和下一页信息的结果。
  const BiliUserCollectionPage({
    required this.items,
    this.total,
    this.nextPage,
  });

  /// 当前页合集条目。
  final List<BiliUserCollection> items;

  /// 服务端返回的合集总数。
  final int? total;

  /// 下一页页码；为空表示没有更多。
  final int? nextPage;
}

/// UP 主公开资料。
final class BiliUpProfile {
  /// 创建 UP 主资料。
  const BiliUpProfile({
    required this.mid,
    required this.name,
    this.avatarUrl,
    this.description,
  });

  /// UP 主 UID。
  final int mid;

  /// UP 主昵称。
  final String name;

  /// UP 主头像地址。
  final String? avatarUrl;

  /// UP 主空间签名或简介。
  final String? description;
}

/// 拉取 B 站用户中心所需的历史、稿件、收藏和点赞列表。
final class BiliUserContentService {
  /// 创建复用统一网络客户端和 WBI 签名器的用户内容服务。
  const BiliUserContentService(this._networkClient, this._wbiSigner);

  /// B 站 API 主域名。
  static const String _apiHost = 'api.bilibili.com';

  /// B 站空间域名，用于部分接口的 Referer。
  static const String _spaceHost = 'space.bilibili.com';

  /// 统一网络客户端，负责 Cookie、重试和登录失效降级。
  final BiliNetworkClient _networkClient;

  /// WBI 签名器，空间投稿接口必须携带签名参数。
  final WbiSigner _wbiSigner;

  /// 拉取指定用户空间的投稿视频。
  Future<BiliUserVideoPage> fetchUploads({
    required int mid,
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
    BiliVideoResolveProgress? onResolveProgress,
  }) async {
    // 投稿接口现在强制 WBI 签名，不能直接拼普通查询参数。
    final signedParameters = await _wbiSigner.sign(<String, Object?>{
      'mid': mid,
      'order': 'pubdate',
      'pn': page,
      'ps': pageSize,
    });
    final envelope = await _networkClient.getJson(
      Uri.https(_apiHost, '/x/space/wbi/arc/search'),
      queryParameters: signedParameters,
      cancelToken: cancelToken,
    );
    final data = biliEnvelopeData(envelope);
    final list = biliJsonObject(data['list'], 'list');
    final pageInfo = biliJsonObject(data['page'], 'page');
    final videos = biliJsonObjectList(list['vlist'], 'list.vlist')
        .map(_parseUploadVideo)
        .where((BiliUserVideoItem item) => item.parseInput != null)
        .toList(growable: false);
    final resolvedVideos = await _resolveVideoPageMetadata(
      videos,
      cancelToken: cancelToken,
      onResolveProgress: onResolveProgress,
    );
    final total = biliJsonInt(pageInfo['count']);
    return BiliUserVideoPage(
      items: resolvedVideos,
      total: total,
      nextPage: resolvedVideos.length >= pageSize ? page + 1 : null,
    );
  }

  /// 拉取指定 UP 主的空间资料。
  Future<BiliUpProfile> fetchUpProfile({
    required int mid,
    CancelToken? cancelToken,
  }) async {
    BiliUpProfile? spaceProfile;
    try {
      // 空间资料接口同样需要 WBI 签名，未签名时容易被风控或返回空数据。
      final signedParameters = await _wbiSigner.sign(<String, Object?>{
        'mid': mid,
        'token': '',
        'platform': 'web',
        'web_location': 1550101,
      });
      final envelope = await _networkClient.getJson(
        Uri.https(_apiHost, '/x/space/wbi/acc/info'),
        queryParameters: signedParameters,
        referer: 'https://$_spaceHost/$mid/',
        cancelToken: cancelToken,
      );
      final data = biliEnvelopeData(envelope);
      spaceProfile = _parseUpProfile(mid, data);
      if (spaceProfile.avatarUrl != null && spaceProfile.description != null) {
        return spaceProfile;
      }
    } on BiliApiException {
      // WBI 资料接口受网页风控影响较大，失败时继续尝试公开用户卡片接口。
    }

    try {
      // 用户卡片接口和 wiliwili-yoga 的用户资料来源相近，未登录也能返回头像、昵称和签名。
      final cardProfile = await _fetchUpCardProfile(
        mid: mid,
        cancelToken: cancelToken,
      );
      return _mergeUpProfile(spaceProfile, cardProfile);
    } on BiliApiException {
      // 卡片兜底失败时，如果前面的空间接口至少返回了部分资料，就保留可用内容。
      if (spaceProfile != null) return spaceProfile;
      rethrow;
    }
  }

  /// 搜索指定 UP 主公开动态里的视频投稿。
  Future<BiliUserVideoPage> searchUpVideos({
    required int mid,
    required String keyword,
    int page = 1,
    String? offset,
    int pageSize = 20,
    CancelToken? cancelToken,
    BiliVideoResolveProgress? onResolveProgress,
  }) async {
    final resolvedKeyword = keyword.trim();
    if (resolvedKeyword.isEmpty) {
      // 空关键词没有业务意义，直接返回空页避免请求动态搜索接口。
      return const BiliUserVideoPage(items: <BiliUserVideoItem>[]);
    }
    final envelope = await _networkClient.getJson(
      Uri.https(_apiHost, '/x/polymer/web-dynamic/v1/feed/space/search'),
      queryParameters: <String, Object?>{
        'host_mid': mid,
        'page': page,
        'offset': offset ?? '',
        'keyword': resolvedKeyword,
        'features':
            'itemOpusStyle,listOnlyfans,opusBigCover,onlyfansVote,forwardListHidden,decorationCard',
      },
      referer: Uri.https(_spaceHost, '/$mid/search/video', <String, Object?>{
        'keyword': resolvedKeyword,
      }).toString(),
      cancelToken: cancelToken,
    );
    final data = biliEnvelopeData(envelope);
    final rawItems = _dynamicSearchItems(data);
    final videos = rawItems
        .map((Map<String, Object?> item) => _parseDynamicSearchVideo(item))
        .whereType<BiliUserVideoItem>()
        .where((BiliUserVideoItem item) => item.parseInput != null)
        .toList(growable: false);
    final resolvedVideos = await _resolveVideoPageMetadata(
      videos,
      cancelToken: cancelToken,
      onResolveProgress: onResolveProgress,
    );
    final nextOffset = biliJsonString(data['offset']).trim().nullIfEmpty;
    final hasMore =
        _jsonTruthy(data['has_more']) ||
        (nextOffset != null && rawItems.length >= pageSize);
    return BiliUserVideoPage(
      items: resolvedVideos,
      total: biliJsonInt(data['total']),
      nextPage: hasMore ? page + 1 : null,
      nextOffset: hasMore ? nextOffset : null,
    );
  }

  /// 拉取指定用户创建的收藏夹。
  Future<List<BiliFavoriteFolder>> fetchFavoriteFolders({
    required int mid,
    CancelToken? cancelToken,
  }) async {
    try {
      final envelope = await _networkClient.getJson(
        Uri.https(_apiHost, '/x/v3/fav/folder/created/list-all'),
        queryParameters: <String, Object?>{'up_mid': mid, 'type': 2},
        cancelToken: cancelToken,
      );
      final data = biliEnvelopeData(envelope);
      final folders = biliJsonObjectList(
        data['list'],
        'data.list',
      ).map(_parseFavoriteFolder).toList(growable: false);
      // 收藏夹概览接口常见不带封面，并发访问官方 info 接口补齐封面，避免列表串行等待过久。
      return Future.wait(
        folders.map((folder) async {
          if (folder.coverUrl != null ||
              folder.mediaCount <= 0 ||
              folder.id <= 0) {
            return folder;
          }
          final coverUrl = await _resolveFavoriteFolderCover(
            mediaId: folder.id,
            cancelToken: cancelToken,
          );
          return folder.copyWithCover(coverUrl);
        }),
      );
    } on BiliApiException catch (error) {
      if (error.kind == BiliApiErrorKind.invalidResponse ||
          error.kind == BiliApiErrorKind.forbidden ||
          error.kind == BiliApiErrorKind.unauthorized) {
        // 未公开收藏夹时 B 站可能返回空 data、异常结构或权限错误，页面统一按无公开数据展示。
        return const <BiliFavoriteFolder>[];
      }
      rethrow;
    }
  }

  /// 拉取收藏夹中的视频资源。
  Future<BiliUserVideoPage> fetchFavoriteVideos({
    int? mediaId,
    int page = 1,
    int pageSize = 20,
    String? keyword,
    CancelToken? cancelToken,
    BiliVideoResolveProgress? onResolveProgress,
  }) async {
    final resolvedKeyword = keyword?.trim();
    final queryParameters = <String, Object?>{'pn': page, 'ps': pageSize};
    if (mediaId != null) {
      // 收藏夹详情需要限定 media_id；收藏搜索页不传 media_id 时搜索全部收藏。
      queryParameters['media_id'] = mediaId;
    }
    if (resolvedKeyword != null && resolvedKeyword.isNotEmpty) {
      // 收藏搜索页使用网页端固定参数：按更新时间搜索所有视频收藏资源，不带分区筛选。
      queryParameters.addAll(<String, Object?>{
        'keyword': resolvedKeyword,
        'order': 'mtime',
        'type': 1,
        'tid': 0,
      });
    }
    final envelope = await _networkClient.getJson(
      Uri.https(_apiHost, '/x/v3/fav/resource/list'),
      queryParameters: queryParameters,
      cancelToken: cancelToken,
    );
    final data = biliEnvelopeData(envelope);
    final info = data['info'] is Map
        ? biliJsonObject(data['info'], 'data.info')
        : const <String, Object?>{};
    // 原始收藏资源用于判断服务端分页，不能用过滤后的视频数判断是否还有下一页。
    final rawMedias = biliJsonObjectList(data['medias'], 'data.medias');
    // 列表只过滤无法定位的视频资源，已失效视频保留展示但由 UI 禁止点击。
    final videos = rawMedias
        .map(_parseFavoriteVideo)
        .where((BiliUserVideoItem item) => item.parseInput != null)
        .toList(growable: false);
    final resolvedVideos = await _resolveVideoPageMetadata(
      videos,
      cancelToken: cancelToken,
      onResolveProgress: onResolveProgress,
    );
    // 收藏夹总数来自 info.media_count，用于最后一页不足 pageSize 时判断是否真正到底。
    final total = biliJsonInt(info['media_count']);
    // B 站收藏夹可能混入不可解析资源；只要原始资源或总数表示还有内容，就允许继续翻页。
    final hasRawNextPage =
        rawMedias.length >= pageSize ||
        (total != null && page * pageSize < total);
    return BiliUserVideoPage(
      items: resolvedVideos,
      total: total,
      nextPage: hasRawNextPage ? page + 1 : null,
    );
  }

  /// 拉取指定 UP 主公开的合集或系列列表。
  Future<BiliUserCollectionPage> fetchCollections({
    required int mid,
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    final envelope = await _networkClient.getJson(
      Uri.https(_apiHost, '/x/polymer/web-space/seasons_series_list'),
      queryParameters: <String, Object?>{
        'mid': mid,
        'page_num': page,
        'page_size': pageSize,
        'web_location': '333.1387',
      },
      referer: 'https://$_spaceHost/$mid/lists',
      cancelToken: cancelToken,
    );
    final data = biliEnvelopeData(envelope);
    final itemLists = data['items_lists'] is Map
        ? biliJsonObject(data['items_lists'], 'data.items_lists')
        : const <String, Object?>{};
    // 空间“合集和系列”页把合集放在 seasons_list；旧收藏接口的 list 字段不再覆盖 UP 空间合集。
    final rawItems = <Map<String, Object?>>[
      ...biliJsonObjectList(
        itemLists['seasons_list'],
        'data.items_lists.seasons_list',
      ),
      ...biliJsonObjectList(
        itemLists['series_list'],
        'data.items_lists.series_list',
      ),
    ];
    final collections = rawItems
        .map(_parseUserCollection)
        .where((BiliUserCollection item) => item.id > 0)
        .toList(growable: false);
    final pageInfo = itemLists['page'] is Map
        ? biliJsonObject(itemLists['page'], 'data.items_lists.page')
        : const <String, Object?>{};
    final total = biliJsonInt(pageInfo['total']) ?? collections.length;
    final hasMore = page * pageSize < total;
    return BiliUserCollectionPage(
      items: collections,
      total: total,
      nextPage: hasMore ? page + 1 : null,
    );
  }

  /// 拉取指定 UP 合集中的视频资源。
  Future<BiliUserVideoPage> fetchCollectionVideos({
    required int collectionId,
    required BiliUserCollectionType collectionType,
    required int mid,
    String? authorName,
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
    BiliVideoResolveProgress? onResolveProgress,
  }) async {
    // web-space 合集详情接口返回的是稿件总时长；旧 season/list 只返回当前播放 P 的时长。
    final isSeries = collectionType == BiliUserCollectionType.series;
    final envelope = await _networkClient.getJson(
      isSeries
          ? Uri.https(_apiHost, '/x/series/archives')
          : Uri.https(_apiHost, '/x/polymer/web-space/seasons_archives_list'),
      queryParameters: isSeries
          ? <String, Object?>{
              'mid': mid,
              'series_id': collectionId,
              'only_normal': true,
              'sort': 'desc',
              'pn': page,
              'ps': pageSize,
            }
          : <String, Object?>{
              'mid': mid,
              'season_id': collectionId,
              'page_num': page,
              'page_size': pageSize,
              'web_location': 333.1387,
            },
      referer: 'https://$_spaceHost/$mid/lists/$collectionId',
      cancelToken: cancelToken,
    );
    final data = biliEnvelopeData(envelope);
    final rawArchives = biliJsonObjectList(data['archives'], 'data.archives');
    final videos = rawArchives
        .map(
          (Map<String, Object?> item) =>
              _parseCollectionVideo(item, authorName: authorName),
        )
        .where((BiliUserVideoItem item) => item.parseInput != null)
        .toList(growable: false);
    final resolvedVideos = await _resolveVideoPageMetadata(
      videos,
      cancelToken: cancelToken,
      onResolveProgress: onResolveProgress,
    );
    final pageInfo = data['page'] is Map
        ? biliJsonObject(data['page'], 'data.page')
        : const <String, Object?>{};
    final total =
        biliJsonInt(pageInfo['total']) ??
        biliJsonInt(pageInfo['count']) ??
        videos.length;
    final hasMore = page * pageSize < total;
    return BiliUserVideoPage(
      items: resolvedVideos,
      total: total,
      nextPage: hasMore ? page + 1 : null,
    );
  }

  /// 限流补齐视频分 P 数，列表阶段就能区分单 P 和多 P。
  Future<List<BiliUserVideoItem>> _resolveVideoPageMetadata(
    List<BiliUserVideoItem> items, {
    CancelToken? cancelToken,
    BiliVideoResolveProgress? onResolveProgress,
  }) async {
    if (items.isEmpty) return items;
    final resolvedItems = List<BiliUserVideoItem>.of(items);
    final targetIndexes = <int>[];
    for (var index = 0; index < resolvedItems.length; index += 1) {
      // 预取目标只包含页数未知或明确需要展开的稿件。
      if (_shouldResolveVideoPageMetadata(resolvedItems[index])) {
        targetIndexes.add(index);
      }
    }
    if (targetIndexes.isEmpty) {
      return List<BiliUserVideoItem>.unmodifiable(items);
    }
    final totalCount = targetIndexes.length;
    onResolveProgress?.call(1, totalCount);
    for (var ordinal = 0; ordinal < targetIndexes.length; ordinal += 1) {
      if (cancelToken?.isCancelled == true) break;
      final index = targetIndexes[ordinal];
      final item = resolvedItems[index];
      resolvedItems[index] = await _resolveSingleVideoPageMetadata(
        item,
        cancelToken: cancelToken,
      );
      final completedCount = ordinal + 1;
      final nextCurrent = completedCount >= totalCount
          ? totalCount
          : completedCount + 1;
      onResolveProgress?.call(nextCurrent, totalCount);
      if (completedCount < totalCount) {
        // view 接口属于高频详情预取，串行间隔能明显降低连续命中风控的概率。
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    return List<BiliUserVideoItem>.unmodifiable(resolvedItems);
  }

  /// 判断某个条目是否需要通过 view 接口补齐页数。
  bool _shouldResolveVideoPageMetadata(BiliUserVideoItem item) {
    if (!item.canParse || item.source == BiliUserVideoSource.episode) {
      return false;
    }
    return item.pageCount == null || item.requiresDetailExpansion;
  }

  /// 读取单个 BV/AV 的 view 元信息，失败时保留原条目。
  Future<BiliUserVideoItem> _resolveSingleVideoPageMetadata(
    BiliUserVideoItem item, {
    CancelToken? cancelToken,
  }) async {
    try {
      final resolvedBvid = item.bvid?.trim();
      final resolvedAid = item.aid;
      final envelope = await _networkClient.getJson(
        Uri.https(_apiHost, '/x/web-interface/view'),
        queryParameters: <String, Object?>{
          if (resolvedBvid != null && resolvedBvid.isNotEmpty)
            'bvid': resolvedBvid
          else if (resolvedAid != null && resolvedAid > 0)
            'aid': resolvedAid,
        },
        cancelToken: cancelToken,
      );
      final data = biliEnvelopeData(envelope);
      final pageItems = _parseVideoPageItems(
        item: item,
        data: data,
        fallbackBvid: resolvedBvid,
        fallbackAid: resolvedAid,
      );
      final pageCount =
          (pageItems.isNotEmpty ? pageItems.length : null) ??
          biliJsonInt(data['videos']) ??
          item.pageCount;
      if (pageCount == null || pageCount <= 0) return item;
      return item.withResolvedPageMetadata(
        pageCount: pageCount,
        duration: _durationFrom(data['duration']),
        resolvedPages: pageItems.isEmpty ? null : pageItems,
      );
    } on BiliApiException {
      // 单个视频详情失败不影响整页列表，保留未知页数继续用详情入口兜底。
      return item;
    } on DioException {
      // 网络取消、超时或风控失败都不应该打断列表展示。
      return item;
    }
  }

  /// 拉取某个投稿自身的分 P 列表，不展开它所属的 UP 合集。
  Future<BiliUserVideoPage> fetchVideoPages({
    required BiliUserVideoItem item,
    CancelToken? cancelToken,
  }) async {
    final resolvedBvid = item.bvid?.trim();
    final resolvedAid = item.aid;
    if ((resolvedBvid == null || resolvedBvid.isEmpty) &&
        (resolvedAid == null || resolvedAid <= 0)) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidInput,
        message: '这个视频缺少可展开的 BV 或 AV 号。',
      );
    }
    final cachedPageItems = item.resolvedPages;
    if (cachedPageItems != null && cachedPageItems.isNotEmpty) {
      // 列表阶段已经预取过 view.pages，详情页直接复用，避免再次请求同一个 BV。
      return BiliUserVideoPage(
        items: cachedPageItems,
        total: cachedPageItems.length,
      );
    }
    // view 接口的 pages 表示当前 BV 自身分 P；这里故意忽略 ugc_season，避免混入整个合集。
    final envelope = await _networkClient.getJson(
      Uri.https(_apiHost, '/x/web-interface/view'),
      queryParameters: <String, Object?>{
        if (resolvedBvid != null && resolvedBvid.isNotEmpty)
          'bvid': resolvedBvid
        else
          'aid': resolvedAid,
      },
      cancelToken: cancelToken,
    );
    final data = biliEnvelopeData(envelope);
    final pageItems = _parseVideoPageItems(
      item: item,
      data: data,
      fallbackBvid: resolvedBvid,
      fallbackAid: resolvedAid,
    );
    if (pageItems.isEmpty) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidResponse,
        message: '视频信息中没有可展开的分 P。',
      );
    }
    return BiliUserVideoPage(
      items: List<BiliUserVideoItem>.unmodifiable(pageItems),
      total: pageItems.length,
    );
  }

  /// 从 view 接口响应解析当前稿件自己的分 P 条目。
  List<BiliUserVideoItem> _parseVideoPageItems({
    required BiliUserVideoItem item,
    required Map<String, Object?> data,
    String? fallbackBvid,
    int? fallbackAid,
  }) {
    final pages = biliJsonObjectList(data['pages'], 'data.pages');
    final currentBvid = biliJsonString(
      data['bvid'],
      fallback: fallbackBvid ?? item.bvid ?? '',
    );
    final currentAid = biliJsonInt(data['aid']) ?? fallbackAid;
    final owner = data['owner'] is Map
        ? biliJsonObject(data['owner'], 'data.owner')
        : const <String, Object?>{};
    final pageItems = <BiliUserVideoItem>[];
    for (final page in pages) {
      final cid = biliJsonInt(page['cid']);
      if (cid == null || currentBvid.isEmpty) continue;
      final pageNumber = biliJsonInt(page['page']) ?? pageItems.length + 1;
      pageItems.add(
        BiliUserVideoItem(
          source: BiliUserVideoSource.episode,
          bvid: currentBvid,
          aid: currentAid,
          title: biliJsonString(
            page['part'],
            fallback:
                '${biliJsonString(data['title'], fallback: item.title)} P$pageNumber',
          ),
          coverUrl: biliJsonString(data['pic']).nullIfEmpty ?? item.coverUrl,
          authorName:
              biliJsonString(owner['name']).nullIfEmpty ?? item.authorName,
          description: biliJsonString(data['desc']).nullIfEmpty,
          pageCount: 1,
          targetCid: cid,
          targetPageNumber: pageNumber,
          duration: Duration(seconds: biliJsonInt(page['duration']) ?? 0),
          publishedAt:
              biliDateTimeFromSeconds(data['pubdate']) ?? item.publishedAt,
        ),
      );
    }
    return List<BiliUserVideoItem>.unmodifiable(pageItems);
  }

  /// 拉取当前登录账号的稿件历史。
  Future<BiliUserVideoPage> fetchHistory({
    int max = 0,
    int viewAt = 0,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    final envelope = await _networkClient.getJson(
      Uri.https(_apiHost, '/x/web-interface/history/cursor'),
      queryParameters: <String, Object?>{
        'max': max,
        'view_at': viewAt,
        'type': 'archive',
        'business': '',
        'ps': pageSize,
      },
      cancelToken: cancelToken,
    );
    final data = biliEnvelopeData(envelope);
    final cursor = biliJsonObject(data['cursor'], 'data.cursor');
    final videos = biliJsonObjectList(data['list'], 'data.list')
        .map(_parseHistoryVideo)
        .where((BiliUserVideoItem item) => item.parseInput != null)
        .toList(growable: false);
    return BiliUserVideoPage(
      items: videos,
      historyCursor: BiliHistoryCursor(
        max: biliJsonInt(cursor['max']) ?? 0,
        viewAt: biliJsonInt(cursor['view_at']) ?? 0,
      ),
    );
  }

  /// 搜索当前登录账号的视频观看历史。
  Future<BiliUserVideoPage> searchHistoryVideos({
    required String keyword,
    required BiliHistorySearchTimeRange timeRange,
    required BiliHistorySearchDurationRange durationRange,
    required BiliHistorySearchDevice device,
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    final envelope = await _networkClient.getJson(
      Uri.https(_apiHost, '/x/web-interface/history/search'),
      queryParameters: <String, Object?>{
        'pn': page,
        'keyword': keyword.trim(),
        'business': 'archive',
        'device_type': _historyDeviceType(device),
        ..._historyTimeParameters(timeRange),
        ..._historyDurationParameters(durationRange),
      },
      cancelToken: cancelToken,
    );
    final data = biliEnvelopeData(envelope);
    final videos = biliJsonObjectList(data['list'], 'data.list')
        .map(_parseHistoryVideo)
        .where((BiliUserVideoItem item) => item.parseInput != null)
        .toList(growable: false);
    return BiliUserVideoPage(
      items: videos,
      total: biliJsonInt(data['total']),
      nextPage: videos.length >= pageSize ? page + 1 : null,
    );
  }

  /// 拉取用户公开的最近点赞视频。
  Future<BiliUserVideoPage> fetchLikedVideos({
    required int mid,
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    try {
      final envelope = await _networkClient.getJson(
        Uri.https(_apiHost, '/x/space/like/video'),
        queryParameters: <String, Object?>{
          'vmid': mid,
          'pn': page,
          'ps': pageSize,
        },
        referer: 'https://$_spaceHost/$mid/',
        cancelToken: cancelToken,
      );
      final data = _likedVideoPayload(envelope);
      final videos = biliJsonObjectList(data, 'data.list')
          .map(_parseLikedVideo)
          .where((BiliUserVideoItem item) => item.parseInput != null)
          .toList(growable: false);
      return BiliUserVideoPage(
        items: videos,
        total: videos.length,
        nextPage: videos.length >= pageSize ? page + 1 : null,
      );
    } on BiliApiException catch (error) {
      // 点赞列表经常受隐私设置影响，给页面一个更像产品文案的错误。
      if (error.kind == BiliApiErrorKind.forbidden ||
          error.kind == BiliApiErrorKind.unauthorized ||
          error.kind == BiliApiErrorKind.invalidResponse) {
        throw const BiliApiException(
          kind: BiliApiErrorKind.forbidden,
          message: '最近点赞不可见，可能是账号隐私设置或接口限制。',
        );
      }
      rethrow;
    }
  }

  /// 解析最近点赞接口的数据载荷，兼容旧数组响应和新对象列表响应。
  Object? _likedVideoPayload(Map<String, Object?> envelope) {
    // 点赞接口在不同资料和账号状态下可能返回 data 数组或 data.list 对象字段。
    final code = biliJsonInt(envelope['code']);
    if (code == null) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidResponse,
        message: 'B 站响应缺少业务码。',
      );
    }
    if (code != 0) {
      final message = biliJsonString(
        envelope['message'] ?? envelope['msg'],
        fallback: 'B 站接口请求失败。',
      );
      throw BiliApiException.fromApi(code: code, message: message);
    }
    final data = envelope['data'];
    if (data is List) return data;
    final object = biliJsonObject(data, 'data');
    return object['list'] ?? object['vlist'] ?? object['items'];
  }

  /// 从收藏夹信息接口解析官方收藏夹封面。
  Future<String?> _resolveFavoriteFolderCover({
    required int mediaId,
    CancelToken? cancelToken,
  }) async {
    try {
      // created/list-all 常见不带 cover，B 站收藏夹详情信息接口才返回文件夹封面。
      final envelope = await _networkClient.getJson(
        Uri.https(_apiHost, '/x/v3/fav/folder/info'),
        queryParameters: <String, Object?>{'media_id': mediaId},
        cancelToken: cancelToken,
      );
      final data = biliEnvelopeData(envelope);
      return biliJsonString(data['cover']).nullIfEmpty;
    } on BiliApiException {
      // 单个收藏夹封面补齐失败不能影响整个收藏夹列表展示。
      return null;
    }
  }

  /// 从动态搜索响应里提取可能承载视频的条目列表。
  List<Map<String, Object?>> _dynamicSearchItems(Map<String, Object?> data) {
    final candidates = <Object?>[
      data['items'],
      data['list'],
      data['cards'],
      data['results'],
    ];
    for (final candidate in candidates) {
      if (candidate is List) {
        // 动态搜索不同实验响应字段名不同，只保留对象条目交给后续视频解析。
        return candidate
            .whereType<Map>()
            .map(
              (Map item) => item.map(
                (Object? key, Object? value) => MapEntry(key.toString(), value),
              ),
            )
            .toList(growable: false);
      }
    }
    return const <Map<String, Object?>>[];
  }

  /// 解析动态搜索中的视频卡片，非视频动态返回 null。
  BiliUserVideoItem? _parseDynamicSearchVideo(Map<String, Object?> item) {
    final modules = item['modules'] is Map
        ? biliJsonObject(item['modules'], 'dynamic.modules')
        : const <String, Object?>{};
    final dynamicModule = modules['module_dynamic'] is Map
        ? biliJsonObject(modules['module_dynamic'], 'dynamic.module_dynamic')
        : const <String, Object?>{};
    final major = dynamicModule['major'] is Map
        ? biliJsonObject(dynamicModule['major'], 'dynamic.major')
        : const <String, Object?>{};
    final archive = major['archive'] is Map
        ? biliJsonObject(major['archive'], 'dynamic.archive')
        : item['archive'] is Map
        ? biliJsonObject(item['archive'], 'dynamic.item.archive')
        : item['video'] is Map
        ? biliJsonObject(item['video'], 'dynamic.item.video')
        : const <String, Object?>{};
    if (archive.isEmpty) return null;
    final author = modules['module_author'] is Map
        ? biliJsonObject(modules['module_author'], 'dynamic.author')
        : const <String, Object?>{};
    final pageCount = biliJsonInt(
      archive['videos'] ?? archive['page_count'] ?? archive['pages'],
    );
    final bvid = biliJsonString(
      archive['bvid'] ?? archive['bvid_str'] ?? archive['bvidStr'],
    ).nullIfEmpty;
    final aid = biliJsonInt(
      archive['aid'] ?? archive['avid'] ?? archive['id'] ?? item['rid'],
    );
    if (bvid == null && aid == null) return null;
    return BiliUserVideoItem(
      source: BiliUserVideoSource.upload,
      bvid: bvid,
      aid: aid,
      title: biliJsonString(archive['title'], fallback: '未命名稿件'),
      coverUrl: biliJsonString(
        archive['cover'] ?? archive['pic'] ?? archive['image'],
      ).nullIfEmpty,
      authorName:
          biliJsonString(author['name']).nullIfEmpty ??
          biliJsonString(archive['author']).nullIfEmpty,
      description:
          biliJsonString(archive['desc']).nullIfEmpty ??
          biliJsonString(archive['summary']).nullIfEmpty,
      pageCount: pageCount,
      requiresDetailExpansion:
          pageCount == null ||
          _jsonTruthy(archive['is_union_video'] ?? archive['is_union']),
      duration: _durationFromCandidates(<Object?>[
        archive['duration'],
        archive['duration_text'],
        archive['length'],
      ]),
      publishedAt: biliDateTimeFromSeconds(
        author['pub_ts'] ?? archive['pubdate'] ?? archive['ctime'],
      ),
    );
  }

  /// 解析空间稿件视频字段。
  BiliUserVideoItem _parseUploadVideo(Map<String, Object?> item) {
    // 投稿列表接口可能不给分 P 数；数量未知时先进入详情，由 view.pages 再确定真实分 P。
    final pageCount = biliJsonInt(item['videos'] ?? item['page_count']);
    return BiliUserVideoItem(
      source: BiliUserVideoSource.upload,
      bvid: biliJsonString(item['bvid']).nullIfEmpty,
      aid: biliJsonInt(item['aid']),
      title: biliJsonString(item['title'], fallback: '未命名稿件'),
      coverUrl: biliJsonString(item['pic']).nullIfEmpty,
      authorName: biliJsonString(item['author']).nullIfEmpty,
      description: biliJsonString(item['description']).nullIfEmpty,
      pageCount: pageCount,
      requiresDetailExpansion:
          pageCount == null ||
          _jsonTruthy(item['is_union_video'] ?? item['is_union']),
      duration: _durationFromCandidates(<Object?>[
        item['duration'],
        item['length'],
      ]),
      publishedAt: biliDateTimeFromSeconds(item['created']),
    );
  }

  /// 解析收藏夹概览字段。
  BiliFavoriteFolder _parseFavoriteFolder(Map<String, Object?> item) {
    return BiliFavoriteFolder(
      id: biliJsonInt(item['id']) ?? 0,
      title: biliJsonString(item['title'], fallback: '未命名收藏夹'),
      mediaCount: biliJsonInt(item['media_count']) ?? 0,
      coverUrl: biliJsonString(item['cover']).nullIfEmpty,
    );
  }

  /// 解析 UP 合集概览字段。
  BiliUserCollection _parseUserCollection(Map<String, Object?> item) {
    final meta = item['meta'] is Map
        ? biliJsonObject(item['meta'], 'collection.meta')
        : item;
    final seasonId = biliJsonInt(meta['season_id']);
    final seriesId = biliJsonInt(meta['series_id']);
    // 新空间接口使用 season_id/series_id，旧接口可能仍返回 id，按可打开详情的 ID 优先。
    final resolvedId =
        seasonId ??
        seriesId ??
        biliJsonInt(meta['id']) ??
        biliJsonInt(item['id']) ??
        0;
    return BiliUserCollection(
      id: resolvedId,
      type: seasonId != null
          ? BiliUserCollectionType.season
          : BiliUserCollectionType.series,
      title: biliJsonString(meta['title'] ?? meta['name'], fallback: '未命名合集'),
      mediaCount:
          biliJsonInt(meta['total']) ??
          biliJsonInt(meta['media_count']) ??
          biliJsonInt(item['media_count']) ??
          0,
      coverUrl: biliJsonString(meta['cover']).nullIfEmpty,
      description:
          biliJsonString(meta['description']).nullIfEmpty ??
          biliJsonString(item['intro']).nullIfEmpty,
    );
  }

  /// 解析 UP 主空间资料字段。
  BiliUpProfile _parseUpProfile(int fallbackMid, Map<String, Object?> data) {
    return BiliUpProfile(
      mid: biliJsonInt(data['mid']) ?? fallbackMid,
      name: biliJsonString(data['name'], fallback: 'UP $fallbackMid'),
      avatarUrl: biliJsonString(data['face']).nullIfEmpty,
      description: biliJsonString(data['sign']).nullIfEmpty,
    );
  }

  /// 拉取公开用户卡片资料，用于补齐空间资料接口缺失的头像和简介。
  Future<BiliUpProfile> _fetchUpCardProfile({
    required int mid,
    CancelToken? cancelToken,
  }) async {
    final envelope = await _networkClient.getJson(
      Uri.https(_apiHost, '/x/web-interface/card'),
      queryParameters: <String, Object?>{'mid': mid, 'photo': false},
      referer: 'https://$_spaceHost/$mid/',
      cancelToken: cancelToken,
    );
    final data = biliEnvelopeData(envelope);
    final card = biliJsonObject(data['card'], 'data.card');
    return _parseUpProfile(mid, card);
  }

  /// 合并两个资料来源，优先使用空间接口，缺失字段由用户卡片补齐。
  BiliUpProfile _mergeUpProfile(
    BiliUpProfile? primary,
    BiliUpProfile fallback,
  ) {
    if (primary == null) return fallback;
    return BiliUpProfile(
      mid: primary.mid > 0 ? primary.mid : fallback.mid,
      name: primary.name.trim().isNotEmpty && !primary.name.startsWith('UP ')
          ? primary.name
          : fallback.name,
      avatarUrl: primary.avatarUrl ?? fallback.avatarUrl,
      description: primary.description ?? fallback.description,
    );
  }

  /// 解析收藏夹中的视频字段，并跳过音频或合集等非视频资源。
  BiliUserVideoItem _parseFavoriteVideo(Map<String, Object?> item) {
    final upper = item['upper'] is Map
        ? biliJsonObject(item['upper'], 'media.upper')
        : const <String, Object?>{};
    // 收藏夹接口经常不给分 P 数量；数量未知时宁可先进入详情，避免误把多 P 当单 P 下载。
    final pageCount = biliJsonInt(item['videos'] ?? item['page_count']);
    return BiliUserVideoItem(
      source: BiliUserVideoSource.favorite,
      bvid: biliJsonString(item['bvid']).nullIfEmpty,
      aid: biliJsonInt(item['id']),
      title: biliJsonString(item['title'], fallback: '未命名收藏视频'),
      coverUrl: biliJsonString(item['cover']).nullIfEmpty,
      authorName: biliJsonString(upper['name']).nullIfEmpty,
      description: biliJsonString(item['intro']).nullIfEmpty,
      pageCount: pageCount,
      requiresDetailExpansion:
          pageCount == null ||
          _jsonTruthy(item['is_union_video'] ?? item['is_union']),
      duration: _durationFrom(item['duration']),
      publishedAt: biliDateTimeFromSeconds(item['pubtime'] ?? item['ctime']),
    );
  }

  /// 解析 UP 合集中的视频字段。
  BiliUserVideoItem _parseCollectionVideo(
    Map<String, Object?> item, {
    String? authorName,
  }) {
    final upper = item['upper'] is Map
        ? biliJsonObject(item['upper'], 'collection.upper')
        : const <String, Object?>{};
    return BiliUserVideoItem(
      source: BiliUserVideoSource.collection,
      bvid: biliJsonString(item['bvid']).nullIfEmpty,
      aid: biliJsonInt(item['aid'] ?? item['id']),
      title: biliJsonString(item['title'], fallback: '未命名合集视频'),
      coverUrl: biliJsonString(item['pic'] ?? item['cover']).nullIfEmpty,
      authorName:
          authorName?.trim().nullIfEmpty ??
          biliJsonString(upper['name']).nullIfEmpty,
      description: biliJsonString(item['intro']).nullIfEmpty,
      pageCount: biliJsonInt(item['videos']),
      duration: _durationFrom(item['duration']),
      publishedAt: biliDateTimeFromSeconds(item['pubdate'] ?? item['pubtime']),
    );
  }

  /// 解析当前登录账号的历史视频字段。
  BiliUserVideoItem _parseHistoryVideo(Map<String, Object?> item) {
    final history = item['history'] is Map
        ? biliJsonObject(item['history'], 'history')
        : const <String, Object?>{};
    final aid = biliJsonInt(history['oid']);
    final historyKey =
        biliJsonString(history['kid'] ?? item['kid']).trim().nullIfEmpty ??
        (aid == null ? null : 'archive_$aid');
    return BiliUserVideoItem(
      source: BiliUserVideoSource.history,
      bvid: biliJsonString(history['bvid']).nullIfEmpty,
      aid: aid,
      title: biliJsonString(item['title'], fallback: '未命名历史视频'),
      coverUrl: biliJsonString(item['cover']).nullIfEmpty,
      authorName: biliJsonString(item['author_name']).nullIfEmpty,
      description: biliJsonString(item['show_title']).nullIfEmpty,
      pageCount: biliJsonInt(item['videos']),
      historyKey: historyKey,
      duration: _durationFrom(item['duration']),
      publishedAt: biliDateTimeFromSeconds(item['view_at']),
    );
  }

  /// 按 B 站网页历史搜索参数生成设备类型值。
  int _historyDeviceType(BiliHistorySearchDevice device) {
    return switch (device) {
      BiliHistorySearchDevice.all => 0,
      BiliHistorySearchDevice.pc => 1,
      BiliHistorySearchDevice.phone => 2,
      BiliHistorySearchDevice.tablet => 3,
      BiliHistorySearchDevice.tv => 4,
    };
  }

  /// 按本地日期生成历史搜索时间参数，遵守网页端今天只传开始时间的行为。
  Map<String, Object?> _historyTimeParameters(
    BiliHistorySearchTimeRange range,
  ) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todaySeconds = todayStart.millisecondsSinceEpoch ~/ 1000;
    return switch (range) {
      BiliHistorySearchTimeRange.all => <String, Object?>{
        'add_time_start': 0,
        'add_time_end': 0,
      },
      BiliHistorySearchTimeRange.today => <String, Object?>{
        'add_time_start': todaySeconds,
      },
      BiliHistorySearchTimeRange.yesterday => <String, Object?>{
        'add_time_start':
            todayStart
                .subtract(const Duration(days: 1))
                .millisecondsSinceEpoch ~/
            1000,
        'add_time_end': todaySeconds - 1,
      },
      BiliHistorySearchTimeRange.week => <String, Object?>{
        'add_time_start':
            todayStart
                .subtract(const Duration(days: 7))
                .millisecondsSinceEpoch ~/
            1000,
      },
    };
  }

  /// 按 B 站网页历史搜索参数生成视频时长范围。
  Map<String, Object?> _historyDurationParameters(
    BiliHistorySearchDurationRange range,
  ) {
    return switch (range) {
      BiliHistorySearchDurationRange.all => <String, Object?>{
        'arc_max_duration': 0,
        'arc_min_duration': 0,
      },
      BiliHistorySearchDurationRange.underTenMinutes => <String, Object?>{
        'arc_max_duration': 599,
      },
      BiliHistorySearchDurationRange.tenToThirtyMinutes => <String, Object?>{
        'arc_max_duration': 1800,
        'arc_min_duration': 600,
      },
      BiliHistorySearchDurationRange.thirtyToSixtyMinutes => <String, Object?>{
        'arc_max_duration': 3600,
        'arc_min_duration': 1801,
      },
      BiliHistorySearchDurationRange.overSixtyMinutes => <String, Object?>{
        'arc_max_duration': 0,
        'arc_min_duration': 3601,
      },
    };
  }

  /// 解析最近点赞视频字段。
  BiliUserVideoItem _parseLikedVideo(Map<String, Object?> item) {
    final owner = item['owner'] is Map
        ? biliJsonObject(item['owner'], 'like.owner')
        : const <String, Object?>{};
    return BiliUserVideoItem(
      source: BiliUserVideoSource.liked,
      bvid: biliJsonString(item['bvid']).nullIfEmpty,
      aid: biliJsonInt(item['aid']),
      title: biliJsonString(item['title'], fallback: '未命名点赞视频'),
      coverUrl: biliJsonString(item['pic']).nullIfEmpty,
      authorName: biliJsonString(owner['name']).nullIfEmpty,
      description: biliJsonString(item['desc']).nullIfEmpty,
      pageCount: biliJsonInt(item['videos']),
      duration: _durationFrom(item['duration']),
      publishedAt: biliDateTimeFromSeconds(item['pubdate']),
    );
  }

  /// 兼容秒数和 `mm:ss` 字符串两种 B 站时长格式。
  Duration _durationFrom(Object? value) {
    // 数字字段直接按秒处理。
    final seconds = biliJsonInt(value);
    if (seconds != null) return Duration(seconds: seconds);
    // 空字符串或未知格式按零时长处理，避免列表渲染失败。
    final text = biliJsonString(value).trim();
    if (text.isEmpty) return Duration.zero;
    final parts = text.split(':').map(int.tryParse).toList(growable: false);
    if (parts.any((int? part) => part == null)) return Duration.zero;
    // 从右向左累乘 60，兼容 `ss`、`mm:ss` 和 `hh:mm:ss`。
    var multiplier = 1;
    var totalSeconds = 0;
    for (final part in parts.reversed) {
      totalSeconds += part! * multiplier;
      multiplier *= 60;
    }
    return Duration(seconds: totalSeconds);
  }

  /// 从多个候选字段里取第一个有效时长，兼容投稿接口的 `length` 字符串。
  Duration _durationFromCandidates(List<Object?> values) {
    for (final value in values) {
      // 不同接口的时长字段名不同，取第一个非零结果展示。
      final duration = _durationFrom(value);
      if (duration.inSeconds > 0) return duration;
    }
    return Duration.zero;
  }

  /// 将 B 站接口里常见的 1/true/"1" 标记统一转换为布尔值。
  bool _jsonTruthy(Object? value) {
    // bool 字段直接使用，数字和字符串字段兼容网页端不同响应形态。
    if (value is bool) return value;
    final number = biliJsonInt(value);
    if (number != null) return number != 0;
    final text = biliJsonString(value).trim().toLowerCase();
    return text == 'true' || text == 'yes';
  }
}
