import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/network/bili_network_client.dart';
import '../../features/downloads/application/queue/download_task_plan.dart';
import '../../features/downloads/domain/download_extra_resource.dart';
import '../../features/downloads/domain/download_task_phase.dart';
import 'bili_api_exception.dart';
import 'bili_input_normalizer.dart';
import 'bili_json.dart';
import 'bili_subtitle_metadata.dart';
import 'models/bili_dash_manifest.dart';
import 'models/bili_media_info.dart';
import 'wbi_signer.dart';

/// 用户输入标准化结果及其对应的媒体信息。
final class BiliParsedInput {
  /// 创建可供页面恢复目标分集选择的解析结果。
  const BiliParsedInput({required this.target, required this.media});

  /// 从原始链接或编号中提取的 BV、AV、EP 或 SS 目标。
  final BiliInputTarget target;

  /// 按目标请求并展开后的媒体与分集信息。
  final BiliMediaInfo media;
}

/// 播放器接口返回的一条可下载字幕语言轨道。
final class BiliSubtitleTrack {
  /// 创建经过地址校验的字幕轨道。
  const BiliSubtitleTrack({
    required this.languageCode,
    required this.languageLabel,
    required this.uri,
  });

  /// 任务内容类型中持久化的稳定语言代码，例如 zh-Hans、en-US 或 ai-zh。
  final String languageCode;

  /// 设置与错误提示使用的可读语言名称。
  final String languageLabel;

  /// 带短期鉴权参数的 BCC JSON 下载地址。
  final Uri uri;

  /// AI 轨道保留独立语言代码，避免同语言人工字幕覆盖自动字幕。
  bool get isAiGenerated => languageCode.toLowerCase().startsWith('ai-');
}

/// 解码不同 CDN 返回的弹幕压缩格式，并限制解压后内存占用。
Uint8List decodeDanmakuPayload(
  Uint8List bytes, {
  String? contentEncoding,
  int maximumDecodedBytes = 64 * 1024 * 1024,
}) {
  // 非正上限属于调用错误，不能让长度计算或缓冲器进入无效状态。
  if (maximumDecodedBytes < 0) {
    throw ArgumentError.value(
      maximumDecodedBytes,
      'maximumDecodedBytes',
      '弹幕解压上限不能为负数。',
    );
  }
  switch (contentEncoding?.toLowerCase()) {
    case 'deflate':
      try {
        // 主站常见响应省略 zlib 头，优先按 raw deflate 解码。
        return _decodeDanmakuWithLimit(
          bytes,
          ZLibDecoder(raw: true),
          maximumDecodedBytes,
        );
      } on _DecodedDanmakuTooLargeException {
        // raw 流已经成功解压但超过上限时必须立即终止，不能误当格式错误再次解压。
        rethrow;
      } on FormatException {
        // 少数边缘节点返回标准 zlib 包装，raw 失败后再安全回退。
        return _decodeDanmakuWithLimit(
          bytes,
          ZLibDecoder(),
          maximumDecodedBytes,
        );
      }
    case 'gzip':
      return _decodeDanmakuWithLimit(bytes, gzip.decoder, maximumDecodedBytes);
    default:
      // 未压缩正文可以在返回原 Uint8List 前直接检查，不产生任何额外副本。
      if (bytes.length > maximumDecodedBytes) {
        throw _DecodedDanmakuTooLargeException(maximumDecodedBytes);
      }
      return bytes;
  }
}

/// 使用分块转换器解压弹幕，并在累计结果超过上限前停止写入内存缓冲区。
Uint8List _decodeDanmakuWithLimit(
  Uint8List bytes,
  Converter<List<int>, List<int>> decoder,
  int maximumDecodedBytes,
) {
  // 限长接收器只保存已通过累计长度检查的输出块。
  final output = _LimitedDanmakuBytesSink(maximumDecodedBytes);
  // 转换器仍可一次接收现有压缩响应，但输出会逐块进入限长接收器。
  final input = decoder.startChunkedConversion(output);
  input
    ..add(bytes)
    ..close();
  // close 完成后转移 BytesBuilder 内存，避免 Uint8List.fromList 再复制一份结果。
  return output.takeBytes();
}

/// 在追加新解压块前执行累计大小检查的字节接收器。
final class _LimitedDanmakuBytesSink implements Sink<List<int>> {
  /// 创建指定最大输出字节数的接收器。
  _LimitedDanmakuBytesSink(this.maximumDecodedBytes);

  /// 本次解压允许保留的最大字节数。
  final int maximumDecodedBytes;

  /// 按块保存已通过上限检查的字节，takeBytes 会转移而不是复制内部缓冲。
  final BytesBuilder _bytes = BytesBuilder(copy: false);

  /// 接收器是否已经关闭，防止转换器生命周期外继续追加数据。
  bool _closed = false;

  /// 追加一块解压结果，超过上限时在保存该块前立即终止。
  @override
  void add(List<int> data) {
    // 关闭后收到数据代表转换器违反 Sink 生命周期，主动暴露状态错误。
    if (_closed) throw StateError('弹幕解压接收器已经关闭。');
    // 使用减法避免两个超大长度相加发生整数边界问题。
    if (data.length > maximumDecodedBytes - _bytes.length) {
      throw _DecodedDanmakuTooLargeException(maximumDecodedBytes);
    }
    _bytes.add(data);
  }

  /// 标记转换完成，后续只允许取走最终字节。
  @override
  void close() {
    _closed = true;
  }

  /// 转移已经完成的解压结果。
  Uint8List takeBytes() {
    // 只有转换器正常关闭后结果才完整，提前读取属于内部调用错误。
    if (!_closed) throw StateError('弹幕解压尚未完成。');
    return _bytes.takeBytes();
  }
}

/// 区分“解压格式无效”和“有效内容超过安全上限”，防止 deflate 回退重复分配。
final class _DecodedDanmakuTooLargeException extends FormatException {
  /// 创建携带当前安全上限的格式异常。
  _DecodedDanmakuTooLargeException(int maximumDecodedBytes)
    : super('解压后的弹幕 XML 超过 $maximumDecodedBytes 字节安全上限。');
}

/// 负责 BV/AV/EP/SS 基础信息、分集和 DASH 播放流解析。
final class BilibiliParserService {
  /// 注入统一网络客户端、输入归一化器和 WBI 签名器。
  const BilibiliParserService(
    this._networkClient,
    this._inputNormalizer,
    this._wbiSigner,
  );

  /// B 站 API 主机。
  static const String _apiHost = 'api.bilibili.com';

  /// 统一网络客户端。
  final BiliNetworkClient _networkClient;

  /// 负责直接标识、网页和短链接归一化的组件。
  final BiliInputNormalizer _inputNormalizer;

  /// 负责为播放接口生成可刷新的 WBI 签名。
  final WbiSigner _wbiSigner;

  /// 解析用户输入并保留标准目标，供页面选中链接实际指向的分集。
  Future<BiliParsedInput> parseInput(
    String input, {
    CancelToken? cancelToken,
  }) async {
    // 先展开短链接并获得标准 BV、AV、EP 或 SS 目标。
    final target = await _inputNormalizer.normalize(
      input,
      cancelToken: cancelToken,
    );
    // 按标准目标选择普通视频或 PGC 信息接口。
    final media = await parseTarget(target, cancelToken: cancelToken);
    // 同时返回标准目标，避免媒体展开为合集后丢失原链接指向。
    return BiliParsedInput(target: target, media: media);
  }

  /// 解析已经标准化的输入目标。
  Future<BiliMediaInfo> parseTarget(
    BiliInputTarget target, {
    CancelToken? cancelToken,
  }) async {
    // 每个目标只调用与其类型对应的公开信息接口。
    return switch (target.kind) {
      BiliInputKind.bvid => _parseBvid(target.bvid!, cancelToken: cancelToken),
      BiliInputKind.avid => _parseAvid(
        target.numericId!,
        cancelToken: cancelToken,
      ),
      BiliInputKind.episode => _parseSeason(
        episodeId: target.numericId!,
        cancelToken: cancelToken,
      ),
      BiliInputKind.season => _parseSeason(
        seasonId: target.numericId!,
        cancelToken: cancelToken,
      ),
    };
  }

  /// 获取指定分集可用的 DASH 视频流和音频流。
  Future<BiliDashManifest> loadDashManifest(
    BiliEpisodeInfo episode, {
    CancelToken? cancelToken,
  }) async {
    // 普通视频使用 WBI 播放接口，PGC 使用独立番剧播放接口。
    if (episode.contentType == BiliContentType.ugc) {
      return _loadUgcDash(episode, cancelToken: cancelToken);
    }
    return _loadPgcDash(episode, cancelToken: cancelToken);
  }

  /// 根据已选视频流和音频流创建协调器可直接执行的双流计划。
  Future<ResolvedDownloadPlan> createDownloadPlan({
    required String taskId,
    required BiliEpisodeInfo episode,
    required BiliDashManifest manifest,
    required String videoTemporaryPath,
    required String audioTemporaryPath,
    required bool includeVideo,
    required bool includeAudio,
    int? qualityId,
    int? audioQualityId,
    BiliVideoCodec? preferredCodec,
  }) async {
    // 用户选择画质时才创建视频分流，无声视频仍只提交这一条来源。
    final video = includeVideo
        ? await createMediaSource(
            episode: episode,
            manifest: manifest,
            kind: DownloadStreamKind.video,
            temporaryPath: videoTemporaryPath,
            qualityId: qualityId,
            preferredCodec: preferredCodec,
          )
        : null;
    // 用户选择音质时才创建音频分流，纯音频任务不请求视频流。
    final audio = includeAudio
        ? await createMediaSource(
            episode: episode,
            manifest: manifest,
            kind: DownloadStreamKind.audio,
            temporaryPath: audioTemporaryPath,
            audioQualityId: audioQualityId,
          )
        : null;
    // 返回协调器可执行的单流或双流计划。
    return ResolvedDownloadPlan(taskId: taskId, video: video, audio: audio);
  }

  /// 为封面、弹幕或字幕创建单一附加资源下载计划。
  Future<ResolvedDownloadPlan> createExtraResourcePlan({
    required String taskId,
    required BiliEpisodeInfo episode,
    required DownloadExtraResource resource,
    required String temporaryPath,
    String? resourceVariant,
  }) async {
    // 附加资源仍使用对应视频页面作为 Referer，满足 B 站来源校验。
    final referer =
        episode.contentType == BiliContentType.pgc && episode.episodeId != null
        ? 'https://www.bilibili.com/bangumi/play/ep${episode.episodeId}'
        : 'https://www.bilibili.com/video/${episode.bvid}';
    // 根据资源类型解析实际下载地址。
    final resourceUri = switch (resource) {
      DownloadExtraResource.cover => _coverResourceUri(episode),
      DownloadExtraResource.danmakuXml || DownloadExtraResource.danmakuAss =>
        Uri.https('comment.bilibili.com', '/${episode.cid}.xml'),
      DownloadExtraResource.subtitles ||
      DownloadExtraResource.aiSubtitles => await _subtitleResourceUri(
        episode,
        referer: referer,
        languageCode: resourceVariant,
        aiGenerated: resource == DownloadExtraResource.aiSubtitles,
      ),
      // 音频使用 DASH 计划，不应进入附加资源解析分支。
      DownloadExtraResource.audio => throw StateError('音频资源必须使用 DASH 下载计划。'),
    };
    // 统一请求头包含 User-Agent、Referer 和可用 Cookie。
    final headers = await _networkClient.requestHeaders(referer: referer);
    // 图片、XML 和字幕正文直接保存原始响应，禁止 aria2 对不一致的压缩头再次解码。
    headers['Accept-Encoding'] = 'identity';
    // 附加资源只提交一条 resource 分流。
    return ResolvedDownloadPlan(
      taskId: taskId,
      resource: ResolvedMediaSource(
        kind: DownloadStreamKind.resource,
        url: resourceUri,
        temporaryPath: temporaryPath,
        codec: downloadExtraResourceCode(resource),
        headers: headers,
      ),
    );
  }

  /// 下载并解码 B 站使用原始 deflate 传输的 XML 弹幕。
  Future<Uint8List> fetchDanmakuXmlBytes(ResolvedMediaSource source) async {
    // B 站 XML 响应的 deflate 流不带标准 zlib 头，必须关闭 HttpClient 自动解压。
    final client = HttpClient()..autoUncompress = false;
    try {
      // 直接请求解析计划中的稳定 XML 地址。
      final request = await client.getUrl(source.url);
      // 复用 Cookie、Referer 和 User-Agent，保持与其他 B 站资源请求一致。
      source.headers.forEach(request.headers.set);
      final response = await request.close();
      // 非成功状态不能写入伪 XML 文件。
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          '弹幕 XML 下载失败，HTTP ${response.statusCode}。',
          uri: source.url,
        );
      }
      // 收集未经自动解压的原始响应字节。
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
        // 异常响应或超长弹幕不能无限占用 UI isolate 内存。
        if (builder.length > 32 * 1024 * 1024) {
          throw const FormatException('弹幕响应超过 32 MB 安全上限。');
        }
      }
      final bytes = builder.takeBytes();
      final contentEncoding = response.headers
          .value(HttpHeaders.contentEncodingHeader)
          ?.toLowerCase();
      // 兼容 raw deflate、标准 zlib deflate、gzip 与未压缩边缘节点响应。
      final decoded = decodeDanmakuPayload(
        bytes,
        contentEncoding: contentEncoding,
      );
      // XML 声明或根节点是最低有效性检查，避免错误页被当作弹幕保存。
      final prefix = utf8.decode(
        decoded.take(1024).toList(growable: false),
        allowMalformed: true,
      );
      if (!prefix.contains('<i>') && !prefix.contains('<?xml')) {
        throw const FormatException('弹幕 XML 响应格式无效。');
      }
      return decoded;
    } finally {
      // 单次资源请求完成后关闭连接池，避免独立任务残留套接字。
      client.close(force: true);
    }
  }

  /// 解析并校验视频封面地址。
  Uri _coverResourceUri(BiliEpisodeInfo episode) {
    // 分集封面为空时不能创建伪造图片任务。
    final coverUrl = episode.coverUrl?.trim();
    final uri = coverUrl == null ? null : Uri.tryParse(coverUrl);
    // 只接受 HTTP(S) 封面地址。
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw StateError('当前视频没有可下载的封面。');
    }
    return uri;
  }

  /// 查询分集字幕轨道；aiGenerated 可分别筛选人工、AI，省略时返回全部类型。
  Future<List<BiliSubtitleTrack>> loadSubtitleTracks(
    BiliEpisodeInfo episode, {
    String? referer,
    bool? aiGenerated,
  }) async {
    // PGC 播放器信息需要同时携带 season_id 与 ep_id 才能覆盖更多剧集类型。
    final query = <String, Object?>{
      'bvid': episode.bvid,
      'cid': episode.cid,
      'season_id': ?episode.seasonId,
      'ep_id': ?episode.episodeId,
    };
    final effectiveReferer =
        referer ??
        (episode.contentType == BiliContentType.pgc && episode.episodeId != null
            ? 'https://www.bilibili.com/bangumi/play/ep${episode.episodeId}'
            : 'https://www.bilibili.com/video/${episode.bvid}');
    // 播放器 JSON 接口保留人工轨道；旧接口失败时普通投稿仍可查询新版 AI 接口。
    var data = const <String, Object?>{};
    try {
      final envelope = await _networkClient.getJson(
        Uri.https(_apiHost, '/x/player/wbi/v2'),
        queryParameters: query,
        referer: effectiveReferer,
      );
      data = biliEnvelopeData(envelope);
    } on BiliApiException {
      // 人工字幕与 PGC 仍依赖播放器接口，不能用普通投稿端点掩盖失败。
      if (aiGenerated == false || episode.contentType == BiliContentType.pgc) {
        rethrow;
      }
    }
    final subtitle = data['subtitle'] is Map
        ? biliJsonObject(data['subtitle'], 'subtitle')
        : const <String, Object?>{};
    final subtitleObjects = biliJsonObjectList(
      subtitle['subtitles'],
      'subtitle.subtitles',
    );
    // 人工与 AI 使用独立语言标识，保留接口优先顺序。
    final tracks = _parseSubtitleTracks(subtitleObjects);
    // 只有需要 AI 且旧接口没有 AI 轨道时才补查，避免重复请求。
    if (aiGenerated != false &&
        episode.contentType == BiliContentType.ugc &&
        !tracks.any((track) => track.isAiGenerated)) {
      try {
        // 新版接口需要 aid；播放器未提供时从当前 BV 元数据读取。
        var aid = biliJsonInt(data['aid']);
        if (aid == null || aid <= 0) {
          final view = biliEnvelopeData(
            await _networkClient.getJson(
              Uri.https(_apiHost, '/x/web-interface/view'),
              queryParameters: <String, Object?>{'bvid': episode.bvid},
              referer: effectiveReferer,
            ),
          );
          aid = biliJsonInt(view['aid']);
        }
        if (aid == null || aid <= 0) {
          throw const FormatException('视频元数据缺少 AI 字幕所需的 aid。');
        }
        // 新播放器元数据是 Protobuf，正文仍为可转换为 SRT 的 BCC JSON。
        final bytes = await _networkClient.getBytes(
          Uri.https(_apiHost, '/x/v2/subtitle/web/view', <String, String>{
            'oid': episode.cid.toString(),
            'pid': aid.toString(),
            'context_ext': '{"video_type":1}',
            'type': '1',
            'cur_production_type': '0',
            'preferred_language': 'ai-zh',
            'playlist_switch': '0',
          }),
          referer: effectiveReferer,
        );
        // 风控或登录失败可能改返 JSON，应展示业务错误而非二进制解析错误。
        final prefix = utf8
            .decode(bytes.take(32).toList(), allowMalformed: true)
            .trimLeft();
        if (prefix.startsWith('{')) {
          biliEnvelopeData(
            biliJsonObject(jsonDecode(utf8.decode(bytes)), 'subtitle'),
          );
          throw const FormatException('新版字幕接口没有返回有效元数据。');
        }
        final knownLanguages = tracks
            .map((track) => track.languageCode)
            .toSet();
        for (final track in _parseSubtitleTracks(
          decodeBiliSubtitleMetadata(bytes),
        )) {
          // 两个接口重复返回的语言只保留首条，人工与 ai-* 不会互相覆盖。
          if (knownLanguages.add(track.languageCode)) tracks.add(track);
        }
      } on Exception {
        // 补查失败不能丢弃已可用的人工轨道；明确下载 AI 时必须反馈真实失败。
        if (aiGenerated == true || tracks.isEmpty) rethrow;
      }
    }
    // null 用于查询全部轨道；两个独立下载选项只获取各自类型。
    final selected = tracks
        .where(
          (track) => aiGenerated == null || track.isAiGenerated == aiGenerated,
        )
        .toList(growable: false);
    if (selected.isEmpty && data['need_login_subtitle'] == true) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.unauthorized,
        message: '当前字幕需要登录，请先在应用内登录 B 站后重试。',
      );
    }
    return List<BiliSubtitleTrack>.unmodifiable(selected);
  }

  /// 统一校验新旧接口轨道地址，并将 AI 类型转换为可持久化的独立语言标识。
  List<BiliSubtitleTrack> _parseSubtitleTracks(
    List<Map<String, Object?>> subtitleObjects,
  ) {
    // 只把完整可下载的轨道加入结果，脏数据不能占用语言去重名额。
    final tracks = <BiliSubtitleTrack>[];
    final seenLanguages = <String>{};
    for (final item in subtitleObjects) {
      // ai_type 是旧接口的自动字幕标记；新版接口通过 ai-* 语言代码识别。
      final rawLanguage = biliJsonString(item['lan']).trim();
      final isAi =
          rawLanguage.toLowerCase().startsWith('ai-') ||
          (biliJsonInt(item['ai_type']) ?? 0) > 0;
      final languageCode = isAi && !rawLanguage.toLowerCase().startsWith('ai-')
          ? 'ai-$rawLanguage'
          : rawLanguage;
      final rawUrl = biliJsonString(item['subtitle_url']).trim();
      // 缺少语言或地址的脏轨道不能生成无法恢复的任务。
      if (rawLanguage.isEmpty || rawUrl.isEmpty) continue;
      final normalizedUrl = rawUrl.startsWith('//') ? 'https:$rawUrl' : rawUrl;
      final uri = Uri.tryParse(normalizedUrl);
      if (uri == null ||
          uri.host.isEmpty ||
          (uri.scheme != 'https' && uri.scheme != 'http')) {
        continue;
      }
      // 通过地址校验后再去重，避免首条坏链接遮挡后续可用字幕。
      if (!seenLanguages.add(languageCode)) continue;
      final languageLabel = biliJsonString(item['lan_doc']).trim();
      tracks.add(
        BiliSubtitleTrack(
          languageCode: languageCode,
          languageLabel: languageLabel.isEmpty ? languageCode : languageLabel,
          uri: uri,
        ),
      );
    }
    return tracks;
  }

  /// 查询当前分集指定语言或第一条可用字幕轨道地址。
  Future<Uri> _subtitleResourceUri(
    BiliEpisodeInfo episode, {
    required String referer,
    String? languageCode,
    required bool aiGenerated,
  }) async {
    // 新任务按选项筛选；旧版 resource.subtitles:ai-* 任务仍按已保存的 AI 语言恢复。
    final requestedAi =
        aiGenerated || (languageCode?.toLowerCase().startsWith('ai-') ?? false);
    final tracks = await loadSubtitleTracks(
      episode,
      referer: referer,
      aiGenerated: requestedAi,
    );
    // 没有字幕轨道时给任务页明确错误。
    if (tracks.isEmpty) {
      throw StateError(
        requestedAi
            ? '当前视频没有可下载的 AI 字幕；请确认已登录且播放器提供 AI 字幕。'
            : '当前视频没有可下载的人工字幕，可尝试选择 AI 字幕。',
      );
    }
    if (languageCode != null && languageCode.isNotEmpty) {
      for (final track in tracks) {
        // 持久化语言代码精确匹配，不能静默下载成另一种语言。
        if (track.languageCode == languageCode) return track.uri;
      }
      throw StateError('当前视频不再提供 $languageCode 字幕。');
    }
    // 旧任务没有语言变体时保持兼容，继续使用接口排序第一轨。
    return tracks.first.uri;
  }

  /// 从最新 DASH 清单创建一条指定类型的媒体分流。
  Future<ResolvedMediaSource> createMediaSource({
    required BiliEpisodeInfo episode,
    required BiliDashManifest manifest,
    required DownloadStreamKind kind,
    required String temporaryPath,
    int? qualityId,
    int? audioQualityId,
    BiliVideoCodec? preferredCodec,
  }) async {
    // 视频按清晰度和编码选择，音频按实际音质代码选择。
    final stream = kind == DownloadStreamKind.video
        ? manifest.selectVideo(
            qualityId: qualityId,
            preferredCodec: preferredCodec,
          )
        : manifest.selectAudio(qualityId: audioQualityId);
    // PGC 与普通视频使用不同来源页，CDN 会校验 Referer。
    final referer =
        episode.contentType == BiliContentType.pgc && episode.episodeId != null
        ? 'https://www.bilibili.com/bangumi/play/ep${episode.episodeId}'
        : 'https://www.bilibili.com/video/${episode.bvid}';
    // 读取当前完整 Cookie 并构造媒体请求所需请求头。
    final headers = await _networkClient.requestHeaders(referer: referer);
    // 返回只包含当前目标类型的新分流参数。
    return ResolvedMediaSource(
      kind: kind,
      url: stream.baseUrl,
      backupUrls: List<Uri>.unmodifiable(stream.backupUrls),
      temporaryPath: temporaryPath,
      codec: kind == DownloadStreamKind.video
          ? stream.videoCodec.name
          : stream.codecs,
      headers: headers,
    );
  }

  /// 调用普通视频 view 接口并解析多 P 或 UGC 合集。
  Future<BiliMediaInfo> _parseBvid(
    String bvid, {
    CancelToken? cancelToken,
  }) async {
    // BVID 使用 view 接口的 bvid 参数查询普通视频。
    return _parseUgcView(
      queryParameters: <String, Object?>{'bvid': bvid},
      cancelToken: cancelToken,
    );
  }

  /// 使用旧 AV 稿件号调用普通视频 view 接口。
  Future<BiliMediaInfo> _parseAvid(int avid, {CancelToken? cancelToken}) async {
    // AV 号是旧稿件 ID，view 接口通过 aid 参数返回同一视频信息。
    return _parseUgcView(
      queryParameters: <String, Object?>{'aid': avid},
      cancelToken: cancelToken,
    );
  }

  /// 调用普通视频 view 接口并解析多 P 或 UGC 合集。
  Future<BiliMediaInfo> _parseUgcView({
    required Map<String, Object?> queryParameters,
    CancelToken? cancelToken,
  }) async {
    // 构造公开 view API 地址。
    final uri = Uri.https(_apiHost, '/x/web-interface/view');
    // 请求当前普通视频信息，调用方决定使用 bvid 或 aid。
    final envelope = await _networkClient.getJson(
      uri,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
    );
    // 校验业务码并提取 data 对象。
    final data = biliEnvelopeData(envelope);
    // 解析集合和分集字段。
    final media = parseUgcMediaInfo(data);
    // 没有任何可用 CID 时不能进入下载流程。
    if (media.episodes.isEmpty) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidResponse,
        message: '视频信息中没有可解析的分集。',
      );
    }
    // 返回普通视频解析结果。
    return media;
  }

  /// 调用 PGC season 接口并解析季度与分集信息。
  Future<BiliMediaInfo> _parseSeason({
    int? episodeId,
    int? seasonId,
    CancelToken? cancelToken,
  }) async {
    // EP 和 SS 至少需要一个，调用方已通过输入归一化校验。
    if (episodeId == null && seasonId == null) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidInput,
        message: '解析番剧需要 EP 或 SS 编号。',
      );
    }
    // 构造 PGC 季度信息 API 地址。
    final uri = Uri.https(_apiHost, '/pgc/view/web/season');
    // 只发送目标对应的一个数字参数，避免接口产生歧义。
    final query = <String, Object?>{
      'ep_id': ?episodeId,
      'season_id': ?seasonId,
    };
    // 请求季度信息；地区限制等业务码由统一异常映射处理。
    final envelope = await _networkClient.getJson(
      uri,
      queryParameters: query,
      cancelToken: cancelToken,
    );
    // PGC 接口成功数据位于 result 字段。
    final result = biliEnvelopeData(envelope, field: 'result');
    // 独立 section 接口覆盖主响应未内嵌的花絮、PV、OP/ED 等 PGC 分区。
    var completeResult = result;
    final resolvedSeasonId = biliJsonInt(result['season_id']) ?? seasonId;
    if (resolvedSeasonId != null) {
      try {
        final sectionEnvelope = await _networkClient.getJson(
          Uri.https(_apiHost, '/pgc/web/season/section'),
          queryParameters: <String, Object?>{'season_id': resolvedSeasonId},
          cancelToken: cancelToken,
        );
        final sectionResult = biliEnvelopeData(
          sectionEnvelope,
          field: 'result',
        );
        final extraSections = <Object?>[
          if (sectionResult['main_section'] is Map)
            sectionResult['main_section'],
          ...?sectionResult['section'] is List
              ? sectionResult['section'] as List<Object?>
              : null,
        ];
        if (extraSections.isNotEmpty) {
          // 解析层已有 EP ID 去重，因此可安全合并主响应和独立分区响应。
          completeResult = <String, Object?>{
            ...result,
            'section': <Object?>[
              ...?result['section'] is List
                  ? result['section'] as List<Object?>
                  : null,
              ...extraSections,
            ],
          };
        }
      } on BiliApiException catch (error) {
        // 登录与地区错误必须保留真实边界，普通缺失分区则继续使用主响应。
        if (error.kind == BiliApiErrorKind.unauthorized ||
            error.kind == BiliApiErrorKind.regionRestricted) {
          rethrow;
        }
      }
    }
    // 解析季度信息和全部分集。
    final media = parsePgcMediaInfo(completeResult);
    // 没有 BVID/CID 的季度无法下载。
    if (media.episodes.isEmpty) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidResponse,
        message: '剧集信息中没有可解析的分集。',
      );
    }
    // 返回 PGC 解析结果。
    return media;
  }

  /// 请求普通视频 WBI DASH 播放信息。
  Future<BiliDashManifest> _loadUgcDash(
    BiliEpisodeInfo episode, {
    CancelToken? cancelToken,
  }) async {
    // 播放接口请求 DASH、4K、HDR、杜比和 AV1 能力集合，实际可用项由账号决定。
    final unsignedParameters = <String, Object?>{
      'bvid': episode.bvid,
      'cid': episode.cid,
      'qn': 127,
      'fnver': 0,
      'fnval': 4048,
      'fourk': 1,
    };
    // 使用当前 nav 密钥生成 wts 和 w_rid。
    final signedParameters = await _wbiSigner.sign(unsignedParameters);
    // 构造普通视频 WBI 播放接口地址。
    final uri = Uri.https(_apiHost, '/x/player/wbi/playurl');
    // 请求播放信息并携带当前视频页面 Referer。
    final envelope = await _networkClient.getJson(
      uri,
      queryParameters: signedParameters,
      referer: 'https://www.bilibili.com/video/${episode.bvid}',
      cancelToken: cancelToken,
    );
    // 校验业务码并解析 data.dash。
    return parseDashManifest(biliEnvelopeData(envelope));
  }

  /// 请求 PGC 剧集 DASH 播放信息。
  Future<BiliDashManifest> _loadPgcDash(
    BiliEpisodeInfo episode, {
    CancelToken? cancelToken,
  }) async {
    // PGC 播放接口需要 EP、BVID 和 CID 共同定位资源。
    final query = <String, Object?>{
      'ep_id': ?episode.episodeId,
      'bvid': episode.bvid,
      'cid': episode.cid,
      'qn': 127,
      'fnver': 0,
      'fnval': 4048,
      'fourk': 1,
    };
    final referer = episode.episodeId == null
        ? BiliNetworkClient.defaultReferer
        : 'https://www.bilibili.com/bangumi/play/ep${episode.episodeId}';
    try {
      // v2 接口覆盖新版 PGC、预览和地区限制插件结构。
      final envelope = await _networkClient.getJson(
        Uri.https(_apiHost, '/pgc/player/web/v2/playurl'),
        queryParameters: query,
        referer: referer,
        cancelToken: cancelToken,
      );
      return parseDashManifest(_normalizePgcPlayurlPayload(envelope));
    } on BiliApiException catch (error) {
      // 权限、登录和地区边界不能回退绕过；仅结构或旧内容兼容问题使用旧接口。
      if (error.kind == BiliApiErrorKind.unauthorized ||
          error.kind == BiliApiErrorKind.forbidden ||
          error.kind == BiliApiErrorKind.regionRestricted) {
        rethrow;
      }
    } on FormatException {
      // v2 返回旧内容不支持的结构时继续请求兼容接口。
    }
    final legacyEnvelope = await _networkClient.getJson(
      Uri.https(_apiHost, '/pgc/player/web/playurl'),
      queryParameters: query,
      referer: referer,
      cancelToken: cancelToken,
    );
    return parseDashManifest(biliEnvelopeData(legacyEnvelope, field: 'result'));
  }

  /// 把 PGC v2 的多种嵌套响应归一化为 parseDashManifest 所需对象。
  Map<String, Object?> _normalizePgcPlayurlPayload(
    Map<String, Object?> envelope,
  ) {
    final code = biliJsonInt(envelope['code']);
    if (code != null && code != 0) {
      throw BiliApiException.fromApi(
        code: code,
        message: biliJsonString(envelope['message'], fallback: 'PGC 播放地址请求失败。'),
      );
    }
    // 先遍历完整响应记录地区插件，后续解包不能丢失 video_info 的同级字段。
    final areaRestricted = _containsBlockedAreaLimitPanel(envelope);
    var payload = envelope;
    // v2 在不同内容类型下可能依次包装 raw、data、result 和 video_info。
    for (final key in const <String>['raw', 'data', 'result', 'video_info']) {
      if (payload[key] is Map) {
        payload = biliJsonObject(payload[key], key);
      }
    }
    if (payload['dash'] is Map) return payload;
    // AreaLimitPanel 是新版接口比单一业务码更可靠的地区限制信号。
    if (areaRestricted) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.regionRestricted,
        message: '当前内容受版权地区限制，所在地区无法播放。',
      );
    }
    throw const BiliApiException(
      kind: BiliApiErrorKind.invalidResponse,
      message: 'PGC 播放接口没有返回可下载的 DASH 资源。',
    );
  }

  /// 递归识别 PGC v2 不同嵌套位置中的 AreaLimitPanel 阻断配置。
  bool _containsBlockedAreaLimitPanel(Object? value) {
    if (value is List) {
      // 数组任意子项命中即可确认地区阻断。
      return value.any(_containsBlockedAreaLimitPanel);
    }
    if (value is! Map) return false;
    final object = value.map(
      (Object? key, Object? item) => MapEntry(key.toString(), item),
    );
    final rawConfig = object['config'];
    if (object['name'] == 'AreaLimitPanel' && rawConfig is Map) {
      final config = rawConfig.map(
        (Object? key, Object? item) => MapEntry(key.toString(), item),
      );
      if (config['is_block'] == true) return true;
    }
    // 插件可能位于 raw/data/result/video_info 任意层，递归遍历全部值。
    return object.values.any(_containsBlockedAreaLimitPanel);
  }
}
