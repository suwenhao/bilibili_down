import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/database/app_database.dart';
import '../../../../core/platform/default_download_directory.dart';
import '../../../../core/platform/output_path_policy.dart';
import '../../../../core/platform/platform_providers.dart';
import '../../../../services/bilibili/bilibili_parser_service.dart';
import '../../../../services/bilibili/bilibili_providers.dart';
import '../../../../services/bilibili/models/bili_media_info.dart';
import '../../../../services/media_output/media_output_publisher.dart';
import '../../domain/download_extra_resource.dart';
import 'download_resource_converter.dart';

/// 批量附加资源导出服务，直接写入下载目录时间戳文件夹，不创建下载任务。
final batchExtraResourceExportServiceProvider =
    Provider<BatchExtraResourceExportService>((Ref ref) {
      // 当前平台决定最终发布方式；所有平台都使用真实文件路径。
      final platform = ref.watch(runtimePlatformProvider);
      // 解析服务负责刷新封面、弹幕和字幕地址，避免使用旧 URL。
      final parser = ref.watch(bilibiliParserServiceProvider);
      // 发布器不再接收 URI，附加资源导出直接写入真实目标路径。
      final publisher = createMediaOutputPublisher(platform);
      final service = BatchExtraResourceExportService(parser, publisher);
      // Provider 销毁时释放独立 HTTP 客户端，避免应用退出残留连接。
      ref.onDispose(service.dispose);
      return service;
    });

/// 批量附加资源导出进度。
final class BatchExtraResourceExportProgress {
  /// 创建当前进度快照。
  const BatchExtraResourceExportProgress({
    required this.completed,
    required this.total,
    required this.currentLabel,
  });

  /// 已完成的资源单元数量。
  final int completed;

  /// 总资源单元数量；字幕按单个视频的一类资源统计。
  final int total;

  /// 当前正在处理的视频和资源文案。
  final String currentLabel;

  /// 返回 0 到 1 的进度比例。
  double get ratio => total <= 0 ? 0 : completed / total;
}

/// 批量附加资源导出结果。
final class BatchExtraResourceExportResult {
  /// 保存导出目录、成功文件数和失败资源数。
  const BatchExtraResourceExportResult({
    required this.outputDirectory,
    required this.exportedFiles,
    required this.failedResources,
  });

  /// 用户选择下载根目录下的时间戳文件夹。
  final String outputDirectory;

  /// 实际发布成功的文件数量，字幕多语言会按多个文件统计。
  final int exportedFiles;

  /// 下载、转换或发布失败的资源单元数量。
  final int failedResources;
}

/// 不经过任务队列的附加资源批量导出器。
final class BatchExtraResourceExportService {
  /// 注入解析服务和平台发布器。
  BatchExtraResourceExportService(this._parser, this._publisher)
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (int? status) => status != null && status < 600,
        ),
      );

  /// B 站解析服务，用于获取最新资源地址。
  final BilibiliParserService _parser;

  /// 平台发布器负责普通文件系统路径的检查和发布。
  final MediaOutputPublisher _publisher;

  /// 小型资源使用独立 HTTP 客户端下载，避免占用 aria2 任务状态。
  final Dio _dio;

  /// 释放 HTTP 客户端。
  void dispose() {
    // 应用销毁时不等待未完成的可选资源请求。
    _dio.close(force: true);
  }

  /// 把所选附加资源导出到下载根目录下的时间戳文件夹。
  Future<BatchExtraResourceExportResult> export({
    required List<DownloadTaskRecord> tasks,
    required Set<DownloadExtraResource> resources,
    required String? downloadDirectoryPath,
    required void Function(BatchExtraResourceExportProgress progress)
    onProgress,
  }) async {
    // 批量直下只处理文本、图片类资源；独立音频需要主下载流和转封装管线。
    final exportResources = resources
        .where(
          (DownloadExtraResource resource) =>
              resource != DownloadExtraResource.audio,
        )
        .toList(growable: false);
    if (tasks.isEmpty || exportResources.isEmpty) {
      throw StateError('没有可导出的附加资源。');
    }
    // 根目录优先使用用户设置，空值回落到平台默认 BiliDown 目录。
    final rootDirectory = await _resolveOutputRoot(downloadDirectoryPath);
    final batchDirectory = Directory(
      p.join(rootDirectory.path, _timestampFolderName(DateTime.now())),
    );
    await batchDirectory.create(recursive: true);
    // 工作目录始终放在默认下载根目录的 .temp 下，Android 发布后可安全移走。
    final temporaryDirectory = Directory(
      p.join(
        (await resolveDefaultDownloadDirectory()).path,
        downloadTemporaryDirectoryName,
        'batch_resources_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    await temporaryDirectory.create(recursive: true);
    final total = tasks.length * exportResources.length;
    var completed = 0;
    var exportedFiles = 0;
    var failedResources = 0;
    try {
      for (final task in tasks) {
        // 每个待下载任务用当前数据库元数据重建分集，资源 URL 由解析器实时获取。
        final episode = _episodeFromTask(task);
        final baseName = sanitizeOutputPathSegment(task.title);
        for (final resource in exportResources) {
          final label =
              '${task.title} - ${downloadExtraResourceLabel(resource)}';
          onProgress(
            BatchExtraResourceExportProgress(
              completed: completed,
              total: total,
              currentLabel: label,
            ),
          );
          try {
            exportedFiles += await _exportSingleResource(
              task: task,
              episode: episode,
              resource: resource,
              temporaryDirectory: temporaryDirectory.path,
              outputDirectory: batchDirectory.path,
              baseName: baseName,
            );
          } catch (_) {
            // 单个视频资源失败不终止整批，避免一条无字幕视频阻断所有封面。
            failedResources++;
          } finally {
            // 完成计数代表该资源单元已经结束，无论成功或失败都推进弹窗进度。
            completed++;
            onProgress(
              BatchExtraResourceExportProgress(
                completed: completed,
                total: total,
                currentLabel: label,
              ),
            );
          }
        }
      }
    } finally {
      // 直下工作目录只保存临时下载和转换文件，失败项已经计数，不保留半成品。
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    }
    return BatchExtraResourceExportResult(
      outputDirectory: batchDirectory.path,
      exportedFiles: exportedFiles,
      failedResources: failedResources,
    );
  }

  /// 解析最终根目录，设置路径为空时回落平台默认目录。
  Future<Directory> _resolveOutputRoot(String? downloadDirectoryPath) async {
    // 用户设置中的空字符串代表沿用默认目录。
    final customPath = downloadDirectoryPath?.trim();
    if (customPath != null && customPath.isNotEmpty) {
      final directory = Directory(customPath);
      await directory.create(recursive: true);
      return directory;
    }
    return resolveDefaultDownloadDirectory();
  }

  /// 根据任务字段重建附加资源解析所需分集信息。
  BiliEpisodeInfo _episodeFromTask(DownloadTaskRecord task) {
    // PGC 任务保存 epid，普通投稿则只依赖 bvid 和 cid。
    final contentType = task.epid == null
        ? BiliContentType.ugc
        : BiliContentType.pgc;
    final bvid = task.bvid;
    final cid = task.cid;
    if (bvid == null || bvid.isEmpty || cid == null) {
      throw StateError('任务缺少 BVID 或 CID，无法导出附加资源。');
    }
    return BiliEpisodeInfo(
      contentType: contentType,
      bvid: bvid,
      cid: cid,
      index: task.partIndex,
      title: task.title,
      duration: Duration(milliseconds: task.durationMilliseconds ?? 0),
      episodeId: task.epid,
      coverUrl: task.coverUrl,
      publishedAt: task.publishedAt,
    );
  }

  /// 导出单个任务的一类附加资源，返回成功发布的文件数量。
  Future<int> _exportSingleResource({
    required DownloadTaskRecord task,
    required BiliEpisodeInfo episode,
    required DownloadExtraResource resource,
    required String temporaryDirectory,
    required String outputDirectory,
    required String baseName,
  }) async {
    switch (resource) {
      case DownloadExtraResource.subtitles:
      case DownloadExtraResource.aiSubtitles:
        return _exportSubtitles(
          resource: resource,
          task: task,
          episode: episode,
          temporaryDirectory: temporaryDirectory,
          outputDirectory: outputDirectory,
          baseName: baseName,
        );
      case DownloadExtraResource.cover:
      case DownloadExtraResource.danmakuXml:
      case DownloadExtraResource.danmakuAss:
        final inputPath = p.join(
          temporaryDirectory,
          '${task.taskId}_${resource.name}.download',
        );
        final plan = await _parser.createExtraResourcePlan(
          taskId: task.taskId,
          episode: episode,
          resource: resource,
          temporaryPath: inputPath,
        );
        final source = plan.resource;
        if (source == null) throw StateError('附加资源解析结果为空。');
        if (resource == DownloadExtraResource.danmakuXml ||
            resource == DownloadExtraResource.danmakuAss) {
          // 弹幕接口响应需要解析器处理 raw deflate。
          final bytes = await _parser.fetchDanmakuXmlBytes(source);
          await File(inputPath).writeAsBytes(bytes, flush: true);
        } else {
          await _downloadSource(source.url, source.headers, inputPath);
        }
        final requestedOutputPath = p.join(
          outputDirectory,
          '$baseName [${downloadExtraResourceLabel(resource)}]'
          '${_extensionForResource(resource, task.coverUrl)}',
        );
        await _publishConvertedResource(
          inputPath: inputPath,
          requestedOutputPath: requestedOutputPath,
          temporaryDirectory: temporaryDirectory,
          resource: resource,
        );
        return 1;
      case DownloadExtraResource.audio:
        throw StateError('批量直下不支持独立音频。');
    }
  }

  /// 导出当前任务的全部字幕轨道。
  Future<int> _exportSubtitles({
    required DownloadExtraResource resource,
    required DownloadTaskRecord task,
    required BiliEpisodeInfo episode,
    required String temporaryDirectory,
    required String outputDirectory,
    required String baseName,
  }) async {
    // 两种字幕开关独立筛选语言轨道，没有匹配轨道时明确报告该资源失败。
    final tracks = await _parser.loadSubtitleTracks(
      episode,
      aiGenerated: resource == DownloadExtraResource.aiSubtitles,
    );
    final label = downloadExtraResourceLabel(resource);
    if (tracks.isEmpty) throw StateError('当前视频没有可下载的$label。');
    var exported = 0;
    for (final track in tracks) {
      final safeLanguage = sanitizeOutputPathSegment(
        track.languageCode,
        fallback: 'subtitle',
        maximumUtf8Bytes: 48,
      );
      final inputPath = p.join(
        temporaryDirectory,
        '${task.taskId}_subtitle_$safeLanguage.download',
      );
      final plan = await _parser.createExtraResourcePlan(
        taskId: task.taskId,
        episode: episode,
        resource: resource,
        temporaryPath: inputPath,
        resourceVariant: track.languageCode,
      );
      final source = plan.resource;
      if (source == null) throw StateError('字幕资源解析结果为空。');
      await _downloadSource(source.url, source.headers, inputPath);
      await _publishConvertedResource(
        inputPath: inputPath,
        requestedOutputPath: p.join(
          outputDirectory,
          '$baseName [$label $safeLanguage].srt',
        ),
        temporaryDirectory: temporaryDirectory,
        resource: resource,
      );
      exported++;
    }
    return exported;
  }

  /// 下载普通 HTTP 资源到临时文件。
  Future<void> _downloadSource(
    Uri uri,
    Map<String, String> headers,
    String destinationPath,
  ) async {
    // 写入前创建父目录，批量多文件不会依赖外层目录是否已经存在。
    await File(destinationPath).parent.create(recursive: true);
    final response = await _dio.downloadUri(
      uri,
      destinationPath,
      options: Options(headers: headers, responseType: ResponseType.bytes),
      deleteOnError: true,
    );
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      final file = File(destinationPath);
      if (await file.exists()) await file.delete();
      throw StateError('附加资源下载返回 HTTP $status。');
    }
  }

  /// 转换并发布临时资源文件。
  Future<void> _publishConvertedResource({
    required String inputPath,
    required String requestedOutputPath,
    required String temporaryDirectory,
    required DownloadExtraResource resource,
  }) async {
    // 发布器会校验并返回真实输出路径，转换阶段直接写入该路径。
    final workingOutputPath = await _publisher.prepareOutputPath(
      requestedOutputPath: requestedOutputPath,
      temporaryDirectory: temporaryDirectory,
    );
    await File(workingOutputPath).parent.create(recursive: true);
    switch (resource) {
      case DownloadExtraResource.cover:
      case DownloadExtraResource.danmakuXml:
        await File(inputPath).copy(workingOutputPath);
      case DownloadExtraResource.danmakuAss:
        await convertBiliDanmakuXmlFileToAss(
          inputPath: inputPath,
          outputPath: workingOutputPath,
        );
      case DownloadExtraResource.subtitles:
      case DownloadExtraResource.aiSubtitles:
        await convertBiliSubtitleJsonFileToSrt(
          inputPath: inputPath,
          outputPath: workingOutputPath,
        );
      case DownloadExtraResource.audio:
        throw StateError('批量直下不支持独立音频。');
    }
    await _publisher.publish(
      workingOutputPath: workingOutputPath,
      requestedOutputPath: requestedOutputPath,
    );
  }

  /// 返回输出扩展名，封面尽量保留服务端格式。
  String _extensionForResource(
    DownloadExtraResource resource,
    String? coverUrl,
  ) {
    return switch (resource) {
      DownloadExtraResource.cover => switch (p
          .extension(Uri.tryParse(coverUrl ?? '')?.path ?? '')
          .toLowerCase()) {
        '.png' => '.png',
        '.webp' => '.webp',
        '.jpeg' => '.jpeg',
        _ => '.jpg',
      },
      DownloadExtraResource.danmakuXml => '.xml',
      DownloadExtraResource.danmakuAss => '.ass',
      DownloadExtraResource.subtitles ||
      DownloadExtraResource.aiSubtitles => '.srt',
      DownloadExtraResource.audio => '.m4a',
    };
  }

  /// 生成稳定且按时间排序的批量导出文件夹名。
  String _timestampFolderName(DateTime value) {
    // 使用数字时间戳避免不同平台文件名区域设置差异。
    String two(int number) => number.toString().padLeft(2, '0');
    return '批量附加资源_${value.year}'
        '${two(value.month)}${two(value.day)}_'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}';
  }
}
