import 'package:path/path.dart' as p;

import '../../../../services/media_output/media_output_publisher.dart';
import '../../data/download_task_draft.dart';
import '../../data/download_task_repository.dart';
import '../../domain/download_task_phase.dart';

/// 启动成品一致性扫描后的修复统计。
final class CompletedOutputIntegrityResult {
  /// 保存检查和修复数量。
  const CompletedOutputIntegrityResult({
    required this.checked,
    required this.repairedCompleted,
    required this.markedInvalid,
    required this.failed,
  });

  /// 已实际访问平台存储的任务数量。
  final int checked;

  /// 因已有有效产物而恢复为 completed 的异常中断任务数量。
  final int repairedCompleted;

  /// 因成品缺失、为空或大小不符而转为 failed 的原完成任务数量。
  final int markedInvalid;

  /// 因平台查询异常而保持原状态的任务数量。
  final int failed;
}

/// 检查已登记成品的存在性和基本完整性，并修复数据库终态漂移。
final class CompletedOutputIntegrityService {
  /// 注入任务仓库和当前平台成品发布器。
  const CompletedOutputIntegrityService(this._repository, this._publisher);

  /// 提供任务、产物查询和受约束状态修复。
  final DownloadTaskRepository _repository;

  /// 统一检查当前可访问的真实文件路径。
  final MediaOutputPublisher _publisher;

  /// 扫描完成任务，以及已经登记产物但未写入 completed 的异常中断任务。
  Future<CompletedOutputIntegrityResult> repair() async {
    final tasks = await _repository.loadAllTasksSnapshot();
    var checked = 0;
    var repairedCompleted = 0;
    var markedInvalid = 0;
    var failed = 0;
    for (final task in tasks) {
      // 主任务可能登记多个附加资源，一致性扫描只以最终视频产物判断任务完成状态。
      final artifact = await _repository.findArtifact(
        taskId: task.taskId,
        kind: DownloadArtifactKind.output,
      );
      // 普通活动任务没有最终产物时仍由下载引擎恢复，不能拿临时输出误判完成。
      if (task.phase != DownloadTaskPhase.completed && artifact == null) {
        continue;
      }
      // 已取消任务不应因磁盘残留重新出现在已下载列表。
      if (task.phase == DownloadTaskPhase.canceled) continue;
      final requestedOutputPath = task.outputPath;
      final storageIdentifier = _resolvedOutputStorageIdentifier(
        artifact?.path,
        requestedOutputPath,
      );
      if (storageIdentifier == null ||
          storageIdentifier.isEmpty ||
          requestedOutputPath == null ||
          requestedOutputPath.isEmpty) {
        // 完成记录缺少任何可定位路径时直接修复为可重试失败态。
        if (task.phase == DownloadTaskPhase.completed) {
          await _repository.repairTaskOutputState(
            taskId: task.taskId,
            outputValid: false,
            errorCode: 'output_location_missing',
            errorMessage: '成品位置记录缺失，请重新下载。',
          );
          markedInvalid++;
        }
        continue;
      }
      try {
        checked++;
        final inspection = await _publisher.inspect(
          storageIdentifier,
          requestedOutputPath: requestedOutputPath,
        );
        // 新旧记录有期望大小时要求完全一致，以发现外部截断或替换。
        final sizeMatches =
            artifact?.sizeBytes == null ||
            artifact!.sizeBytes == inspection.sizeBytes;
        final valid =
            inspection.exists && inspection.basicIntegrityValid && sizeMatches;
        if (valid) {
          if (artifact == null || artifact.path != storageIdentifier) {
            // 旧版任务只有 outputPath，或旧产物记录不是文件路径时补齐真实路径。
            await _repository.upsertArtifact(
              DownloadArtifactDraft(
                taskId: task.taskId,
                kind: DownloadArtifactKind.output,
                path: storageIdentifier,
                sizeBytes: inspection.sizeBytes,
                retained: true,
              ),
            );
          }
          if (task.phase != DownloadTaskPhase.completed) {
            // 产物已登记但应用在写 completed 前退出时恢复正确终态。
            await _repository.repairTaskOutputState(
              taskId: task.taskId,
              outputValid: true,
            );
            repairedCompleted++;
          }
          continue;
        }
        if (task.phase == DownloadTaskPhase.completed) {
          // 无效成品从“已下载”移到可重试失败态，并保留具体修复原因。
          await _repository.repairTaskOutputState(
            taskId: task.taskId,
            outputValid: false,
            errorCode: _integrityErrorCode(inspection),
            errorMessage: _integrityErrorMessage(inspection),
          );
          markedInvalid++;
        }
      } catch (_) {
        // 存储提供器暂时不可用时不改变任务状态，下次启动可以再次检查。
        failed++;
      }
    }
    return CompletedOutputIntegrityResult(
      checked: checked,
      repairedCompleted: repairedCompleted,
      markedInvalid: markedInvalid,
      failed: failed,
    );
  }

  /// 根据成品检查结果返回可持久化的错误码。
  String _integrityErrorCode(MediaOutputInspection inspection) {
    // 文件缺失优先级最高，说明路径已经不可恢复。
    if (!inspection.exists) return 'output_missing';
    // 文件存在但基本格式不合格时允许用户重新下载。
    if (!inspection.basicIntegrityValid) return 'output_corrupt';
    // 其余无效情况归为记录大小与实际文件不一致。
    return 'output_size_mismatch';
  }

  /// 根据成品检查结果返回用户可读的修复提示。
  String _integrityErrorMessage(MediaOutputInspection inspection) {
    // 文件缺失时提示用户重新下载，不暴露本地绝对路径。
    if (!inspection.exists) return '成品文件已不存在，请重新下载。';
    // 空文件或格式缺失时给出明确损坏原因。
    if (!inspection.basicIntegrityValid) return '成品文件为空或格式不完整，请重新下载。';
    // 大小不一致通常来自外部修改或恢复中断。
    return '成品文件大小与下载记录不一致，请重新下载。';
  }
}

/// 选择完整性检查要访问的真实成品路径。
String? _resolvedOutputStorageIdentifier(
  String? artifactPath,
  String? outputPath,
) {
  // 产物记录优先，但必须是可直接访问的绝对文件路径。
  final normalizedOutputPath = outputPath?.trim();
  final normalizedArtifactPath = artifactPath?.trim();
  if (normalizedArtifactPath != null &&
      normalizedArtifactPath.isNotEmpty &&
      _isAbsoluteFilePath(normalizedArtifactPath)) {
    return normalizedArtifactPath;
  }
  // outputPath 是当前下载创建阶段保存的真实文件位置。
  if (normalizedOutputPath != null &&
      _isAbsoluteFilePath(normalizedOutputPath)) {
    return normalizedOutputPath;
  }
  return null;
}

/// 判断路径是否为可检查的绝对文件路径。
bool _isAbsoluteFilePath(String storageIdentifier) {
  // 完整性扫描只能访问真实文件路径。
  final path = storageIdentifier.trim();
  return path.isNotEmpty && p.isAbsolute(path);
}
