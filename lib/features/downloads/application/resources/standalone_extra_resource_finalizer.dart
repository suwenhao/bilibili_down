import 'dart:io';

import '../../../../core/database/app_database.dart';
import '../../../../services/bilibili/bili_api_exception.dart';
import '../../../../services/media_output/media_output_publisher.dart';
import '../../data/download_task_draft.dart';
import '../../data/download_task_repository.dart';
import '../../domain/download_extra_resource.dart';
import '../../domain/download_task_phase.dart';
import '../maintenance/download_completion_cleanup_service.dart';
import 'download_resource_converter.dart';

/// 以状态机保护方式写入任务阶段。
typedef DownloadTaskTransitionWriter =
    Future<void> Function(
      String taskId,
      DownloadTaskPhase next, {
      String? errorCode,
      String? errorMessage,
    });

/// 发布不需要音视频合并的独立附加资源任务。
final class StandaloneExtraResourceFinalizer {
  /// 创建独立附加资源发布服务。
  const StandaloneExtraResourceFinalizer(
    this._repository,
    this._mediaOutputPublisher,
    this._completionCleanup,
  );

  /// 写入最终产物记录和任务状态的下载仓库。
  final DownloadTaskRepository _repository;

  /// 将工作文件发布到平台最终目录。
  final MediaOutputPublisher _mediaOutputPublisher;

  /// 复用完成任务的旧记录和临时目录清理逻辑。
  final DownloadCompletionCleanupService _completionCleanup;

  /// 把封面、弹幕或字幕临时文件发布为独立任务成品。
  Future<void> finalize(
    DownloadTaskRecord task,
    List<DownloadStreamRecord> streams,
    DownloadExtraResource resource, {
    required DownloadTaskTransitionWriter transitionIfAllowed,
    required DownloadCleanupErrorReporter reportCleanupError,
  }) async {
    // 附加资源任务只能包含一条 resource 分流，避免误把媒体流当作文本转换。
    if (streams.length != 1 ||
        streams.single.kind != DownloadStreamKind.resource) {
      throw StateError('Task ${task.taskId} has invalid resource streams.');
    }
    // 最终输出路径在派生任务入队时已经根据资源类型确定。
    final outputPath = task.outputPath;
    if (outputPath == null || outputPath.isEmpty) {
      throw StateError('Task ${task.taskId} has no resource output path.');
    }
    // 转换阶段沿用 merging，页面可统一展示后处理中的动态进度状态。
    await transitionIfAllowed(task.taskId, DownloadTaskPhase.merging);
    // 发布器会校验并返回真实输出路径，附加资源直接写入最终文件。
    final workingOutputPath = await _mediaOutputPublisher.prepareOutputPath(
      requestedOutputPath: outputPath,
      temporaryDirectory: task.temporaryDirectory,
    );
    try {
      // 根据资源类型选择直接复制、XML 转 ASS 或 BCC JSON 转 SRT。
      await _writeExtraResource(
        inputPath: streams.single.temporaryPath,
        outputPath: workingOutputPath,
        resource: resource,
      );
      // 发布前读取真实大小，写入数据库后详情页和删除计划可直接使用。
      final outputSize = await File(workingOutputPath).length();
      // 平台发布器负责把成品放入用户可见目录并返回稳定存储标识。
      final publishedOutput = await _mediaOutputPublisher.publish(
        workingOutputPath: workingOutputPath,
        requestedOutputPath: outputPath,
      );
      // 最终产物类型按资源语义保存，删除记录时仍能区分封面、字幕和弹幕。
      await _repository.upsertArtifact(
        DownloadArtifactDraft(
          taskId: task.taskId,
          kind: artifactKindForExtraResource(resource),
          path: publishedOutput.storageIdentifier,
          sizeBytes: outputSize,
          retained: true,
        ),
      );
      // 发布成功后才进入 completed，防止列表展示并不存在的成品。
      await transitionIfAllowed(task.taskId, DownloadTaskPhase.completed);
      // 独立资源覆盖成功后同样清理同路径旧终态记录，活动任务仍由仓库保护。
      await _completionCleanup.cleanupSupersededOutputRecords(
        outputPath,
        keepingTaskId: task.taskId,
        newStorageIdentifier: publishedOutput.storageIdentifier,
      );
      // 独立资源转换完成后同样移除原始下载文件和控制文件。
      await _completionCleanup.cleanupCompletedTaskTemporaryDirectory(
        task,
        reportError: reportCleanupError,
      );
    } catch (error) {
      // 转换或发布失败保留源文件并进入可重试失败态。
      await transitionIfAllowed(
        task.taskId,
        DownloadTaskPhase.failed,
        errorCode: 'resource_finalize_failed',
        errorMessage: biliUserMessage(error, fallback: '附加资源保存失败，请重试。'),
      );
      rethrow;
    }
  }

  /// 按附加资源类型生成目标文件内容。
  Future<void> _writeExtraResource({
    required String inputPath,
    required String outputPath,
    required DownloadExtraResource resource,
  }) async {
    // 输出父目录必须在文件写入前存在，兼容用户自定义的嵌套目录模板。
    await Directory(File(outputPath).parent.path).create(recursive: true);
    switch (resource) {
      case DownloadExtraResource.cover:
      case DownloadExtraResource.danmakuXml:
        // 图片和原始 XML 不需要转码，直接复制能够保持服务端字节内容。
        await File(inputPath).copy(outputPath);
      case DownloadExtraResource.danmakuAss:
        // ASS 任务下载的是同一 CID 的 XML，流式转换避免同时持有完整输入和输出文本。
        await convertBiliDanmakuXmlFileToAss(
          inputPath: inputPath,
          outputPath: outputPath,
        );
      case DownloadExtraResource.subtitles:
      case DownloadExtraResource.aiSubtitles:
        // B 站字幕正文是 BCC JSON，读取前先限制文件大小再转换为通用 SRT。
        await convertBiliSubtitleJsonFileToSrt(
          inputPath: inputPath,
          outputPath: outputPath,
        );
      case DownloadExtraResource.audio:
        // 音频通过 DASH 单流和 FFmpeg remux 处理，不会进入资源分流分支。
        throw StateError('Audio resource must use the media pipeline.');
    }
  }
}
