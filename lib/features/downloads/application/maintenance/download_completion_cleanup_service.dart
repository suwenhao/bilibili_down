import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/database/app_database.dart';
import '../../../../core/platform/default_download_directory.dart';
import '../../../../services/media_output/media_output_publisher.dart';
import '../../data/download_task_repository.dart';
import '../../domain/download_task_phase.dart';

/// 下载完成后的旧成品记录和临时目录清理错误回调。
typedef DownloadCleanupErrorReporter =
    void Function(String? taskId, Object error, StackTrace stackTrace);

/// 处理下载完成后的文件记录收尾，不参与下载状态机调度。
final class DownloadCompletionCleanupService {
  /// 创建依赖仓库和平台发布器的完成清理服务。
  const DownloadCompletionCleanupService(
    this._repository,
    this._mediaOutputPublisher,
  );

  /// 读取和删除旧任务记录的下载仓库。
  final DownloadTaskRepository _repository;

  /// 删除平台成品文件时使用的发布器抽象。
  final MediaOutputPublisher _mediaOutputPublisher;

  /// 覆盖发布成功后删除旧平台成品和终态记录，同时保留全部活动任务。
  Future<void> cleanupSupersededOutputRecords(
    String outputPath, {
    required String keepingTaskId,
    required String newStorageIdentifier,
  }) async {
    // 同路径查询用于找到已经被新成品覆盖的旧终态任务记录。
    final tasks = await _repository.findTasksForOutputPath(
      outputPath,
      excludingTaskId: keepingTaskId,
    );
    for (final task in tasks) {
      // 活动、暂停和失败任务仍可能恢复写入，覆盖清理绝不能删除它们。
      if (task.phase != DownloadTaskPhase.completed &&
          task.phase != DownloadTaskPhase.canceled) {
        continue;
      }
      // 旧产物优先使用最新产物记录定位真实文件。
      final artifact = await _repository.findLatestArtifact(task.taskId);
      final oldStorageIdentifier = artifact?.path ?? task.outputPath;
      // 桌面覆盖前后路径相同，此时旧文件已经被新文件替换，不能再次删除。
      if (oldStorageIdentifier != null &&
          oldStorageIdentifier != newStorageIdentifier) {
        try {
          // 新成品发布成功后再删除旧成品，避免覆盖流程中丢失用户文件。
          await _mediaOutputPublisher.delete(oldStorageIdentifier);
        } catch (_) {
          // 平台拒绝删除时保留旧记录，用户仍可从历史卡片继续手动处理。
          continue;
        }
      }
      // 旧文件已被替换或删除后移除终态记录，防止其卡片误操作新成品。
      await _repository.deleteRemovableTask(task.taskId);
    }
  }

  /// 成品完成后安全删除当前任务专属临时目录。
  Future<void> cleanupCompletedTaskTemporaryDirectory(
    DownloadTaskRecord task, {
    required DownloadCleanupErrorReporter reportError,
  }) async {
    // 失败、暂停和恢复流程仍依赖该目录；本方法只由 completed 成功路径调用。
    final temporaryPath = task.temporaryDirectory;
    // 旧任务可能没有保存临时目录，此时无需清理。
    if (temporaryPath == null || temporaryPath.isEmpty) return;
    try {
      // 绝对化并规范化路径，防止相对片段绕过任务目录边界。
      final normalizedPath = p.normalize(p.absolute(temporaryPath));
      // 仅接受 `.temp/<taskId>` 与旧版 `.bilidown/<taskId>` 两种专属目录。
      final safeTemporaryDirectory = isDownloadTemporaryTaskDirectory(
        directoryPath: normalizedPath,
        taskId: task.taskId,
      );
      // 路径不满足边界时拒绝递归删除，但不能把已经完成的任务回退为失败。
      if (!safeTemporaryDirectory) {
        throw StateError('完成任务的临时目录不在应用专属目录中，已跳过清理。');
      }
      // 目录可能已被用户手动清理，存在时才执行递归删除。
      final directory = Directory(normalizedPath);
      if (await directory.exists()) {
        // 删除范围已经通过任务 ID 和临时根目录双重校验。
        await directory.delete(recursive: true);
      }
    } catch (error, stackTrace) {
      // 清理失败只进入诊断流，最终文件和 completed 状态仍然有效。
      reportError(task.taskId, error, stackTrace);
    }
  }
}
