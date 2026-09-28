import '../bili_api_exception.dart';
import '../bili_json.dart';

/// B 站 DASH 视频编码偏好。
enum BiliVideoCodec {
  /// H.264/AVC，兼容性最好。
  avc,

  /// H.265/HEVC，压缩率较高。
  hevc,

  /// AV1，压缩率高但设备解码要求更高。
  av1,

  /// 接口返回尚未识别的编码。
  unknown,
}

/// DASH 中一条可独立下载的视频流或音频流。
final class BiliDashStream {
  /// 创建一条已经完成 JSON 解析的媒体流。
  const BiliDashStream({
    required this.id,
    required this.baseUrl,
    required this.backupUrls,
    required this.bandwidth,
    required this.mimeType,
    required this.codecs,
    required this.codecId,
    this.width,
    this.height,
    this.frameRate,
  });

  /// 清晰度或音质代码。
  final int id;

  /// 首选 CDN 下载地址。
  final Uri baseUrl;

  /// 首选 CDN 失败时可尝试的备用地址。
  final List<Uri> backupUrls;

  /// 接口声明的平均码率。
  final int bandwidth;

  /// 媒体 MIME 类型。
  final String mimeType;

  /// RFC 6381 编码描述。
  final String codecs;

  /// B 站内部编码 ID。
  final int codecId;

  /// 视频宽度，音频流为空。
  final int? width;

  /// 视频高度，音频流为空。
  final int? height;

  /// 视频帧率文本，音频流为空。
  final String? frameRate;

  /// 将 B 站 codecId 和 codecs 文本转换为稳定视频编码枚举。
  BiliVideoCodec get videoCodec {
    // 优先使用稳定 codecId，文本作为旧接口回退。
    if (codecId == 7 || codecs.startsWith('avc')) return BiliVideoCodec.avc;
    if (codecId == 12 || codecs.startsWith('hev')) return BiliVideoCodec.hevc;
    if (codecId == 13 || codecs.startsWith('av01')) return BiliVideoCodec.av1;
    // 未知编码保留供界面展示，不误归类。
    return BiliVideoCodec.unknown;
  }
}

/// 一个分集可用的 DASH 视频流、音频流和质量说明。
final class BiliDashManifest {
  /// 创建不可变 DASH 播放流集合。
  BiliDashManifest({
    required this.duration,
    required List<BiliDashStream> videoStreams,
    required List<BiliDashStream> audioStreams,
    required Map<int, String> qualityDescriptions,
  }) : videoStreams = List<BiliDashStream>.unmodifiable(videoStreams),
       audioStreams = List<BiliDashStream>.unmodifiable(audioStreams),
       qualityDescriptions = Map<int, String>.unmodifiable(qualityDescriptions);

  /// DASH 媒体总时长。
  final Duration duration;

  /// 所有可用视频清晰度与编码组合。
  final List<BiliDashStream> videoStreams;

  /// 所有可用普通、杜比或 Hi-Res 音频流。
  final List<BiliDashStream> audioStreams;

  /// 清晰度代码到界面说明的映射。
  final Map<int, String> qualityDescriptions;

  /// 按清晰度和编码偏好选择视频流，并提供安全回退。
  BiliDashStream selectVideo({int? qualityId, BiliVideoCodec? preferredCodec}) {
    // 播放接口没有返回视频流时不能创建下载计划。
    if (videoStreams.isEmpty) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidResponse,
        message: '播放接口没有返回 DASH 视频流。',
      );
    }
    // 先选定一个实际可用清晰度，编码回退不能跨清晰度改变结果。
    final selectedQualityId = _selectVideoQualityId(qualityId);
    // 只保留实际清晰度下的编码候选。
    final availableCandidates = videoStreams
        .where((BiliDashStream stream) => stream.id == selectedQualityId)
        .toList(growable: false);
    // 在实际清晰度中优先匹配用户选择的编码。
    final codecCandidates = preferredCodec == null
        ? availableCandidates
        : availableCandidates
              .where(
                (BiliDashStream stream) => stream.videoCodec == preferredCodec,
              )
              .toList(growable: false);
    // 编码不可用时保留同清晰度其他编码作为兼容回退。
    final candidates = codecCandidates.isEmpty
        ? availableCandidates
        : codecCandidates;
    // 复制列表后按兼容编码优先级、分辨率和码率降序选择。
    final sorted = List<BiliDashStream>.of(candidates)
      ..sort((BiliDashStream left, BiliDashStream right) {
        // 没有命中指定编码时优先 AVC，其次 HEVC、AV1 和未知编码。
        final codecComparison = _videoCodecFallbackRank(
          left.videoCodec,
        ).compareTo(_videoCodecFallbackRank(right.videoCodec));
        if (codecComparison != 0) return codecComparison;
        // 同清晰度优先更高像素高度。
        final heightComparison = (right.height ?? 0).compareTo(
          left.height ?? 0,
        );
        if (heightComparison != 0) return heightComparison;
        // 最后使用带宽选择码率更高的流。
        return right.bandwidth.compareTo(left.bandwidth);
      });
    // 返回排序后的首选流。
    return sorted.first;
  }

  /// 按目标音质选择音频流，目标不可用时选择不高于目标的最高档。
  BiliDashStream selectAudio({int? qualityId}) {
    // 播放接口没有返回独立音频时无法执行双流下载。
    if (audioStreams.isEmpty) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidResponse,
        message: '播放接口没有返回 DASH 音频流。',
      );
    }
    // 先按产品音质顺序确定实际可用档位。
    final selectedQualityId = _selectAudioQualityId(qualityId);
    // 同档位可能存在多个 CDN 或编码，按码率选择最佳流。
    final sorted =
        audioStreams
            .where((BiliDashStream stream) => stream.id == selectedQualityId)
            .toList(growable: false)
          ..sort(
            (BiliDashStream left, BiliDashStream right) =>
                right.bandwidth.compareTo(left.bandwidth),
          );
    // 返回最高码率音频。
    return sorted.first;
  }

  /// 选择视频实际清晰度：精确命中，否则向下取最高档，再向上取最低档。
  int _selectVideoQualityId(int? requestedQualityId) {
    // 去重后的清晰度代码用于避免同画质多编码影响降级判断。
    final availableQualityIds =
        videoStreams
            .map((BiliDashStream stream) => stream.id)
            .toSet()
            .toList(growable: false)
          ..sort();
    // 未指定目标时选择账号当前可用的最高画质。
    if (requestedQualityId == null) return availableQualityIds.last;
    // 精确画质存在时直接使用，不触发降级。
    if (availableQualityIds.contains(requestedQualityId)) {
      return requestedQualityId;
    }
    // 优先寻找不高于目标的最高画质，例如 4K 不可用时选择 1080P。
    final lowerOrEqual = availableQualityIds
        .where((int qualityId) => qualityId < requestedQualityId)
        .toList(growable: false);
    if (lowerOrEqual.isNotEmpty) return lowerOrEqual.last;
    // 目标低于所有可用档位时选择最低可用画质，保证仍能创建任务。
    return availableQualityIds.first;
  }

  /// 选择音频实际档位：精确命中，否则按音质等级向下或向上就近回退。
  int _selectAudioQualityId(int? requestedQualityId) {
    // 去重后的音频 ID 用于处理普通、杜比和 Hi-Res 混合清单。
    final availableQualityIds =
        audioStreams
            .map((BiliDashStream stream) => stream.id)
            .toSet()
            .toList(growable: false)
          ..sort(
            (int left, int right) =>
                _audioQualityRank(left).compareTo(_audioQualityRank(right)),
          );
    // 未指定目标时沿用最高可用音质行为。
    if (requestedQualityId == null) return availableQualityIds.last;
    // 精确音质存在时直接使用。
    if (availableQualityIds.contains(requestedQualityId)) {
      return requestedQualityId;
    }
    // 将目标 ID 转换为产品音质等级，不能直接比较 B 站非连续 ID。
    final requestedRank = _audioQualityRank(requestedQualityId);
    // 优先选择不高于目标的最高档位。
    final lowerOrEqual = availableQualityIds
        .where((int id) => _audioQualityRank(id) < requestedRank)
        .toList(growable: false);
    if (lowerOrEqual.isNotEmpty) return lowerOrEqual.last;
    // 目标低于所有可用档位时选择最低可用音质。
    return availableQualityIds.first;
  }
}

/// 使用 DASH 平均码率和媒体时长估算一条分流的下载字节数。
int? estimateDashStreamSizeBytes(BiliDashStream stream, Duration duration) {
  // 接口没有有效码率或时长时不能伪造预计大小。
  if (stream.bandwidth <= 0 || duration.inMilliseconds <= 0) return null;
  // DASH bandwidth 单位为 bit/s，乘毫秒后除以 8000 转换为字节并向上取整。
  final bitMilliseconds = stream.bandwidth * duration.inMilliseconds;
  // 使用整数运算避免浮点精度让大文件预计值产生额外偏差。
  return (bitMilliseconds + 7999) ~/ 8000;
}

/// 返回视频编码自动回退优先级，数值越小越优先。
int _videoCodecFallbackRank(BiliVideoCodec codec) => switch (codec) {
  BiliVideoCodec.avc => 0,
  BiliVideoCodec.hevc => 1,
  BiliVideoCodec.av1 => 2,
  BiliVideoCodec.unknown => 3,
};

/// 将 B 站音频 ID 转换为从低到高的稳定产品等级。
int _audioQualityRank(int qualityId) => switch (qualityId) {
  30216 => 0,
  30232 => 1,
  30280 => 2,
  30250 => 3,
  30251 => 4,
  // 未知普通音轨按 ID 放在已知普通档位之后、扩展音轨之前。
  _ => 2,
};

/// 从 UGC data 或 PGC result 对象解析 DASH 播放流。
BiliDashManifest parseDashManifest(Map<String, Object?> data) {
  // 部分 PGC 接口把实际播放信息包在 video_info 中。
  final playInfo = data['video_info'] is Map
      ? biliJsonObject(data['video_info'], 'video_info')
      : data;
  // DASH 字段是双流下载的必要结构。
  final dash = biliJsonObject(playInfo['dash'], 'dash');
  // 解析普通视频流和音频流。
  final videos = biliJsonObjectList(
    dash['video'],
    'dash.video',
  ).map(_parseDashStream).whereType<BiliDashStream>().toList();
  final audios = biliJsonObjectList(
    dash['audio'],
    'dash.audio',
  ).map(_parseDashStream).whereType<BiliDashStream>().toList();
  // 新版接口可能把无损音频放在 flac.audio 中。
  final flac = dash['flac'] is Map
      ? biliJsonObject(dash['flac'], 'dash.flac')
      : null;
  if (flac?['audio'] is Map) {
    // 解析并追加有效 FLAC 音频。
    final stream = _parseDashStream(
      biliJsonObject(flac!['audio'], 'dash.flac.audio'),
    );
    if (stream != null) audios.add(stream);
  }
  // 杜比音频通常位于 dolby.audio 数组。
  final dolby = dash['dolby'] is Map
      ? biliJsonObject(dash['dolby'], 'dash.dolby')
      : null;
  if (dolby != null) {
    // 逐条追加有效杜比音频。
    for (final item in biliJsonObjectList(dolby['audio'], 'dash.dolby.audio')) {
      final stream = _parseDashStream(item);
      if (stream != null) audios.add(stream);
    }
  }
  // 按 URL 去重，避免普通列表和扩展音频节点重复。
  final uniqueAudios = <String, BiliDashStream>{};
  for (final audio in audios) {
    uniqueAudios[audio.baseUrl.toString()] = audio;
  }
  // accept_quality 与 accept_description 使用相同索引。
  final rawQualityIds = playInfo['accept_quality'];
  final qualityIds = rawQualityIds is List
      ? rawQualityIds.map(biliJsonInt).whereType<int>().toList()
      : const <int>[];
  // 接口可能缺少描述数组，缺失时不影响清晰度流本身解析。
  final rawDescriptions = playInfo['accept_description'];
  final descriptions = rawDescriptions is List
      ? rawDescriptions.map((Object? value) => biliJsonString(value)).toList()
      : const <String>[];
  final qualityDescriptions = <int, String>{};
  // 只配对两个数组共同存在的部分。
  final pairCount = qualityIds.length < descriptions.length
      ? qualityIds.length
      : descriptions.length;
  for (var index = 0; index < pairCount; index++) {
    qualityDescriptions[qualityIds[index]] = descriptions[index];
  }
  // DASH duration 以秒表示，缺失时使用 timelength 毫秒回退。
  final dashSeconds = biliJsonInt(dash['duration']);
  final timeLengthMilliseconds = biliJsonInt(playInfo['timelength']);
  final duration = dashSeconds != null
      ? Duration(seconds: dashSeconds)
      : Duration(milliseconds: timeLengthMilliseconds ?? 0);
  // 返回不可变播放流集合。
  return BiliDashManifest(
    duration: duration,
    videoStreams: videos,
    audioStreams: uniqueAudios.values.toList(growable: false),
    qualityDescriptions: qualityDescriptions,
  );
}

/// 解析一条 DASH 流，URL 或 ID 无效时返回空并跳过。
BiliDashStream? _parseDashStream(Map<String, Object?> json) {
  // 同时兼容驼峰和下划线字段名。
  final rawUrl = biliJsonString(json['baseUrl'] ?? json['base_url']);
  final id = biliJsonInt(json['id']);
  final uri = Uri.tryParse(rawUrl);
  // 下载地址必须是 HTTP(S)，ID 必须存在。
  if (id == null ||
      uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    return null;
  }
  // 解析备用 CDN 地址并过滤无效协议。
  final backupValues = json['backupUrl'] ?? json['backup_url'];
  final backupUrls = backupValues is List
      ? backupValues
            .map((Object? value) => Uri.tryParse(biliJsonString(value)))
            .whereType<Uri>()
            .where(
              (Uri value) => value.scheme == 'https' || value.scheme == 'http',
            )
            .toList(growable: false)
      : const <Uri>[];
  // 构造媒体流模型。
  return BiliDashStream(
    id: id,
    baseUrl: uri,
    backupUrls: backupUrls,
    bandwidth: biliJsonInt(json['bandwidth']) ?? 0,
    mimeType: biliJsonString(json['mimeType'] ?? json['mime_type']),
    codecs: biliJsonString(json['codecs']),
    codecId: biliJsonInt(json['codecid']) ?? 0,
    width: biliJsonInt(json['width']),
    height: biliJsonInt(json['height']),
    frameRate: biliJsonString(
      json['frameRate'] ?? json['frame_rate'],
    ).nullIfEmpty,
  );
}

/// 为可选帧率文本提供空字符串转空值能力。
extension _EmptyStringExtension on String {
  /// 空字符串返回 null，非空字符串保持原值。
  String? get nullIfEmpty => isEmpty ? null : this;
}
