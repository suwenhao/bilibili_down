import 'package:drift/drift.dart';

import '../../../features/downloads/domain/download_task_phase.dart';

/// 下载任务主表，保存视频身份、用户选择、总进度和最终结果。
@DataClassName('DownloadTaskRecord')
@TableIndex(name: 'download_tasks_phase_updated', columns: {#phase, #updatedAt})
class DownloadTasks extends Table {
  /// 业务层生成且跨应用重启保持稳定的任务 ID。
  TextColumn get taskId => text()();

  /// 用户粘贴的原始链接或 BV、AV、EP、SS 输入。
  TextColumn get sourceInput => text()();

  /// 普通视频解析后的 BVID，番剧或解析前允许为空。
  TextColumn get bvid => text().nullable()();

  /// 选中分集对应的 CID，解析前允许为空。
  IntColumn get cid => integer().nullable()();

  /// 番剧分集 EP ID，普通视频允许为空。
  IntColumn get epid => integer().nullable()();

  /// 视频或分集标题。
  TextColumn get title => text()();

  /// UP 主或内容发布者名称，接口未返回时允许为空。
  TextColumn get publisherName => text().nullable()();

  /// UP 主数字 ID，PGC 或旧任务允许为空。
  IntColumn get publisherId => integer().nullable()();

  /// 合集、季度或视频主标题，用于后续本地重算命名规则。
  TextColumn get collectionTitle => text().nullable()();

  /// 解析时保存的普通投稿或 PGC 内容类型名称。
  TextColumn get contentType => text().nullable()();

  /// 视频或合集简介，接口未返回时允许为空。
  TextColumn get description => text().nullable()();

  /// 原始分辨率文本，例如 1920x1080。
  TextColumn get resolutionLabel => text().nullable()();

  /// 视频或分集发布时间，接口未返回时允许为空。
  DateTimeColumn get publishedAt => dateTime().nullable()();

  /// 封面远程地址，接口未返回时允许为空。
  TextColumn get coverUrl => text().nullable()();

  /// 多 P 或合集中的显示顺序，从一开始计数。
  IntColumn get partIndex => integer().withDefault(const Constant(1))();

  /// 用户选择的 B 站清晰度代码。
  IntColumn get qualityId => integer().nullable()();

  /// 清晰度显示名称，例如 1080P 高码率。
  TextColumn get qualityLabel => text().nullable()();

  /// 用户选择的视频编码名称，例如 AVC、HEVC 或 AV1。
  TextColumn get videoCodec => text().nullable()();

  /// 用户选择的音频编码或音质名称。
  TextColumn get audioCodec => text().nullable()();

  /// 用户实际选中的 B 站 DASH 音频质量代码。
  IntColumn get audioQualityId => integer().nullable()();

  /// 解析时根据选中视频流码率和时长计算的预计字节数。
  IntColumn get estimatedVideoSizeBytes => integer().nullable()();

  /// 解析时根据选中音频流码率和时长计算的预计字节数。
  IntColumn get estimatedAudioSizeBytes => integer().nullable()();

  /// 解析时保存的不含临时 URL 的 DASH 候选流 JSON。
  TextColumn get dashOptionsJson => text().nullable()();

  /// 当前主任务勾选的封面、音频、弹幕和字幕 JSON 字符串数组。
  TextColumn get extraResourcesJson =>
      text().withDefault(const Constant('[]'))();

  /// 视频总时长毫秒数，用于计算 FFmpeg 合并进度。
  IntColumn get durationMilliseconds => integer().nullable()();

  /// 下载和合并临时文件所在目录。
  TextColumn get temporaryDirectory => text().nullable()();

  /// 合并完成后交付给用户的最终文件路径。
  TextColumn get outputPath => text().nullable()();

  /// 当前任务使用的 aria2 或系统下载后端。
  TextColumn get downloadBackend =>
      textEnum<PersistedDownloadBackend>().nullable()();

  /// 任务当前所处的业务阶段。
  TextColumn get phase => textEnum<DownloadTaskPhase>().withDefault(
    Constant(DownloadTaskPhase.queued.name),
  )();

  /// 进入暂停前的阶段，恢复时用于返回正确流程位置。
  TextColumn get resumePhase => textEnum<DownloadTaskPhase>().nullable()();

  /// 任务总进度，取值范围为零到一。
  RealColumn get progress => real().withDefault(const Constant(0.0))();

  /// 音视频分流当前网络速度之和，单位为字节每秒。
  IntColumn get downloadSpeedBytesPerSecond =>
      integer().withDefault(const Constant(0))();

  /// 解析或下载失败后的累计重试次数。
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  /// 便于程序判断的稳定错误码。
  TextColumn get errorCode => text().nullable()();

  /// 面向日志和界面展示的错误说明。
  TextColumn get errorMessage => text().nullable()();

  /// 任务首次创建时间。
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 任务最近一次状态或进度更新时间。
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// 最终文件生成时间，未完成时为空。
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// 使用业务任务 ID 作为主键，保证引擎事件可以直接关联。
  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{taskId};
}
