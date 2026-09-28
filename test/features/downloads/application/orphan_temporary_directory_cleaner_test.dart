import 'dart:io';

import 'package:bilibili_down/core/platform/default_download_directory.dart';
import 'package:bilibili_down/features/downloads/application/maintenance/orphan_temporary_directory_cleaner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  /// 验证清理器只删除无数据库引用的临时一级目录。
  test('删除孤立目录并保留数据库保护目录', () async {
    // 系统临时目录隔离测试，结束后无论断言结果都递归清理。
    final root = await Directory.systemTemp.createTemp('bilidown-orphan-test-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final temporaryRoot = Directory(
      p.join(root.path, downloadTemporaryDirectoryName),
    );
    final protectedDirectory = Directory(
      p.join(temporaryRoot.path, 'protected-task'),
    );
    final orphanDirectory = Directory(
      p.join(temporaryRoot.path, 'orphan-task'),
    );
    final legacyOrphanDirectory = Directory(
      p.join(root.path, legacyDownloadTemporaryDirectoryName, 'legacy-task'),
    );
    // 每个目录写入文件，确认递归删除和完整保护都覆盖真实任务布局。
    await protectedDirectory.create(recursive: true);
    await File(p.join(protectedDirectory.path, 'video.m4s')).writeAsString('x');
    await orphanDirectory.create(recursive: true);
    await File(p.join(orphanDirectory.path, 'audio.m4s')).writeAsString('x');
    await legacyOrphanDirectory.create(recursive: true);
    await File(
      p.join(legacyOrphanDirectory.path, 'old.tmp'),
    ).writeAsString('x');

    // 零等待期用于测试立即清理，真实启动仍使用二十四小时安全等待期。
    final result =
        await const OrphanTemporaryDirectoryCleaner(
          minimumOrphanAge: Duration.zero,
        ).cleanup(
          downloadRoots: <Directory>[root],
          protectedTemporaryDirectories: <String>[protectedDirectory.path],
          now: DateTime.now().add(const Duration(minutes: 1)),
        );

    expect(result.deleted, 2);
    expect(result.protected, 1);
    expect(result.failed, 0);
    expect(await protectedDirectory.exists(), isTrue);
    expect(await orphanDirectory.exists(), isFalse);
    expect(await legacyOrphanDirectory.exists(), isFalse);
  });

  /// 验证刚出现的未知目录不会在任务入库竞态窗口内被删除。
  test('保留未超过安全等待期的未知目录', () async {
    // 创建与真实 `.temp/<taskId>` 相同的目录结构。
    final root = await Directory.systemTemp.createTemp('bilidown-recent-test-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final recentDirectory = Directory(
      p.join(root.path, downloadTemporaryDirectoryName, 'pending-task'),
    );
    await recentDirectory.create(recursive: true);

    // 默认二十四小时等待期应把刚创建目录计为 recent 并完整保留。
    final result = await const OrphanTemporaryDirectoryCleaner().cleanup(
      downloadRoots: <Directory>[root],
      protectedTemporaryDirectories: const <String>[],
    );
    expect(result.deleted, 0);
    expect(result.tooRecent, 1);
    expect(await recentDirectory.exists(), isTrue);
  });
}
