import 'package:drift/drift.dart';

import '../../../features/downloads/domain/download_task_phase.dart';
import 'download_tasks.dart';

/// 下载任务本地产物表，统一记录最终视频、临时流、封面、字幕和弹幕。
@DataClassName('DownloadArtifactRecord')
@TableIndex(name: 'download_artifacts_task_kind', columns: {#taskId, #kind})
class DownloadArtifacts extends Table {
  /// 数据库自增产物 ID。
  IntColumn get id => integer().autoIncrement()();

  /// 所属业务任务 ID，删除主任务时级联清理记录。
  TextColumn get taskId =>
      text().references(DownloadTasks, #taskId, onDelete: KeyAction.cascade)();

  /// 文件属于最终视频、临时流、封面、字幕或弹幕。
  TextColumn get kind => textEnum<DownloadArtifactKind>()();

  /// 文件绝对路径。
  TextColumn get path => text()();

  /// 文件大小，尚未生成或无法读取时为空。
  IntColumn get sizeBytes => integer().nullable()();

  /// 可选文件摘要，用于完整性校验和重复文件判断。
  TextColumn get checksum => text().nullable()();

  /// 任务完成后是否仍应保留该文件。
  BoolColumn get retained => boolean().withDefault(const Constant(false))();

  /// 产物记录创建时间。
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 同一任务、类型和路径只保存一条产物记录。
  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{taskId, kind, path},
  ];
}
