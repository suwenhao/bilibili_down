import 'package:bilibili_down/core/database/app_database.dart';
import 'package:bilibili_down/features/downloads/application/maintenance/completed_output_integrity_service.dart';
import 'package:bilibili_down/features/downloads/data/download_task_draft.dart';
import 'package:bilibili_down/features/downloads/data/download_task_repository.dart';
import 'package:bilibili_down/features/downloads/domain/download_task_phase.dart';
import 'package:bilibili_down/services/media_output/media_output_publisher.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 验证完成记录的成品缺失时会转为可重试失败态。
  test('缺失成品从 completed 修复为 failed', () async {
    // 内存 Drift 保留正式状态字段和产物外键行为。
    final database = AppDatabase(NativeDatabase.memory());
    final repository = DownloadTaskRepository(database);
    addTearDown(database.close);
    await repository.createTask(
      const DownloadTaskDraft(
        taskId: 'missing-output',
        sourceInput: 'BV-missing',
        title: '缺失成品',
        outputPath: '/downloads/missing.mp4',
        phase: DownloadTaskPhase.completed,
      ),
    );

    // 平台检查明确报告文件不存在，服务应修复数据库终态。
    final result = await CompletedOutputIntegrityService(
      repository,
      const _FakeMediaOutputPublisher(
        inspection: MediaOutputInspection(
          exists: false,
          sizeBytes: 0,
          basicIntegrityValid: false,
        ),
      ),
    ).repair();
    final repaired = await repository.findTask('missing-output');
    expect(result.markedInvalid, 1);
    expect(repaired?.phase, DownloadTaskPhase.failed);
    expect(repaired?.errorCode, 'output_missing');
  });

  /// 验证发布成功但 completed 写库前退出的任务可由有效产物恢复。
  test('有效已登记产物把异常中断任务修复为 completed', () async {
    // merging 模拟发布产物后、状态切换前应用异常退出的数据库快照。
    final database = AppDatabase(NativeDatabase.memory());
    final repository = DownloadTaskRepository(database);
    addTearDown(database.close);
    await repository.createTask(
      const DownloadTaskDraft(
        taskId: 'published-output',
        sourceInput: 'BV-published',
        title: '已发布成品',
        outputPath: '/downloads/published.mp4',
        phase: DownloadTaskPhase.merging,
      ),
    );
    await repository.upsertArtifact(
      const DownloadArtifactDraft(
        taskId: 'published-output',
        kind: DownloadArtifactKind.output,
        path: '/downloads/published.mp4',
        sizeBytes: 1024,
      ),
    );

    // 文件存在、基础格式和登记大小均一致时才能恢复完成态。
    final result = await CompletedOutputIntegrityService(
      repository,
      const _FakeMediaOutputPublisher(
        inspection: MediaOutputInspection(
          exists: true,
          sizeBytes: 1024,
          basicIntegrityValid: true,
        ),
      ),
    ).repair();
    final repaired = await repository.findTask('published-output');
    expect(result.repairedCompleted, 1);
    expect(repaired?.phase, DownloadTaskPhase.completed);
    expect(repaired?.progress, 1);
  });
}

/// 为一致性服务提供确定性平台检查结果的测试发布器。
final class _FakeMediaOutputPublisher implements MediaOutputPublisher {
  /// 创建始终返回指定检查结果的发布器。
  const _FakeMediaOutputPublisher({required this.inspection});

  /// 本次测试需要返回的平台成品状态。
  final MediaOutputInspection inspection;

  @override
  Future<void> delete(String storageIdentifier) async {
    // 一致性修复不删除文件，此空实现只满足平台接口。
  }

  @override
  Future<void> deleteAll(Iterable<String> storageIdentifiers) async {
    // 一致性修复不执行批量删除，此空实现只满足平台接口。
  }

  @override
  Future<MediaOutputInspection> inspect(
    String storageIdentifier, {
    required String requestedOutputPath,
  }) async {
    // 返回测试预设结果，输入路径由服务负责正确传递。
    return inspection;
  }

  @override
  Future<String> prepareOutputPath({
    required String requestedOutputPath,
    required String? temporaryDirectory,
  }) async {
    // 测试不执行合并，保持请求路径即可。
    return requestedOutputPath;
  }

  @override
  Future<PublishedMediaOutput> publish({
    required String workingOutputPath,
    required String requestedOutputPath,
  }) async {
    // 测试不执行发布，返回工作路径满足接口约定。
    return PublishedMediaOutput(storageIdentifier: workingOutputPath);
  }
}
