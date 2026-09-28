import 'package:bilibili_down/core/database/app_database.dart';
import 'package:bilibili_down/features/downloads/data/download_task_draft.dart';
import 'package:bilibili_down/features/downloads/data/download_task_repository.dart';
import 'package:bilibili_down/features/downloads/domain/download_task_phase.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 验证视频和附加资源批量写入失败时不会留下半批任务。
  test('批量创建任务任一失败时回滚整批', () async {
    // 内存数据库提供与正式 Drift 相同的主键和事务语义。
    final database = AppDatabase(NativeDatabase.memory());
    // 仓库批量接口负责把同一视频的全部草稿放入单一事务。
    final repository = DownloadTaskRepository(database);
    addTearDown(database.close);

    // 两个草稿故意使用相同主键，使第二条插入触发唯一约束失败。
    final drafts = <DownloadTaskDraft>[
      const DownloadTaskDraft(
        taskId: 'duplicate-task',
        sourceInput: 'BV1nfj86AEAo',
        title: '视频任务',
      ),
      const DownloadTaskDraft(
        taskId: 'duplicate-task',
        sourceInput: 'BV1nfj86AEAo',
        title: '封面任务',
      ),
    ];
    // 批次必须向调用方暴露数据库失败，不能吞掉后伪报成功。
    await expectLater(
      repository.createTasks(drafts),
      throwsA(isA<Exception>()),
    );
    // 第一条插入也应随事务回滚，数据库不能残留半批数据。
    expect(await repository.findTask('duplicate-task'), isNull);
  });

  /// 验证任务恢复时重复登记同一个临时文件会更新原记录，而不是触发唯一键错误。
  test('按任务类型和路径更新已有产物', () async {
    // 内存数据库隔离测试数据，并启用与正式应用相同的表结构和唯一约束。
    final database = AppDatabase(NativeDatabase.memory());
    // 仓库负责把领域草稿转换为 Drift 写入操作。
    final repository = DownloadTaskRepository(database);
    addTearDown(database.close);

    // 产物外键要求主任务先存在，测试只填写最低必要字段。
    await repository.createTask(
      const DownloadTaskDraft(
        taskId: 'task-1',
        sourceInput: 'BV1nfj86AEAo',
        title: '测试视频',
      ),
    );
    // 首次解析登记尚未完成的视频临时流。
    await repository.upsertArtifact(
      const DownloadArtifactDraft(
        taskId: 'task-1',
        kind: DownloadArtifactKind.videoStream,
        path: '/tmp/video.m4s',
      ),
    );
    // 恢复流程用同一复合唯一键写入最新文件信息。
    await repository.upsertArtifact(
      const DownloadArtifactDraft(
        taskId: 'task-1',
        kind: DownloadArtifactKind.videoStream,
        path: '/tmp/video.m4s',
        sizeBytes: 1024,
        checksum: 'updated',
      ),
    );

    // 数据库只能保留一行，并包含第二次写入的可变字段。
    final artifacts = await database.select(database.downloadArtifacts).get();
    expect(artifacts, hasLength(1));
    expect(artifacts.single.sizeBytes, 1024);
    expect(artifacts.single.checksum, 'updated');
  });

  /// 验证覆盖完成后的清理只删除同路径终态历史，绝不影响活动任务。
  test('覆盖成品后只清理同路径旧终态任务', () async {
    // 内存数据库用于验证删除条件和外键级联的真实 Drift 行为。
    final database = AppDatabase(NativeDatabase.memory());
    // 仓库是协调器完成覆盖后执行历史清理的唯一入口。
    final repository = DownloadTaskRepository(database);
    addTearDown(database.close);
    const outputPath = '/downloads/same-name.mp4';

    // 新成品、旧完成记录和仍在等待的活动任务故意共享同一输出路径。
    for (final draft in const <DownloadTaskDraft>[
      DownloadTaskDraft(
        taskId: 'new-completed',
        sourceInput: 'BV-new',
        title: '新成品',
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
        phase: DownloadTaskPhase.waitingToStart,
      ),
    ]) {
      await repository.createTask(draft);
    }

    // 指定新成品为保留记录，清理结果应只包含旧终态任务。
    final deleted = await repository.deleteSupersededTasksForOutputPath(
      outputPath,
      keepingTaskId: 'new-completed',
    );
    expect(deleted, 1);
    expect(await repository.findTask('old-completed'), isNull);
    expect(await repository.findTask('new-completed'), isNotNull);
    expect(await repository.findTask('active-task'), isNotNull);
  });

  /// 验证轻量查询按阶段筛选、聚合和恢复枚举，不改变原任务排序与语义。
  test('按用途监听任务阶段避免加载无关完整记录', () async {
    // 内存数据库执行与正式 SQLite 相同的 selectOnly 和 textEnum 存储逻辑。
    final database = AppDatabase(NativeDatabase.memory());
    // 仓库暴露本轮需要验证的三类轻量监听接口。
    final repository = DownloadTaskRepository(database);
    addTearDown(database.close);

    // 三个任务覆盖待下载、活动和完成页签，标题用于确认完整记录仍可读取。
    for (final draft in const <DownloadTaskDraft>[
      DownloadTaskDraft(
        taskId: 'queued-task',
        sourceInput: 'BV-queued',
        title: '待下载任务',
      ),
      DownloadTaskDraft(
        taskId: 'active-task',
        sourceInput: 'BV-active',
        title: '活动任务',
        phase: DownloadTaskPhase.downloading,
      ),
      DownloadTaskDraft(
        taskId: 'completed-task',
        sourceInput: 'BV-completed',
        title: '完成任务',
        phase: DownloadTaskPhase.completed,
      ),
    ]) {
      await repository.createTask(draft);
    }

    // 页签查询只返回命中阶段的完整记录，其他历史阶段不会进入内存列表。
    final pendingTasks = await repository.watchTasksByPhases(
      const <DownloadTaskPhase>[
        DownloadTaskPhase.queued,
        DownloadTaskPhase.failed,
      ],
    ).first;
    expect(pendingTasks.map((task) => task.taskId), <String>['queued-task']);

    // 聚合查询必须把数据库原始阶段字符串恢复成领域枚举并给出准确数量。
    final counts = await repository.watchTaskPhaseCounts().first;
    expect(counts[DownloadTaskPhase.queued], 1);
    expect(counts[DownloadTaskPhase.downloading], 1);
    expect(counts[DownloadTaskPhase.completed], 1);

    // 历史页上限由 SQL LIMIT 执行，只物化请求数量且不影响聚合总数。
    final limitedTasks =
        await repository.watchTasksByPhases(const <DownloadTaskPhase>[
          DownloadTaskPhase.queued,
          DownloadTaskPhase.downloading,
          DownloadTaskPhase.completed,
        ], limit: 2).first;
    expect(limitedTasks, hasLength(2));

    // 声音观察快照只保留身份与阶段，但仍完整覆盖现有任务基线。
    final snapshots = await repository.watchTaskPhaseSnapshots().first;
    expect(snapshots, hasLength(3));
    expect(
      snapshots
          .firstWhere((snapshot) => snapshot.taskId == 'active-task')
          .phase,
      DownloadTaskPhase.downloading,
    );
  });

  /// 验证待下载页签按任务加入顺序从早到晚展示。
  test('待下载任务按加入时间正序查询', () async {
    // queued 与 failed 同属待下载页签，排序必须跨阶段保持真实加入先后。
    final database = AppDatabase(NativeDatabase.memory());
    final repository = DownloadTaskRepository(database);
    addTearDown(database.close);
    await repository.createTask(
      const DownloadTaskDraft(
        taskId: 'pending-earlier',
        sourceInput: 'BV-pending-earlier',
        title: '先加入任务',
        phase: DownloadTaskPhase.queued,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await repository.createTask(
      const DownloadTaskDraft(
        taskId: 'pending-later',
        sourceInput: 'BV-pending-later',
        title: '后加入任务',
        phase: DownloadTaskPhase.failed,
      ),
    );

    final tasks = await repository.watchTasksByPhases(const <DownloadTaskPhase>[
      DownloadTaskPhase.queued,
      DownloadTaskPhase.failed,
    ], sortOrder: DownloadTaskSortOrder.oldestCreated).first;

    expect(tasks.map((DownloadTaskRecord task) => task.taskId), <String>[
      'pending-earlier',
      'pending-later',
    ]);
  });

  /// 验证下载中页签能够按任务创建时间从早到晚展示。
  test('活动任务按创建时间正序查询', () async {
    // 内存数据库保留真实 Drift 排序语义，两个任务使用短延迟形成明确时间先后。
    final database = AppDatabase(NativeDatabase.memory());
    final repository = DownloadTaskRepository(database);
    addTearDown(database.close);
    await repository.createTask(
      const DownloadTaskDraft(
        taskId: 'earlier-task',
        sourceInput: 'BV-earlier',
        title: '较早任务',
        phase: DownloadTaskPhase.downloading,
      ),
    );
    // 延迟只用于避免测试平台时钟精度把两次创建压到同一时间点。
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await repository.createTask(
      const DownloadTaskDraft(
        taskId: 'later-task',
        sourceInput: 'BV-later',
        title: '较晚任务',
        phase: DownloadTaskPhase.waitingToStart,
      ),
    );

    final tasks = await repository.watchTasksByPhases(const <DownloadTaskPhase>[
      DownloadTaskPhase.waitingToStart,
      DownloadTaskPhase.downloading,
    ], sortOrder: DownloadTaskSortOrder.oldestCreated).first;

    expect(tasks.map((DownloadTaskRecord task) => task.taskId), <String>[
      'earlier-task',
      'later-task',
    ]);
  });

  /// 验证已下载页签使用实际处理完成时间，而不是最初加入时间。
  test('完成任务按完成时间倒序查询', () async {
    // 先加入的任务故意最后完成，用于证明排序字段不是 createdAt。
    final database = AppDatabase(NativeDatabase.memory());
    final repository = DownloadTaskRepository(database);
    addTearDown(database.close);
    await repository.createTask(
      const DownloadTaskDraft(
        taskId: 'created-earlier',
        sourceInput: 'BV-created-earlier',
        title: '先加入后完成',
        phase: DownloadTaskPhase.merging,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await repository.createTask(
      const DownloadTaskDraft(
        taskId: 'created-later',
        sourceInput: 'BV-created-later',
        title: '后加入先完成',
        phase: DownloadTaskPhase.merging,
      ),
    );
    // 后加入任务先完成，随后延迟完成早期任务以形成相反的完成顺序。
    await repository.transitionTask(
      'created-later',
      DownloadTaskPhase.completed,
    );
    await repository.transitionTask(
      'created-earlier',
      DownloadTaskPhase.completed,
    );
    // 使用固定且不同的完成时间隔离 SQLite 时间精度，直接验证查询字段和方向。
    await (database.update(
      database.downloadTasks,
    )..where((table) => table.taskId.equals('created-later'))).write(
      DownloadTasksCompanion(
        completedAt: Value<DateTime?>(DateTime.utc(2026, 1, 1, 12)),
      ),
    );
    await (database.update(
      database.downloadTasks,
    )..where((table) => table.taskId.equals('created-earlier'))).write(
      DownloadTasksCompanion(
        completedAt: Value<DateTime?>(DateTime.utc(2026, 1, 1, 13)),
      ),
    );

    final tasks = await repository.watchTasksByPhases(const <DownloadTaskPhase>[
      DownloadTaskPhase.completed,
    ], sortOrder: DownloadTaskSortOrder.newestCompleted).first;

    expect(tasks.map((DownloadTaskRecord task) => task.taskId), <String>[
      'created-earlier',
      'created-later',
    ]);
  });

  /// 验证新进程启动时只暂停活动任务，并完整保留手动继续所需的阶段与分流断点。
  test('启动恢复把活动任务和分流统一降级为暂停', () async {
    // 内存数据库验证主任务与分流状态在同一事务内完成转换。
    final database = AppDatabase(NativeDatabase.memory());
    // 仓库提供与正式启动流程相同的原子暂停入口。
    final repository = DownloadTaskRepository(database);
    addTearDown(database.close);
    // 活动任务模拟应用闪退时仍在传输的下载记录。
    await repository.createTask(
      const DownloadTaskDraft(
        taskId: 'interrupted-task',
        sourceInput: 'BV-interrupted',
        title: '异常中断任务',
        phase: DownloadTaskPhase.downloading,
      ),
    );
    // 待下载任务不属于正在执行队列，启动恢复不得改变它。
    await repository.createTask(
      const DownloadTaskDraft(
        taskId: 'queued-task',
        sourceInput: 'BV-queued',
        title: '待下载任务',
      ),
    );
    // 下载中分流保存稳定引擎 ID 和临时路径，暂停后仍可按断点继续。
    await repository.upsertStream(
      const DownloadStreamDraft(
        streamId: 'interrupted-task-video',
        taskId: 'interrupted-task',
        kind: DownloadStreamKind.video,
        remoteUrl: 'https://example.invalid/video.m4s',
        temporaryPath: 'temporary/video.m4s',
        engineTaskId: 'interrupted-task-video',
        phase: DownloadStreamPhase.downloading,
      ),
    );

    // 启动恢复应只处理一条活动任务，不自动启动或删除任何记录。
    expect(await repository.pauseInterruptedTasks(), 1);
    // 主任务进入暂停并保存 downloading，用户点击继续时可恢复原流程。
    final interruptedTask = await repository.findTask('interrupted-task');
    expect(interruptedTask?.phase, DownloadTaskPhase.paused);
    expect(interruptedTask?.resumePhase, DownloadTaskPhase.downloading);
    // 分流同步进入暂停且保留引擎 ID，底层可继续使用已有断点。
    final streams = await repository.loadStreams('interrupted-task');
    expect(streams.single.phase, DownloadStreamPhase.paused);
    expect(streams.single.engineTaskId, 'interrupted-task-video');
    // queued 任务仍留在待下载页，不因启动安全恢复被错误迁移。
    expect(
      (await repository.findTask('queued-task'))?.phase,
      DownloadTaskPhase.queued,
    );
  });

  /// 验证启动流程的条件阶段写入不会覆盖用户暂停决定。
  test('条件阶段切换不会把暂停任务写回下载中', () async {
    // 内存数据库保留真实事务语义，用于模拟启动 Future 与暂停操作交叉。
    final database = AppDatabase(NativeDatabase.memory());
    // 仓库条件切换是协调器防止旧启动流程覆盖用户决定的核心门闩。
    final repository = DownloadTaskRepository(database);
    addTearDown(database.close);

    // 任务先进入解析阶段，代表调度器已经认领并开始准备下载地址。
    await repository.createTask(
      const DownloadTaskDraft(
        taskId: 'race-task',
        sourceInput: 'BV-race',
        title: '并发暂停任务',
        phase: DownloadTaskPhase.resolving,
      ),
    );
    // 用户在解析 Future 未结束时点击暂停，数据库保存恢复目标。
    await repository.transitionTask('race-task', DownloadTaskPhase.paused);

    // 旧启动 Future 迟到后尝试从 resolving 写回 downloading，必须被条件挡住。
    final changed = await repository.transitionTaskIfPhase(
      'race-task',
      expected: DownloadTaskPhase.resolving,
      next: DownloadTaskPhase.downloading,
    );

    // 返回 false 表示没有写库，暂停阶段和恢复目标都不能被破坏。
    expect(changed, isFalse);
    final task = await repository.findTask('race-task');
    expect(task?.phase, DownloadTaskPhase.paused);
    expect(task?.resumePhase, DownloadTaskPhase.resolving);
  });

  /// 验证断点继续时后端短暂回报零进度不会覆盖已有分流字节。
  test('断点继续的零进度事件不会让任务进度回退', () async {
    // 内存数据库让仓库进度重算与正式 SQLite 使用同一事务路径。
    final database = AppDatabase(NativeDatabase.memory());
    // 仓库是下载事件落库和主任务百分比重算的统一入口。
    final repository = DownloadTaskRepository(database);
    addTearDown(database.close);

    // 创建一条下载中任务和对应视频分流，模拟暂停前已经存在的断点记录。
    await repository.createTask(
      const DownloadTaskDraft(
        taskId: 'resume-task',
        sourceInput: 'BV-resume',
        title: '断点任务',
        phase: DownloadTaskPhase.downloading,
      ),
    );
    await repository.upsertStream(
      const DownloadStreamDraft(
        streamId: 'resume-task-video',
        taskId: 'resume-task',
        kind: DownloadStreamKind.video,
        remoteUrl: 'https://example.invalid/video.m4s',
        temporaryPath: 'temporary/video.m4s',
        engineTaskId: 'resume-engine-video',
        phase: DownloadStreamPhase.downloading,
      ),
    );

    // 首次正常进度事件写入 500/1000，主任务应展示 50%。
    await repository.updateStreamProgress(
      engineTaskId: 'resume-engine-video',
      phase: DownloadStreamPhase.downloading,
      downloadedBytes: 500,
      totalBytes: 1000,
    );
    expect(
      (await repository.loadStreams('resume-task')).single.downloadedBytes,
      500,
    );
    expect((await repository.findTask('resume-task'))?.progress, 0.5);

    // 用户点击继续后，下载后端可能先发一条 0/0 的排队快照。
    await repository.updateStreamProgress(
      engineTaskId: 'resume-engine-video',
      phase: DownloadStreamPhase.queued,
      downloadedBytes: 0,
      totalBytes: 0,
    );

    // 仓库必须保留已有断点和总量，避免 UI 的 MB 文案和进度条短暂跳回 0。
    final resumedStream = (await repository.loadStreams('resume-task')).single;
    expect(resumedStream.phase, DownloadStreamPhase.queued);
    expect(resumedStream.downloadedBytes, 500);
    expect(resumedStream.totalBytes, 1000);
    expect((await repository.findTask('resume-task'))?.progress, 0.5);

    // 后续真实进度到达时仍应正常前进，不会被防回退逻辑卡住。
    await repository.updateStreamProgress(
      engineTaskId: 'resume-engine-video',
      phase: DownloadStreamPhase.downloading,
      downloadedBytes: 700,
      totalBytes: 1000,
    );
    expect(
      (await repository.loadStreams('resume-task')).single.downloadedBytes,
      700,
    );
    expect((await repository.findTask('resume-task'))?.progress, 0.7);
  });

  /// 验证全局启动失败和删除兜底需要的状态回退都只影响安全阶段。
  test('等待队列可回退且失败任务可强制进入删除终态', () async {
    // 内存数据库验证新增兜底入口的真实事务和外键行为。
    final database = AppDatabase(NativeDatabase.memory());
    final repository = DownloadTaskRepository(database);
    addTearDown(database.close);

    for (final draft in const <DownloadTaskDraft>[
      DownloadTaskDraft(
        taskId: 'failed-current',
        sourceInput: 'BV-current',
        title: '当前失败任务',
        phase: DownloadTaskPhase.failed,
      ),
      DownloadTaskDraft(
        taskId: 'waiting-back',
        sourceInput: 'BV-waiting',
        title: '等待回退任务',
        phase: DownloadTaskPhase.waitingToStart,
      ),
      DownloadTaskDraft(
        taskId: 'downloading-keep',
        sourceInput: 'BV-downloading',
        title: '下载中任务',
        phase: DownloadTaskPhase.downloading,
      ),
    ]) {
      await repository.createTask(draft);
    }
    await repository.upsertStream(
      const DownloadStreamDraft(
        streamId: 'failed-current-video',
        taskId: 'failed-current',
        kind: DownloadStreamKind.video,
        remoteUrl: 'https://example.invalid/video.m4s',
        temporaryPath: 'temporary/video.m4s',
        engineTaskId: 'lost-gid',
        phase: DownloadStreamPhase.downloading,
      ),
    );

    // 只回退仍在 waitingToStart 的任务，当前失败项和下载中项都不被误改。
    expect(
      await repository.requeueWaitingToStartTasks(
        exceptTaskId: 'failed-current',
      ),
      1,
    );
    expect(
      (await repository.findTask('waiting-back'))?.phase,
      DownloadTaskPhase.queued,
    );
    expect(
      (await repository.findTask('downloading-keep'))?.phase,
      DownloadTaskPhase.downloading,
    );

    // 删除兜底把失败任务转成 canceled，并同步取消未完成分流，记录随后可删除。
    await repository.markTaskCanceledForRemoval('failed-current');
    expect(
      (await repository.findTask('failed-current'))?.phase,
      DownloadTaskPhase.canceled,
    );
    expect(
      (await repository.loadStreams('failed-current')).single.phase,
      DownloadStreamPhase.canceled,
    );
    await repository.deleteRemovableTask('failed-current');
    expect(await repository.findTask('failed-current'), isNull);
  });
}
