import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../../../core/database/app_database.dart';
import '../../../../core/logging/app_debug_log.dart';
import '../../../../services/bilibili/bilibili_parser_service.dart';
import '../../../../services/bilibili/models/bili_media_info.dart';
import '../../../../services/media_merge/media_merger.dart';
import '../../../../services/media_output/media_output_publisher.dart';
import '../../data/download_task_draft.dart';
import '../../data/download_task_repository.dart';
import '../../domain/download_extra_resource.dart';
import '../../domain/download_task_phase.dart';
import 'download_resource_converter.dart';

/// 把主任务勾选的附加资源生成到同一标题目录，并登记为同一任务的多个产物。
final class EmbeddedExtraResourceProcessor {
  /// 注入解析、下载、转封装、发布和持久化依赖。
  EmbeddedExtraResourceProcessor(
    this._parser,
    this._mediaMerger,
    this._mediaOutputPublisher,
    this._repository,
  ) : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (int? status) => status != null && status < 600,
        ),
      );

  /// 解析 B 站附加资源地址，并负责弹幕的特殊压缩响应。
  final BilibiliParserService _parser;

  /// 独立音频复用主任务已下载的音频流执行无损转封装。
  final MediaMerger _mediaMerger;

  /// 发布器负责校验真实文件路径并登记最终产物。
  final MediaOutputPublisher _mediaOutputPublisher;

  /// 每个成功资源都作为当前主任务的保留产物写入数据库。
  final DownloadTaskRepository _repository;

  /// 小型图片和文本资源使用独立短生命周期 HTTP 客户端下载。
  final Dio _dio;

  /// 释放附加资源 HTTP 连接池；协调器销毁后不能继续保留网络句柄。
  void dispose() {
    // force=true 立即终止仍在等待的资源请求，应用退出无需等待文本资源超时。
    _dio.close(force: true);
  }

  /// 处理任务 JSON 中的全部资源；任一资源失败会保留临时流供用户重试。
  Future<void> process({
    required DownloadTaskRecord task,
    required List<DownloadStreamRecord> streams,
  }) async {
    // JSON 是待下载页最终确认的选择，空集合不创建目录外文件。
    final resources = decodeDownloadExtraResources(task.extraResourcesJson);
    if (resources.isEmpty) return;
    // 主任务身份用于重新解析封面、弹幕和字幕地址，不能依赖过期 URL。
    final episode = _episodeFromTask(task);
    // 输出目录在主任务入队时已经固定为标题目录，资源开关不会再搬移路径。
    final outputPath = task.outputPath;
    if (outputPath == null || outputPath.trim().isEmpty) {
      throw StateError('主任务缺少附加资源输出目录。');
    }
    // 基础名称沿用主视频最终文件名，所有资源能够与对应视频一眼关联。
    final outputDirectory = p.dirname(outputPath);
    final baseName = p.basenameWithoutExtension(outputPath);
    // 临时资源只能写入任务专属目录，失败和取消时由现有安全清理规则处理。
    final temporaryDirectory = task.temporaryDirectory;
    if (temporaryDirectory == null || temporaryDirectory.trim().isEmpty) {
      throw StateError('主任务缺少附加资源临时目录。');
    }
    final resourceTemporaryDirectory = Directory(
      p.join(temporaryDirectory, 'resources'),
    );
    await resourceTemporaryDirectory.create(recursive: true);
    // 枚举顺序提供稳定的下载和产物排列，不能依赖 Set 的实现细节。
    for (final resource in DownloadExtraResource.values) {
      if (!resources.contains(resource)) continue;
      try {
        switch (resource) {
          case DownloadExtraResource.audio:
            await _publishStandaloneAudio(
              task: task,
              streams: streams,
              requestedOutputPath: p.join(
                outputDirectory,
                '$baseName [音频].m4a',
              ),
            );
          case DownloadExtraResource.subtitles:
          case DownloadExtraResource.aiSubtitles:
            await _publishSubtitles(
              resource: resource,
              task: task,
              episode: episode,
              temporaryDirectory: resourceTemporaryDirectory.path,
              outputDirectory: outputDirectory,
              baseName: baseName,
            );
          case DownloadExtraResource.cover:
          case DownloadExtraResource.danmakuXml:
          case DownloadExtraResource.danmakuAss:
            await _publishSingleResource(
              task: task,
              episode: episode,
              resource: resource,
              temporaryDirectory: resourceTemporaryDirectory.path,
              requestedOutputPath: p.join(
                outputDirectory,
                '$baseName [${downloadExtraResourceLabel(resource)}]'
                '${_extensionForResource(resource, task.coverUrl)}',
              ),
            );
        }
      } catch (error) {
        // 附加资源属于可选交付，单项缺失不能让已经下载完成的主视频整体失败。
        AppDebugLog.aria2(
          'Embedded resource skipped task=${task.taskId} '
          'resource=${resource.name} error=${error.runtimeType}',
        );
      }
    }
  }

  /// 从永久任务字段重建解析服务所需的分集对象。
  BiliEpisodeInfo _episodeFromTask(DownloadTaskRecord task) {
    // 普通投稿没有 EP ID，PGC 任务由 EP ID 恢复内容类型。
    final contentType = task.epid == null
        ? BiliContentType.ugc
        : BiliContentType.pgc;
    final bvid = task.bvid;
    final cid = task.cid;
    if (bvid == null || bvid.isEmpty || cid == null) {
      throw StateError('主任务缺少附加资源解析所需的 BVID 或 CID。');
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

  /// 将主任务音频临时流转封装为用户可直接播放的独立 m4a 文件。
  Future<void> _publishStandaloneAudio({
    required DownloadTaskRecord task,
    required List<DownloadStreamRecord> streams,
    required String requestedOutputPath,
  }) async {
    // 只有本次任务实际下载过音频流时才能生成独立音频，禁用音频的任务不伪造文件。
    final audioStreams = streams.where(
      (DownloadStreamRecord stream) => stream.kind == DownloadStreamKind.audio,
    );
    if (audioStreams.isEmpty) throw StateError('当前任务没有可导出的音频流。');
    final workingOutputPath = await _mediaOutputPublisher.prepareOutputPath(
      requestedOutputPath: requestedOutputPath,
      temporaryDirectory: task.temporaryDirectory,
    );
    // FFmpeg 只接收音频输入时执行转封装，不重新编码音频内容。
    await _mediaMerger.merge(
      MediaMergeRequest(
        audioPath: audioStreams.single.temporaryPath,
        outputPath: workingOutputPath,
        expectedDuration: task.durationMilliseconds == null
            ? null
            : Duration(milliseconds: task.durationMilliseconds!),
      ),
    );
    await _publishArtifact(
      taskId: task.taskId,
      kind: DownloadArtifactKind.standaloneAudio,
      workingOutputPath: workingOutputPath,
      requestedOutputPath: requestedOutputPath,
    );
  }

  /// 下载并发布封面或单份弹幕资源。
  Future<void> _publishSingleResource({
    required DownloadTaskRecord task,
    required BiliEpisodeInfo episode,
    required DownloadExtraResource resource,
    required String temporaryDirectory,
    required String requestedOutputPath,
  }) async {
    // 原始响应路径与转换后文件分开，失败重试不能误用半成品。
    final inputPath = p.join(temporaryDirectory, '${resource.name}.download');
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
      // 弹幕接口使用 raw deflate，必须复用解析器的受限解码逻辑。
      final bytes = await _parser.fetchDanmakuXmlBytes(source);
      await File(inputPath).writeAsBytes(bytes, flush: true);
    } else {
      await _downloadSource(source.url, source.headers, inputPath);
    }
    final workingOutputPath = await _mediaOutputPublisher.prepareOutputPath(
      requestedOutputPath: requestedOutputPath,
      temporaryDirectory: task.temporaryDirectory,
    );
    await _writeResource(
      inputPath: inputPath,
      outputPath: workingOutputPath,
      resource: resource,
    );
    await _publishArtifact(
      taskId: task.taskId,
      kind: artifactKindForExtraResource(resource),
      workingOutputPath: workingOutputPath,
      requestedOutputPath: requestedOutputPath,
    );
  }

  /// 下载并发布当前视频提供的全部字幕轨道。
  Future<void> _publishSubtitles({
    required DownloadExtraResource resource,
    required DownloadTaskRecord task,
    required BiliEpisodeInfo episode,
    required String temporaryDirectory,
    required String outputDirectory,
    required String baseName,
  }) async {
    // 人工与 AI 选项分别导出各自全部语言，禁止两个选项重复下载同一轨道。
    final tracks = await _parser.loadSubtitleTracks(
      episode,
      aiGenerated: resource == DownloadExtraResource.aiSubtitles,
    );
    final label = downloadExtraResourceLabel(resource);
    if (tracks.isEmpty) throw StateError('当前视频没有可下载的$label。');
    for (final track in tracks) {
      // 语言代码经过文件名安全替换，外部接口文本不能直接拼接到路径。
      final safeLanguage = track.languageCode.replaceAll(
        RegExp(r'[^A-Za-z0-9._-]'),
        '_',
      );
      final inputPath = p.join(
        temporaryDirectory,
        'subtitle_$safeLanguage.download',
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
      final requestedOutputPath = p.join(
        outputDirectory,
        '$baseName [$label $safeLanguage].srt',
      );
      final workingOutputPath = await _mediaOutputPublisher.prepareOutputPath(
        requestedOutputPath: requestedOutputPath,
        temporaryDirectory: task.temporaryDirectory,
      );
      await _writeResource(
        inputPath: inputPath,
        outputPath: workingOutputPath,
        resource: resource,
      );
      await _publishArtifact(
        taskId: task.taskId,
        kind: DownloadArtifactKind.subtitle,
        workingOutputPath: workingOutputPath,
        requestedOutputPath: requestedOutputPath,
      );
    }
  }

  /// 使用解析器提供的鉴权头把小型资源下载到任务临时目录。
  Future<void> _downloadSource(
    Uri uri,
    Map<String, String> headers,
    String destinationPath,
  ) async {
    // 每次写入前创建父目录，兼容资源子目录首次生成。
    await File(destinationPath).parent.create(recursive: true);
    final response = await _dio.downloadUri(
      uri,
      destinationPath,
      options: Options(headers: headers, responseType: ResponseType.bytes),
      deleteOnError: true,
    );
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      // 非成功响应不能进入转换阶段，避免把错误页保存为封面或字幕。
      final file = File(destinationPath);
      if (await file.exists()) await file.delete();
      throw StateError('附加资源下载返回 HTTP $status。');
    }
  }

  /// 根据资源语义复制原文或转换为通用格式。
  Future<void> _writeResource({
    required String inputPath,
    required String outputPath,
    required DownloadExtraResource resource,
  }) async {
    // 发布器可能返回平台临时路径，写入前必须确保其父目录存在。
    await File(outputPath).parent.create(recursive: true);
    switch (resource) {
      case DownloadExtraResource.cover:
      case DownloadExtraResource.danmakuXml:
        await File(inputPath).copy(outputPath);
      case DownloadExtraResource.danmakuAss:
        await convertBiliDanmakuXmlFileToAss(
          inputPath: inputPath,
          outputPath: outputPath,
        );
      case DownloadExtraResource.subtitles:
      case DownloadExtraResource.aiSubtitles:
        await convertBiliSubtitleJsonFileToSrt(
          inputPath: inputPath,
          outputPath: outputPath,
        );
      case DownloadExtraResource.audio:
        throw StateError('独立音频必须使用媒体转封装流程。');
    }
  }

  /// 发布一个文件并把真实平台标识登记到主任务产物列表。
  Future<void> _publishArtifact({
    required String taskId,
    required DownloadArtifactKind kind,
    required String workingOutputPath,
    required String requestedOutputPath,
  }) async {
    // Android 发布后工作文件可能被移动，大小必须提前读取。
    final sizeBytes = await File(workingOutputPath).length();
    final publishedOutput = await _mediaOutputPublisher.publish(
      workingOutputPath: workingOutputPath,
      requestedOutputPath: requestedOutputPath,
    );
    await _repository.upsertArtifact(
      DownloadArtifactDraft(
        taskId: taskId,
        kind: kind,
        path: publishedOutput.storageIdentifier,
        sizeBytes: sizeBytes,
        retained: true,
      ),
    );
  }

  /// 返回资源最终扩展名；封面尽量保留服务端图片格式。
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
}
