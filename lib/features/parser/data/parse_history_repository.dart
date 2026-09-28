import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/database/tables/parse_histories.dart';
import '../../../core/logging/app_debug_log.dart';
import '../../../services/bilibili/bili_input_normalizer.dart';
import '../../../services/bilibili/bilibili_parser_service.dart';
import '../../../services/bilibili/models/bili_media_info.dart';

/// 提供解析历史持久化仓库。
final parseHistoryRepositoryProvider = Provider<ParseHistoryRepository>((
  Ref ref,
) {
  // 解析历史和下载任务共用同一个 SQLite 数据库连接。
  final database = ref.watch(appDatabaseProvider);
  // 仓库只封装解析历史表，避免解析控制器直接操作 Drift 细节。
  return ParseHistoryRepository(database);
});

/// 监听最近解析历史列表。
final parseHistoryEntriesProvider =
    StreamProvider.autoDispose<List<ParseHistoryEntry>>((Ref ref) {
      // 历史页只需要最近列表，离开页面后自动释放查询订阅。
      final repository = ref.watch(parseHistoryRepositoryProvider);
      return repository.watchRecent();
    });

/// 一条可直接恢复到解析页的历史记录。
final class ParseHistoryEntry {
  /// 创建解析历史展示和恢复对象。
  const ParseHistoryEntry({
    required this.record,
    required this.media,
    required this.selectedIndexes,
  });

  /// Drift 返回的历史记录原始行。
  final ParseHistoryRecord record;

  /// 从 JSON 快照还原的媒体信息。
  final BiliMediaInfo media;

  /// 点击历史后需要恢复的分集选择。
  final Set<int> selectedIndexes;
}

/// 解析历史表读写封装。
final class ParseHistoryRepository {
  /// 创建解析历史仓库。
  const ParseHistoryRepository(this._database);

  /// 应用级 SQLite 数据库。
  final AppDatabase _database;

  /// 监听最近解析历史，默认最多返回一百条。
  Stream<List<ParseHistoryEntry>> watchRecent({int limit = 100}) {
    // 查询按最近刷新时间倒序，和用户中心历史的阅读顺序保持一致。
    final query = _database.select(_database.parseHistories)
      ..orderBy(<OrderClauseGenerator<ParseHistories>>[
        (ParseHistories table) => OrderingTerm.desc(table.updatedAt),
        (ParseHistories table) => OrderingTerm.asc(table.mediaTitle),
      ])
      ..limit(limit);
    // 解码失败的旧记录会被跳过，避免一条损坏快照拖垮整页历史。
    return query.watch().map((List<ParseHistoryRecord> records) {
      return records
          .map(_entryFromRecord)
          .whereType<ParseHistoryEntry>()
          .toList(growable: false);
    });
  }

  /// 保存一次成功解析后的完整媒体快照。
  Future<void> saveParsedInput({
    required String sourceInput,
    required BiliParsedInput parsedInput,
    required Set<int> selectedIndexes,
  }) async {
    // 解析目标提供去重键，同一目标重复解析只更新最近快照。
    final historyKey = _historyKey(parsedInput.target);
    // 当前时间由 Dart 侧生成，保证插入和更新使用同一时刻。
    final now = DateTime.now();
    // 选中集合按数值排序后写入，恢复时不会受 Set 遍历顺序影响。
    final sortedIndexes = selectedIndexes.toList(growable: false)..sort();
    // Companion 同时携带展示字段和完整 JSON 快照。
    final companion = ParseHistoriesCompanion.insert(
      historyKey: historyKey,
      sourceInput: sourceInput,
      targetKind: parsedInput.target.kind.name,
      canonicalId: parsedInput.target.canonicalId,
      mediaTitle: parsedInput.media.title,
      coverUrl: Value(parsedInput.media.coverUrl),
      publisherName: Value(parsedInput.media.publisherName),
      episodeCount: Value(parsedInput.media.episodes.length),
      mediaJson: jsonEncode(_mediaToJson(parsedInput.media)),
      selectedIndexesJson: Value(jsonEncode(sortedIndexes)),
      updatedAt: Value(now),
    );
    // 主键冲突时更新最近解析结果，保留用户历史列表中的单条入口。
    await _database
        .into(_database.parseHistories)
        .insertOnConflictUpdate(companion);
    AppDebugLog.parser(
      'Parse history saved target=${parsedInput.target.kind.name} '
      'episodes=${parsedInput.media.episodes.length} selected=${sortedIndexes.length}',
    );
  }

  /// 删除指定历史键对应的一条解析快照。
  Future<int> deleteByHistoryKey(String historyKey) async {
    // 历史键是解析历史表主键，单条删除不会影响同目标以外的记录。
    final deleted =
        await (_database.delete(_database.parseHistories)..where(
              (ParseHistories table) => table.historyKey.equals(historyKey),
            ))
            .go();
    AppDebugLog.parser('Parse history deleted count=$deleted');
    return deleted;
  }

  /// 清空全部解析历史快照。
  Future<int> clearAll() async {
    // 清空仅删除解析历史表，不触碰下载任务、账号数据或缓存文件。
    final deleted = await _database.delete(_database.parseHistories).go();
    AppDebugLog.parser('Parse history cleared count=$deleted');
    return deleted;
  }

  /// 从数据库行恢复可用条目，快照损坏时返回空值。
  ParseHistoryEntry? _entryFromRecord(ParseHistoryRecord record) {
    try {
      // mediaJson 是解析页恢复的核心快照，必须解成对象后才能展示。
      final media = _mediaFromJson(jsonDecode(record.mediaJson));
      // selectedIndexesJson 只保存整数数组，异常时回退首个分集。
      final selectedIndexes = _selectedIndexesFromJson(
        jsonDecode(record.selectedIndexesJson),
        media,
      );
      return ParseHistoryEntry(
        record: record,
        media: media,
        selectedIndexes: selectedIndexes,
      );
    } on Object catch (error) {
      // 损坏记录留在库里便于未来诊断，本次列表渲染直接跳过。
      AppDebugLog.parser('Parse history skipped corrupt record error=$error');
      return null;
    }
  }

  /// 生成目标去重键。
  String _historyKey(BiliInputTarget target) {
    // BVID 大小写不影响同一稿件身份，其余数字目标本身稳定。
    final canonicalId = target.kind == BiliInputKind.bvid
        ? target.canonicalId.toLowerCase()
        : target.canonicalId;
    return '${target.kind.name}:$canonicalId';
  }

  /// 把媒体对象转换成可持久化 JSON。
  Map<String, Object?> _mediaToJson(BiliMediaInfo media) {
    return <String, Object?>{
      'contentType': media.contentType.name,
      'title': media.title,
      'coverUrl': media.coverUrl,
      'description': media.description,
      'publisherName': media.publisherName,
      'publisherId': media.publisherId,
      'publishedAt': media.publishedAt?.millisecondsSinceEpoch,
      'seasonId': media.seasonId,
      'episodes': media.episodes.map(_episodeToJson).toList(growable: false),
    };
  }

  /// 把分集对象转换成可持久化 JSON。
  Map<String, Object?> _episodeToJson(BiliEpisodeInfo episode) {
    return <String, Object?>{
      'contentType': episode.contentType.name,
      'bvid': episode.bvid,
      'cid': episode.cid,
      'index': episode.index,
      'title': episode.title,
      'durationMilliseconds': episode.duration.inMilliseconds,
      'episodeId': episode.episodeId,
      'seasonId': episode.seasonId,
      'coverUrl': episode.coverUrl,
      'width': episode.width,
      'height': episode.height,
      'publishedAt': episode.publishedAt?.millisecondsSinceEpoch,
      'pageNumber': episode.pageNumber,
    };
  }

  /// 从 JSON 快照恢复媒体对象。
  BiliMediaInfo _mediaFromJson(Object? value) {
    // 快照根节点必须是对象，缺失时说明数据库记录已损坏。
    if (value is! Map) {
      throw const FormatException('解析历史媒体快照格式错误。');
    }
    // JSON 解码得到的动态 Map 需要转成业务读取使用的键值类型。
    final json = value.cast<String, Object?>();
    // episodes 是解析页分集列表的必需数据。
    final rawEpisodes = json['episodes'];
    if (rawEpisodes is! List) {
      throw const FormatException('解析历史分集快照格式错误。');
    }
    // 解码全部分集并保持数据库中的原始顺序。
    final episodes = rawEpisodes.map(_episodeFromJson).toList(growable: false);
    return BiliMediaInfo(
      contentType: _contentTypeFromName(json['contentType']),
      title: _stringValue(json['title'], fallback: '未命名视频'),
      coverUrl: _nullableString(json['coverUrl']),
      description: _nullableString(json['description']),
      publisherName: _nullableString(json['publisherName']),
      publisherId: _intValue(json['publisherId']),
      publishedAt: _dateTimeValue(json['publishedAt']),
      seasonId: _intValue(json['seasonId']),
      episodes: List<BiliEpisodeInfo>.unmodifiable(episodes),
    );
  }

  /// 从 JSON 快照恢复单个分集。
  BiliEpisodeInfo _episodeFromJson(Object? value) {
    // 每个分集必须是对象，否则不能构造可下载身份。
    if (value is! Map) {
      throw const FormatException('解析历史分集条目格式错误。');
    }
    // JSON 解码得到的动态 Map 需要转成业务读取使用的键值类型。
    final json = value.cast<String, Object?>();
    return BiliEpisodeInfo(
      contentType: _contentTypeFromName(json['contentType']),
      bvid: _stringValue(json['bvid']),
      cid: _intValue(json['cid']) ?? 0,
      index: _intValue(json['index']) ?? 1,
      title: _stringValue(json['title'], fallback: '未命名分集'),
      duration: Duration(
        milliseconds: _intValue(json['durationMilliseconds']) ?? 0,
      ),
      episodeId: _intValue(json['episodeId']),
      seasonId: _intValue(json['seasonId']),
      coverUrl: _nullableString(json['coverUrl']),
      width: _intValue(json['width']),
      height: _intValue(json['height']),
      publishedAt: _dateTimeValue(json['publishedAt']),
      pageNumber: _intValue(json['pageNumber']),
    );
  }

  /// 从 JSON 数组恢复选中分集，缺失时选中首个分集。
  Set<int> _selectedIndexesFromJson(Object? value, BiliMediaInfo media) {
    // 数据库里的数组只接受整数，其他类型忽略。
    final indexes = value is List
        ? value.whereType<int>().toSet()
        : const <int>{};
    // 过滤已经不在快照中的 index，防止后续 UI 选择不存在条目。
    final available = media.episodes
        .map((BiliEpisodeInfo episode) => episode.index)
        .toSet();
    final selected = indexes.intersection(available);
    // 没有有效选择时兜底第一项，保持解析页底部操作栏可用。
    if (selected.isEmpty && media.episodes.isNotEmpty) {
      return <int>{media.episodes.first.index};
    }
    return selected;
  }

  /// 从文本名称恢复内容类型。
  BiliContentType _contentTypeFromName(Object? value) {
    // 未知旧值按普通投稿处理，避免历史页无法打开。
    final name = value is String ? value : '';
    return BiliContentType.values.firstWhere(
      (BiliContentType type) => type.name == name,
      orElse: () => BiliContentType.ugc,
    );
  }

  /// 读取可空字符串，空串按空值处理。
  String? _nullableString(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }

  /// 读取必填字符串，缺失时使用兜底文案。
  String _stringValue(Object? value, {String fallback = ''}) {
    final text = value is String ? value : '';
    return text.isEmpty ? fallback : text;
  }

  /// 读取整数，兼容 JSON 解码后的 num。
  int? _intValue(Object? value) {
    return value is num ? value.toInt() : null;
  }

  /// 从毫秒时间戳恢复时间。
  DateTime? _dateTimeValue(Object? value) {
    final milliseconds = _intValue(value);
    if (milliseconds == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
}
