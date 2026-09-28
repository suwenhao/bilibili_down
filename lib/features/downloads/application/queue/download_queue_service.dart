import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/platform/default_download_directory.dart';
import '../../../../core/platform/output_path_policy.dart';
import '../../../../core/platform/platform_providers.dart';
import '../../../../core/platform/runtime_platform.dart';
import '../../../../services/bilibili/bilibili_parser_service.dart';
import '../../../../services/bilibili/bilibili_providers.dart';
import '../../../../services/bilibili/models/bili_media_info.dart';
import '../../../settings/application/app_settings_controller.dart';
import '../../../settings/domain/app_settings.dart';
import '../../data/download_task_draft.dart';
import '../../data/download_task_repository.dart';
import '../../domain/download_task_phase.dart';
import '../../domain/download_extra_resource.dart';
import '../../domain/stored_dash_options.dart';
import 'download_queue_policy.dart';
import 'download_task_naming_service.dart';

export 'download_queue_policy.dart';

/// 自动重名最多尝试的序号数量，防止异常目录状态让入队流程无上限查询。
const int _maximumOutputRenameAttempts = 10000;

/// 提供解析页写入待下载任务的应用服务。
final downloadQueueServiceProvider = Provider<DownloadQueueService>((Ref ref) {
  // 获取能够等待设置恢复完成并始终返回最新快照的控制器。
  final settingsController = ref.read(appSettingsControllerProvider.notifier);
  // 注入任务仓库、平台、解析器和当前设置快照。
  return DownloadQueueService(
    ref.watch(downloadTaskRepositoryProvider),
    ref.watch(runtimePlatformProvider),
    ref.watch(bilibiliParserServiceProvider),
    settingsController.loadReadySettings,
  );
});

/// 批量加入待下载任务后的统计结果。
final class QueueEpisodesResult {
  /// 创建本次新增数量结果。
  const QueueEpisodesResult({
    required this.added,
    this.extraAdded = 0,
    this.skipped = 0,
  });

  /// 本次实际新增任务数量。
  final int added;

  /// 随主任务保存的附加资源选择数量。
  final int extraAdded;

  /// 因重名策略选择“跳过”而未创建的视频任务数量。
  final int skipped;
}

/// 批量解析时上报当前处理序号和总任务数。
typedef QueueEpisodesProgressCallback = void Function(int current, int total);

/// 已经完成基础信息解析、等待生成待下载任务的一组分集。
final class QueueEpisodeRequest {
  /// 创建一组来源、媒体和待入队分集。
  const QueueEpisodeRequest({
    required this.sourceInput,
    required this.media,
    required this.episodes,
  });

  /// 用户原始输入或用户中心条目的标准视频入口。
  final String sourceInput;

  /// 解析得到的媒体集合。
  final BiliMediaInfo media;

  /// 本次需要加入待下载的分集列表。
  final List<BiliEpisodeInfo> episodes;
}

/// 设置中心同步待下载任务后的统计结果。
final class QueuedTaskSettingsSyncResult {
  /// 创建成功与失败数量结果。
  const QueuedTaskSettingsSyncResult({
    required this.updated,
    required this.failed,
  });

  /// 本次成功同步的 queued 任务数量。
  final int updated;

  /// 因旧任务缺少本地清单或路径处理失败而保持原快照的任务数量。
  final int failed;
}

/// 将解析分集转换为可恢复的 Drift 待下载任务。
final class DownloadQueueService {
  /// 统一渲染文件名、文件夹并执行跨平台安全清理。
  static const DownloadTaskNamingService _namingService =
      DownloadTaskNamingService();

  /// 创建任务入队服务。
  DownloadQueueService(
    this._repository,
    this._platform,
    this._parser,
    this._settingsLoader,
  );

  /// 负责任务写入和输出路径占用查询的仓库。
  final DownloadTaskRepository _repository;

  /// 决定任务首选下载后端的运行平台。
  final RuntimePlatform _platform;

  /// 负责在进入待下载页前解析每个分集的 DASH 质量信息。
  final BilibiliParserService _parser;

  /// 等待本地设置恢复后返回当前快照的加载器。
  final Future<AppSettings> Function() _settingsLoader;

  /// UUID v4 生成器不包含标题等外部输入。
  static const Uuid _uuid = Uuid();

  /// 串行执行设置同步，防止用户快速切换选项时旧请求最后覆盖新选择。
  Future<void> _settingsSynchronizationQueue = Future<void>.value();

  /// 把选中分集批量加入待下载列表。
  Future<QueueEpisodesResult> queueEpisodes({
    required String sourceInput,
    required BiliMediaInfo media,
    required List<BiliEpisodeInfo> episodes,
    QueueEpisodesProgressCallback? onProgress,
  }) async {
    // 单媒体入队走统一批量入口，保证解析完成后再集中写库。
    return queueEpisodeRequests(
      requests: <QueueEpisodeRequest>[
        QueueEpisodeRequest(
          sourceInput: sourceInput,
          media: media,
          episodes: episodes,
        ),
      ],
      onProgress: onProgress,
    );
  }

  /// 把多组已经完成基础解析的分集批量加入待下载列表。
  Future<QueueEpisodesResult> queueEpisodeRequests({
    required List<QueueEpisodeRequest> requests,
    QueueEpisodesProgressCallback? onProgress,
  }) async {
    // 先固化非空分集请求，避免后续异步阶段读到调用方变化后的列表。
    final pendingRequests = requests
        .where((QueueEpisodeRequest request) => request.episodes.isNotEmpty)
        .toList(growable: false);
    final totalEpisodes = pendingRequests.fold<int>(
      0,
      (int total, QueueEpisodeRequest request) =>
          total + request.episodes.length,
    );
    // 空选择不创建目录或数据库记录。
    if (totalEpisodes == 0) return const QueueEpisodesResult(added: 0);
    // 下载配置不能使用首帧默认值覆盖用户上次保存的选择。
    final settings = await _settingsLoader();
    // 解析当前平台推荐的用户下载目录。
    final downloadRoot = await _resolveDownloadRoot(settings);
    // 保存本次已经准备好的主任务草稿，全部解析完成后再统一写库。
    final drafts = <DownloadTaskDraft>[];
    // 保存本批次已预留但尚未入库的输出路径，避免延迟写库导致同批任务重名。
    final reservedOutputPaths = <String>{};
    // 保存根据默认下载内容写入主任务的附加资源选择数量。
    var extraAdded = 0;
    // 保存因重名策略未创建的视频数量，供解析页明确反馈。
    var skipped = 0;
    // 下载内容设置只映射实际文件资源，自动关机和剪贴板由独立运行时处理。
    final automaticResources = automaticExtraResources(
      settings.downloadContents,
    );
    // 将平台后端类型转换为数据库稳定枚举。
    final backend =
        _platform.primaryDownloadBackend == DownloadBackendKind.aria2
        ? PersistedDownloadBackend.aria2
        : PersistedDownloadBackend.system;
    var progressPosition = 0;
    for (final request in pendingRequests) {
      // 每组请求保留自己的来源输入和媒体上下文。
      final sourceInput = request.sourceInput;
      final media = request.media;
      for (final episode in request.episodes) {
        progressPosition++;
        // 在网络解析开始前上报当前项，让首项等待期间也有明确反馈。
        onProgress?.call(progressPosition, totalEpisodes);
        // 单集任务与解析页统一使用视频主标题，多分集任务继续保留各自分集标题。
        final taskEpisode = _episodeForTask(media: media, episode: episode);
        // “解析选中项目”需要先获得可用视频和音频流，待下载页才能展示默认选择。
        final manifest = await _parser.loadDashManifest(episode);
        // 立即保存不含临时 URL 的完整候选元数据，后续设置变化只在本地重选。
        final storedOptions = StoredDashOptions.fromManifest(manifest);
        // 按设置目标从本地候选选画质；目标不可用时向下选择最高可用档。
        final video = storedOptions.selectVideo(
          qualityId: settings.defaultVideoQuality.qualityId,
          preferredCodec: settings.preferredVideoCodec,
        );
        // 音质使用同一份本地候选和确定性降级规则。
        final audio = storedOptions.selectAudio(
          qualityId: settings.defaultAudioQuality.dashId,
        );
        // 播放清单时长优先，接口缺失时回退基础分集时长。
        final effectiveDuration = storedOptions.durationMilliseconds > 0
            ? Duration(milliseconds: storedOptions.durationMilliseconds)
            : episode.duration;
        // 为业务任务生成不受标题影响的稳定随机 ID。
        final taskId = _uuid.v4();
        // 根据设置中心命名模板构造最终文件名。
        final baseName = _namingService.safeFileName(
          _namingService.renderNamingTemplate(
            settings: settings,
            media: media,
            episode: taskEpisode,
            videoQuality: '${video.qualityLabel} ${video.codec.name}',
            audioQuality: '${audio.qualityLabel} ${audio.codec}',
          ),
        );
        // 按高级存储模板渲染根目录下的安全相对子目录。
        final relativeFolderPath = _namingService.safeRelativeFolderPath(
          _namingService.renderFolderTemplate(
            settings: settings,
            media: media,
            episode: taskEpisode,
            videoQuality: '${video.qualityLabel} ${video.codec.name}',
            audioQuality: '${audio.qualityLabel} ${audio.codec}',
          ),
        );
        // 空模板直接使用下载根目录，非空模板创建对应动态子目录。
        final baseOutputDirectory = relativeFolderPath.isEmpty
            ? downloadRoot
            : Directory(p.join(downloadRoot.path, relativeFolderPath));
        // 每个任务使用独立隐藏临时目录，防止分流文件互相覆盖。
        final temporaryDirectory = p.join(
          downloadRoot.path,
          downloadTemporaryDirectoryName,
          taskId,
        );
        // 有附加资源时使用标题目录收纳主视频和资源；无附加资源时直接平铺到高级目录。
        final outputPath = await _availableMainTaskOutputPath(
          baseOutputDirectory: baseOutputDirectory,
          baseName: baseName,
          hasExtraResources: automaticResources.isNotEmpty,
          strategy: settings.outputConflictStrategy,
          reservedOutputPaths: reservedOutputPaths,
        );
        // 跳过策略遇到已有文件或活动任务时，不创建本集及其附加资源。
        if (outputPath == null) {
          skipped++;
          continue;
        }
        // 延迟写库时先在内存里预留路径，后续同批任务必须避开它。
        reservedOutputPaths.add(_normalizedOutputPath(outputPath));
        // 待下载阶段只保存规划路径，标题目录和临时目录必须等任务真正启动后再创建。
        // 创建只包含永久元数据的视频草稿，短期 DASH URL 在开始时再请求。
        final videoDraft = DownloadTaskDraft(
          taskId: taskId,
          sourceInput: sourceInput,
          title: taskEpisode.title,
          publisherName: media.publisherName,
          publisherId: media.publisherId,
          collectionTitle: media.title,
          contentType: media.contentType.name,
          description: media.description,
          resolutionLabel: taskEpisode.resolutionLabel,
          publishedAt: taskEpisode.publishedAt ?? media.publishedAt,
          bvid: taskEpisode.bvid,
          cid: taskEpisode.cid,
          epid: taskEpisode.episodeId,
          coverUrl: taskEpisode.coverUrl ?? media.coverUrl,
          partIndex: taskEpisode.index,
          qualityId: video.qualityId,
          qualityLabel: video.qualityLabel,
          videoCodec: video.codec.name,
          audioCodec: '${audio.qualityLabel} | ${audio.codec}',
          audioQualityId: audio.qualityId,
          estimatedVideoSizeBytes: video.estimatedSizeBytes,
          estimatedAudioSizeBytes: audio.estimatedSizeBytes,
          dashOptionsJson: storedOptions.encode(),
          extraResourcesJson: encodeDownloadExtraResources(automaticResources),
          durationMilliseconds: effectiveDuration.inMilliseconds,
          temporaryDirectory: temporaryDirectory,
          outputPath: outputPath,
          downloadBackend: backend,
          phase: DownloadTaskPhase.queued,
        );
        // 先仅保存到内存列表，待全部解析和路径规划完成后统一写入数据库。
        drafts.add(videoDraft);
        // 统计随主任务保存的附加资源选择数量，不再代表独立任务卡片数量。
        extraAdded += automaticResources.length;
      }
    }
    // 所有待下载任务草稿准备完成后再开启一次数据库事务批量写入。
    await _repository.createTasks(drafts);
    // 返回解析页用于提示的统计结果。
    return QueueEpisodesResult(
      added: drafts.length,
      extraAdded: extraAdded,
      skipped: skipped,
    );
  }

  /// 更新一条待下载主任务的附加资源复选项，并按资源数量重算输出路径。
  Future<void> updateTaskExtraResources({
    required DownloadTaskRecord task,
    required Set<DownloadExtraResource> resources,
  }) async {
    // 主任务必须已有解析阶段生成的最终路径才能保存资源选择。
    final currentOutputPath = task.outputPath;
    if (currentOutputPath == null || currentOutputPath.trim().isEmpty) {
      throw StateError('当前任务缺少输出路径。');
    }
    // 读取当前设置与下载根目录，附加资源切换会影响是否需要标题目录。
    final settings = await _settingsLoader();
    final downloadRoot = await _resolveDownloadRoot(settings);
    // 从任务永久字段重建命名上下文，不发起网络请求。
    final episode = _episodeFromTask(task);
    final media = _mediaFromTask(task, episode);
    // 使用任务当前质量文案渲染文件名和高级目录变量。
    final audioQualityText = task.audioCodec ?? '自动';
    final videoQualityText = <String>[
      task.qualityLabel ?? '自动',
      if (task.videoCodec != null && task.videoCodec!.isNotEmpty)
        task.videoCodec!,
    ].join(' ');
    // 使用当前命名模板重新生成主任务基础文件名。
    final baseName = _namingService.safeFileName(
      _namingService.renderNamingTemplate(
        settings: settings,
        media: media,
        episode: episode,
        videoQuality: videoQualityText,
        audioQuality: audioQualityText,
        downloadDate: task.createdAt,
      ),
    );
    // 使用当前高级存储规则重新生成根目录下的安全相对目录。
    final relativeFolderPath = _namingService.safeRelativeFolderPath(
      _namingService.renderFolderTemplate(
        settings: settings,
        media: media,
        episode: episode,
        videoQuality: videoQualityText,
        audioQuality: audioQualityText,
        downloadDate: task.createdAt,
      ),
    );
    // 空高级规则使用下载根目录，否则使用高级规则生成的目录。
    final baseOutputDirectory = relativeFolderPath.isEmpty
        ? downloadRoot
        : Directory(p.join(downloadRoot.path, relativeFolderPath));
    // 音频模式或普通视频模式需要保留对应扩展名。
    final extension = _outputExtensionForQueuedTask(
      coverUrl: task.coverUrl,
      extraResource: null,
      qualityId: task.qualityId,
      audioQualityId: task.audioQualityId,
    );
    // 有附加资源时切换到标题目录；无附加资源时回到高级目录平铺。
    final outputPath = await _availableMainTaskOutputPath(
      baseOutputDirectory: baseOutputDirectory,
      baseName: baseName,
      hasExtraResources: resources.isNotEmpty,
      extension: extension,
      strategy: settings.outputConflictStrategy,
      excludingTaskId: task.taskId,
    );
    if (outputPath == null) throw const OutputConflictSkippedException();
    // 资源开关只更新数据库路径和选择，不提前创建标题目录或临时工作目录。
    await _repository.updateExtraResourcesJson(
      task.taskId,
      encodeDownloadExtraResources(resources),
      outputPath,
    );
  }

  /// 批量把同一组附加资源复选项写入多条待下载主任务。
  Future<int> updateTasksExtraResources({
    required List<DownloadTaskRecord> tasks,
    required Set<DownloadExtraResource> resources,
  }) async {
    // 逐任务复用单项目录和 JSON 规则，任一失败由调用方明确反馈。
    var updated = 0;
    for (final task in tasks) {
      // 每次成功写库后再增加计数，避免返回虚假的更新数量。
      await updateTaskExtraResources(task: task, resources: resources);
      updated++;
    }
    // 返回真实更新的主任务数供批量弹窗提示。
    return updated;
  }

  /// 返回文件系统和任务列表中都未占用的输出路径。
  Future<String?> _availableOutputPath({
    required Directory outputDirectory,
    required String baseName,
    required OutputConflictStrategy strategy,
    Set<String> reservedOutputPaths = const <String>{},
    String extension = '.mp4',
    String? excludingTaskId,
  }) async {
    // 精确路径先执行策略判断，覆盖只允许替换终态历史，不能抢占活动任务。
    final exactPath = p.join(outputDirectory.path, '$baseName$extension');
    final exactFileExists = await File(exactPath).exists();
    final exactTasks = await _repository.findTasksForOutputPath(
      exactPath,
      excludingTaskId: excludingTaskId,
    );
    // 批量延迟写库时，同批次已经准备好的路径也必须视为活动占用。
    final exactReserved = reservedOutputPaths.contains(
      _normalizedOutputPath(exactPath),
    );
    final decision = decideOutputConflict(
      strategy: strategy,
      fileExists: exactFileExists,
      conflictingPhases: <DownloadTaskPhase>[
        ...exactTasks.map((DownloadTaskRecord task) => task.phase),
        if (exactReserved) DownloadTaskPhase.queued,
      ],
    );
    // 原名可直接使用或可安全覆盖终态历史时，校验完整路径后返回。
    if (decision == OutputConflictDecision.useExact) {
      validateOutputPath(exactPath, operatingSystem: _platform.operatingSystem);
      return exactPath;
    }
    // “跳过”以及覆盖遇到活动任务时都不创建共享输出路径的任务。
    if (decision == OutputConflictDecision.skip) return null;
    // 自动编号从第二个候选开始，原名已经确认被占用。
    var sequence = 2;
    while (sequence <= _maximumOutputRenameAttempts) {
      // 原名已经确认冲突，后续候选统一使用常见括号序号。
      final candidateName = '$baseName ($sequence)$extension';
      // 输出目录已经通过安全模板生成，这里只拼接最终文件名。
      final candidatePath = p.join(outputDirectory.path, candidateName);
      // 同时检查磁盘成品和数据库任务，避免并发或排队任务指向同一路径。
      final occupiedByFile = await File(candidatePath).exists();
      final occupiedByTask = await _repository.hasTaskForOutputPath(
        candidatePath,
        excludingTaskId: excludingTaskId,
      );
      final occupiedByBatch = reservedOutputPaths.contains(
        _normalizedOutputPath(candidatePath),
      );
      // 两处都未占用时返回本次任务独立输出路径。
      if (!occupiedByFile && !occupiedByTask && !occupiedByBatch) {
        // 入库前再次校验完整路径长度和最终文件名，避免错误延迟到下载完成。
        validateOutputPath(
          candidatePath,
          operatingSystem: _platform.operatingSystem,
        );
        return candidatePath;
      }
      // 当前候选被占用时继续尝试下一个序号。
      sequence++;
    }
    // 如果同名编号过多，继续查找只会长时间占用入队流程，交给上层显示失败原因。
    throw StateError('无法在 $_maximumOutputRenameAttempts 次尝试内生成未占用的输出路径。');
  }

  /// 根据附加资源选择为主任务寻找输出路径。
  Future<String?> _availableMainTaskOutputPath({
    required Directory baseOutputDirectory,
    required String baseName,
    required bool hasExtraResources,
    required OutputConflictStrategy strategy,
    Set<String> reservedOutputPaths = const <String>{},
    String extension = '.mp4',
    String? excludingTaskId,
  }) {
    // 附加资源需要和主视频放在同一标题目录内，避免封面、字幕和弹幕散落。
    if (hasExtraResources) {
      return _availableTaskOutputPath(
        parentDirectory: baseOutputDirectory,
        baseName: baseName,
        extension: extension,
        strategy: strategy,
        reservedOutputPaths: reservedOutputPaths,
        excludingTaskId: excludingTaskId,
      );
    }
    // 没有附加资源时无需额外标题目录，主视频直接保存到高级目录或下载根目录。
    return _availableOutputPath(
      outputDirectory: baseOutputDirectory,
      baseName: baseName,
      extension: extension,
      strategy: strategy,
      reservedOutputPaths: reservedOutputPaths,
      excludingTaskId: excludingTaskId,
    );
  }

  /// 为主任务寻找未占用的“标题目录/标题文件”输出路径。
  Future<String?> _availableTaskOutputPath({
    required Directory parentDirectory,
    required String baseName,
    required OutputConflictStrategy strategy,
    Set<String> reservedOutputPaths = const <String>{},
    String extension = '.mp4',
    String? excludingTaskId,
  }) async {
    // 精确候选的目录名和文件基础名相同，附加资源随后复用该目录。
    final exactPath = buildTaskOutputPath(
      parentDirectory: parentDirectory.path,
      baseName: baseName,
      extension: extension,
    );
    final exactDirectory = Directory(p.dirname(exactPath));
    // 非空既有目录也视为占用，防止新任务混入用户已有同名资料。
    final directoryOccupied =
        await exactDirectory.exists() && !await exactDirectory.list().isEmpty;
    final exactTasks = await _repository.findTasksForOutputPath(
      exactPath,
      excludingTaskId: excludingTaskId,
    );
    // 批量延迟写库时，同批次已经准备好的路径也必须视为活动占用。
    final exactReserved = reservedOutputPaths.contains(
      _normalizedOutputPath(exactPath),
    );
    final decision = decideOutputConflict(
      strategy: strategy,
      fileExists: directoryOccupied || await File(exactPath).exists(),
      conflictingPhases: <DownloadTaskPhase>[
        ...exactTasks.map((DownloadTaskRecord task) => task.phase),
        if (exactReserved) DownloadTaskPhase.queued,
      ],
    );
    if (decision == OutputConflictDecision.useExact) {
      // 最终路径包含新增标题层级，入库前必须重新执行平台长度和文件名校验。
      validateOutputPath(exactPath, operatingSystem: _platform.operatingSystem);
      return exactPath;
    }
    if (decision == OutputConflictDecision.skip) return null;
    // 自动编号同时作用于目录名和文件名，避免多个任务共享同一标题目录。
    var sequence = 2;
    while (sequence <= _maximumOutputRenameAttempts) {
      final candidateBaseName = '$baseName ($sequence)';
      final candidatePath = buildTaskOutputPath(
        parentDirectory: parentDirectory.path,
        baseName: candidateBaseName,
        extension: extension,
      );
      final candidateDirectory = Directory(p.dirname(candidatePath));
      final occupiedByDirectory =
          await candidateDirectory.exists() &&
          !await candidateDirectory.list().isEmpty;
      final occupiedByTask = await _repository.hasTaskForOutputPath(
        candidatePath,
        excludingTaskId: excludingTaskId,
      );
      final occupiedByBatch = reservedOutputPaths.contains(
        _normalizedOutputPath(candidatePath),
      );
      if (!occupiedByDirectory && !occupiedByTask && !occupiedByBatch) {
        // 候选目录和数据库都未占用时返回完整主任务路径。
        validateOutputPath(
          candidatePath,
          operatingSystem: _platform.operatingSystem,
        );
        return candidatePath;
      }
      sequence++;
    }
    // 极端重名目录会持续触发文件系统与数据库查询，主动终止避免页面一直等待。
    throw StateError('无法在 $_maximumOutputRenameAttempts 次尝试内生成未占用的任务目录。');
  }

  /// 规范化输出路径，供同批次内存预留集合比较使用。
  String _normalizedOutputPath(String path) {
    // absolute 让同一相对路径和绝对路径不会在批量规划中被误判为不同目标。
    return p.normalize(p.absolute(path));
  }

  /// 根据任务内容类型返回最终文件扩展名。
  String _outputExtensionForQueuedTask({
    required String? coverUrl,
    required DownloadExtraResource? extraResource,
    required int? qualityId,
    required int? audioQualityId,
  }) {
    // 独立附加资源保留各自真实文件格式。
    if (extraResource != null) {
      return _extraResourceExtensionForCover(coverUrl, extraResource);
    }
    // 只有音频质量而没有视频质量时输出独立音频文件。
    if (qualityId == null && audioQualityId != null) return '.m4a';
    // 普通视频任务统一输出 mp4。
    return '.mp4';
  }

  /// 返回附加资源对应的最终文件扩展名。
  String _extraResourceExtensionForCover(
    String? coverUrl,
    DownloadExtraResource resource,
  ) => switch (resource) {
    DownloadExtraResource.cover => _coverExtension(coverUrl),
    DownloadExtraResource.audio => '.m4a',
    DownloadExtraResource.danmakuXml => '.xml',
    DownloadExtraResource.danmakuAss => '.ass',
    DownloadExtraResource.subtitles ||
    DownloadExtraResource.aiSubtitles => '.srt',
  };

  /// 从封面地址保留常见图片扩展名。
  String _coverExtension(String? coverUrl) {
    // URL 缺失或扩展名未知时使用兼容性最好的 jpg。
    final path = Uri.tryParse(coverUrl ?? '')?.path ?? '';
    final extension = p.extension(path).toLowerCase();
    // 只允许常见图片扩展名进入最终文件名。
    return const <String>{'.jpg', '.jpeg', '.png', '.webp'}.contains(extension)
        ? extension
        : '.jpg';
  }

  /// 创建与解析页显示规则一致的任务分集快照。
  BiliEpisodeInfo _episodeForTask({
    required BiliMediaInfo media,
    required BiliEpisodeInfo episode,
  }) {
    // 先清理媒体主标题首尾空白，避免生成看似为空的任务名称。
    final mediaTitle = media.title.trim();
    // 单集内容使用媒体主标题；主标题异常为空或属于多分集时保留原始分集标题。
    final taskTitle = media.episodes.length == 1 && mediaTitle.isNotEmpty
        ? mediaTitle
        : episode.title;
    // 标题没有变化时直接复用原对象，避免无意义分配。
    if (taskTitle == episode.title) return episode;
    // 只替换展示和命名使用的标题，其余解析标识保持原值。
    return BiliEpisodeInfo(
      contentType: episode.contentType,
      bvid: episode.bvid,
      cid: episode.cid,
      index: episode.index,
      title: taskTitle,
      duration: episode.duration,
      episodeId: episode.episodeId,
      seasonId: episode.seasonId,
      coverUrl: episode.coverUrl,
      width: episode.width,
      height: episode.height,
      publishedAt: episode.publishedAt,
    );
  }

  /// 按当前设置重新计算所有尚未启动任务并触发任务列表实时刷新。
  Future<QueuedTaskSettingsSyncResult> synchronizeQueuedTasks({
    required bool refreshQuality,
  }) {
    // 把本次同步排在已有请求之后，后一次请求最终一定使用最新设置覆盖前一次。
    final operation = _settingsSynchronizationQueue.then(
      (_) => _performQueuedTaskSynchronization(refreshQuality: refreshQuality),
    );
    // 队列自身吞掉错误以保证后续同步仍能继续执行，调用方仍通过 operation 收到异常。
    _settingsSynchronizationQueue = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    // 返回本次独立操作结果供设置页反馈。
    return operation;
  }

  /// 执行一次实际的 queued 任务设置同步。
  Future<QueuedTaskSettingsSyncResult> _performQueuedTaskSynchronization({
    required bool refreshQuality,
  }) async {
    // 等待设置持久化完成后读取最终快照，避免使用点击前的旧值。
    final settings = await _settingsLoader();
    // 获取新设置对应的实际下载根目录。
    final downloadRoot = await _resolveDownloadRoot(settings);
    // 仅加载 queued 任务，活动与终态任务不会跟随设置变化。
    final tasks = await _repository.loadQueuedTasks();
    // 保存成功同步数量。
    var updated = 0;
    // 保存单任务本地同步失败数量。
    var failed = 0;
    for (final task in tasks) {
      try {
        // 独立资源任务与媒体任务共用命名和目录模板，但不能参与 DASH 质量重选。
        final extraResource = downloadExtraResourceFromCode(task.contentType);
        // 新版主任务随设置同步附加资源 JSON；旧独立资源记录保持原类型直至用户清理。
        final embeddedResources = extraResource == null
            ? automaticExtraResources(settings.downloadContents)
            : const <DownloadExtraResource>{};
        // 从解析时入库的永久字段重建命名和高级目录上下文，不发网络请求。
        final episode = _episodeFromTask(task);
        // 从任务永久字段重建媒体集合上下文。
        final media = _mediaFromTask(task, episode);
        // 默认沿用任务当前选中质量，只有质量设置变化时从本地清单重选。
        var qualityId = task.qualityId;
        // 沿用当前视频质量文案。
        var qualityLabel = task.qualityLabel;
        // 沿用当前视频编码。
        var videoCodec = task.videoCodec;
        // 沿用当前音频质量代码。
        var audioQualityId = task.audioQualityId;
        // 沿用当前音频显示文案。
        var audioCodec = task.audioCodec;
        // 沿用当前视频预计大小。
        var estimatedVideoSizeBytes = task.estimatedVideoSizeBytes;
        // 沿用当前音频预计大小。
        var estimatedAudioSizeBytes = task.estimatedAudioSizeBytes;
        // 默认沿用数据库时长，本地候选重选后改用解析清单时长。
        var durationMilliseconds = task.durationMilliseconds;
        if (refreshQuality && extraResource == null) {
          // 旧任务没有候选清单时不能在本地可靠重选，要求重新解析任务。
          final source = task.dashOptionsJson;
          if (source == null || source.isEmpty) {
            throw StateError('旧任务缺少 DASH 候选清单，请重新解析。');
          }
          // 从数据库恢复解析时已经获得的完整候选元数据。
          final storedOptions = StoredDashOptions.decode(source);
          // 按最新设置目标在本地选择视频并执行向下降级。
          final video = storedOptions.selectVideo(
            qualityId: settings.defaultVideoQuality.qualityId,
            preferredCodec: settings.preferredVideoCodec,
          );
          // 按最新设置目标在本地选择音频。
          final audio = storedOptions.selectAudio(
            qualityId: settings.defaultAudioQuality.dashId,
          );
          // 使用持久化候选中的实际视频质量文案。
          qualityLabel = video.qualityLabel;
          // 写入实际命中的视频质量代码。
          qualityId = video.qualityId;
          // 写入实际命中的稳定编码名称。
          videoCodec = video.codec.name;
          // 写入实际命中的音频质量代码。
          audioQualityId = audio.qualityId;
          // 生成任务卡和命名模板共用的音频文案。
          audioCodec = '${audio.qualityLabel} | ${audio.codec}';
          // 预计大小直接读取解析时计算并入库的候选值。
          estimatedVideoSizeBytes = video.estimatedSizeBytes;
          // 同步读取实际音频候选预计大小。
          estimatedAudioSizeBytes = audio.estimatedSizeBytes;
          // 本地候选保存了原清单时长，存在时同步回任务字段。
          if (storedOptions.durationMilliseconds > 0) {
            durationMilliseconds = storedOptions.durationMilliseconds;
          }
        }
        // 组合当前任务最终音质文案供文件名和高级目录变量使用。
        final audioQualityText = audioCodec ?? '自动';
        // 组合当前任务最终画质与编码文案。
        final videoQualityText = <String>[
          qualityLabel ?? '自动',
          if (videoCodec != null && videoCodec.isNotEmpty) videoCodec,
        ].join(' ');
        // 使用最新设置重新渲染最终文件名，质量变量会同步变化。
        final renderedBaseName = _namingService.safeFileName(
          _namingService.renderNamingTemplate(
            settings: settings,
            media: media,
            episode: episode,
            videoQuality: videoQualityText,
            audioQuality: audioQualityText,
            downloadDate: task.createdAt,
          ),
        );
        // 独立资源沿用媒体基础名称并追加资源类型，避免封面、字幕和弹幕互相覆盖。
        final baseName = extraResource == null
            ? renderedBaseName
            : '$renderedBaseName [${downloadExtraResourceLabel(extraResource)}]';
        // 媒体按实际分流选择扩展名，独立资源保留各自真实文件格式。
        final extension = _outputExtensionForQueuedTask(
          coverUrl: task.coverUrl,
          extraResource: extraResource,
          qualityId: qualityId,
          audioQualityId: audioQualityId,
        );
        // 使用最新高级存储规则重新计算根目录下相对层级。
        final relativeFolderPath = _namingService.safeRelativeFolderPath(
          _namingService.renderFolderTemplate(
            settings: settings,
            media: media,
            episode: episode,
            videoQuality: videoQualityText,
            audioQuality: audioQualityText,
            downloadDate: task.createdAt,
          ),
        );
        // 空高级规则直接使用根目录，否则拼接安全相对子目录。
        final baseOutputDirectory = relativeFolderPath.isEmpty
            ? downloadRoot
            : Directory(p.join(downloadRoot.path, relativeFolderPath));
        // 主任务有附加资源时创建标题目录；无附加资源时直接平铺到高级目录。
        final outputPath = extraResource == null
            ? await _availableMainTaskOutputPath(
                baseOutputDirectory: baseOutputDirectory,
                baseName: baseName,
                hasExtraResources: embeddedResources.isNotEmpty,
                extension: extension,
                strategy: settings.outputConflictStrategy,
                excludingTaskId: task.taskId,
              )
            : await _availableOutputPath(
                outputDirectory: baseOutputDirectory,
                baseName: baseName,
                extension: extension,
                strategy: settings.outputConflictStrategy,
                excludingTaskId: task.taskId,
              );
        // 同步时若新目标按策略不可用，保留原任务快照并计入失败提示。
        if (outputPath == null) throw const OutputConflictSkippedException();
        // 设置同步只重算并保存路径，真实目录继续延迟到任务启动阶段创建。
        // 原子写入质量、预计大小和路径，Drift 监听器会立即刷新任务列表。
        await _repository.updateQueuedTaskSettings(
          taskId: task.taskId,
          qualityId: qualityId,
          qualityLabel: qualityLabel,
          videoCodec: videoCodec,
          audioQualityId: audioQualityId,
          audioCodec: audioCodec,
          estimatedVideoSizeBytes: estimatedVideoSizeBytes,
          estimatedAudioSizeBytes: estimatedAudioSizeBytes,
          durationMilliseconds: durationMilliseconds,
          temporaryDirectory: p.join(
            downloadRoot.path,
            downloadTemporaryDirectoryName,
            task.taskId,
          ),
          outputPath: outputPath,
        );
        if (extraResource == null) {
          // JSON 与同步后的路径再次同次约束更新，卡片菜单不会残留已关闭设置。
          await _repository.updateExtraResourcesJson(
            task.taskId,
            encodeDownloadExtraResources(embeddedResources),
            outputPath,
          );
        }
        // 当前任务同步完成后累加成功数量。
        updated++;
      } catch (_) {
        // 单条任务失败不阻塞其余任务，界面最终统一报告失败数量。
        failed++;
      }
    }
    // 返回设置页用于反馈部分失败的统计结果。
    return QueuedTaskSettingsSyncResult(updated: updated, failed: failed);
  }

  /// 从任务永久字段重建一条分集上下文。
  BiliEpisodeInfo _episodeFromTask(DownloadTaskRecord task) {
    // BVID 与 CID 是本地重选和最终刷新 URL 的必要标识。
    final bvid = task.bvid;
    // 读取分集 CID。
    final cid = task.cid;
    if (bvid == null || bvid.isEmpty || cid == null) {
      throw StateError('任务缺少 BVID 或 CID：${task.taskId}');
    }
    // 优先使用解析时保存的内容类型，旧任务按 EP ID 推断。
    final contentType =
        task.contentType == BiliContentType.pgc.name || task.epid != null
        ? BiliContentType.pgc
        : BiliContentType.ugc;
    // 返回不依赖网络的分集上下文。
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

  /// 从任务永久字段重建命名和高级目录所需媒体上下文。
  BiliMediaInfo _mediaFromTask(
    DownloadTaskRecord task,
    BiliEpisodeInfo episode,
  ) {
    // 返回解析时已经保存的集合级元数据，不重新请求基础信息接口。
    return BiliMediaInfo(
      contentType: episode.contentType,
      title: task.collectionTitle ?? task.title,
      episodes: <BiliEpisodeInfo>[episode],
      coverUrl: task.coverUrl,
      description: task.description,
      publisherName: task.publisherName,
      publisherId: task.publisherId,
      publishedAt: task.publishedAt,
    );
  }

  /// 解析跨平台默认下载目录。
  Future<Directory> _resolveDownloadRoot(AppSettings settings) async {
    // iOS 只在应用沙箱中下载和合并，不能复用没有安全作用域书签的历史普通路径。
    if (_platform.operatingSystem == HostOperatingSystem.ios) {
      return resolveDefaultDownloadDirectory();
    }
    // 用户选择过自定义目录时优先使用；Android 这里保存的也是全文件权限下的真实路径。
    final customPath = settings.downloadDirectoryPath;
    if (customPath != null && customPath.trim().isNotEmpty) {
      // 构造用户明确选择的目录对象。
      final customDirectory = Directory(customPath.trim());
      // 递归创建不存在的目录，失败时把真实文件系统错误交给界面。
      await customDirectory.create(recursive: true);
      // 返回已确认可用的自定义目录。
      return customDirectory;
    }
    // 统一解析可写工作目录，Android 默认落到公共 Download/BiliDown 真实路径。
    return resolveDefaultDownloadDirectory();
  }
}
