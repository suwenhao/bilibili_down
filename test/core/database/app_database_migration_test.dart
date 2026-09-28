import 'dart:io';

import 'package:bilibili_down/core/database/app_database.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  /// 验证每一个历史结构版本都能按顺序升级到当前版本并保留任务数据。
  test('版本 1 到 8 均可迁移到当前结构', () async {
    for (var fromVersion = 1; fromVersion < 9; fromVersion++) {
      // 每个历史版本使用独立文件，防止上一次升级结果污染下一次验证。
      final directory = await Directory.systemTemp.createTemp(
        'bilidown-migration-v$fromVersion-',
      );
      final databaseFile = File(p.join(directory.path, 'migration.sqlite'));
      try {
        // 先让 Drift 创建精确的当前表、外键和索引，再逆向移除后续版本字段。
        final current = AppDatabase(NativeDatabase(databaseFile));
        await current.customSelect('SELECT 1').getSingle();
        await current.close();
        final legacy = sqlite.sqlite3.open(databaseFile.path);
        try {
          for (final migration in _columnsAddedByVersion.entries) {
            // 模拟指定版本时只移除其后才出现的字段。
            if (migration.key <= fromVersion) continue;
            for (final column in migration.value) {
              legacy.execute(
                'ALTER TABLE ${column.table} DROP COLUMN ${column.name}',
              );
            }
          }
          for (final migration in _tablesAddedByVersion.entries) {
            // 新增表需要从旧版本快照中删除，才能验证 createTable 迁移。
            if (migration.key <= fromVersion) continue;
            for (final table in migration.value) {
              legacy.execute('DROP TABLE IF EXISTS $table');
            }
          }
          // 历史数据只写入所有版本共有的最低必要字段。
          legacy.execute(
            "INSERT INTO download_tasks (task_id, source_input, title) "
            "VALUES ('legacy-$fromVersion', 'BV-legacy', '历史任务')",
          );
          legacy.execute('PRAGMA user_version = $fromVersion');
        } finally {
          legacy.close();
        }

        // 重新打开会触发 AppDatabase 从指定历史版本依次执行迁移。
        final migrated = AppDatabase(NativeDatabase(databaseFile));
        final version = await migrated
            .customSelect('PRAGMA user_version')
            .getSingle();
        final taskColumns = await migrated
            .customSelect('PRAGMA table_info(download_tasks)')
            .get();
        final streamColumns = await migrated
            .customSelect('PRAGMA table_info(download_streams)')
            .get();
        final parseHistoryTable = await migrated
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name = 'parse_histories'",
            )
            .get();
        final preserved = await migrated
            .customSelect(
              'SELECT title FROM download_tasks WHERE task_id = ?',
              variables: <Variable<Object>>[
                Variable<String>('legacy-$fromVersion'),
              ],
            )
            .getSingle();
        expect(
          version.read<int>('user_version'),
          9,
          reason: 'v$fromVersion 应升级到 v9',
        );
        expect(
          taskColumns.map((row) => row.read<String>('name')),
          containsAll(_currentTaskColumns),
          reason: 'v$fromVersion 升级后任务字段应完整',
        );
        expect(
          streamColumns.map((row) => row.read<String>('name')),
          contains('download_speed_bytes_per_second'),
          reason: 'v$fromVersion 升级后分流速度字段应存在',
        );
        expect(
          parseHistoryTable,
          isNotEmpty,
          reason: 'v$fromVersion 升级后解析历史表应存在',
        );
        expect(preserved.read<String>('title'), '历史任务');
        await migrated.close();
      } finally {
        // 单个版本无论成功失败都清理测试数据库和旁路文件。
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    }
  });

  /// 验证非 SQLite 或页面损坏文件会被保留证据并让目标路径可重建。
  test('损坏数据库主文件和旁路文件会备份', () async {
    // 构造无法通过 SQLite 文件头检查的损坏主文件与两个旁路文件。
    final directory = await Directory.systemTemp.createTemp(
      'bilidown-corrupt-',
    );
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final databaseFile = File(p.join(directory.path, 'bilidown.sqlite'));
    await databaseFile.writeAsString('not a sqlite database');
    await File('${databaseFile.path}-wal').writeAsString('wal evidence');
    await File('${databaseFile.path}-shm').writeAsString('shm evidence');

    // 固定时间确保备份名称可预测，并验证原目标被释放给 Drift 重建。
    final backupPath = await backupCorruptDatabaseIfNeeded(
      databaseFile,
      now: DateTime.utc(2026, 7, 12),
    );
    expect(backupPath, isNotNull);
    expect(await databaseFile.exists(), isFalse);
    expect(await File(backupPath!).readAsString(), 'not a sqlite database');
    // SQLite 只读探测可能刷新旁路文件内容，但两份恢复证据仍必须随主文件保留。
    expect(await File('$backupPath-wal').exists(), isTrue);
    expect(await File('$backupPath-shm').exists(), isTrue);
  });
}

/// 一个历史版本新增字段所属表与数据库列名。
final class _AddedColumn {
  /// 保存 SQL 表名和蛇形列名。
  const _AddedColumn(this.table, this.name);

  /// 迁移执行 ALTER TABLE 的目标表。
  final String table;

  /// SQLite 中的真实列名。
  final String name;
}

/// 按 AppDatabase 迁移顺序列出 v2 至 v8 的新增字段。
const Map<int, List<_AddedColumn>> _columnsAddedByVersion =
    <int, List<_AddedColumn>>{
      2: <_AddedColumn>[
        _AddedColumn('download_tasks', 'duration_milliseconds'),
      ],
      3: <_AddedColumn>[
        _AddedColumn('download_tasks', 'publisher_name'),
        _AddedColumn('download_tasks', 'description'),
        _AddedColumn('download_tasks', 'resolution_label'),
        _AddedColumn('download_tasks', 'published_at'),
      ],
      4: <_AddedColumn>[_AddedColumn('download_tasks', 'audio_quality_id')],
      5: <_AddedColumn>[
        _AddedColumn('download_tasks', 'estimated_video_size_bytes'),
        _AddedColumn('download_tasks', 'estimated_audio_size_bytes'),
      ],
      6: <_AddedColumn>[
        _AddedColumn('download_tasks', 'publisher_id'),
        _AddedColumn('download_tasks', 'collection_title'),
        _AddedColumn('download_tasks', 'content_type'),
        _AddedColumn('download_tasks', 'dash_options_json'),
      ],
      7: <_AddedColumn>[
        _AddedColumn('download_tasks', 'download_speed_bytes_per_second'),
        _AddedColumn('download_streams', 'download_speed_bytes_per_second'),
      ],
      8: <_AddedColumn>[_AddedColumn('download_tasks', 'extra_resources_json')],
    };

/// 按 AppDatabase 迁移顺序列出新增表。
const Map<int, List<String>> _tablesAddedByVersion = <int, List<String>>{
  9: <String>['parse_histories'],
};

/// 当前主任务表中所有逐版本新增列，用于确认迁移结果完整。
const List<String> _currentTaskColumns = <String>[
  'duration_milliseconds',
  'publisher_name',
  'description',
  'resolution_label',
  'published_at',
  'audio_quality_id',
  'estimated_video_size_bytes',
  'estimated_audio_size_bytes',
  'publisher_id',
  'collection_title',
  'content_type',
  'dash_options_json',
  'download_speed_bytes_per_second',
  'extra_resources_json',
];
