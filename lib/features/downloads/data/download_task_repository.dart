import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/download_artifacts.dart';
import '../../../core/database/tables/download_streams.dart';
import '../../../core/database/tables/download_tasks.dart';
import '../domain/download_extra_resource.dart';
import '../domain/download_task_phase.dart';
import 'download_task_draft.dart';

/// 声音与通知观察器只需要的任务身份和阶段，不携带封面、简介或 DASH 清单。
typedef DownloadTaskPhaseSnapshot = ({String taskId, DownloadTaskPhase phase});

/// 待下载任务 DASH 候选和当前音画质选择的一次性修正结果。
typedef DownloadTaskDashSelectionUpdate = ({
  String taskId,
  String dashOptionsJson,
  int? qualityId,
  String? qualityLabel,
  String? videoCodec,
  String? audioCodec,
  int? audioQualityId,
  int? estimatedVideoSizeBytes,
  int? estimatedAudioSizeBytes,
  int? durationMilliseconds,
});

/// 任务列表查询使用的稳定排序语义。
enum DownloadTaskSortOrder {
  /// 按加入时间倒序，最新加入的任务优先。
  newestCreated,

  /// 按加入时间正序，最早加入的任务优先。
  oldestCreated,

  /// 按处理完成时间倒序，最近完成的任务优先。
  newestCompleted,
}

/// 封装下载任务、媒体分流和文件产物的持久化操作。
final class DownloadTaskRepository {
  /// 使用应用数据库创建任务仓库。
  const DownloadTaskRepository(this._database);

  /// 提供类型安全表访问和事务能力的应用数据库。
  final AppDatabase _database;

  /// 创建一条新的业务下载任务。
  Future<void> createTask(DownloadTaskDraft draft) async {
    // 任务 ID、输入和标题是恢复流程的最低必要信息，禁止写入空值。
    if (draft.taskId.isEmpty ||
        draft.sourceInput.isEmpty ||
        draft.title.isEmpty) {
      throw ArgumentError('Task id, source input and title must not be empty.');
    }
    // 新建任务只能保存文件系统真实路径，避免 Android 旧 URI 混入下载、重试和合并链路。
    _validateOptionalFileSystemPath(
      draft.temporaryDirectory,
      'temporaryDirectory',
    );
    _validateOptionalFileSystemPath(draft.outputPath, 'outputPath');
    // 记录统一时间，避免同次写入的创建与更新时间产生细微差异。
    final now = DateTime.now();
    // 将领域草稿转换为 Drift Companion 并插入主表。
    await _database
        .into(_database.downloadTasks)
        .insert(
          DownloadTasksCompanion.insert(
            taskId: draft.taskId,
            sourceInput: draft.sourceInput,
            title: draft.title,
            publisherName: Value<String?>(draft.publisherName),
            publisherId: Value<int?>(draft.publisherId),
            collectionTitle: Value<String?>(draft.collectionTitle),
            contentType: Value<String?>(draft.contentType),
            description: Value<String?>(draft.description),
            resolutionLabel: Value<String?>(draft.resolutionLabel),
            publishedAt: Value<DateTime?>(draft.publishedAt),
            bvid: Value<String?>(draft.bvid),
            cid: Value<int?>(draft.cid),
            epid: Value<int?>(draft.epid),
            coverUrl: Value<String?>(draft.coverUrl),
            partIndex: Value<int>(draft.partIndex),
            qualityId: Value<int?>(draft.qualityId),
            qualityLabel: Value<String?>(draft.qualityLabel),
            videoCodec: Value<String?>(draft.videoCodec),
            audioCodec: Value<String?>(draft.audioCodec),
            audioQualityId: Value<int?>(draft.audioQualityId),
            estimatedVideoSizeBytes: Value<int?>(draft.estimatedVideoSizeBytes),
            estimatedAudioSizeBytes: Value<int?>(draft.estimatedAudioSizeBytes),
            dashOptionsJson: Value<String?>(draft.dashOptionsJson),
            extraResourcesJson: Value<String>(draft.extraResourcesJson),
            durationMilliseconds: Value<int?>(draft.durationMilliseconds),
            temporaryDirectory: Value<String?>(draft.temporaryDirectory),
            outputPath: Value<String?>(draft.outputPath),
            downloadBackend: Value<PersistedDownloadBackend?>(
              draft.downloadBackend,
            ),
            phase: Value<DownloadTaskPhase>(draft.phase),
            createdAt: Value<DateTime>(now),
            updatedAt: Value<DateTime>(now),
          ),
        );
  }

  /// 在一个 Drift 事务中批量创建多条业务下载任务。
  Future<void> createTasks(Iterable<DownloadTaskDraft> drafts) async {
    // 固化调用方集合，避免事务执行期间延迟迭代读到变化后的内容。
    final taskDrafts = List<DownloadTaskDraft>.of(drafts, growable: false);
    // 空批次不打开事务，也不产生数据库写入。
    if (taskDrafts.isEmpty) return;
    // 同一视频及其附加资源必须全部成功，否则整批回滚。
    await _database.transaction(() async {
      for (final draft in taskDrafts) {
        // 复用单任务校验和插入逻辑，事务 Zone 会绑定同一连接。
        await createTask(draft);
      }
    });
  }

  /// 根据业务任务 ID 查询主任务。
  Future<DownloadTaskRecord?> findTask(String taskId) {
    // 主键查询最多返回一行，不存在时返回空。
    return (_database.select(_database.downloadTasks)
          ..where((DownloadTasks table) => table.taskId.equals(taskId)))
        .getSingleOrNull();
  }

  /// 监听单条主任务，供详情页在记录删除或状态变化时实时刷新。
  Stream<DownloadTaskRecord?> watchTask(String taskId) {
    // 主键监听最多返回一条记录；删除后发出 null，页面据此返回上一层。
    return (_database.select(_database.downloadTasks)
          ..where((DownloadTasks table) => table.taskId.equals(taskId)))
        .watchSingleOrNull();
  }

  /// 删除一条尚未启动的待下载任务。
  Future<void> deleteQueuedTask(String taskId) async {
    // 查询和删除放在同一事务，避免任务启动后仍被页面误删。
    await _database.transaction(() async {
      // 读取任务当前阶段作为删除保护条件。
      final task = await findTask(taskId);
      // 已被其他操作删除时直接结束，保持删除操作幂等。
      if (task == null) return;
      // 仅允许删除未启动任务，活动任务需要走协调器取消流程。
      if (task.phase != DownloadTaskPhase.queued) {
        throw StateError('只能删除尚未启动的待下载任务。');
      }
      // 按主键删除任务，关联的流记录由数据库外键级联清理。
      await (_database.delete(
        _database.downloadTasks,
      )..where((DownloadTasks table) => table.taskId.equals(taskId))).go();
    });
  }

  /// 删除一条已完成或已取消任务的数据库记录。
  Future<void> deleteRemovableTask(String taskId) async {
    // 查询和删除放在同一事务，避免任务阶段变化后误删活动记录。
    await _database.transaction(() async {
      // 读取任务当前阶段作为删除保护条件。
      final task = await findTask(taskId);
      // 已被其他操作删除时直接结束，保持删除操作幂等。
      if (task == null) return;
      // 暂停任务必须先由协调器取消，数据库只接受终态记录删除。
      if (task.phase != DownloadTaskPhase.completed &&
          task.phase != DownloadTaskPhase.canceled) {
        throw StateError('只能删除已经完成或取消的下载记录。');
      }
      // 按主键删除任务记录，关联流记录由数据库外键级联清理。
      await (_database.delete(
        _database.downloadTasks,
      )..where((DownloadTasks table) => table.taskId.equals(taskId))).go();
    });
  }

  /// 清空所有尚未启动的待下载任务。
  Future<int> deleteAllQueuedTasks() {
    // 失败或活动任务可能保留临时文件，因此批量清空只处理 queued 阶段。
    return (_database.delete(_database.downloadTasks)..where(
          (DownloadTasks table) =>
              table.phase.equals(DownloadTaskPhase.queued.name),
        ))
        .go();
  }

  /// 判断指定最终输出路径是否已经被其他任务占用。
  Future<bool> hasTaskForOutputPath(
    String outputPath, {
    String? excludingTaskId,
  }) async {
    // 路径只用于避免两个独立任务写入同一文件，不限制同一视频重复下载。
    final query = _database.select(_database.downloadTasks)
      ..where((DownloadTasks table) {
        // 同步现有待下载任务时排除任务自身，否则保持原路径也会被误判为重名。
        final isDifferentTask = excludingTaskId == null
            ? const Constant<bool>(true)
            : table.taskId.equals(excludingTaskId).not();
        // 已取消记录不再占用输出名称，其余活动和历史任务都必须避让。
        return table.outputPath.equals(outputPath) &
            table.phase.equals(DownloadTaskPhase.canceled.name).not() &
            isDifferentTask;
      })
      // 只需要判断存在性，限制一行减少数据库读取。
      ..limit(1);
    // 找到任意记录表示需要为新任务生成带序号的输出文件名。
    return (await query.getSingleOrNull()) != null;
  }

  /// 查询指定输出路径关联的其他任务，供重名策略区分活动与终态记录。
  Future<List<DownloadTaskRecord>> findTasksForOutputPath(
    String outputPath, {
    String? excludingTaskId,
  }) {
    // 同步现有任务时必须排除自身，否则保持原路径会被错误识别为冲突。
    final query = _database.select(_database.downloadTasks)
      ..where((DownloadTasks table) {
        final isDifferentTask = excludingTaskId == null
            ? const Constant<bool>(true)
            : table.taskId.equals(excludingTaskId).not();
        // canceled 记录也返回，由覆盖策略统一判断并在新成品成功后清理。
        return table.outputPath.equals(outputPath) & isDifferentTask;
      });
    // 调用方只读取阶段，不修改本次查询快照。
    return query.get();
  }

  /// 新成品覆盖成功后删除同路径旧终态记录，避免历史卡片误删新文件。
  Future<int> deleteSupersededTasksForOutputPath(
    String outputPath, {
    required String keepingTaskId,
  }) {
    // 活动、暂停和失败任务仍可能恢复写入，绝不能作为覆盖历史清理。
    return (_database.delete(_database.downloadTasks)..where(
          (DownloadTasks table) =>
              table.outputPath.equals(outputPath) &
              table.taskId.equals(keepingTaskId).not() &
              table.phase.isIn(<String>[
                DownloadTaskPhase.completed.name,
                DownloadTaskPhase.canceled.name,
              ]),
        ))
        .go();
  }

  /// 按下载引擎任务 ID 查询对应的媒体分流。
  Future<DownloadStreamRecord?> findStreamByEngineTaskId(String engineTaskId) {
    // 引擎任务 ID 建有唯一索引，因此查询最多返回一条分流。
    return (_database.select(_database.downloadStreams)..where(
          (DownloadStreams table) => table.engineTaskId.equals(engineTaskId),
        ))
        .getSingleOrNull();
  }

  /// 按创建时间倒序监听全部任务，进度更新不能改变列表位置。
  Stream<List<DownloadTaskRecord>> watchAllTasks() {
    // 下载页需要随数据库变化自动刷新，因此返回 Drift 查询流。
    final query = _database.select(_database.downloadTasks)
      ..orderBy(<OrderClauseGenerator<DownloadTasks>>[
        // 最新创建的任务固定在顶部，下载进度和暂停状态更新不参与排序。
        (DownloadTasks table) => OrderingTerm.desc(table.createdAt),
        // 同一时刻批量创建时使用任务 ID 提供确定性顺序，避免数据库返回顺序漂移。
        (DownloadTasks table) => OrderingTerm.desc(table.taskId),
      ]);
    // 监听查询并让 Drift 在相关表更新后重新发出列表。
    return query.watch();
  }

  /// 按指定阶段监听任务完整记录，页面和调度器无需加载无关历史页签。
  Stream<List<DownloadTaskRecord>> watchTasksByPhases(
    Iterable<DownloadTaskPhase> phases, {
    int? limit,
    DownloadTaskSortOrder sortOrder = DownloadTaskSortOrder.newestCreated,
  }) {
    // 固化枚举名称，避免 Drift 延迟执行时读取到调用方后续修改的集合。
    final phaseNames = phases
        .map((DownloadTaskPhase phase) => phase.name)
        .toList(growable: false);
    // 空筛选不会访问数据库，直接返回稳定空快照。
    if (phaseNames.isEmpty) {
      return Stream<List<DownloadTaskRecord>>.value(
        const <DownloadTaskRecord>[],
      );
    }
    final query = _database.select(_database.downloadTasks)
      ..where((DownloadTasks table) => table.phase.isIn(phaseNames));
    // 页签显式选择加入时间或完成时间，不能用一个倒序规则覆盖全部产品语义。
    final ordering = switch (sortOrder) {
      DownloadTaskSortOrder.newestCreated =>
        <OrderClauseGenerator<DownloadTasks>>[
          (DownloadTasks table) => OrderingTerm.desc(table.createdAt),
          (DownloadTasks table) => OrderingTerm.desc(table.taskId),
        ],
      DownloadTaskSortOrder.oldestCreated =>
        <OrderClauseGenerator<DownloadTasks>>[
          (DownloadTasks table) => OrderingTerm.asc(table.createdAt),
          (DownloadTasks table) => OrderingTerm.asc(table.taskId),
        ],
      DownloadTaskSortOrder.newestCompleted =>
        <OrderClauseGenerator<DownloadTasks>>[
          // completedAt 代表实际处理完成，不受任务最初加入时间影响。
          (DownloadTasks table) => OrderingTerm.desc(table.completedAt),
          // 极短批次完成时间相同时使用加入时间和任务 ID 保持稳定顺序。
          (DownloadTasks table) => OrderingTerm.desc(table.createdAt),
          (DownloadTasks table) => OrderingTerm.desc(table.taskId),
        ],
    };
    query.orderBy(ordering);
    // 已下载历史可以按页面增量扩大上限；活动与待下载不传上限以保留批量操作语义。
    if (limit != null) {
      if (limit <= 0) {
        throw ArgumentError.value(limit, 'limit', '任务查询上限必须大于零。');
      }
      query.limit(limit);
    }
    // 相关表发生变化时只重新物化命中阶段的完整记录。
    return query.watch();
  }

  /// 一次读取指定阶段任务，批量文件操作需要稳定快照时使用。
  Future<List<DownloadTaskRecord>> loadTasksByPhases(
    Iterable<DownloadTaskPhase> phases,
  ) {
    // 复用同一阶段筛选与稳定排序，并只取得首份数据库结果。
    return watchTasksByPhases(phases).first;
  }

  /// 按阶段聚合监听任务数量，角标和页签不再加载完整任务对象。
  Stream<Map<DownloadTaskPhase, int>> watchTaskPhaseCounts() {
    // 只选择阶段和计数表达式，避免读取标题、封面、简介及候选清单等大字段。
    final phaseColumn = _database.downloadTasks.phase;
    final contentTypeColumn = _database.downloadTasks.contentType;
    final countExpression = _database.downloadTasks.taskId.count();
    final query = _database.selectOnly(_database.downloadTasks)
      ..addColumns(<Expression<Object>>[phaseColumn, countExpression])
      // 旧版独立附加资源任务不再出现在列表中，页签和导航角标也必须按主任务计数。
      ..where(
        contentTypeColumn.isNull() |
            contentTypeColumn.like('$downloadExtraResourcePrefix%').not(),
      )
      ..groupBy(<Expression<Object>>[phaseColumn]);
    return query.watch().map((List<TypedResult> rows) {
      // 每次查询构造独立只读语义快照，消费者只能按枚举读取数量。
      return <DownloadTaskPhase, int>{
        for (final row in rows)
          // selectOnly 返回数据库原始字符串，必须显式恢复 textEnum 领域枚举。
          DownloadTaskPhase.values.byName(row.read(phaseColumn)!):
              row.read(countExpression) ?? 0,
      };
    });
  }

  /// 监听任务 ID 与阶段轻量快照，供声音和通知识别真实阶段跃迁。
  Stream<List<DownloadTaskPhaseSnapshot>> watchTaskPhaseSnapshots() {
    // 提示音需要观察历史任务基线，但不需要物化其余二十多个业务字段。
    final taskIdColumn = _database.downloadTasks.taskId;
    final phaseColumn = _database.downloadTasks.phase;
    final query = _database.selectOnly(_database.downloadTasks)
      ..addColumns(<Expression<Object>>[taskIdColumn, phaseColumn]);
    return query.watch().map(
      (List<TypedResult> rows) => rows
          .map(
            (TypedResult row) => (
              taskId: row.read(taskIdColumn)!,
              // selectOnly 不应用生成记录的 textEnum 转换器，这里恢复领域阶段。
              phase: DownloadTaskPhase.values.byName(row.read(phaseColumn)!),
            ),
          )
          .toList(growable: false),
    );
  }

  /// 读取全部任务的一次性快照，供启动成品一致性检查使用。
  Future<List<DownloadTaskRecord>> loadAllTasksSnapshot() {
    // 校验服务自行筛选 completed 和带产物的异常中断任务，仓库只返回稳定快照。
    return _database.select(_database.downloadTasks).get();
  }

  /// 按成品检查结果修复任务终态，不经过普通运行时状态机。
  Future<void> repairTaskOutputState({
    required String taskId,
    required bool outputValid,
    String? errorCode,
    String? errorMessage,
  }) async {
    // 读取与更新必须在同一事务，防止恢复后的下载事件与启动检查交叉覆盖。
    await _database.transaction(() async {
      final task = await findTask(taskId);
      if (task == null || task.phase == DownloadTaskPhase.canceled) return;
      final now = DateTime.now();
      if (outputValid) {
        // 只有已登记产物的异常中断任务会调用此分支，直接恢复 completed 快照。
        await (_database.update(
          _database.downloadTasks,
        )..where((DownloadTasks table) => table.taskId.equals(taskId))).write(
          DownloadTasksCompanion(
            phase: const Value<DownloadTaskPhase>(DownloadTaskPhase.completed),
            resumePhase: const Value<DownloadTaskPhase?>(null),
            progress: const Value<double>(1),
            errorCode: const Value<String?>(null),
            errorMessage: const Value<String?>(null),
            updatedAt: Value<DateTime>(now),
            completedAt: Value<DateTime?>(task.completedAt ?? now),
          ),
        );
        return;
      }
      // 无效成品只允许把 completed 记录转为可手动重试的 failed，活动任务保持不变。
      if (task.phase != DownloadTaskPhase.completed) return;
      await (_database.update(
        _database.downloadTasks,
      )..where((DownloadTasks table) => table.taskId.equals(taskId))).write(
        DownloadTasksCompanion(
          phase: const Value<DownloadTaskPhase>(DownloadTaskPhase.failed),
          progress: const Value<double>(0),
          errorCode: Value<String?>(errorCode ?? 'output_invalid'),
          errorMessage: Value<String?>(errorMessage ?? '成品文件不存在或已损坏，请重试。'),
          updatedAt: Value<DateTime>(now),
          completedAt: const Value<DateTime?>(null),
        ),
      );
    });
  }

  /// 查询所有仍未启动、允许跟随设置中心同步的任务。
  Future<List<DownloadTaskRecord>> loadQueuedTasks() {
    // 只选择 queued 阶段，下载中、失败和已完成任务必须保持原始快照。
    final query = _database.select(_database.downloadTasks)
      ..where(
        (DownloadTasks table) =>
            table.phase.equals(DownloadTaskPhase.queued.name),
      )
      // 按创建时间同步，保持用户原始加入顺序。
      ..orderBy(<OrderClauseGenerator<DownloadTasks>>[
        (DownloadTasks table) => OrderingTerm.asc(table.createdAt),
      ]);
    // 返回一次性快照供设置同步服务处理。
    return query.get();
  }

  /// 在单个事务中把待下载或失败任务全部移入等待启动队列。
  Future<List<String>> queueTasksForStart(Iterable<String> taskIds) async {
    // 去重后保留调用方顺序，避免重复 ID 被多次增加重试次数。
    final orderedTaskIds = taskIds.toSet().toList(growable: false);
    // 所有阶段写入必须原子完成，界面不能看到任务逐条从待下载移动。
    return _database.transaction(() async {
      // 记录真正进入等待队列的任务 ID，失效快照由调用方统一忽略。
      final queuedTaskIds = <String>[];
      for (final taskId in orderedTaskIds) {
        // 事务内读取最新阶段，防止页面快照与单项启动操作发生竞争。
        final current = await findTask(taskId);
        // 已删除或已经活动的任务不重复排队。
        if (current == null ||
            (current.phase != DownloadTaskPhase.queued &&
                current.phase != DownloadTaskPhase.failed)) {
          continue;
        }
        // 领域状态机必须明确允许本次等待队列转换。
        DownloadTaskStateMachine.ensureCanTransition(
          current.phase,
          DownloadTaskPhase.waitingToStart,
        );
        // 失败任务重新加入队列时增加重试次数，普通待下载任务保持原值。
        final nextRetryCount = current.phase == DownloadTaskPhase.failed
            ? current.retryCount + 1
            : current.retryCount;
        // 清除旧错误并写入统一时间，事务提交后 Drift 只发出一批变化。
        await (_database.update(
          _database.downloadTasks,
        )..where((DownloadTasks table) => table.taskId.equals(taskId))).write(
          DownloadTasksCompanion(
            phase: const Value<DownloadTaskPhase>(
              DownloadTaskPhase.waitingToStart,
            ),
            retryCount: Value<int>(nextRetryCount),
            errorCode: const Value<String?>(null),
            errorMessage: const Value<String?>(null),
            updatedAt: Value<DateTime>(DateTime.now()),
          ),
        );
        // 当前任务成功写入后加入返回结果。
        queuedTaskIds.add(taskId);
      }
      // 返回不可修改快照，调度器只能消费不能改变事务结果。
      return List<String>.unmodifiable(queuedTaskIds);
    });
  }

  /// 将尚未提交给下载引擎的等待任务退回待下载队列。
  Future<int> requeueWaitingToStartTasks({String? exceptTaskId}) {
    // 全局启动失败时使用该入口止损，避免后续任务继续被调度器批量打成失败。
    return _database.transaction(() async {
      // 读取当前仍处在等待并发名额的任务，已进入解析或下载的任务不能回退。
      final waitingTasks =
          await (_database.select(_database.downloadTasks)..where(
                (DownloadTasks table) =>
                    table.phase.equals(DownloadTaskPhase.waitingToStart.name),
              ))
              .get();
      // 同一次回退使用统一时间，便于日志和列表排序判断本轮止损。
      final now = DateTime.now();
      var updated = 0;
      for (final task in waitingTasks) {
        // 当前失败的任务由调度器单独写入 failed，不能被这里重新变回待下载。
        if (task.taskId == exceptTaskId) continue;
        // 状态机明确允许等待队列回退，防止未来阶段扩展时误改活动任务。
        DownloadTaskStateMachine.ensureCanTransition(
          task.phase,
          DownloadTaskPhase.queued,
        );
        await (_database.update(
              _database.downloadTasks,
            )..where((DownloadTasks table) => table.taskId.equals(task.taskId)))
            .write(
              DownloadTasksCompanion(
                phase: const Value<DownloadTaskPhase>(DownloadTaskPhase.queued),
                resumePhase: const Value<DownloadTaskPhase?>(null),
                errorCode: const Value<String?>(null),
                errorMessage: const Value<String?>(null),
                downloadSpeedBytesPerSecond: const Value<int>(0),
                updatedAt: Value<DateTime>(now),
              ),
            );
        updated++;
      }
      // 返回实际回退数量，调度器日志可判断是否止住了后续队列。
      return updated;
    });
  }

  /// 将任务强制标记为可删除的取消终态。
  Future<void> markTaskCanceledForRemoval(String taskId) async {
    // 用户已二次确认删除时使用该兜底，避免 aria2 异常阻塞记录清理。
    await _database.transaction(() async {
      // 读取最新任务阶段，已被其他操作删除时保持幂等。
      final task = await findTask(taskId);
      if (task == null) return;
      // 已完成记录仍按完成删除流程处理，不在兜底中改写历史结果。
      if (task.phase == DownloadTaskPhase.completed) return;
      final now = DateTime.now();
      if (task.phase != DownloadTaskPhase.canceled) {
        // 只有状态机允许取消的活动或失败任务才能强制转入删除终态。
        DownloadTaskStateMachine.ensureCanTransition(
          task.phase,
          DownloadTaskPhase.canceled,
        );
        await (_database.update(
          _database.downloadTasks,
        )..where((DownloadTasks table) => table.taskId.equals(taskId))).write(
          DownloadTasksCompanion(
            phase: const Value<DownloadTaskPhase>(DownloadTaskPhase.canceled),
            resumePhase: const Value<DownloadTaskPhase?>(null),
            downloadSpeedBytesPerSecond: const Value<int>(0),
            updatedAt: Value<DateTime>(now),
          ),
        );
      }
      // 分流记录同步进入取消终态，防止删除后迟到事件继续显示活动状态。
      await (_database.update(_database.downloadStreams)..where(
            (DownloadStreams table) =>
                table.taskId.equals(taskId) &
                table.phase.isIn(<String>[
                  DownloadStreamPhase.pending.name,
                  DownloadStreamPhase.queued.name,
                  DownloadStreamPhase.downloading.name,
                  DownloadStreamPhase.paused.name,
                ]),
          ))
          .write(
            DownloadStreamsCompanion(
              phase: const Value<DownloadStreamPhase>(
                DownloadStreamPhase.canceled,
              ),
              downloadSpeedBytesPerSecond: const Value<int>(0),
              updatedAt: Value<DateTime>(now),
            ),
          );
    });
  }

  /// 查询应用启动后需要向真实下载引擎校准的活动任务。
  Future<List<DownloadTaskRecord>> loadRecoverableTasks() {
    // 终态 completed、canceled 和等待用户决定的 failed 不自动恢复。
    const recoverablePhases = <DownloadTaskPhase>[
      DownloadTaskPhase.queued,
      DownloadTaskPhase.waitingToStart,
      DownloadTaskPhase.resolving,
      DownloadTaskPhase.downloading,
      DownloadTaskPhase.waitingForMerge,
      DownloadTaskPhase.merging,
      DownloadTaskPhase.paused,
    ];
    // textEnum 在 SQLite 中按枚举名称保存，因此查询条件需要转换为字符串。
    final recoverablePhaseNames = recoverablePhases.map(
      (DownloadTaskPhase phase) => phase.name,
    );
    // 按更新时间从早到晚恢复，保持原任务处理顺序。
    final query = _database.select(_database.downloadTasks)
      ..where((DownloadTasks table) => table.phase.isIn(recoverablePhaseNames))
      ..orderBy(<OrderClauseGenerator<DownloadTasks>>[
        (DownloadTasks table) => OrderingTerm.asc(table.updatedAt),
      ]);
    // 执行一次性查询供启动恢复协调器使用。
    return query.get();
  }

  /// 把上次进程遗留的活动任务原子降级为暂停，并保留用户手动继续所需的恢复阶段。
  Future<int> pauseInterruptedTasks() async {
    // 仅处理“下载中”页签会自动执行的阶段；待下载和原本已暂停的任务保持不变。
    const interruptedPhases = <DownloadTaskPhase>[
      DownloadTaskPhase.waitingToStart,
      DownloadTaskPhase.resolving,
      DownloadTaskPhase.downloading,
      DownloadTaskPhase.waitingForMerge,
      DownloadTaskPhase.merging,
    ];
    // textEnum 在 SQLite 中保存枚举名称，查询必须使用对应字符串集合。
    final interruptedPhaseNames = interruptedPhases
        .map((DownloadTaskPhase phase) => phase.name)
        .toList(growable: false);
    // 主任务和分流必须在同一事务内暂停，避免界面看到主任务暂停但分流仍在下载。
    return _database.transaction(() async {
      // 先读取每条任务原阶段，作为用户点击继续时的恢复目标。
      final interruptedTasks =
          await (_database.select(_database.downloadTasks)..where(
                (DownloadTasks table) =>
                    table.phase.isIn(interruptedPhaseNames),
              ))
              .get();
      // 没有异常遗留任务时不产生无意义的数据库写入和列表刷新。
      if (interruptedTasks.isEmpty) return 0;
      // 同次恢复使用统一时间，便于诊断本轮启动暂停了哪些记录。
      final pausedAt = DateTime.now();
      // 逐任务保存各自恢复阶段，并同步暂停尚未完成的媒体分流。
      for (final task in interruptedTasks) {
        // 当前阶段是断点恢复的业务语义，不能统一覆盖成 downloading。
        final resumePhase = task.phase;
        // 先暂停对应分流，防止主任务状态提交后仍显示非零下载速度。
        await (_database.update(_database.downloadStreams)..where(
              (DownloadStreams table) =>
                  table.taskId.equals(task.taskId) &
                  table.phase.isIn(<String>[
                    DownloadStreamPhase.queued.name,
                    DownloadStreamPhase.downloading.name,
                  ]),
            ))
            .write(
              DownloadStreamsCompanion(
                phase: const Value<DownloadStreamPhase>(
                  DownloadStreamPhase.paused,
                ),
                downloadSpeedBytesPerSecond: const Value<int>(0),
                updatedAt: Value<DateTime>(pausedAt),
              ),
            );
        // 主任务进入暂停并记录原阶段，重新启动后只能由用户显式继续。
        await (_database.update(
              _database.downloadTasks,
            )..where((DownloadTasks table) => table.taskId.equals(task.taskId)))
            .write(
              DownloadTasksCompanion(
                phase: const Value<DownloadTaskPhase>(DownloadTaskPhase.paused),
                resumePhase: Value<DownloadTaskPhase?>(resumePhase),
                downloadSpeedBytesPerSecond: const Value<int>(0),
                updatedAt: Value<DateTime>(pausedAt),
              ),
            );
      }
      // 返回真实暂停数量供启动日志和退出诊断使用。
      return interruptedTasks.length;
    });
  }

  /// 查询全部仍存在任务记录的临时目录，作为启动清理的保护白名单。
  Future<List<String>> loadProtectedTemporaryDirectories() async {
    // 失败任务可能由用户稍后重试，终态记录也可能处于文件清理失败状态，因此全部保护。
    final query = _database.selectOnly(_database.downloadTasks)
      ..addColumns(<Expression<Object>>[
        _database.downloadTasks.temporaryDirectory,
      ])
      ..where(_database.downloadTasks.temporaryDirectory.isNotNull());
    final rows = await query.get();
    // 过滤空值并去重，调用方只读使用本次数据库快照。
    return rows
        .map(
          (TypedResult row) =>
              row.read(_database.downloadTasks.temporaryDirectory),
        )
        .whereType<String>()
        .where((String path) => path.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  /// 在事务中校验并写入任务阶段变化。
  Future<void> transitionTask(
    String taskId,
    DownloadTaskPhase next, {
    String? errorCode,
    String? errorMessage,
    bool incrementRetry = false,
  }) async {
    // 状态读取、校验和写入必须在同一事务内完成，避免并发事件交叉覆盖。
    await _database.transaction(() async {
      // 读取数据库当前状态作为状态机输入。
      final current = await findTask(taskId);
      // 引擎事件对应任务不存在时说明持久化流程出现错误。
      if (current == null) {
        throw StateError('Unknown download task: $taskId');
      }
      // 阻止完成或取消任务重新进入活动阶段等非法跳转。
      DownloadTaskStateMachine.ensureCanTransition(current.phase, next);
      // 同次更新使用统一时间戳。
      final now = DateTime.now();
      // 暂停时保存恢复目标，离开暂停阶段时清空旧目标。
      final resumePhase = _resumePhaseValue(current.phase, next);
      // 只有失败阶段保留错误，重试或恢复后清除旧错误。
      final shouldClearError = next != DownloadTaskPhase.failed;
      // 完成任务强制写入百分之百进度，进入合并时重新从零记录阶段进度。
      final isCompleted = next == DownloadTaskPhase.completed;
      final isStartingMerge = next == DownloadTaskPhase.merging;
      // 按状态语义构造部分更新 Companion。
      final companion = DownloadTasksCompanion(
        phase: Value<DownloadTaskPhase>(next),
        resumePhase: resumePhase,
        progress: _phaseProgressValue(
          isCompleted: isCompleted,
          isStartingMerge: isStartingMerge,
        ),
        retryCount: incrementRetry
            ? Value<int>(current.retryCount + 1)
            : const Value<int>.absent(),
        errorCode: shouldClearError
            ? const Value<String?>(null)
            : Value<String?>(errorCode),
        errorMessage: shouldClearError
            ? const Value<String?>(null)
            : Value<String?>(errorMessage),
        updatedAt: Value<DateTime>(now),
        completedAt: isCompleted
            ? Value<DateTime?>(now)
            : const Value<DateTime?>.absent(),
      );
      // 使用主键限制更新范围，确保只修改目标任务。
      await (_database.update(_database.downloadTasks)
            ..where((DownloadTasks table) => table.taskId.equals(taskId)))
          .write(companion);
    });
  }

  /// 仅当任务仍停留在预期阶段时写入下一阶段，避免异步启动覆盖用户暂停。
  Future<bool> transitionTaskIfPhase(
    String taskId, {
    required DownloadTaskPhase expected,
    required DownloadTaskPhase next,
    bool incrementRetry = false,
  }) async {
    // 条件读取和阶段写入必须共用事务，防止暂停与启动提交交叉覆盖。
    return _database.transaction(() async {
      // 读取当前阶段作为条件更新的业务前置状态。
      final current = await findTask(taskId);
      // 任务被删除时说明外部清理已经接管，调用方无需继续启动。
      if (current == null) return false;
      // 阶段已经变化时保持用户或其他后端事件的最新决定。
      if (current.phase != expected) return false;
      // 状态机仍负责限制合法阶段跳转。
      DownloadTaskStateMachine.ensureCanTransition(current.phase, next);
      // 同次阶段写入使用统一时间，便于诊断启动与暂停竞态。
      final now = DateTime.now();
      // 完成任务强制写满进度，进入合并时重置阶段进度。
      final isCompleted = next == DownloadTaskPhase.completed;
      final isStartingMerge = next == DownloadTaskPhase.merging;
      await (_database.update(
        _database.downloadTasks,
      )..where((DownloadTasks table) => table.taskId.equals(taskId))).write(
        DownloadTasksCompanion(
          phase: Value<DownloadTaskPhase>(next),
          resumePhase: _resumePhaseValue(current.phase, next),
          progress: _phaseProgressValue(
            isCompleted: isCompleted,
            isStartingMerge: isStartingMerge,
          ),
          retryCount: incrementRetry
              ? Value<int>(current.retryCount + 1)
              : const Value<int>.absent(),
          errorCode: const Value<String?>(null),
          errorMessage: const Value<String?>(null),
          updatedAt: Value<DateTime>(now),
          completedAt: isCompleted
              ? Value<DateTime?>(now)
              : const Value<DateTime?>.absent(),
        ),
      );
      // 返回 true 表示本轮确实完成了预期阶段转换。
      return true;
    });
  }

  /// 根据当前阶段和目标阶段构造恢复目标写入值。
  Value<DownloadTaskPhase?> _resumePhaseValue(
    DownloadTaskPhase current,
    DownloadTaskPhase next,
  ) {
    // 重复进入暂停态时不能覆盖已有恢复目标。
    if (next == DownloadTaskPhase.paused) {
      if (current == DownloadTaskPhase.paused) {
        return const Value<DownloadTaskPhase?>.absent();
      }
      return Value<DownloadTaskPhase?>(current);
    }
    // 从暂停态离开时清空恢复目标，避免后续任务误用旧阶段。
    if (current == DownloadTaskPhase.paused) {
      return const Value<DownloadTaskPhase?>(null);
    }
    // 其他阶段切换不触碰恢复目标字段。
    return const Value<DownloadTaskPhase?>.absent();
  }

  /// 根据目标阶段构造进度字段写入值。
  Value<double> _phaseProgressValue({
    required bool isCompleted,
    required bool isStartingMerge,
  }) {
    // 完成任务强制写入百分之百进度。
    if (isCompleted) return const Value<double>(1.0);
    // 进入合并时重新从零记录阶段进度。
    if (isStartingMerge) return const Value<double>(0.0);
    // 普通阶段切换不覆盖现有进度。
    return const Value<double>.absent();
  }

  /// 更新待下载主任务勾选的附加资源 JSON，不创建新的业务任务记录。
  Future<void> updateExtraResourcesJson(
    String taskId,
    String extraResourcesJson,
    String outputPath,
  ) async {
    // 附加资源开关会重算主任务输出位置，写库前必须确认仍是真实文件路径。
    _validateRequiredFileSystemPath(outputPath, 'outputPath');
    // 只允许仍在待下载或失败重试阶段的任务修改输出内容，活动任务保持计划稳定。
    final current = await findTask(taskId);
    if (current == null) throw StateError('Unknown download task: $taskId');
    if (current.phase != DownloadTaskPhase.queued &&
        current.phase != DownloadTaskPhase.failed) {
      throw StateError('Task $taskId cannot change extra resources now.');
    }
    // 单字段更新保留任务身份、画质、断点和历史错误信息。
    // 写入时再次校验阶段，防止旧页面快照覆盖已经启动或完成的任务。
    final updatedRows =
        await (_database.update(_database.downloadTasks)..where(
              (DownloadTasks table) =>
                  table.taskId.equals(taskId) &
                  table.phase.equals(current.phase.name),
            ))
            .write(
              DownloadTasksCompanion(
                extraResourcesJson: Value<String>(extraResourcesJson),
                outputPath: Value<String?>(outputPath),
                updatedAt: Value<DateTime>(DateTime.now()),
              ),
            );
    if (updatedRows == 0) {
      throw StateError('任务状态已变化，未修改附加资源。');
    }
  }

  /// 更新当前任务所在阶段的零到一进度。
  Future<void> updateTaskProgress(String taskId, double progress) async {
    // 将外部回调比例限制到数据库约定范围。
    final normalizedProgress = progress.clamp(0.0, 1.0);
    // 只更新目标任务进度与时间戳，不隐式改变业务阶段。
    await (_database.update(
      _database.downloadTasks,
    )..where((DownloadTasks table) => table.taskId.equals(taskId))).write(
      DownloadTasksCompanion(
        progress: Value<double>(normalizedProgress),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  /// 更新待下载或失败任务的视频画质和编码选择。
  Future<void> updateVideoSelection(
    String taskId, {
    required int? qualityId,
    required String? qualityLabel,
    required String? videoCodec,
    required int? estimatedVideoSizeBytes,
  }) async {
    // 读取和更新放在同一事务，避免任务启动后仍修改播放流选择。
    await _database.transaction(() async {
      // 查询任务当前阶段。
      final task = await findTask(taskId);
      if (task == null) throw StateError('Unknown download task: $taskId');
      // 只有尚未开始或失败待重试任务允许改选。
      if (task.phase != DownloadTaskPhase.queued &&
          task.phase != DownloadTaskPhase.failed) {
        throw StateError('活动下载任务不能修改画质。');
      }
      // 取消视频前必须仍保留音频，禁止产生没有任何媒体流的任务。
      if (qualityId == null && task.audioQualityId == null) {
        throw StateError('音质和画质不能同时选择“无”。');
      }
      // 纯音频任务使用 m4a，其余任务继续使用 mp4。
      final outputPath = task.outputPath == null
          ? null
          : p.setExtension(
              task.outputPath!,
              qualityId == null ? '.m4a' : '.mp4',
            );
      // 更新实际质量代码、显示文案、编码和时间戳。
      // 写入条件继续绑定读取到的阶段，避免启动中的任务被旧点击覆盖。
      final updatedRows =
          await (_database.update(_database.downloadTasks)..where(
                (DownloadTasks table) =>
                    table.taskId.equals(taskId) &
                    table.phase.equals(task.phase.name),
              ))
              .write(
                DownloadTasksCompanion(
                  qualityId: Value<int?>(qualityId),
                  qualityLabel: Value<String?>(qualityLabel),
                  videoCodec: Value<String?>(videoCodec),
                  estimatedVideoSizeBytes: Value<int?>(estimatedVideoSizeBytes),
                  outputPath: Value<String?>(outputPath),
                  updatedAt: Value<DateTime>(DateTime.now()),
                ),
              );
      if (updatedRows == 0) {
        throw StateError('任务状态已变化，未修改画质。');
      }
    });
  }

  /// 更新待下载或失败任务的音频质量和编码选择。
  Future<void> updateAudioSelection(
    String taskId, {
    required int? audioQualityId,
    required String? audioCodec,
    required int? estimatedAudioSizeBytes,
  }) async {
    // 读取和更新放在同一事务，避免任务启动后仍修改音轨。
    await _database.transaction(() async {
      // 查询任务当前阶段。
      final task = await findTask(taskId);
      if (task == null) throw StateError('Unknown download task: $taskId');
      // 只有尚未开始或失败待重试任务允许改选。
      if (task.phase != DownloadTaskPhase.queued &&
          task.phase != DownloadTaskPhase.failed) {
        throw StateError('活动下载任务不能修改音质。');
      }
      // 取消音频前必须仍保留视频，禁止产生没有任何媒体流的任务。
      if (audioQualityId == null && task.qualityId == null) {
        throw StateError('音质和画质不能同时选择“无”。');
      }
      // 只有无视频任务使用 m4a，恢复音频不会改变已有视频任务扩展名。
      final outputPath = task.outputPath == null
          ? null
          : p.setExtension(
              task.outputPath!,
              task.qualityId == null ? '.m4a' : '.mp4',
            );
      // 更新实际音质代码、显示文案和时间戳。
      // 写入条件继续绑定读取到的阶段，避免启动中的任务被旧点击覆盖。
      final updatedRows =
          await (_database.update(_database.downloadTasks)..where(
                (DownloadTasks table) =>
                    table.taskId.equals(taskId) &
                    table.phase.equals(task.phase.name),
              ))
              .write(
                DownloadTasksCompanion(
                  audioQualityId: Value<int?>(audioQualityId),
                  audioCodec: Value<String?>(audioCodec),
                  estimatedAudioSizeBytes: Value<int?>(estimatedAudioSizeBytes),
                  outputPath: Value<String?>(outputPath),
                  updatedAt: Value<DateTime>(DateTime.now()),
                ),
              );
      if (updatedRows == 0) {
        throw StateError('任务状态已变化，未修改音质。');
      }
    });
  }

  /// 批量修正待下载或失败任务的本地 DASH 候选和当前音画质选择。
  Future<int> updateQueuedDashSelections(
    Iterable<DownloadTaskDashSelectionUpdate> updates,
  ) async {
    // 固化调用方生成的更新集合，保证事务期间不会重复计算或读到变化后的迭代器。
    final changes = updates.toList(growable: false);
    // 没有待修正任务时避免打开写事务。
    if (changes.isEmpty) return 0;
    // 同一轮账号降级必须批量提交，避免列表短暂出现候选已裁剪但选择仍是高档。
    return _database.transaction(() async {
      // 统计真实写入行数，供账号流程记录诊断日志。
      var updatedRows = 0;
      // 同批更新使用统一时间，便于定位哪一轮退出触发了任务候选降级。
      final now = DateTime.now();
      for (final change in changes) {
        // 读取最新任务快照，防止页面或调度器已经把任务启动到活动阶段。
        final task = await findTask(change.taskId);
        // 任务已删除时保持批量修正幂等。
        if (task == null) continue;
        // 只允许未启动任务和失败待重试任务被账号权限降级改写。
        if (task.phase != DownloadTaskPhase.queued &&
            task.phase != DownloadTaskPhase.failed) {
          continue;
        }
        // 修正后无视频的任务应保持音频扩展名，其余任务保持普通视频扩展名。
        final outputPath = task.outputPath == null
            ? null
            : p.setExtension(
                task.outputPath!,
                change.qualityId == null ? '.m4a' : '.mp4',
              );
        // 单条更新同时写入候选 JSON 和当前选择，避免启动下载时读取到不匹配状态。
        final rows =
            await (_database.update(_database.downloadTasks)..where(
                  (DownloadTasks table) =>
                      table.taskId.equals(change.taskId) &
                      table.phase.equals(task.phase.name),
                ))
                .write(
                  DownloadTasksCompanion(
                    qualityId: Value<int?>(change.qualityId),
                    qualityLabel: Value<String?>(change.qualityLabel),
                    videoCodec: Value<String?>(change.videoCodec),
                    audioCodec: Value<String?>(change.audioCodec),
                    audioQualityId: Value<int?>(change.audioQualityId),
                    estimatedVideoSizeBytes: Value<int?>(
                      change.estimatedVideoSizeBytes,
                    ),
                    estimatedAudioSizeBytes: Value<int?>(
                      change.estimatedAudioSizeBytes,
                    ),
                    dashOptionsJson: Value<String?>(change.dashOptionsJson),
                    durationMilliseconds: Value<int?>(
                      change.durationMilliseconds,
                    ),
                    outputPath: Value<String?>(outputPath),
                    updatedAt: Value<DateTime>(now),
                  ),
                );
        // Drift 返回受影响行数，阶段竞态导致零行时不视为整批失败。
        updatedRows += rows;
      }
      // 返回真实落库数量。
      return updatedRows;
    });
  }

  /// 更新尚未启动任务的临时目录和最终输出路径。
  Future<void> updateQueuedTaskPaths({
    required String taskId,
    required String temporaryDirectory,
    required String outputPath,
  }) async {
    // 队列路径重算属于下载创建链路，禁止写入相对路径或 content URI。
    _validateRequiredFileSystemPath(temporaryDirectory, 'temporaryDirectory');
    _validateRequiredFileSystemPath(outputPath, 'outputPath');
    // 只更新仍处于 queued 的任务，失败任务可能已经存在可恢复临时文件。
    await (_database.update(_database.downloadTasks)..where(
          (DownloadTasks table) =>
              table.taskId.equals(taskId) &
              table.phase.equals(DownloadTaskPhase.queued.name),
        ))
        .write(
          DownloadTasksCompanion(
            temporaryDirectory: Value<String?>(temporaryDirectory),
            outputPath: Value<String?>(outputPath),
            updatedAt: Value<DateTime>(DateTime.now()),
          ),
        );
  }

  /// 原子写入设置中心重新计算后的待下载任务快照。
  Future<void> updateQueuedTaskSettings({
    required String taskId,
    required int? qualityId,
    required String? qualityLabel,
    required String? videoCodec,
    required int? audioQualityId,
    required String? audioCodec,
    required int? estimatedVideoSizeBytes,
    required int? estimatedAudioSizeBytes,
    required int? durationMilliseconds,
    required String temporaryDirectory,
    required String outputPath,
  }) async {
    // 设置同步会批量改写待下载任务路径，同样只接受真实文件系统路径。
    _validateRequiredFileSystemPath(temporaryDirectory, 'temporaryDirectory');
    _validateRequiredFileSystemPath(outputPath, 'outputPath');
    // WHERE 同时校验任务 ID 和 queued 阶段，避免同步期间启动的任务被覆盖。
    await (_database.update(_database.downloadTasks)..where(
          (DownloadTasks table) =>
              table.taskId.equals(taskId) &
              table.phase.equals(DownloadTaskPhase.queued.name),
        ))
        .write(
          DownloadTasksCompanion(
            qualityId: Value<int?>(qualityId),
            qualityLabel: Value<String?>(qualityLabel),
            videoCodec: Value<String?>(videoCodec),
            audioQualityId: Value<int?>(audioQualityId),
            audioCodec: Value<String?>(audioCodec),
            estimatedVideoSizeBytes: Value<int?>(estimatedVideoSizeBytes),
            estimatedAudioSizeBytes: Value<int?>(estimatedAudioSizeBytes),
            durationMilliseconds: Value<int?>(durationMilliseconds),
            temporaryDirectory: Value<String?>(temporaryDirectory),
            outputPath: Value<String?>(outputPath),
            updatedAt: Value<DateTime>(DateTime.now()),
          ),
        );
  }

  /// 从暂停阶段恢复到进入暂停前保存的阶段。
  Future<void> resumePausedTask(String taskId) async {
    // 查询任务以确定恢复目标阶段。
    final current = await findTask(taskId);
    // 任务不存在时无法恢复。
    if (current == null) throw StateError('Unknown download task: $taskId');
    // 只有暂停任务允许调用该方法，避免误改活动任务。
    if (current.phase != DownloadTaskPhase.paused) {
      throw StateError('Download task is not paused: $taskId');
    }
    // 解析阶段没有可恢复的临时 URL 或执行上下文，恢复时重新交回并发等待队列。
    final target = current.resumePhase == DownloadTaskPhase.resolving
        ? DownloadTaskPhase.waitingToStart
        : current.resumePhase ?? DownloadTaskPhase.queued;
    // 复用状态机事务完成恢复并清空 resumePhase。
    await transitionTask(taskId, target);
  }

  /// 新增或更新一条媒体分流记录。
  Future<void> upsertStream(DownloadStreamDraft draft) async {
    // 分流 ID、任务 ID、地址和临时路径均是下载恢复的必要字段。
    if (draft.streamId.isEmpty ||
        draft.taskId.isEmpty ||
        draft.remoteUrl.isEmpty ||
        draft.temporaryPath.isEmpty) {
      throw ArgumentError(
        'Stream identifiers, URL and path must not be empty.',
      );
    }
    // 分流临时文件由下载引擎直接读写，必须是普通文件绝对路径。
    _validateRequiredFileSystemPath(draft.temporaryPath, 'temporaryPath');
    // 使用同一时间标记 URL 刷新和记录更新。
    final now = DateTime.now();
    // 主键冲突时更新播放地址、编码和引擎任务信息。
    await _database
        .into(_database.downloadStreams)
        .insertOnConflictUpdate(
          DownloadStreamsCompanion.insert(
            streamId: draft.streamId,
            taskId: draft.taskId,
            kind: draft.kind,
            remoteUrl: draft.remoteUrl,
            codec: Value<String?>(draft.codec),
            temporaryPath: draft.temporaryPath,
            engineTaskId: Value<String?>(draft.engineTaskId),
            phase: Value<DownloadStreamPhase>(draft.phase),
            urlRefreshedAt: Value<DateTime>(now),
            updatedAt: Value<DateTime>(now),
          ),
        );
  }

  /// 查询指定业务任务的全部媒体分流。
  Future<List<DownloadStreamRecord>> loadStreams(String taskId) {
    // 视频流优先、音频流随后，保证协调器获得稳定顺序。
    final query = _database.select(_database.downloadStreams)
      ..where((DownloadStreams table) => table.taskId.equals(taskId))
      ..orderBy(<OrderClauseGenerator<DownloadStreams>>[
        (DownloadStreams table) => OrderingTerm.asc(table.kind),
      ]);
    // 执行一次性分流查询。
    return query.get();
  }

  /// 持续监听指定业务任务的全部媒体分流。
  Stream<List<DownloadStreamRecord>> watchStreams(String taskId) {
    // 下载卡片需要实时读取分流类型、字节、速度和重试状态。
    final query = _database.select(_database.downloadStreams)
      ..where((DownloadStreams table) => table.taskId.equals(taskId))
      ..orderBy(<OrderClauseGenerator<DownloadStreams>>[
        // 视频流优先、音频流随后，保证当前任务标签顺序稳定。
        (DownloadStreams table) => OrderingTerm.asc(table.kind),
      ]);
    // Drift 会在任一分流进度更新时重新发出当前两条记录。
    return query.watch();
  }

  /// 按引擎任务 ID 更新分流状态和字节进度，并重算主任务总进度。
  Future<bool> updateStreamProgress({
    required String engineTaskId,
    required DownloadStreamPhase phase,
    required int downloadedBytes,
    int? totalBytes,
    int downloadSpeedBytesPerSecond = 0,
    String? errorCode,
    String? errorMessage,
  }) async {
    // 引擎任务 ID 为空时无法关联到持久化分流。
    if (engineTaskId.isEmpty) return false;
    // 分流更新和主任务进度重算必须在同一事务内完成。
    return _database.transaction(() async {
      // 查询引擎事件对应的媒体分流。
      final stream =
          await (_database.select(_database.downloadStreams)..where(
                (DownloadStreams table) =>
                    table.engineTaskId.equals(engineTaskId),
              ))
              .getSingleOrNull();
      // 事件可能来自已经清理的旧任务，找不到时由调用方忽略。
      if (stream == null) return false;
      // 后端可能在继续断点任务的瞬间先回报 0 或未知总量，不能覆盖已有断点总量。
      final normalizedTotalBytes = totalBytes != null && totalBytes > 0
          ? totalBytes
          : stream.totalBytes;
      // 总大小有效时限制已下载字节不超过总大小。
      final boundedDownloadedBytes = _boundedDownloadedBytes(
        downloadedBytes: downloadedBytes,
        totalBytes: normalizedTotalBytes,
      );
      // 下载完成事件以总量为准，避免后端终态缺少 completedLength 时不能进入满进度。
      final completedDownloadedBytes =
          phase == DownloadStreamPhase.completed &&
              normalizedTotalBytes != null &&
              normalizedTotalBytes > 0
          ? normalizedTotalBytes
          : boundedDownloadedBytes;
      // 同一分流的中间态进度只能前进；继续下载时后端短暂回报 0 不应让界面闪回初始值。
      final shouldKeepExistingProgress =
          _shouldKeepExistingStreamProgress(phase) &&
          _isSameStreamExtent(stream.totalBytes, normalizedTotalBytes) &&
          stream.downloadedBytes > completedDownloadedBytes;
      // 最终写库的已下载字节，优先保留可信的历史断点。
      final normalizedDownloadedBytes = shouldKeepExistingProgress
          ? stream.downloadedBytes
          : completedDownloadedBytes;
      // 只有下载阶段保留非负速度，其他阶段立即归零避免显示旧值。
      final normalizedDownloadSpeed =
          phase == DownloadStreamPhase.downloading &&
              downloadSpeedBytesPerSecond > 0
          ? downloadSpeedBytesPerSecond
          : 0;
      // 非失败状态清除旧错误，失败状态保存本次错误。
      final shouldClearError = phase != DownloadStreamPhase.failed;
      // 写入当前分流状态、进度、错误和更新时间。
      await (_database.update(_database.downloadStreams)..where(
            (DownloadStreams table) => table.streamId.equals(stream.streamId),
          ))
          .write(
            DownloadStreamsCompanion(
              phase: Value<DownloadStreamPhase>(phase),
              downloadedBytes: Value<int>(normalizedDownloadedBytes),
              totalBytes: Value<int?>(normalizedTotalBytes),
              downloadSpeedBytesPerSecond: Value<int>(normalizedDownloadSpeed),
              errorCode: shouldClearError
                  ? const Value<String?>(null)
                  : Value<String?>(errorCode),
              errorMessage: shouldClearError
                  ? const Value<String?>(null)
                  : Value<String?>(errorMessage),
              updatedAt: Value<DateTime>(DateTime.now()),
            ),
          );
      // 汇总同一任务所有已知分流的字节比例，更新主任务下载进度。
      await _recalculateTaskProgress(stream.taskId);
      // 返回 true 表示事件已经成功关联并持久化。
      return true;
    });
  }

  /// 更新过期媒体地址并清除旧下载错误。
  Future<void> refreshStreamUrl(String streamId, String remoteUrl) async {
    // 新地址为空时不能覆盖仍可用于诊断的旧地址。
    if (remoteUrl.isEmpty) throw ArgumentError.value(remoteUrl, 'remoteUrl');
    // 使用统一时间标记地址刷新和记录更新。
    final now = DateTime.now();
    // 只修改目标分流的 URL、刷新时间和错误字段。
    await (_database.update(
      _database.downloadStreams,
    )..where((DownloadStreams table) => table.streamId.equals(streamId))).write(
      DownloadStreamsCompanion(
        remoteUrl: Value<String>(remoteUrl),
        errorCode: const Value<String?>(null),
        errorMessage: const Value<String?>(null),
        urlRefreshedAt: Value<DateTime>(now),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  /// 新增或更新任务产生的本地文件记录。
  Future<void> upsertArtifact(DownloadArtifactDraft draft) async {
    // 任务 ID 和文件路径为空时无法执行后续清理或交付。
    if (draft.taskId.isEmpty || draft.path.isEmpty) {
      throw ArgumentError('Artifact task id and path must not be empty.');
    }
    // 完成产物用于打开、删除和转换，必须保存真实文件路径。
    _validateRequiredFileSystemPath(draft.path, 'path');
    // 复合唯一键不包含自增 ID，必须显式指定冲突目标，不能使用只按主键更新的便捷方法。
    final artifact = DownloadArtifactsCompanion.insert(
      taskId: draft.taskId,
      kind: draft.kind,
      path: draft.path,
      sizeBytes: Value<int?>(draft.sizeBytes),
      checksum: Value<String?>(draft.checksum),
      retained: Value<bool>(draft.retained),
    );
    // 同一任务恢复或重试时更新原记录，避免重复插入触发 SQLite 2067。
    await _database
        .into(_database.downloadArtifacts)
        .insert(
          artifact,
          onConflict: DoUpdate(
            (_) => artifact,
            target: <Column<Object>>[
              _database.downloadArtifacts.taskId,
              _database.downloadArtifacts.kind,
              _database.downloadArtifacts.path,
            ],
          ),
        );
  }

  /// 删除指定路径的产物记录，供用户移除转换派生文件。
  Future<int> deleteArtifactByPath({
    required String taskId,
    required DownloadArtifactKind kind,
    required String path,
  }) {
    // 删除条件必须同时包含任务、类型和绝对路径，避免误删同任务其他本地资源。
    return (_database.delete(_database.downloadArtifacts)..where(
          (DownloadArtifacts table) =>
              table.taskId.equals(taskId) &
              table.kind.equals(kind.name) &
              table.path.equals(path),
        ))
        .go();
  }

  /// 查询任务指定类型的最新产物，供平台存储清理使用。
  Future<DownloadArtifactRecord?> findArtifact({
    required String taskId,
    required DownloadArtifactKind kind,
  }) {
    // 按任务与产物类型定位记录；同一任务正常只存在一个最终输出。
    final query = _database.select(_database.downloadArtifacts)
      ..where(
        (DownloadArtifacts table) =>
            table.taskId.equals(taskId) & table.kind.equals(kind.name),
      )
      // 重试产生多个历史标识时优先使用最新写入的记录。
      ..orderBy(<OrderingTerm Function(DownloadArtifacts)>[
        (DownloadArtifacts table) => OrderingTerm.desc(table.createdAt),
      ])
      ..limit(1);
    // 没有产物的旧任务返回 null，由调用方回退任务输出路径。
    return query.getSingleOrNull();
  }

  /// 查询任务最新的任意类型最终产物，供“同时删除文件”跨平台清理使用。
  Future<DownloadArtifactRecord?> findLatestArtifact(String taskId) {
    // 一个独立任务只会发布一种最终资源，但类型可能是视频、封面、弹幕或字幕。
    final query = _database.select(_database.downloadArtifacts)
      ..where((DownloadArtifacts table) => table.taskId.equals(taskId))
      // 重试或迁移产生多条记录时优先删除最后一次成功发布的稳定标识。
      ..orderBy(<OrderingTerm Function(DownloadArtifacts)>[
        (DownloadArtifacts table) => OrderingTerm.desc(table.createdAt),
      ])
      ..limit(1);
    // 旧版任务没有产物记录时返回 null，由页面回退到 outputPath。
    return query.getSingleOrNull();
  }

  /// 查询任务全部保留产物，供“同时删除文件”清理主视频和所有附加资源。
  Future<List<DownloadArtifactRecord>> loadRetainedArtifacts(String taskId) {
    // retained=false 的临时索引由任务临时目录清理，不能当作用户成品重复删除。
    final query = _database.select(_database.downloadArtifacts)
      ..where(
        (DownloadArtifacts table) =>
            table.taskId.equals(taskId) & table.retained.equals(true),
      )
      // 先删除后生成的资源，最后删除主视频，失败时仍尽量保留核心成品。
      ..orderBy(<OrderingTerm Function(DownloadArtifacts)>[
        (DownloadArtifacts table) => OrderingTerm.desc(table.createdAt),
      ]);
    return query.get();
  }

  /// 监听任务全部保留产物，供已下载详情页展示最终视频和附加资源。
  Stream<List<DownloadArtifactRecord>> watchRetainedArtifacts(String taskId) {
    // retained=false 的临时流只用于清理和诊断，详情页只展示用户可见的最终文件。
    final query = _database.select(_database.downloadArtifacts)
      ..where(
        (DownloadArtifacts table) =>
            table.taskId.equals(taskId) & table.retained.equals(true),
      )
      // SQL 层只提供稳定顺序，页面再按业务关注度整理展示顺序。
      ..orderBy(<OrderingTerm Function(DownloadArtifacts)>[
        (DownloadArtifacts table) => OrderingTerm.asc(table.kind),
        (DownloadArtifacts table) => OrderingTerm.asc(table.createdAt),
      ]);
    return query.watch();
  }

  /// 汇总媒体分流字节数与实时速度并更新主任务。
  Future<void> _recalculateTaskProgress(String taskId) async {
    // 读取任务的全部视频与音频分流。
    final streams = await loadStreams(taskId);
    // 只汇总仍处于下载阶段的音视频速度，暂停和完成分流不参与。
    final downloadSpeedBytesPerSecond = streams
        .where(
          (DownloadStreamRecord stream) =>
              stream.phase == DownloadStreamPhase.downloading,
        )
        .fold<int>(
          0,
          (int total, DownloadStreamRecord stream) =>
              total + stream.downloadSpeedBytesPerSecond,
        );
    // 只统计总大小已知且大于零的分流，未知大小不参与分母。
    final measurableStreams = streams.where(
      (DownloadStreamRecord stream) => (stream.totalBytes ?? 0) > 0,
    );
    // 没有可计算分流时保留进度，但仍同步当前双流速度。
    if (measurableStreams.isEmpty) {
      await (_database.update(
        _database.downloadTasks,
      )..where((DownloadTasks table) => table.taskId.equals(taskId))).write(
        DownloadTasksCompanion(
          downloadSpeedBytesPerSecond: Value<int>(downloadSpeedBytesPerSecond),
          updatedAt: Value<DateTime>(DateTime.now()),
        ),
      );
      return;
    }
    // 累加可测量分流的已下载字节。
    final downloaded = measurableStreams.fold<int>(
      0,
      (int total, DownloadStreamRecord stream) =>
          total + stream.downloadedBytes,
    );
    // 累加可测量分流的总字节数。
    final total = measurableStreams.fold<int>(
      0,
      (int value, DownloadStreamRecord stream) =>
          value + (stream.totalBytes ?? 0),
    );
    // 计算并限制零到一之间的下载进度。
    final progress = (downloaded / total).clamp(0.0, 1.0);
    // 更新主任务进度和时间戳，不自动推进业务阶段。
    await (_database.update(
      _database.downloadTasks,
    )..where((DownloadTasks table) => table.taskId.equals(taskId))).write(
      DownloadTasksCompanion(
        progress: Value<double>(progress),
        downloadSpeedBytesPerSecond: Value<int>(downloadSpeedBytesPerSecond),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  /// 根据总量边界修正后端上报的已下载字节。
  int _boundedDownloadedBytes({
    required int downloadedBytes,
    required int? totalBytes,
  }) {
    // 总大小有效时限制已下载字节不超过总大小。
    if (totalBytes != null && totalBytes > 0) {
      return downloadedBytes.clamp(0, totalBytes);
    }
    // 总量未知时仍要阻止负数字节污染界面。
    if (downloadedBytes < 0) return 0;
    return downloadedBytes;
  }
}

/// 判断分流事件是否属于可恢复的传输中间态。
bool _shouldKeepExistingStreamProgress(DownloadStreamPhase phase) {
  // 只有排队、下载和暂停会出现断点恢复回调；失败、取消和完成必须按终态事件落库。
  return switch (phase) {
    DownloadStreamPhase.queued ||
    DownloadStreamPhase.downloading ||
    DownloadStreamPhase.paused => true,
    _ => false,
  };
}

/// 判断新旧总量是否仍代表同一份远程分流。
bool _isSameStreamExtent(int? existingTotalBytes, int? nextTotalBytes) {
  // 任一侧缺少有效总量时无法证明文件变化，保守视为同一断点文件。
  if (existingTotalBytes == null ||
      existingTotalBytes <= 0 ||
      nextTotalBytes == null ||
      nextTotalBytes <= 0) {
    return true;
  }
  // 两侧都有总量时必须完全一致，避免新 URL 文件大小变化后错误保留旧进度。
  return existingTotalBytes == nextTotalBytes;
}

/// 校验可空路径字段，空值表示当前阶段尚未规划真实文件位置。
void _validateOptionalFileSystemPath(String? value, String fieldName) {
  // 旧任务或早期阶段允许暂时没有路径，但一旦提供就必须是文件系统绝对路径。
  if (value == null || value.isEmpty) return;
  _validateRequiredFileSystemPath(value, fieldName);
}

/// 校验必填路径字段，阻断 content URI 和相对路径继续进入下载核心。
void _validateRequiredFileSystemPath(String value, String fieldName) {
  // 路径写库前统一去除首尾空白，避免 UI 输入或平台返回值带来的伪路径。
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, fieldName, '文件路径不能为空。');
  }
  // 下载、转换、删除都直接操作文件系统，数据库里只允许保存真实绝对路径。
  if (!p.isAbsolute(trimmed)) {
    throw ArgumentError.value(value, fieldName, '必须是文件系统绝对路径。');
  }
}
