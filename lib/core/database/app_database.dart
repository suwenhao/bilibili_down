import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../features/downloads/domain/download_task_phase.dart';
import '../logging/app_debug_log.dart';
import '../platform/application_data_directory.dart';
import 'tables/download_artifacts.dart';
import 'tables/download_streams.dart';
import 'tables/download_tasks.dart';
import 'tables/parse_histories.dart';

part 'app_database.g.dart';

/// BiliDown 业务数据库，保存下载任务、媒体分流和本地文件记录。
@DriftDatabase(
  tables: <Type>[
    DownloadTasks,
    DownloadStreams,
    DownloadArtifacts,
    ParseHistories,
  ],
)
final class AppDatabase extends _$AppDatabase {
  /// 创建跨平台后台数据库连接；测试时可以注入内存执行器。
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? _openApplicationDatabase());

  /// 保存唯一关闭任务，允许退出链路和 Provider 销毁安全复用。
  Future<void>? _closeFuture;

  /// 当前数据库结构版本；版本九新增解析历史快照。
  @override
  int get schemaVersion => 9;

  /// 关闭 SQLite 连接和后台 isolate，重复调用时等待同一次关闭操作。
  @override
  Future<void> close() {
    // Provider 销毁可能与桌面退出链路先后触发，不能重复关闭执行器。
    final existing = _closeFuture;
    if (existing != null) return existing;
    // 保存 Drift 返回的关闭任务，供后续调用者等待相同生命周期结果。
    final closeFuture = super.close();
    _closeFuture = closeFuture;
    return closeFuture;
  }

  /// 定义首次建库、未来升级入口和每次连接初始化规则。
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) async {
      // 首次启动时按依赖顺序创建全部业务表和索引。
      await migrator.createAll();
    },
    onUpgrade: (Migrator migrator, int from, int to) async {
      // 从版本一升级时为主任务增加可为空的视频时长，不影响已有任务数据。
      if (from < 2) {
        await migrator.addColumn(
          downloadTasks,
          downloadTasks.durationMilliseconds,
        );
      }
      // 从旧版本升级时补充 v2 任务卡展示所需字段，全部可空以兼容已有任务。
      if (from < 3) {
        // 增加发布者名称。
        await migrator.addColumn(downloadTasks, downloadTasks.publisherName);
        // 增加视频简介。
        await migrator.addColumn(downloadTasks, downloadTasks.description);
        // 增加原始分辨率文本。
        await migrator.addColumn(downloadTasks, downloadTasks.resolutionLabel);
        // 增加视频发布时间。
        await migrator.addColumn(downloadTasks, downloadTasks.publishedAt);
      }
      // 从旧版本升级时补充音频质量 ID，旧任务为空时仍按原最高音质逻辑恢复。
      if (from < 4) {
        // 增加实际选中的 DASH 音频质量代码。
        await migrator.addColumn(downloadTasks, downloadTasks.audioQualityId);
      }
      // 从旧版本升级时补充解析阶段预计音视频大小，旧任务保持为空。
      if (from < 5) {
        // 增加选中视频流预计字节数。
        await migrator.addColumn(
          downloadTasks,
          downloadTasks.estimatedVideoSizeBytes,
        );
        // 增加选中音频流预计字节数。
        await migrator.addColumn(
          downloadTasks,
          downloadTasks.estimatedAudioSizeBytes,
        );
      }
      // 从旧版本升级时补充本地质量重选和路径重算所需解析快照。
      if (from < 6) {
        // 增加 UP 主数字 ID。
        await migrator.addColumn(downloadTasks, downloadTasks.publisherId);
        // 增加合集或季度主标题。
        await migrator.addColumn(downloadTasks, downloadTasks.collectionTitle);
        // 增加普通投稿或 PGC 内容类型名称。
        await migrator.addColumn(downloadTasks, downloadTasks.contentType);
        // 增加不含临时 URL 的 DASH 候选流 JSON。
        await migrator.addColumn(downloadTasks, downloadTasks.dashOptionsJson);
      }
      // 从旧版本升级时补充实时速度，默认零表示未知或当前未下载。
      if (from < 7) {
        // 主任务速度用于任务列表直接监听双流汇总结果。
        await migrator.addColumn(
          downloadTasks,
          downloadTasks.downloadSpeedBytesPerSecond,
        );
        // 分流速度分别保存音频和视频引擎上报值。
        await migrator.addColumn(
          downloadStreams,
          downloadStreams.downloadSpeedBytesPerSecond,
        );
      }
      // 新任务把附加资源选择收口到主任务 JSON 数组，不再创建独立资源卡片。
      if (from < 8) {
        // 默认空数组兼容升级前普通任务；旧独立资源记录由用户自行清理。
        await migrator.addColumn(
          downloadTasks,
          downloadTasks.extraResourcesJson,
        );
      }
      // 从旧版本升级时新增解析历史表，保存解析页可直接恢复的本地快照。
      if (from < 9) {
        // 历史表没有外键依赖，可在现有任务表之后独立创建。
        await migrator.createTable(parseHistories);
      }
      // 未来升级必须继续按版本顺序追加迁移，禁止删库重建用户数据。
      if (to > 9) {
        throw StateError('Unsupported database migration: $from -> $to');
      }
    },
    beforeOpen: (OpeningDetails details) async {
      // SQLite 默认关闭外键约束，每次连接都必须显式开启级联删除。
      await customStatement('PRAGMA foreign_keys = ON');
      // 数据库繁忙时最多等待五秒，降低后台任务并发写入产生的瞬时失败。
      await customStatement('PRAGMA busy_timeout = 5000');
    },
  );
}

/// 创建位于应用内部数据目录中的 Drift 连接。
QueryExecutor _openApplicationDatabase() {
  // 自定义完整数据库路径，避免 drift_flutter 把文件放到平台默认的不透明位置。
  return driftDatabase(
    name: 'bilidown',
    native: DriftNativeOptions(
      databasePath: _resolveApplicationDatabasePath,
      setup: (database) {
        // WAL 允许读取列表与下载进度写入更好地并行，适合多任务持续更新。
        database.execute('PRAGMA journal_mode = WAL;');
        // NORMAL 在 WAL 模式下兼顾崩溃安全与高频进度写入性能。
        database.execute('PRAGMA synchronous = NORMAL;');
      },
    ),
  );
}

/// 解析数据库路径；旧 Documents 目录由用户按需手动迁移。
Future<String> _resolveApplicationDatabasePath() async {
  // 数据库与封面缓存、诊断日志共用统一应用数据目录。
  final applicationDirectory = await resolveApplicationDataDirectory();
  // 数据库固定保存在统一应用数据目录中，Windows 对应 Roaming/com.bilidown.app。
  final targetFile = File(p.join(applicationDirectory.path, 'bilidown.sqlite'));
  // Drift 打开前先执行 SQLite 快速检查，损坏文件会完整备份后由当前结构重建。
  await backupCorruptDatabaseIfNeeded(targetFile);
  // 返回 drift_flutter 要打开的最终绝对路径。
  return targetFile.path;
}

/// 检查现有 SQLite 主文件，损坏时备份主文件和 WAL/SHM 后返回备份路径。
Future<String?> backupCorruptDatabaseIfNeeded(
  File databaseFile, {
  DateTime? now,
}) async {
  // 首次启动没有旧文件时直接交给 Drift 创建当前结构。
  if (!await databaseFile.exists()) return null;
  sqlite.Database? database;
  var valid = false;
  try {
    // 只读打开避免检查过程修改用户数据库或创建新的日志文件。
    database = sqlite.sqlite3.open(
      databaseFile.path,
      mode: sqlite.OpenMode.readOnly,
    );
    // quick_check(1) 在发现首个问题后停止，降低每次启动的检查成本。
    final result = database.select('PRAGMA quick_check(1)');
    valid = result.isNotEmpty && result.first.values.first == 'ok';
  } on sqlite.SqliteException {
    // 文件头损坏、页面校验失败或并非 SQLite 都进入备份重建流程。
    valid = false;
  } finally {
    // 释放只读句柄后才能在 Windows 上移动损坏文件。
    database?.close();
  }
  if (valid) return null;
  // 文件名使用 UTC 微秒时间戳，连续两次损坏也不会覆盖之前备份。
  final timestamp = (now ?? DateTime.now()).toUtc().microsecondsSinceEpoch;
  final backupPath = '${databaseFile.path}.corrupt-$timestamp';
  AppDebugLog.database('Corrupt database detected backup=$backupPath');
  // 先移动 WAL/SHM，最后移动主文件作为整组备份完成标记。
  for (final suffix in const <String>['-wal', '-shm']) {
    final sidecar = File('${databaseFile.path}$suffix');
    if (!await sidecar.exists()) continue;
    await _moveDatabaseFile(sidecar, File('$backupPath$suffix'));
  }
  await _moveDatabaseFile(databaseFile, File(backupPath));
  AppDebugLog.database('Corrupt database backup completed');
  // 返回主备份路径供测试或未来诊断界面展示。
  return backupPath;
}

/// 优先原地移动数据库文件，跨文件系统失败时回退复制后删除。
Future<void> _moveDatabaseFile(File source, File target) async {
  try {
    // 同一文档目录下 rename 是原子操作，能避免复制中断产生半个数据库。
    await source.rename(target.path);
  } on FileSystemException {
    // 部分平台或沙盒不允许跨目录 rename，回退为完整复制。
    await source.copy(target.path);
    // 复制成功后删除旧文件，避免以后误打开旧数据库。
    await source.delete();
  }
}
