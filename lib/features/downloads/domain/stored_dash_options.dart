import 'dart:convert';

import '../../../services/bilibili/models/bili_dash_manifest.dart';

/// 下载任务持久化的非过期 DASH 候选流元数据。
final class StoredDashOptions {
  /// 创建一份可在本地重新选择质量的清单快照。
  StoredDashOptions({
    required this.durationMilliseconds,
    required List<StoredVideoOption> videos,
    required List<StoredAudioOption> audios,
  }) : videos = List<StoredVideoOption>.unmodifiable(videos),
       audios = List<StoredAudioOption>.unmodifiable(audios);

  /// DASH 清单声明的媒体总时长毫秒数。
  final int durationMilliseconds;

  /// 按画质从高到低保存的视频质量和编码组合。
  final List<StoredVideoOption> videos;

  /// 按音质从高到低保存的音频质量组合。
  final List<StoredAudioOption> audios;

  /// 从刚解析的 DASH 清单创建不包含临时 URL 的数据库快照。
  factory StoredDashOptions.fromManifest(BiliDashManifest manifest) {
    // 相同画质和编码只保留平均码率最高的代表流。
    final bestVideos = <String, BiliDashStream>{};
    for (final stream in manifest.videoStreams) {
      // 画质代码和稳定编码共同组成唯一候选键。
      final key = '${stream.id}:${stream.videoCodec.name}';
      // 读取当前同组代表流。
      final current = bestVideos[key];
      if (current == null || stream.bandwidth > current.bandwidth) {
        // 更高平均码率的流替换旧代表。
        bestVideos[key] = stream;
      }
    }
    // 把视频流转换为可持久化候选项。
    final videos = bestVideos.values
        .map(
          (BiliDashStream stream) => StoredVideoOption(
            qualityId: stream.id,
            qualityLabel:
                manifest.qualityDescriptions[stream.id] ??
                '${stream.height ?? 0}P',
            codec: stream.videoCodec,
            bandwidth: stream.bandwidth,
            width: stream.width,
            height: stream.height,
            estimatedSizeBytes: estimateDashStreamSizeBytes(
              stream,
              manifest.duration,
            ),
          ),
        )
        .toList(growable: false);
    // 视频先按画质降序，再按兼容编码顺序排列。
    videos.sort((StoredVideoOption left, StoredVideoOption right) {
      // 更高质量代码排在前面。
      final qualityComparison = right.qualityId.compareTo(left.qualityId);
      if (qualityComparison != 0) return qualityComparison;
      // 同画质按 AVC、HEVC、AV1、未知编码排序。
      return _videoCodecRank(
        left.codec,
      ).compareTo(_videoCodecRank(right.codec));
    });
    // 相同音质代码只保留平均码率最高的代表音轨。
    final bestAudios = <int, BiliDashStream>{};
    for (final stream in manifest.audioStreams) {
      // 读取当前音质代码代表流。
      final current = bestAudios[stream.id];
      if (current == null || stream.bandwidth > current.bandwidth) {
        // 保存更高平均码率音轨。
        bestAudios[stream.id] = stream;
      }
    }
    // 把音频流转换为可持久化候选项。
    final audios = bestAudios.values
        .map(
          (BiliDashStream stream) => StoredAudioOption(
            qualityId: stream.id,
            qualityLabel: _audioQualityLabel(stream.id, stream.bandwidth),
            codec: stream.codecs,
            bandwidth: stream.bandwidth,
            estimatedSizeBytes: estimateDashStreamSizeBytes(
              stream,
              manifest.duration,
            ),
          ),
        )
        .toList(growable: false);
    // 音频按产品音质等级从高到低排序。
    audios.sort(
      (StoredAudioOption left, StoredAudioOption right) => _audioQualityRank(
        right.qualityId,
      ).compareTo(_audioQualityRank(left.qualityId)),
    );
    // 返回完整本地候选清单。
    return StoredDashOptions(
      durationMilliseconds: manifest.duration.inMilliseconds,
      videos: videos,
      audios: audios,
    );
  }

  /// 从数据库 JSON 恢复候选清单。
  factory StoredDashOptions.decode(String source) {
    // JSON 根节点必须是对象。
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('DASH 候选清单格式无效。');
    }
    // 读取视频和音频原始数组。
    final rawVideos = decoded['videos'];
    final rawAudios = decoded['audios'];
    if (rawVideos is! List || rawAudios is! List) {
      throw const FormatException('DASH 候选清单缺少音视频数组。');
    }
    // 逐项恢复类型安全视频候选。
    final videos = rawVideos
        .map(StoredVideoOption.fromJson)
        .toList(growable: false);
    // 逐项恢复类型安全音频候选。
    final audios = rawAudios
        .map(StoredAudioOption.fromJson)
        .toList(growable: false);
    // 返回数据库快照。
    return StoredDashOptions(
      durationMilliseconds: _jsonInt(decoded['durationMilliseconds']) ?? 0,
      videos: videos,
      audios: audios,
    );
  }

  /// 编码为数据库可保存的稳定 JSON 字符串。
  String encode() {
    // URL 不属于长期元数据，因此序列化内容只包含本地选择所需字段。
    return jsonEncode(<String, Object?>{
      'durationMilliseconds': durationMilliseconds,
      'videos': videos
          .map((StoredVideoOption option) => option.toJson())
          .toList(growable: false),
      'audios': audios
          .map((StoredAudioOption option) => option.toJson())
          .toList(growable: false),
    });
  }

  /// 按目标画质和编码从本地候选中选择实际视频项。
  StoredVideoOption selectVideo({
    int? qualityId,
    BiliVideoCodec? preferredCodec,
  }) {
    // 没有视频候选时不能创建有效任务选择。
    if (videos.isEmpty) throw StateError('本地 DASH 清单没有视频候选。');
    // 去重并按质量代码升序排列，便于执行向下降级。
    final availableQualityIds =
        videos
            .map((StoredVideoOption option) => option.qualityId)
            .toSet()
            .toList(growable: false)
          ..sort();
    // 选择精确目标、低于目标的最高档或最低可用档。
    final selectedQualityId = _selectQualityId(availableQualityIds, qualityId);
    // 保留实际画质下的全部编码候选。
    final qualityCandidates = videos
        .where(
          (StoredVideoOption option) => option.qualityId == selectedQualityId,
        )
        .toList(growable: false);
    // 指定编码存在时优先精确匹配。
    final codecCandidates = preferredCodec == null
        ? qualityCandidates
        : qualityCandidates
              .where(
                (StoredVideoOption option) => option.codec == preferredCodec,
              )
              .toList(growable: false);
    // 指定编码不可用时回退同画质其他编码。
    final candidates = codecCandidates.isEmpty
        ? qualityCandidates
        : codecCandidates;
    // 按兼容编码和平均码率选择稳定代表项。
    candidates.sort((StoredVideoOption left, StoredVideoOption right) {
      // 优先兼容编码顺序。
      final codecComparison = _videoCodecRank(
        left.codec,
      ).compareTo(_videoCodecRank(right.codec));
      if (codecComparison != 0) return codecComparison;
      // 同编码优先更高平均码率。
      return right.bandwidth.compareTo(left.bandwidth);
    });
    // 返回最终本地选择。
    return candidates.first;
  }

  /// 按目标音质从本地候选中选择实际音频项。
  StoredAudioOption selectAudio({int? qualityId}) {
    // 没有音频候选时不能创建双流任务。
    if (audios.isEmpty) throw StateError('本地 DASH 清单没有音频候选。');
    // 去重后按产品音质等级升序排列。
    final availableQualityIds =
        audios
            .map((StoredAudioOption option) => option.qualityId)
            .toSet()
            .toList(growable: false)
          ..sort(
            (int left, int right) =>
                _audioQualityRank(left).compareTo(_audioQualityRank(right)),
          );
    // 未指定目标时选择本地最高音质。
    var selectedQualityId = availableQualityIds.last;
    if (qualityId != null && availableQualityIds.contains(qualityId)) {
      // 精确存在时直接命中。
      selectedQualityId = qualityId;
    } else if (qualityId != null) {
      // 目标不存在时优先选择不高于目标的最高档。
      final requestedRank = _audioQualityRank(qualityId);
      // 筛选低于目标的候选。
      final lower = availableQualityIds
          .where((int id) => _audioQualityRank(id) < requestedRank)
          .toList(growable: false);
      // 没有更低档时使用最低可用音质。
      selectedQualityId = lower.isEmpty
          ? availableQualityIds.first
          : lower.last;
    }
    // 同音质只保留平均码率最高的代表项。
    final candidates =
        audios
            .where(
              (StoredAudioOption option) =>
                  option.qualityId == selectedQualityId,
            )
            .toList(growable: false)
          ..sort(
            (StoredAudioOption left, StoredAudioOption right) =>
                right.bandwidth.compareTo(left.bandwidth),
          );
    // 返回最终本地选择。
    return candidates.first;
  }
}

/// 一条持久化视频画质和编码候选。
final class StoredVideoOption {
  /// 创建视频候选元数据。
  const StoredVideoOption({
    required this.qualityId,
    required this.qualityLabel,
    required this.codec,
    required this.bandwidth,
    required this.width,
    required this.height,
    required this.estimatedSizeBytes,
  });

  /// B 站视频质量代码。
  final int qualityId;

  /// 质量显示文案。
  final String qualityLabel;

  /// 稳定视频编码枚举。
  final BiliVideoCodec codec;

  /// DASH 平均码率 bit/s。
  final int bandwidth;

  /// 视频宽度。
  final int? width;

  /// 视频高度。
  final int? height;

  /// 解析时计算的预计字节数。
  final int? estimatedSizeBytes;

  /// 从 JSON 节点恢复视频候选。
  factory StoredVideoOption.fromJson(Object? source) {
    // 单项必须是字符串键对象。
    if (source is! Map<String, Object?>) {
      throw const FormatException('视频候选格式无效。');
    }
    // 解析稳定编码名称，未知值保持 unknown。
    final codecName = source['codec']?.toString();
    // 查找对应编码枚举。
    final codec = BiliVideoCodec.values.firstWhere(
      (BiliVideoCodec value) => value.name == codecName,
      orElse: () => BiliVideoCodec.unknown,
    );
    // 质量代码是候选项必要字段。
    final qualityId = _jsonInt(source['qualityId']);
    if (qualityId == null) throw const FormatException('视频候选缺少质量代码。');
    // 返回类型安全候选。
    return StoredVideoOption(
      qualityId: qualityId,
      qualityLabel: source['qualityLabel']?.toString() ?? '${qualityId}P',
      codec: codec,
      bandwidth: _jsonInt(source['bandwidth']) ?? 0,
      width: _jsonInt(source['width']),
      height: _jsonInt(source['height']),
      estimatedSizeBytes: _jsonInt(source['estimatedSizeBytes']),
    );
  }

  /// 转换为稳定 JSON 对象。
  Map<String, Object?> toJson() => <String, Object?>{
    'qualityId': qualityId,
    'qualityLabel': qualityLabel,
    'codec': codec.name,
    'bandwidth': bandwidth,
    'width': width,
    'height': height,
    'estimatedSizeBytes': estimatedSizeBytes,
  };
}

/// 一条持久化音频质量候选。
final class StoredAudioOption {
  /// 创建音频候选元数据。
  const StoredAudioOption({
    required this.qualityId,
    required this.qualityLabel,
    required this.codec,
    required this.bandwidth,
    required this.estimatedSizeBytes,
  });

  /// B 站音频质量代码。
  final int qualityId;

  /// 音质显示文案。
  final String qualityLabel;

  /// RFC 6381 音频编码文本。
  final String codec;

  /// DASH 平均码率 bit/s。
  final int bandwidth;

  /// 解析时计算的预计字节数。
  final int? estimatedSizeBytes;

  /// 从 JSON 节点恢复音频候选。
  factory StoredAudioOption.fromJson(Object? source) {
    // 单项必须是字符串键对象。
    if (source is! Map<String, Object?>) {
      throw const FormatException('音频候选格式无效。');
    }
    // 质量代码是候选项必要字段。
    final qualityId = _jsonInt(source['qualityId']);
    if (qualityId == null) throw const FormatException('音频候选缺少质量代码。');
    // 返回类型安全候选。
    return StoredAudioOption(
      qualityId: qualityId,
      qualityLabel: source['qualityLabel']?.toString() ?? '自动',
      codec: source['codec']?.toString() ?? '',
      bandwidth: _jsonInt(source['bandwidth']) ?? 0,
      estimatedSizeBytes: _jsonInt(source['estimatedSizeBytes']),
    );
  }

  /// 转换为稳定 JSON 对象。
  Map<String, Object?> toJson() => <String, Object?>{
    'qualityId': qualityId,
    'qualityLabel': qualityLabel,
    'codec': codec,
    'bandwidth': bandwidth,
    'estimatedSizeBytes': estimatedSizeBytes,
  };
}

/// 从升序质量代码中执行精确命中和向下降级。
int _selectQualityId(List<int> availableQualityIds, int? requestedQualityId) {
  // 未指定目标时使用最高可用画质。
  if (requestedQualityId == null) return availableQualityIds.last;
  // 精确存在时直接返回。
  if (availableQualityIds.contains(requestedQualityId)) {
    return requestedQualityId;
  }
  // 选择低于目标的全部候选。
  final lower = availableQualityIds
      .where((int qualityId) => qualityId < requestedQualityId)
      .toList(growable: false);
  // 没有更低档时使用最低可用画质。
  return lower.isEmpty ? availableQualityIds.first : lower.last;
}

/// 返回稳定视频编码优先级。
int _videoCodecRank(BiliVideoCodec codec) => switch (codec) {
  BiliVideoCodec.avc => 0,
  BiliVideoCodec.hevc => 1,
  BiliVideoCodec.av1 => 2,
  BiliVideoCodec.unknown => 3,
};

/// 返回音质从低到高的产品等级。
int _audioQualityRank(int qualityId) => switch (qualityId) {
  30216 => 0,
  30232 => 1,
  30280 => 2,
  30250 => 3,
  30251 => 4,
  _ => 2,
};

/// 将音频质量代码转换为产品短文案。
String _audioQualityLabel(int qualityId, int bandwidth) => switch (qualityId) {
  30216 => '64K',
  30232 => '132K',
  30280 => '192K',
  30250 => '杜比',
  30251 => 'Hi-Res',
  _ => bandwidth > 0 ? '${(bandwidth / 1000).round()}K' : '自动',
};

/// 将 JSON 数值安全转换为整数。
int? _jsonInt(Object? value) {
  // JSON 解码后的整数直接返回。
  if (value is int) return value;
  // 兼容被编码为浮点但没有小数部分的数值。
  if (value is num) return value.toInt();
  // 其余类型视为缺失。
  return null;
}
