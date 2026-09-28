import 'package:drift/drift.dart';

import '../../../features/downloads/domain/download_task_phase.dart';
import 'download_tasks.dart';

/// DASH 视频流和音频流表，保存独立下载进度及引擎任务标识。
@DataClassName('DownloadStreamRecord')
@TableIndex(
  name: 'download_streams_engine_task',
  columns: {#engineTaskId},
  unique: true,
)
class DownloadStreams extends Table {
  /// 内部稳定分流 ID，建议使用“任务 ID + video/audio”。
  TextColumn get streamId => text()();

  /// 所属业务任务 ID，删除主任务时级联清理。
  TextColumn get taskId =>
      text().references(DownloadTasks, #taskId, onDelete: KeyAction.cascade)();

  /// 当前记录是视频流还是音频流。
  TextColumn get kind => textEnum<DownloadStreamKind>()();

  /// B 站返回的临时媒体地址，过期后由解析服务刷新。
  TextColumn get remoteUrl => text()();

  /// 媒体编码或音质标识。
  TextColumn get codec => text().nullable()();

  /// 分流文件下载完成后的本地临时路径。
  TextColumn get temporaryPath => text()();

  /// aria2 GID 或系统后台下载任务 ID。
  TextColumn get engineTaskId => text().nullable()();

  /// 分流在下载引擎中的当前状态。
  TextColumn get phase => textEnum<DownloadStreamPhase>().withDefault(
    Constant(DownloadStreamPhase.pending.name),
  )();

  /// 已经写入临时文件的字节数。
  IntColumn get downloadedBytes => integer().withDefault(const Constant(0))();

  /// 服务端声明的总字节数，未知时为空。
  IntColumn get totalBytes => integer().nullable()();

  /// 当前分流网络下载速度，单位为字节每秒，非下载阶段为零。
  IntColumn get downloadSpeedBytesPerSecond =>
      integer().withDefault(const Constant(0))();

  /// 分流下载失败时用于程序判断的稳定错误码。
  TextColumn get errorCode => text().nullable()();

  /// 分流下载失败时的原始错误说明。
  TextColumn get errorMessage => text().nullable()();

  /// 媒体地址最近一次解析或刷新时间。
  DateTimeColumn get urlRefreshedAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// 分流状态或进度最近更新时间。
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// 使用稳定分流 ID 作为主键。
  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{streamId};

  /// 同一业务任务只能有一条视频流和一条音频流。
  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{taskId, kind},
  ];
}
