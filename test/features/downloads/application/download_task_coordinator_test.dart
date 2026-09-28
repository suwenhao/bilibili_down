import 'dart:async';

import 'package:bilibili_down/core/database/app_database.dart';
import 'package:bilibili_down/core/network/bili_network_client.dart';
import 'package:bilibili_down/features/downloads/application/maintenance/download_completion_cleanup_service.dart';
import 'package:bilibili_down/features/downloads/application/queue/download_task_plan.dart';
import 'package:bilibili_down/features/downloads/application/runtime/download_task_coordinator.dart';
import 'package:bilibili_down/features/downloads/application/runtime/expired_media_url_resolver.dart';
import 'package:bilibili_down/features/downloads/application/resources/embedded_extra_resource_processor.dart';
import 'package:bilibili_down/features/downloads/application/resources/standalone_extra_resource_finalizer.dart';
import 'package:bilibili_down/features/downloads/data/download_task_draft.dart';
import 'package:bilibili_down/features/downloads/data/download_task_repository.dart';
import 'package:bilibili_down/features/downloads/domain/download_task_phase.dart';
import 'package:bilibili_down/services/bilibili/bili_input_normalizer.dart';
import 'package:bilibili_down/services/bilibili/bilibili_parser_service.dart';
import 'package:bilibili_down/services/bilibili/wbi_signer.dart';
import 'package:bilibili_down/services/download_engine/download_engine.dart';
import 'package:bilibili_down/services/media_merge/media_merger.dart';
import 'package:bilibili_down/services/media_output/media_output_publisher.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 验证真实事件链会换源两次，并在耗尽后保留诊断与可操作提示。
  test('证书吊销服务离线会有限换源，持续失败不会无限重试', () async {
    // 内存数据库保存实际主任务与分流状态，不访问网络或真实下载文件。
    final database = AppDatabase(NativeDatabase.memory());
    final repository = DownloadTaskRepository(database);
    // 收集每次提交的 URL，防止只刷新地址却始终选择同一 CDN。
    final requests = <DownloadRequest>[];
    // 模拟截图中的 Windows Schannel 错误，所有候选 CDN 均不可用。
    const failure = DownloadEvent(
      taskId: 'revocation-offline.video',
      status: DownloadStatus.failed,
      errorCode: '1',
      errorMessage: 'SSL/TLS handshake failure: Error: 由于吊销服务器已脱机，吊销功能无法检查吊销。',
    );
    // 重试提交后继续发出失败，以覆盖自动重试上限和最终提示。
    late final _FakeDownloadEngine engine;
    engine = _FakeDownloadEngine(
      onEnqueue: (DownloadRequest request) async {
        requests.add(request);
        // 首次失败在任务进入下载状态后发送，后续失败模拟重试仍不可用。
        if (requests.length > 1) engine._events.add(failure);
      },
    );
    final coordinator = _createCoordinator(
      engine: engine,
      repository: repository,
    );
    // 先关闭事件消费者，再关闭内存数据库，避免迟到事件访问已释放连接。
    addTearDown(() async {
      await coordinator.dispose();
      await database.close();
    });
    await repository.createTask(
      const DownloadTaskDraft(
        taskId: 'revocation-offline',
        sourceInput: 'BV-offline',
        title: '证书吊销服务离线',
        phase: DownloadTaskPhase.waitingToStart,
        outputPath: 'D:/downloads/offline.mp4',
        temporaryDirectory: 'D:/temp/offline',
      ),
    );
    await coordinator.startResolvedTask(_singleVideoPlan('revocation-offline'));
    // 在发送失败前订阅最终状态，等待事件链完成而不依赖固定延迟。
    final failedTask = repository
        .watchTask('revocation-offline')
        .firstWhere((task) => task?.phase == DownloadTaskPhase.failed)
        .timeout(const Duration(seconds: 5));
    engine._events.add(failure);
    final task = await failedTask;

    // 首次下载加两次自动恢复，分别选择两个不同备用主机。
    expect(requests.map((request) => request.url.host), <String>[
      'example.invalid',
      'backup-1.example.invalid',
      'backup-2.example.invalid',
    ]);
    expect(task?.retryCount, 2);
    expect(task?.errorCode, 'certificate_revocation_unavailable');
    expect(task?.errorMessage, contains('请检查网络、代理或防火墙后重试'));
    // 分流原始异常留在数据库，导出诊断时仍能定位系统返回的原因。
    final streams = await repository.loadStreams('revocation-offline');
    expect(streams.single.errorMessage, failure.errorMessage);
  });

  /// 验证网络错误会按重试次数依次选择备用 CDN。
  test('备用 CDN 按有限重试次数轮换到首位', () {
    // 主地址和两个备用地址模拟 B 站 DASH 清单返回顺序。
    final primary = Uri.parse('https://primary.example/video.m4s');
    final firstBackup = Uri.parse('https://backup-1.example/video.m4s');
    final secondBackup = Uri.parse('https://backup-2.example/video.m4s');
    // 第一次自动重试应优先第一个备用地址。
    expect(
      orderedCdnRetryUrls(
        primary: primary,
        backups: <Uri>[firstBackup, secondBackup],
        retryCount: 0,
        rotate: true,
      ),
      <Uri>[firstBackup, primary, secondBackup],
    );
    // 第二次自动重试继续选择第二个备用地址。
    expect(
      orderedCdnRetryUrls(
        primary: primary,
        backups: <Uri>[firstBackup, secondBackup],
        retryCount: 1,
        rotate: true,
      ).first,
      secondBackup,
    );
  });

  /// 验证鉴权刷新保持主地址且重复备用地址会被去除。
  test('鉴权刷新不轮换并去除重复地址', () {
    // 401/403 需要最新鉴权主地址，不能误切换到旧备用地址。
    final primary = Uri.parse('https://primary.example/video.m4s');
    final backup = Uri.parse('https://backup.example/video.m4s');
    expect(
      orderedCdnRetryUrls(
        primary: primary,
        backups: <Uri>[primary, backup, backup],
        retryCount: 0,
        rotate: false,
      ),
      <Uri>[primary, backup],
    );
  });

  /// 验证引擎事件状态保持原有分流持久化映射。
  test('下载事件状态映射为分流状态', () {
    // resolving 在分流表中仍属于已排队，避免提前显示正在下载。
    expect(
      streamPhaseFor(DownloadStatus.resolving),
      DownloadStreamPhase.queued,
    );
    expect(
      streamPhaseFor(DownloadStatus.downloading),
      DownloadStreamPhase.downloading,
    );
    expect(
      streamPhaseFor(DownloadStatus.completed),
      DownloadStreamPhase.completed,
    );
  });

  /// 验证鉴权、网络和 TLS 文本继续提取稳定业务错误码。
  test('下载错误文本提取稳定错误码', () {
    // 覆盖 aria2 状态码、Socket 异常和 OpenSSL 协议错误三类刷新分支。
    expect(downloadErrorCodeFor('status=403'), '403');
    expect(
      downloadErrorCodeFor('SocketException: connection reset'),
      'network_error',
    );
    expect(downloadErrorCodeFor('SSL protocol error'), 'protocol_error');
    // aria2 errorCode=22 是 HTTP 响应异常；带具体状态时优先返回状态码。
    expect(
      downloadErrorCodeFor(
        'errorCode=22 The response status is not successful. status=514',
        aria2ErrorCode: '22',
      ),
      'http_error',
    );
    // 所有 CDN 都不可用时 aria2 会返回 No URI available，需要触发重新解析。
    expect(downloadErrorCodeFor('No URI available.'), 'no_uri');
    expect(downloadErrorCodeFor('unknown failure'), isNull);
  });

  /// 验证分流 ID 不包含标题或路径等外部输入。
  test('分流 ID 使用任务 ID 和流类型', () {
    // ID 格式必须与已持久化的引擎任务标识保持兼容。
    expect(
      downloadStreamId('task-1', DownloadStreamKind.video),
      'task-1.video',
    );
  });

  /// 验证旧启动流程进入协调器时不会覆盖用户已经做出的暂停决定。
  test('暂停任务不会被迟到的启动计划提交到底层引擎', () async {
    // 内存数据库提供真实状态机和 Drift 事务语义。
    final database = AppDatabase(NativeDatabase.memory());
    final repository = DownloadTaskRepository(database);
    final engine = _FakeDownloadEngine();
    final coordinator = _createCoordinator(
      engine: engine,
      repository: repository,
    );
    addTearDown(() async {
      await coordinator.dispose();
      await database.close();
    });
    // 任务已经由用户暂停，模拟启动服务长异步步骤结束后的迟到提交。
    await repository.createTask(
      const DownloadTaskDraft(
        taskId: 'paused-before-submit',
        sourceInput: 'BV-paused',
        title: '已暂停任务',
        phase: DownloadTaskPhase.paused,
        outputPath: 'D:/downloads/paused.mp4',
        temporaryDirectory: 'D:/temp/paused',
      ),
    );

    await coordinator.startResolvedTask(
      _singleVideoPlan('paused-before-submit'),
    );

    // 协调器入口必须幂等退出，不创建分流、不提交底层下载。
    expect(engine.enqueuedTaskIds, isEmpty);
    expect(await repository.loadStreams('paused-before-submit'), isEmpty);
    expect(
      (await repository.findTask('paused-before-submit'))?.phase,
      DownloadTaskPhase.paused,
    );
  });

  /// 验证提交分流过程中用户暂停时，后续分流不会继续保持下载。
  test('提交过程中进入暂停会立即补暂停全部已提交分流', () async {
    // 两条分流模拟真实音视频任务，第一条提交后立刻发生用户暂停。
    final database = AppDatabase(NativeDatabase.memory());
    final repository = DownloadTaskRepository(database);
    late final DownloadTaskCoordinator coordinator;
    final engine = _FakeDownloadEngine(
      onEnqueue: (DownloadRequest request) async {
        if (request.taskId.endsWith('.video')) {
          // 用户操作可能与底层提交交错，这里直接写主任务暂停来模拟竞态结果。
          await repository.transitionTask(
            'pause-during-submit',
            DownloadTaskPhase.paused,
          );
        }
      },
    );
    coordinator = _createCoordinator(engine: engine, repository: repository);
    addTearDown(() async {
      await coordinator.dispose();
      await database.close();
    });
    await repository.createTask(
      const DownloadTaskDraft(
        taskId: 'pause-during-submit',
        sourceInput: 'BV-race',
        title: '提交中暂停',
        phase: DownloadTaskPhase.waitingToStart,
        outputPath: 'D:/downloads/race.mp4',
        temporaryDirectory: 'D:/temp/race',
      ),
    );

    await coordinator.startResolvedTask(_audioVideoPlan('pause-during-submit'));

    // 两条分流都会被提交，但发现主任务暂停后必须马上补发底层暂停。
    expect(engine.enqueuedTaskIds, <String>[
      'pause-during-submit.video',
      'pause-during-submit.audio',
    ]);
    expect(engine.pausedTaskIds, <String>[
      'pause-during-submit.video',
      'pause-during-submit.audio',
    ]);
    expect(
      (await repository.findTask('pause-during-submit'))?.phase,
      DownloadTaskPhase.paused,
    );
    expect(
      (await repository.loadStreams(
        'pause-during-submit',
      )).map((DownloadStreamRecord stream) => stream.phase),
      everyElement(DownloadStreamPhase.paused),
    );
  });

  /// 验证解析期暂停留下的保护会在继续时清理，不影响下一轮启动。
  test('解析期暂停后继续不会让新提交分流再次被保护暂停', () async {
    // pending 分流拥有稳定引擎 ID，但尚未真正提交到底层下载引擎。
    final database = AppDatabase(NativeDatabase.memory());
    final repository = DownloadTaskRepository(database);
    final engine = _FakeDownloadEngine();
    final coordinator = _createCoordinator(
      engine: engine,
      repository: repository,
    );
    addTearDown(() async {
      await coordinator.dispose();
      await database.close();
    });
    await repository.createTask(
      const DownloadTaskDraft(
        taskId: 'resume-after-pending-pause',
        sourceInput: 'BV-resume',
        title: '解析期暂停后继续',
        phase: DownloadTaskPhase.resolving,
        outputPath: 'D:/downloads/resume.mp4',
        temporaryDirectory: 'D:/temp/resume',
      ),
    );
    await repository.upsertStream(
      const DownloadStreamDraft(
        streamId: 'resume-after-pending-pause.video',
        taskId: 'resume-after-pending-pause',
        kind: DownloadStreamKind.video,
        remoteUrl: 'https://example.invalid/old-video.m4s',
        temporaryPath: 'D:/temp/resume/video.m4s',
        engineTaskId: 'resume-after-pending-pause.video',
      ),
    );

    await coordinator.pauseTask('resume-after-pending-pause');
    await coordinator.resumeTask('resume-after-pending-pause');
    await coordinator.startResolvedTask(
      _singleVideoPlan('resume-after-pending-pause'),
    );

    // 如果继续时没有清掉保护集合，这里会在 enqueue 后又被错误 pause。
    expect(engine.enqueuedTaskIds, <String>[
      'resume-after-pending-pause.video',
    ]);
    expect(engine.pausedTaskIds, isEmpty);
    expect(
      (await repository.findTask('resume-after-pending-pause'))?.phase,
      DownloadTaskPhase.downloading,
    );
  });
}

DownloadTaskCoordinator _createCoordinator({
  required DownloadEngine engine,
  required DownloadTaskRepository repository,
}) {
  // 附加资源处理器在这些测试中不会被触发，仍使用真实构造以覆盖协调器依赖装配。
  final networkClient = BiliNetworkClient();
  final parser = BilibiliParserService(
    networkClient,
    BiliInputNormalizer(networkClient),
    WbiSigner(networkClient),
  );
  final merger = _FakeMediaMerger();
  final publisher = _FakeMediaOutputPublisher();
  final cleanup = DownloadCompletionCleanupService(repository, publisher);
  return DownloadTaskCoordinator(
    engine,
    merger,
    publisher,
    repository,
    EmbeddedExtraResourceProcessor(parser, merger, publisher, repository),
    autoMergeCompletedStreams: false,
    expiredMediaUrlResolver: _FakeExpiredMediaUrlResolver(),
    completionCleanup: cleanup,
    standaloneExtraResourceFinalizer: StandaloneExtraResourceFinalizer(
      repository,
      publisher,
      cleanup,
    ),
  );
}

ResolvedDownloadPlan _singleVideoPlan(String taskId) {
  // 单视频流计划足够覆盖下载引擎提交和暂停保护逻辑。
  return ResolvedDownloadPlan(
    taskId: taskId,
    video: ResolvedMediaSource(
      kind: DownloadStreamKind.video,
      url: Uri.parse('https://example.invalid/$taskId/video.m4s'),
      temporaryPath: 'D:/temp/$taskId/video.m4s',
    ),
  );
}

ResolvedDownloadPlan _audioVideoPlan(String taskId) {
  // 音视频双流计划用于验证一条暂停后另一条不会漏掉。
  return ResolvedDownloadPlan(
    taskId: taskId,
    video: ResolvedMediaSource(
      kind: DownloadStreamKind.video,
      url: Uri.parse('https://example.invalid/$taskId/video.m4s'),
      temporaryPath: 'D:/temp/$taskId/video.m4s',
    ),
    audio: ResolvedMediaSource(
      kind: DownloadStreamKind.audio,
      url: Uri.parse('https://example.invalid/$taskId/audio.m4s'),
      temporaryPath: 'D:/temp/$taskId/audio.m4s',
    ),
  );
}

final class _FakeDownloadEngine implements DownloadEngine {
  _FakeDownloadEngine({this.onEnqueue});

  /// enqueue 期间的测试钩子，用于制造暂停与提交交错。
  final Future<void> Function(DownloadRequest request)? onEnqueue;

  /// 已提交到底层引擎的任务 ID。
  final List<String> enqueuedTaskIds = <String>[];

  /// 已请求暂停的任务 ID。
  final List<String> pausedTaskIds = <String>[];

  /// 模拟下载状态回调，覆盖主动控制命令和失败后的自动恢复。
  final StreamController<DownloadEvent> _events =
      StreamController<DownloadEvent>.broadcast();

  @override
  Stream<DownloadEvent> watchEvents() => _events.stream;

  @override
  Future<void> enqueue(DownloadRequest request) async {
    // 先记录提交，再执行钩子，模拟真实后端已接受任务后用户操作交错。
    enqueuedTaskIds.add(request.taskId);
    await onEnqueue?.call(request);
  }

  @override
  Future<void> pause(String taskId) async {
    // 保留调用顺序，双流暂停测试需要验证视频和音频都覆盖。
    pausedTaskIds.add(taskId);
  }

  @override
  Future<void> resume(String taskId) async {}

  @override
  Future<void> cancel(String taskId) async {}

  @override
  Future<void> restore() async {}

  @override
  Future<void> dispose() => _events.close();
}

final class _FakeMediaMerger implements MediaMerger {
  final StreamController<MediaMergeProgress> _progress =
      StreamController<MediaMergeProgress>.broadcast();

  @override
  Stream<MediaMergeProgress> watchProgress() => _progress.stream;

  @override
  Future<void> merge(MediaMergeRequest request) async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() => _progress.close();
}

final class _FakeMediaOutputPublisher implements MediaOutputPublisher {
  @override
  Future<String> prepareOutputPath({
    required String requestedOutputPath,
    required String? temporaryDirectory,
  }) async {
    return requestedOutputPath;
  }

  @override
  Future<PublishedMediaOutput> publish({
    required String workingOutputPath,
    required String requestedOutputPath,
  }) async {
    return PublishedMediaOutput(storageIdentifier: workingOutputPath);
  }

  @override
  Future<MediaOutputInspection> inspect(
    String storageIdentifier, {
    required String requestedOutputPath,
  }) async {
    return const MediaOutputInspection(
      exists: true,
      sizeBytes: 1,
      basicIntegrityValid: true,
    );
  }

  @override
  Future<void> delete(String storageIdentifier) async {}

  @override
  Future<void> deleteAll(Iterable<String> storageIdentifiers) async {}
}

final class _FakeExpiredMediaUrlResolver implements ExpiredMediaUrlResolver {
  @override
  Future<ResolvedMediaSource> refresh({
    required String taskId,
    required DownloadStreamKind kind,
  }) async {
    return ResolvedMediaSource(
      kind: kind,
      url: Uri.parse('https://example.invalid/$taskId/refreshed.m4s'),
      // 提供两个独立 CDN，验证失败恢复确实依次切换到备用线路。
      backupUrls: <Uri>[
        Uri.parse('https://backup-1.example.invalid/$taskId/refreshed.m4s'),
        Uri.parse('https://backup-2.example.invalid/$taskId/refreshed.m4s'),
      ],
      temporaryPath: 'D:/temp/$taskId/refreshed.m4s',
    );
  }
}
