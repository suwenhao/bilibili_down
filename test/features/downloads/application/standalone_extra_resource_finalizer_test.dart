import 'dart:io';

import 'package:bilibili_down/core/database/app_database.dart';
import 'package:bilibili_down/core/platform/default_download_directory.dart';
import 'package:bilibili_down/features/downloads/application/maintenance/download_completion_cleanup_service.dart';
import 'package:bilibili_down/features/downloads/application/resources/standalone_extra_resource_finalizer.dart';
import 'package:bilibili_down/features/downloads/data/download_task_draft.dart';
import 'package:bilibili_down/features/downloads/data/download_task_repository.dart';
import 'package:bilibili_down/features/downloads/domain/download_extra_resource.dart';
import 'package:bilibili_down/features/downloads/domain/download_task_phase.dart';
import 'package:bilibili_down/services/media_output/media_output_publisher.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  /// 验证独立资源收尾服务保留原复制、发布、登记产物和清理临时目录语义。
  test('独立封面资源完成后发布成品并清理临时目录', () async {
    // 内存数据库让任务阶段、分流和产物写入走真实 Drift 逻辑。
    final database = AppDatabase(NativeDatabase.memory());
    // 仓库提供和协调器运行时一致的持久化入口。
    final repository = DownloadTaskRepository(database);
    // 临时根使用 `.temp/<taskId>` 布局，匹配完成清理服务的安全边界。
    final root = await Directory.systemTemp.createTemp('bilidown-finalizer-');
    final taskTemporaryDirectory = Directory(
      p.join(root.path, downloadTemporaryDirectoryName, 'cover-task'),
    );
    await taskTemporaryDirectory.create(recursive: true);
    final inputPath = p.join(taskTemporaryDirectory.path, 'cover.input');
    await File(inputPath).writeAsString('cover-bytes');
    final outputPath = p.join(root.path, 'cover.jpg');
    final publisher = _PassthroughMediaOutputPublisher();
    final cleanup = DownloadCompletionCleanupService(repository, publisher);
    final finalizer = StandaloneExtraResourceFinalizer(
      repository,
      publisher,
      cleanup,
    );
    addTearDown(database.close);
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    await repository.createTask(
      DownloadTaskDraft(
        taskId: 'cover-task',
        sourceInput: 'BV-cover',
        title: '封面任务',
        outputPath: outputPath,
        temporaryDirectory: taskTemporaryDirectory.path,
        phase: DownloadTaskPhase.downloading,
      ),
    );
    await repository.upsertStream(
      DownloadStreamDraft(
        streamId: 'cover-task.resource',
        taskId: 'cover-task',
        kind: DownloadStreamKind.resource,
        remoteUrl: 'https://example.invalid/cover.jpg',
        temporaryPath: inputPath,
        engineTaskId: 'cover-task.resource',
        phase: DownloadStreamPhase.completed,
      ),
    );

    final task = (await repository.findTask('cover-task'))!;
    final streams = await repository.loadStreams('cover-task');
    await finalizer.finalize(
      task,
      streams,
      DownloadExtraResource.cover,
      transitionIfAllowed: (taskId, next, {errorCode, errorMessage}) {
        // 测试使用仓库状态机执行真实阶段转换。
        return repository.transitionTask(
          taskId,
          next,
          errorCode: errorCode,
          errorMessage: errorMessage,
        );
      },
      reportCleanupError: (taskId, error, stackTrace) {
        // 本测试路径满足安全边界，不应触发清理错误。
        fail('unexpected cleanup error: $error');
      },
    );

    expect(await File(outputPath).readAsString(), 'cover-bytes');
    expect(
      (await repository.findTask('cover-task'))?.phase,
      DownloadTaskPhase.completed,
    );
    final artifact = await repository.findLatestArtifact('cover-task');
    expect(artifact?.kind, DownloadArtifactKind.cover);
    expect(artifact?.path, outputPath);
    expect(await taskTemporaryDirectory.exists(), isFalse);
    expect(publisher.publishedStorageIdentifiers, <String>[outputPath]);
  });
}

/// 保持工作路径即发布路径的测试发布器。
final class _PassthroughMediaOutputPublisher implements MediaOutputPublisher {
  /// 已发布成品标识。
  final List<String> publishedStorageIdentifiers = <String>[];

  @override
  Future<void> delete(String storageIdentifier) async {
    // 当前测试没有旧成品需要删除。
  }

  @override
  Future<void> deleteAll(Iterable<String> storageIdentifiers) async {
    // 当前测试没有批量删除需求。
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
    // 桌面路径直接作为工作路径，便于验证复制后的文件内容。
    return requestedOutputPath;
  }

  @override
  Future<PublishedMediaOutput> publish({
    required String workingOutputPath,
    required String requestedOutputPath,
  }) async {
    // 发布时保留工作路径作为稳定标识。
    publishedStorageIdentifiers.add(workingOutputPath);
    return PublishedMediaOutput(storageIdentifier: workingOutputPath);
  }
}
