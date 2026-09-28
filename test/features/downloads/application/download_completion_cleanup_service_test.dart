import 'package:bilibili_down/core/database/app_database.dart';
import 'package:bilibili_down/features/downloads/application/maintenance/download_completion_cleanup_service.dart';
import 'package:bilibili_down/features/downloads/data/download_task_draft.dart';
import 'package:bilibili_down/features/downloads/data/download_task_repository.dart';
import 'package:bilibili_down/features/downloads/domain/download_task_phase.dart';
import 'package:bilibili_down/services/media_output/media_output_publisher.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 验证覆盖清理服务只删除同路径旧终态记录，并保留当前任务和活动任务。
  test('覆盖成品清理只影响旧终态任务', () async {
    // 内存数据库提供真实外键和删除语义，避免测试绕过仓库保护。
    final database = AppDatabase(NativeDatabase.memory());
    // 仓库负责创建任务、产物和执行终态记录删除。
    final repository = DownloadTaskRepository(database);
    // 假发布器记录被要求删除的平台成品标识。
    final publisher = _RecordingMediaOutputPublisher();
    // 完成清理服务是本次拆分出的文件收尾入口。
    final service = DownloadCompletionCleanupService(repository, publisher);
    addTearDown(database.close);

    const outputPath = '/downloads/same-title.mp4';
    for (final draft in const <DownloadTaskDraft>[
      DownloadTaskDraft(
        taskId: 'current-task',
        sourceInput: 'BV-current',
        title: '当前成品',
        outputPath: outputPath,
        phase: DownloadTaskPhase.completed,
      ),
      DownloadTaskDraft(
        taskId: 'old-completed',
        sourceInput: 'BV-old',
        title: '旧成品',
        outputPath: outputPath,
        phase: DownloadTaskPhase.completed,
      ),
      DownloadTaskDraft(
        taskId: 'active-task',
        sourceInput: 'BV-active',
        title: '活动任务',
        outputPath: outputPath,
        phase: DownloadTaskPhase.downloading,
      ),
    ]) {
      await repository.createTask(draft);
    }
    await repository.upsertArtifact(
      const DownloadArtifactDraft(
        taskId: 'old-completed',
        kind: DownloadArtifactKind.output,
        path: 'content://old-output',
        retained: true,
      ),
    );

    await service.cleanupSupersededOutputRecords(
      outputPath,
      keepingTaskId: 'current-task',
      newStorageIdentifier: 'content://new-output',
    );

    expect(await repository.findTask('old-completed'), isNull);
    expect(await repository.findTask('current-task'), isNotNull);
    expect(await repository.findTask('active-task'), isNotNull);
    expect(publisher.deletedStorageIdentifiers, <String>[
      'content://old-output',
    ]);
  });
}

/// 记录删除请求的测试发布器。
final class _RecordingMediaOutputPublisher implements MediaOutputPublisher {
  /// 已请求删除的平台成品标识。
  final List<String> deletedStorageIdentifiers = <String>[];

  @override
  Future<void> delete(String storageIdentifier) async {
    // 记录删除请求，供测试验证服务没有删除当前任务或活动任务。
    deletedStorageIdentifiers.add(storageIdentifier);
  }

  @override
  Future<void> deleteAll(Iterable<String> storageIdentifiers) async {
    // 完成清理服务不使用批量删除，保留实现以满足接口。
    deletedStorageIdentifiers.addAll(storageIdentifiers);
  }

  @override
  Future<MediaOutputInspection> inspect(
    String storageIdentifier, {
    required String requestedOutputPath,
  }) async {
    // 当前测试不检查成品完整性。
    throw UnimplementedError('inspect is not used by this test.');
  }

  @override
  Future<String> prepareOutputPath({
    required String requestedOutputPath,
    required String? temporaryDirectory,
  }) async {
    // 当前测试不执行发布前路径准备。
    return requestedOutputPath;
  }

  @override
  Future<PublishedMediaOutput> publish({
    required String workingOutputPath,
    required String requestedOutputPath,
  }) async {
    // 当前测试不执行成品发布。
    return PublishedMediaOutput(storageIdentifier: workingOutputPath);
  }
}
