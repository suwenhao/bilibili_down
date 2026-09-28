import 'package:drift/drift.dart';

/// 解析历史表，保存解析页可直接恢复的媒体快照。
@DataClassName('ParseHistoryRecord')
@TableIndex(name: 'parse_histories_updated', columns: {#updatedAt})
class ParseHistories extends Table {
  /// 目标类型和标准 ID 组成的稳定键，同一个视频或季度重复解析时覆盖旧快照。
  TextColumn get historyKey => text()();

  /// 用户最近一次提交的原始输入，回填解析页输入框时使用。
  TextColumn get sourceInput => text()();

  /// 标准化后的目标类型，例如 bvid、episode 或 season。
  TextColumn get targetKind => text()();

  /// 标准化后的目标 ID，例如 BV 号、ep123 或 ss123。
  TextColumn get canonicalId => text()();

  /// 媒体主标题，列表展示和搜索摘要使用。
  TextColumn get mediaTitle => text()();

  /// 媒体封面远程地址，接口未返回时为空。
  TextColumn get coverUrl => text().nullable()();

  /// UP 主或内容发布者名称，接口未返回时为空。
  TextColumn get publisherName => text().nullable()();

  /// 当前解析结果包含的分集数量，列表无需解码 JSON 也能展示。
  IntColumn get episodeCount => integer().withDefault(const Constant(0))();

  /// 完整媒体和分集快照 JSON，用于点击历史后直接恢复解析页。
  TextColumn get mediaJson => text()();

  /// 解析完成时的选中分集 index JSON 数组，用于恢复默认勾选状态。
  TextColumn get selectedIndexesJson =>
      text().withDefault(const Constant('[]'))();

  /// 首次写入该历史目标的时间。
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 最近一次解析并刷新快照的时间。
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// 使用稳定历史键作为主键，避免同一目标产生无意义重复记录。
  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{historyKey};
}
