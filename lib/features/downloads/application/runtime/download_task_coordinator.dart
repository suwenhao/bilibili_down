import 'dart:async';
import 'dart:io';

import '../../../../core/database/app_database.dart';
import '../../../../core/logging/app_debug_log.dart';
import '../../../../services/bilibili/bili_api_exception.dart';
import '../../../../services/download_engine/download_engine.dart';
import '../../../../services/media_merge/media_merge_files.dart';
import '../../../../services/media_merge/media_merger.dart';
import '../../../../services/media_output/media_output_publisher.dart';
import '../../data/download_task_draft.dart';
import '../../data/download_task_repository.dart';
import '../../domain/download_extra_resource.dart';
import '../../domain/download_task_phase.dart';
import 'download_event_buffer.dart';
import 'download_event_policy.dart';
import 'download_merge_policy.dart';
import 'expired_media_url_resolver.dart';
import '../maintenance/download_completion_cleanup_service.dart';
import '../queue/download_task_plan.dart';
import '../resources/embedded_extra_resource_processor.dart';
import '../resources/standalone_extra_resource_finalizer.dart';

export 'download_event_policy.dart';

/// 下载协调器异步处理事件失败时向诊断层发送的错误。
final class DownloadCoordinatorError {
  /// 保存可选任务 ID、原始异常和堆栈。
  const DownloadCoordinatorError({
    required this.taskId,
    required this.error,
    required this.stackTrace,
  });

  /// 能够关联时对应的业务任务 ID。
  final String? taskId;

  /// 下载、数据库或合并过程抛出的原始异常。
  final Object error;

  /// 原始异常堆栈。
  final StackTrace stackTrace;
}

/// 协调视频流、音频流、Drift 状态和 FFmpeg 合并的任务核心。
final class DownloadTaskCoordinator {
  /// 创建协调器并立即监听下载事件和合并进度。
  DownloadTaskCoordinator(
    this._downloadEngine,
    this._mediaMerger,
    this._mediaOutputPublisher,
    this._repository,
    this._extraResourceProcessor, {
    required this.autoMergeCompletedStreams,
    required this._expiredMediaUrlResolver,
    required this._completionCleanup,
    required this._standaloneExtraResourceFinalizer,
  }) {
    // 下载事件必须在 restore 前监听，才能接收引擎重放的真实状态。
    _downloadSubscription = _downloadEngine.watchEvents().listen(
      _queueDownloadEvent,
    );
    // 合并器同一时间只运行一个任务，因此可用活动任务 ID 关联进度。
    _mergeProgressSubscription = _mediaMerger.watchProgress().listen(
      _queueMergeProgress,
    );
  }

  /// 统一下载引擎，平台选择由组合根完成。
  final DownloadEngine _downloadEngine;

  /// 当前平台对应的 FFmpegKit 或 CLI 合并器。
  final MediaMerger _mediaMerger;

  /// 把合并成品发布到平台最终可见存储区。
  final MediaOutputPublisher _mediaOutputPublisher;

  /// 负责持久化任务、分流和文件产物的 Drift 仓库。
  final DownloadTaskRepository _repository;

  /// 在 CDN 地址失效时按原任务选择重新请求单条分流。
  final ExpiredMediaUrlResolver _expiredMediaUrlResolver;

  /// 在主视频发布后生成同任务勾选的封面、音频、弹幕和字幕产物。
  final EmbeddedExtraResourceProcessor _extraResourceProcessor;

  /// 清理被覆盖旧成品和当前任务临时目录的完成收尾服务。
  final DownloadCompletionCleanupService _completionCleanup;

  /// 发布独立封面、弹幕和字幕任务的资源收尾服务。
  final StandaloneExtraResourceFinalizer _standaloneExtraResourceFinalizer;

  /// 两条分流完成后是否允许立即执行合并；iOS 默认关闭。
  final bool autoMergeCompletedStreams;

  /// 向日志或诊断界面广播无法在原回调中抛出的异步错误。
  final StreamController<DownloadCoordinatorError> _errors =
      StreamController<DownloadCoordinatorError>.broadcast();

  /// 下载引擎事件流订阅。
  late final StreamSubscription<DownloadEvent> _downloadSubscription;

  /// FFmpeg 合并进度流订阅。
  late final StreamSubscription<MediaMergeProgress> _mergeProgressSubscription;

  /// 尚未持久化的下载事件；普通进度按任务合并，状态机事件保持原始顺序。
  final DownloadEventBuffer _pendingDownloadEvents = DownloadEventBuffer();

  /// 串行处理下载事件，避免视频与音频回调并发覆盖 Drift 状态。
  Future<void> _eventQueue = Future<void>.value();

  /// 下载事件消费器是否已经排入串行 Future，防止每个进度创建一层 then 链。
  bool _eventDrainScheduled = false;

  /// FFmpeg 进度串行写入链，和下载事件分离后仍在完成状态前显式等待。
  Future<void> _mergeProgressQueue = Future<void>.value();

  /// 尚未写库的最新 FFmpeg 进度，同一时刻最多保留一个快照。
  ({String taskId, double ratio})? _pendingMergeProgress;

  /// FFmpeg 进度消费器是否正在运行或已经排队。
  bool _mergeProgressDrainScheduled = false;

  /// 串行执行不同任务的 FFmpeg 合并，匹配单合并器实例约束。
  Future<void> _mergeQueue = Future<void>.value();

  /// 每个已排队合并任务对应的完成信号。
  final Map<String, Completer<void>> _mergeCompleters =
      <String, Completer<void>>{};

  /// 当前正在使用合并器的业务任务 ID。
  String? _activeMergeTaskId;

  /// 正在重新解析和提交的引擎任务 ID，用于忽略旧任务的迟到失败或取消事件。
  final Set<String> _refreshingEngineTaskIds = <String>{};

  /// 刷新前主动取消的旧引擎任务 ID，用于只忽略对应迟到取消事件。
  final Set<String> _ignoredCanceledEngineTaskIds = <String>{};

  /// 记录当前进程内每条分流的自动 URL 刷新次数，避免复用任务总重试次数。
  final Map<String, int> _automaticUrlRefreshCountsByEngineTaskId =
      <String, int>{};

  /// 数据库明确要求保持暂停的引擎任务 ID，阻止引擎恢复时短暂自动续传。
  final Set<String> _persistentlyPausedEngineTaskIds = <String>{};

  /// 单个业务任务最多自动刷新两次，防止账号或风控错误导致无限请求。
  static const int _maximumAutomaticUrlRefreshes = 2;

  /// 协调器是否已经释放。
  bool _disposed = false;

  /// 监听协调器内部异步错误。
  Stream<DownloadCoordinatorError> watchErrors() => _errors.stream;

  /// 恢复下载引擎状态，并把数据库中的暂停决定同步到底层下载后端。
  Future<void> restore() async {
    // 已释放的协调器不能重新建立任务监听。
    _ensureNotDisposed();
    // 引擎启动前先读取暂停任务，防止恢复事件把持久化暂停状态覆盖为下载中。
    final tasks = await _repository.loadRecoverableTasks();
    // 只同步用户或启动恢复明确暂停的任务，不自动处理等待和合并阶段。
    for (final task in tasks) {
      // 非暂停任务由当前进程的正常调度流程负责，不在恢复阶段隐式启动。
      if (task.phase != DownloadTaskPhase.paused) continue;
      // 分流记录中的稳定引擎 ID 用于恢复 aria2 或系统下载断点。
      final streams = await _repository.loadStreams(task.taskId);
      // 每条未完成暂停分流都加入保护集合，直到用户显式点击继续。
      for (final stream in streams) {
        // 已完成、失败或取消的分流不需要向底层重复发送暂停命令。
        if (stream.phase != DownloadStreamPhase.paused) continue;
        // 尚未提交引擎的分流没有可操作 ID，只保留主任务暂停状态即可。
        final engineTaskId = stream.engineTaskId;
        if (engineTaskId != null) {
          _persistentlyPausedEngineTaskIds.add(engineTaskId);
        }
      }
    }
    // 要求引擎在监听建立后重放真实任务状态。
    await _downloadEngine.restore();
    // 显式暂停恢复出的后端任务，确保引擎会话状态也遵守数据库决定。
    for (final engineTaskId in _persistentlyPausedEngineTaskIds) {
      try {
        // 后端可能已经保持暂停；重复暂停必须按下载引擎的幂等约定处理。
        await _downloadEngine.pause(engineTaskId);
      } catch (error) {
        // 部分系统后端不会恢复不存在的任务，保留数据库暂停并等待用户重试即可。
        AppDebugLog.aria2(
          'Restore pause skipped engineTask=$engineTaskId error=$error',
        );
      }
    }
  }

  /// 保存解析后的两条分流并同时提交下载引擎。
  Future<void> startResolvedTask(ResolvedDownloadPlan plan) async {
    // 已释放的协调器不能启动新任务。
    _ensureNotDisposed();
    // 主任务必须先由解析流程创建，协调器只负责解析完成后的阶段。
    final task = await _repository.findTask(plan.taskId);
    if (task == null) throw StateError('Unknown download task: ${plan.taskId}');
    if (task.phase == DownloadTaskPhase.paused ||
        task.phase == DownloadTaskPhase.canceled ||
        task.phase == DownloadTaskPhase.completed) {
      // 启动服务的长异步步骤可能被用户暂停或取消打断，协调器入口保持幂等退出。
      AppDebugLog.aria2(
        'Start resolved skipped task=${plan.taskId} phase=${task.phase.name}',
      );
      return;
    }
    // 待下载或调度器等待任务先进入解析阶段，失败任务重试时增加重试次数。
    if (task.phase == DownloadTaskPhase.queued ||
        task.phase == DownloadTaskPhase.waitingToStart) {
      final enteredResolving = await _repository.transitionTaskIfPhase(
        plan.taskId,
        expected: task.phase,
        next: DownloadTaskPhase.resolving,
      );
      // 用户可能已经暂停或取消等待任务，不能再覆盖最新阶段继续启动。
      if (!enteredResolving) {
        AppDebugLog.aria2(
          'Launch resolving skipped after phase changed task=${plan.taskId}',
        );
        return;
      }
    } else if (task.phase == DownloadTaskPhase.failed) {
      // 手动重试失败任务前先清理旧引擎占位，旧取消事件会被 failed 主阶段保护。
      await _clearExistingEngineStreamsForRetry(plan.taskId);
      final enteredResolving = await _repository.transitionTaskIfPhase(
        plan.taskId,
        expected: DownloadTaskPhase.failed,
        next: DownloadTaskPhase.resolving,
        incrementRetry: true,
      );
      // 失败任务可能已被用户移除或重新排队，旧启动流程必须停止。
      if (!enteredResolving) {
        AppDebugLog.aria2(
          'Retry resolving skipped after phase changed task=${plan.taskId}',
        );
        return;
      }
    } else if (task.phase != DownloadTaskPhase.resolving) {
      // 其他阶段重复提交会破坏已有下载或合并流程。
      throw StateError(
        'Task ${plan.taskId} cannot start from ${task.phase.name}.',
      );
    }

    // 记录已经成功提交的引擎任务，后续提交失败时用于回滚运行状态。
    final enqueuedEngineTaskIds = <String>[];
    // 区分数据库准备失败和下载引擎提交失败，便于任务卡展示准确错误码。
    var submittingToEngine = false;
    try {
      // 先持久化两条分流和临时文件产物，确保早到的引擎事件能够关联。
      for (final source in plan.sources) {
        await _saveResolvedSource(plan.taskId, source);
      }
      // 分流记录准备完成后进入下载阶段。
      final enteredDownloading = await _repository.transitionTaskIfPhase(
        plan.taskId,
        expected: DownloadTaskPhase.resolving,
        next: DownloadTaskPhase.downloading,
      );
      // 用户可能在解析期间已经批量暂停，此时不能再把任务提交到底层下载后端。
      if (!enteredDownloading) {
        AppDebugLog.aria2(
          'Launch skipped after phase changed task=${plan.taskId}',
        );
        return;
      }
      // 从此处开始的异常属于 aria2 或系统下载引擎提交阶段。
      submittingToEngine = true;
      // 视频流与音频流分别提交统一下载引擎。
      for (final source in plan.sources) {
        // 使用稳定的分流 ID 同时作为引擎任务 ID。
        final engineTaskId = downloadStreamId(plan.taskId, source.kind);
        // 批量暂停可能刚好发生在分流保存后、引擎提交前，提交后需要立即补暂停。
        final shouldPauseAfterEnqueue = _persistentlyPausedEngineTaskIds
            .contains(engineTaskId);
        // 调用下载引擎并保留 CDN 所需请求头。
        await _downloadEngine.enqueue(
          DownloadRequest(
            taskId: engineTaskId,
            url: source.url,
            backupUrls: source.backupUrls,
            destinationPath: source.temporaryPath,
            headers: source.headers,
          ),
        );
        // 仅在引擎接受后加入回滚列表。
        enqueuedEngineTaskIds.add(engineTaskId);
        // 提交期间再次读取主任务阶段，尊重用户刚刚发出的暂停或取消决定。
        final latestTask = await _repository.findTask(plan.taskId);
        if (latestTask == null ||
            latestTask.phase == DownloadTaskPhase.canceled ||
            latestTask.phase == DownloadTaskPhase.failed ||
            latestTask.phase == DownloadTaskPhase.completed) {
          // 任务已经离开活动链路时取消本轮已提交的引擎任务。
          for (final submittedEngineTaskId in enqueuedEngineTaskIds) {
            try {
              await _downloadEngine.cancel(submittedEngineTaskId);
            } catch (_) {
              // 取消迟到任务失败不能覆盖用户已经选择的终态。
            }
          }
          return;
        }
        if (shouldPauseAfterEnqueue ||
            latestTask.phase == DownloadTaskPhase.paused) {
          // 主任务已暂停时，新提交的底层任务也必须立刻进入暂停保护。
          _persistentlyPausedEngineTaskIds.add(engineTaskId);
          try {
            // 后端刚接受任务时可能短暂处于不可暂停窗口，后续受保护事件会继续补暂停。
            await _downloadEngine.pause(engineTaskId);
          } catch (error) {
            // 补暂停失败不能把用户明确暂停的业务任务改成失败。
            AppDebugLog.aria2(
              'Late enqueue pause deferred engineTask=$engineTaskId error=$error',
            );
          }
          await _repository.updateStreamProgress(
            engineTaskId: engineTaskId,
            phase: DownloadStreamPhase.paused,
            downloadedBytes: 0,
          );
        }
      }
    } catch (error, stackTrace) {
      // 任一分流提交失败时取消已经提交的另一条分流。
      for (final engineTaskId in enqueuedEngineTaskIds) {
        try {
          await _downloadEngine.cancel(engineTaskId);
        } catch (_) {
          // 回滚取消失败不覆盖最初的提交异常，真实状态仍会由引擎事件校准。
        }
      }
      // 将主任务标记为失败并记录可诊断错误。
      await _transitionIfAllowed(
        plan.taskId,
        DownloadTaskPhase.failed,
        errorCode: submittingToEngine ? 'enqueue_failed' : 'prepare_failed',
        errorMessage: biliUserMessage(error, fallback: '下载准备失败，请重试。'),
      );
      // 同时广播异步诊断信息后把异常交回调用方。
      _emitError(plan.taskId, error, stackTrace);
      rethrow;
    }
  }

  /// 执行应用内直接下载的单一资源，并复用任务后处理和发布流程。
  Future<void> startPreparedResource(
    ResolvedDownloadPlan plan, {
    required Future<int> Function(ResolvedMediaSource source) prepare,
  }) async {
    // 只有一条 resource 分流的计划允许绕过下载引擎。
    final source = plan.resource;
    if (source == null || plan.sources.length != 1) {
      throw StateError('Prepared resource plan must contain one resource.');
    }
    _ensureNotDisposed();
    final task = await _requireTask(plan.taskId);
    if (task.phase == DownloadTaskPhase.paused ||
        task.phase == DownloadTaskPhase.canceled ||
        task.phase == DownloadTaskPhase.completed) {
      // 应用内资源准备也必须尊重用户在网络请求期间做出的阶段决定。
      AppDebugLog.aria2(
        'Prepared resource skipped task=${plan.taskId} phase=${task.phase.name}',
      );
      return;
    }
    // 与普通启动相同地进入 resolving，并记录失败任务的重试次数。
    if (task.phase == DownloadTaskPhase.queued ||
        task.phase == DownloadTaskPhase.waitingToStart) {
      final enteredResolving = await _repository.transitionTaskIfPhase(
        plan.taskId,
        expected: task.phase,
        next: DownloadTaskPhase.resolving,
      );
      // 用户可能已经暂停或取消等待任务，不能再执行应用内资源下载。
      if (!enteredResolving) return;
    } else if (task.phase == DownloadTaskPhase.failed) {
      final enteredResolving = await _repository.transitionTaskIfPhase(
        plan.taskId,
        expected: DownloadTaskPhase.failed,
        next: DownloadTaskPhase.resolving,
        incrementRetry: true,
      );
      // 失败任务状态已变化时停止旧的资源准备流程。
      if (!enteredResolving) return;
    } else if (task.phase != DownloadTaskPhase.resolving) {
      throw StateError(
        'Task ${plan.taskId} cannot prepare from ${task.phase.name}.',
      );
    }
    try {
      // 回调负责把网络正文写到计划的临时路径并返回真实字节数。
      final totalBytes = await prepare(source);
      // 文件落盘后再保存分流，避免应用重启恢复到不存在的直接资源。
      await _saveResolvedSource(plan.taskId, source);
      final enteredDownloading = await _repository.transitionTaskIfPhase(
        plan.taskId,
        expected: DownloadTaskPhase.resolving,
        next: DownloadTaskPhase.downloading,
      );
      // 资源准备期间用户可能已经暂停，不能继续推进完成和发布流程。
      if (!enteredDownloading) return;
      // 直接资源已经完整写入，持久化为单分流百分之百状态。
      await _repository.updateStreamProgress(
        engineTaskId: downloadStreamId(plan.taskId, source.kind),
        phase: DownloadStreamPhase.completed,
        downloadedBytes: totalBytes,
        totalBytes: totalBytes,
      );
      // 复用复制、ASS 转换和平台发布逻辑，但不会调用下载引擎或 FFmpeg。
      await mergeTaskNow(plan.taskId);
    } catch (error, stackTrace) {
      // 网络、解压、写文件或发布失败都转为可移除、可重试的失败任务。
      await _transitionIfAllowed(
        plan.taskId,
        DownloadTaskPhase.failed,
        errorCode: 'resource_prepare_failed',
        errorMessage: biliUserMessage(error, fallback: '资源准备失败，请重试。'),
      );
      _emitError(plan.taskId, error, stackTrace);
      rethrow;
    }
  }

  /// 暂停当前任务仍在等待或传输的媒体分流。
  Future<void> pauseTask(String taskId) async {
    // 检查生命周期并读取任务当前阶段。
    _ensureNotDisposed();
    final task = await _requireTask(taskId);
    // 合并和终态不能再触碰下载后端，避免对已结束分流重复发送暂停请求。
    if (!canToggleDownloadTaskPause(task.phase) ||
        task.phase == DownloadTaskPhase.paused) {
      return;
    }
    // 逐条暂停已保存或正在传输的媒体分流。
    final streams = await _repository.loadStreams(taskId);
    for (final stream in streams) {
      if (stream.phase == DownloadStreamPhase.pending ||
          stream.phase == DownloadStreamPhase.queued ||
          stream.phase == DownloadStreamPhase.downloading) {
        final engineTaskId = stream.engineTaskId;
        // 没有引擎任务 ID 的分流尚未提交，无需调用暂停。
        if (engineTaskId != null) {
          // 先记录用户暂停决定，防止暂停 RPC 期间的下载中事件继续写入进度。
          _persistentlyPausedEngineTaskIds.add(engineTaskId);
          if (stream.phase == DownloadStreamPhase.pending) {
            // 待提交分流由启动流程提交后立即补暂停，这里只登记保护意图。
            continue;
          }
          // 先要求原生下载引擎保存断点并暂停任务。
          await _downloadEngine.pause(engineTaskId);
          // 主动持久化暂停，避免用户立即恢复时等待异步状态回调。
          await _repository.updateStreamProgress(
            engineTaskId: engineTaskId,
            phase: DownloadStreamPhase.paused,
            downloadedBytes: stream.downloadedBytes,
            totalBytes: stream.totalBytes,
          );
        }
      }
    }
    // 下载回调可能在暂停请求期间把任务推进到合并阶段，写入暂停前必须再次读取真实阶段。
    final latestTask = await _requireTask(taskId);
    // 只有仍可暂停的下载阶段才能落库，合并阶段保持现状并等待界面隐藏按钮。
    if (latestTask.phase == DownloadTaskPhase.waitingToStart ||
        latestTask.phase == DownloadTaskPhase.resolving ||
        latestTask.phase == DownloadTaskPhase.downloading) {
      await _repository.transitionTask(taskId, DownloadTaskPhase.paused);
    }
  }

  /// 将暂停任务恢复到暂停前的下载或合并阶段。
  Future<void> resumeTask(String taskId) async {
    // 检查任务存在并且确实处于暂停阶段。
    _ensureNotDisposed();
    final task = await _requireTask(taskId);
    if (task.phase != DownloadTaskPhase.paused) {
      throw StateError('Download task is not paused: $taskId');
    }
    // 保存恢复目标，仓库写入后 resumePhase 会被清空。
    final target = task.resumePhase ?? DownloadTaskPhase.queued;
    // 用户点击继续后先清除本任务所有分流保护，避免解析期暂停残留影响重新入队。
    final streams = await _repository.loadStreams(taskId);
    for (final stream in streams) {
      // 分流 ID 可能来自尚未提交引擎的 pending 记录，也必须同步释放保护。
      final engineTaskId = stream.engineTaskId;
      if (engineTaskId != null) {
        _persistentlyPausedEngineTaskIds.remove(engineTaskId);
      }
    }
    // 下载阶段需要先恢复所有暂停的引擎分流。
    if (target == DownloadTaskPhase.downloading) {
      for (final stream in streams) {
        // 只有已经被后端暂停的分流需要发送恢复请求。
        final engineTaskId = stream.engineTaskId;
        if (stream.phase == DownloadStreamPhase.paused) {
          // 已持久化的引擎任务 ID 是恢复系统断点所需的关联键。
          if (engineTaskId != null) {
            try {
              // 先把断点任务重新提交给原生下载队列。
              await _downloadEngine.resume(engineTaskId);
            } catch (_) {
              // 恢复失败时重新启用暂停保护，避免迟到事件误把界面切回下载中。
              _persistentlyPausedEngineTaskIds.add(engineTaskId);
              rethrow;
            }
            // 主动写入排队状态，避免迟到的 paused 回调误导界面。
            await _repository.updateStreamProgress(
              engineTaskId: engineTaskId,
              phase: DownloadStreamPhase.queued,
              downloadedBytes: stream.downloadedBytes,
              totalBytes: stream.totalBytes,
            );
          }
        }
      }
    }
    // 恢复主任务到暂停前阶段。
    await _repository.resumePausedTask(taskId);
    // 引擎恢复期间分流可能已经完成，用户继续后需要重新检查而不是等待不存在的新事件。
    if (target == DownloadTaskPhase.downloading) {
      await _handleStreamsCompleted(taskId);
    }
    // 显式恢复合并表示应用当前允许执行，即使 iOS 关闭自动合并也可以继续。
    if (target == DownloadTaskPhase.waitingForMerge ||
        target == DownloadTaskPhase.merging) {
      await mergeTaskNow(taskId);
    }
  }

  /// 取消任务的下载分流和活动合并。
  Future<void> cancelTask(String taskId) async {
    // 先把主任务写入取消终态，让随后到达的失败回调不能覆盖用户决定。
    _ensureNotDisposed();
    await _transitionIfAllowed(taskId, DownloadTaskPhase.canceled);
    // 当前任务正在合并时通知 FFmpeg 取消。
    if (_activeMergeTaskId == taskId) await _mediaMerger.cancel();
    // 取消所有尚未进入终态且具有引擎 ID 的媒体分流。
    final streams = await _repository.loadStreams(taskId);
    for (final stream in streams) {
      if (stream.phase != DownloadStreamPhase.completed &&
          stream.phase != DownloadStreamPhase.failed &&
          stream.phase != DownloadStreamPhase.canceled) {
        final engineTaskId = stream.engineTaskId;
        // 尚未提交到引擎的分流无需远程取消。
        if (engineTaskId != null) {
          // 用户取消后移除暂停保护，避免集合长期保留已经删除的引擎任务。
          _persistentlyPausedEngineTaskIds.remove(engineTaskId);
          // 请求下载引擎终止任务并清理其运行状态。
          await _downloadEngine.cancel(engineTaskId);
          // 主动持久化取消，迟到事件仍会被主任务终态保护。
          await _repository.updateStreamProgress(
            engineTaskId: engineTaskId,
            phase: DownloadStreamPhase.canceled,
            downloadedBytes: stream.downloadedBytes,
            totalBytes: stream.totalBytes,
          );
        }
      }
    }
  }

  /// 正常退出前暂停全部活动任务，保留临时文件、进度和原恢复阶段。
  Future<int> pauseAllForShutdown() async {
    // 已释放协调器不能再向下载引擎或合并器发送控制命令。
    _ensureNotDisposed();
    // 读取当前非终态任务，待下载和原暂停任务不需要重复操作。
    final tasks = await _repository.loadRecoverableTasks();
    // 记录本轮尝试暂停的活动任务数量，仅用于退出诊断。
    var pauseRequestedCount = 0;
    // 逐项暂停可让 aria2 保存每条断点，并让 FFmpeg 完成取消清理。
    for (final task in tasks) {
      // queued 仍属于待下载；paused 已满足退出要求，二者均保持原状。
      if (task.phase == DownloadTaskPhase.queued ||
          task.phase == DownloadTaskPhase.paused) {
        continue;
      }
      // 每条活动任务都计入请求数量，即使某个后端暂停调用失败。
      pauseRequestedCount += 1;
      try {
        // 复用单任务暂停逻辑，确保下载分流和合并阶段按原有规则清理。
        await pauseTask(task.taskId);
      } catch (error) {
        // 单任务失败不能阻止其他任务暂停，数据库兜底会在退出链路统一执行。
        AppDebugLog.aria2(
          'Shutdown pause failed task=${task.taskId} error=$error',
        );
      }
    }
    // 返回尝试数量供退出日志确认调用覆盖范围。
    return pauseRequestedCount;
  }

  /// 显式把两条已完成分流加入串行 FFmpeg 合并队列。
  Future<void> mergeTaskNow(String taskId) {
    // 已释放的协调器不能继续排队合并。
    _ensureNotDisposed();
    // 同一任务已经排队时复用原完成信号，防止重复创建输出文件。
    final existingCompleter = _mergeCompleters[taskId];
    if (existingCompleter != null) return existingCompleter.future;
    // 创建调用方可等待的任务完成信号。
    final completer = Completer<void>();
    _mergeCompleters[taskId] = completer;
    // 追加到全局合并队列，确保一个 MediaMerger 同时只执行一项任务。
    _mergeQueue = _mergeQueue.then((_) async {
      try {
        // 执行实际文件校验、合并和状态写入。
        await _mergeTask(taskId);
        // 成功时完成调用方 Future。
        if (!completer.isCompleted) completer.complete();
      } catch (error, stackTrace) {
        // 广播诊断错误并让显式调用方收到同一异常。
        _emitError(taskId, error, stackTrace);
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      } finally {
        // 无论结果如何都允许后续重试重新排队该任务。
        _mergeCompleters.remove(taskId);
      }
    });
    // 返回当前任务独立的完成信号，而不是整个队列 Future。
    return completer.future;
  }

  /// 取消监听、结束活动合并并等待串行队列清理完成。
  Future<void> dispose() async {
    // 重复释放直接返回。
    if (_disposed) return;
    // 先阻止外部继续提交操作。
    _disposed = true;
    // 停止接收新的下载和合并进度事件。
    await _downloadSubscription.cancel();
    await _mergeProgressSubscription.cancel();
    // 活动合并必须取消，避免协调器销毁后继续写入数据库。
    if (_activeMergeTaskId != null) await _mediaMerger.cancel();
    // 等待已经进入队列的数据库事件和合并清理结束。
    await _eventQueue;
    await _mergeProgressQueue;
    await _mergeQueue;
    // 所有合并与附加资源任务结束后关闭其 HTTP 连接池。
    _extraResourceProcessor.dispose();
    // 最后关闭诊断错误广播流。
    await _errors.close();
  }

  /// 保存解析后的单条分流及其临时文件产物记录。
  Future<void> _saveResolvedSource(
    String taskId,
    ResolvedMediaSource source,
  ) async {
    // 重新解析后的媒体地址必须可提交给下载引擎，历史空地址不能覆盖分流记录。
    if (source.url.toString().trim().isEmpty) {
      throw StateError('播放地址已失效，未拿到可下载地址。');
    }
    // 分流 ID 同时作为下载引擎任务 ID，简化事件关联和恢复。
    final streamId = downloadStreamId(taskId, source.kind);
    // 写入或刷新媒体地址、编码、本地路径和引擎 ID。
    await _repository.upsertStream(
      DownloadStreamDraft(
        streamId: streamId,
        taskId: taskId,
        kind: source.kind,
        remoteUrl: source.url.toString(),
        codec: source.codec,
        temporaryPath: source.temporaryPath,
        engineTaskId: streamId,
        phase: DownloadStreamPhase.queued,
      ),
    );
    // 注册临时文件路径，后续清理流程由用户设置和确认界面决定。
    await _repository.upsertArtifact(
      DownloadArtifactDraft(
        taskId: taskId,
        kind: switch (source.kind) {
          DownloadStreamKind.video => DownloadArtifactKind.videoStream,
          DownloadStreamKind.audio => DownloadArtifactKind.audioStream,
          DownloadStreamKind.resource => DownloadArtifactKind.resource,
        },
        path: source.temporaryPath,
      ),
    );
  }

  /// 将下载引擎事件加入串行数据库处理队列。
  void _queueDownloadEvent(DownloadEvent event) {
    // 缓冲器只覆盖尚未处理的普通进度，所有状态机事件仍按到达顺序排队。
    _pendingDownloadEvents.add(event);
    _scheduleDownloadEventDrain();
  }

  /// 保证同一时刻只有一个下载事件消费器，并把本轮全部缓冲事件串行写库。
  void _scheduleDownloadEventDrain() {
    // 已有消费器会继续读取新加入节点，不需要再创建 Future 链。
    if (_eventDrainScheduled) return;
    _eventDrainScheduled = true;
    _eventQueue = _eventQueue.then((_) async {
      try {
        // FIFO 顺序保护暂停、取消、失败和完成事件；连续进度已在缓冲器内合并。
        while (!_pendingDownloadEvents.isEmpty) {
          final event = _pendingDownloadEvents.removeFirst();
          try {
            await _handleDownloadEvent(event);
          } catch (error, stackTrace) {
            // 单条事件失败只进入诊断流，后续终态仍必须继续处理。
            _emitError(null, error, stackTrace);
          }
        }
      } finally {
        // 当前 Future 完成前同步清除标记；单 isolate 不会在此处遗漏新事件。
        _eventDrainScheduled = false;
      }
    });
  }

  /// 将 FFmpeg 进度加入同一串行数据库队列。
  void _queueMergeProgress(MediaMergeProgress progress) {
    // 没有活动任务或无法计算比例时不写入无意义进度。
    final taskId = _activeMergeTaskId;
    final ratio = progress.ratio;
    if (taskId == null || ratio == null) return;
    // 合并开始阶段已在启动 FFmpeg 前落库，因此这里只保留尚未写入的最新比例。
    _pendingMergeProgress = (taskId: taskId, ratio: ratio);
    _scheduleMergeProgressDrain();
  }

  /// 串行写入 FFmpeg 最新进度，并在数据库较慢时覆盖过时的中间比例。
  void _scheduleMergeProgressDrain() {
    // 已运行的消费器会在当前写入完成后读取最新待写值。
    if (_mergeProgressDrainScheduled) return;
    _mergeProgressDrainScheduled = true;
    _mergeProgressQueue = _mergeProgressQueue.then((_) async {
      try {
        // 每轮先清空待写槽；写库期间到达的新比例会重新填入并在下一轮处理。
        while (_pendingMergeProgress != null) {
          // 非空检查后固定本轮快照，下一条回调可以安全覆盖待写槽。
          final pending = _pendingMergeProgress!;
          _pendingMergeProgress = null;
          try {
            await _repository.updateTaskProgress(pending.taskId, pending.ratio);
          } catch (error, stackTrace) {
            // 合并进度持久化失败通过诊断流报告，不中断 FFmpeg 会话。
            _emitError(pending.taskId, error, stackTrace);
          }
        }
      } finally {
        // 退出循环代表待写槽为空，可以允许下一次合并重新创建消费器。
        _mergeProgressDrainScheduled = false;
      }
    });
  }

  /// 把统一下载事件写入对应分流并推进主任务状态。
  Future<void> _handleDownloadEvent(DownloadEvent event) async {
    // 先按唯一引擎任务 ID 找到媒体分流。
    final stream = await _repository.findStreamByEngineTaskId(event.taskId);
    // 非协调器创建的下载任务不属于当前双流流程。
    if (stream == null) return;
    // 将下载引擎状态映射为持久化分流状态。
    final streamPhase = streamPhaseFor(event.status);
    // 判断该分流是否受启动恢复或用户暂停保护，后端旧事件不能越过该决定。
    final isPersistentlyPaused = _persistentlyPausedEngineTaskIds.contains(
      event.taskId,
    );
    // 引擎恢复可能重放旧的活动状态，但数据库暂停决定必须优先于后端会话。
    if (isPersistentlyPaused &&
        (streamPhase == DownloadStreamPhase.queued ||
            streamPhase == DownloadStreamPhase.downloading)) {
      try {
        // 再次发送暂停，使底层会话尽快回到与数据库一致的安全状态。
        await _downloadEngine.pause(event.taskId);
      } catch (error) {
        // 暂停失败不允许把分流写回下载中，退出或下次恢复会再次兜底。
        AppDebugLog.aria2(
          'Protected pause failed engineTask=${event.taskId} error=$error',
        );
      }
      // 忽略本次旧活动事件，界面和主任务继续保持暂停。
      return;
    }
    // 暂停任务的旧失败或取消事件通常来自上次进程，不能覆盖本次安全恢复状态。
    if (isPersistentlyPaused &&
        (streamPhase == DownloadStreamPhase.failed ||
            streamPhase == DownloadStreamPhase.canceled)) {
      return;
    }
    // 刷新期间旧引擎任务可能迟到发送失败或取消，不能覆盖新下载状态。
    if (_refreshingEngineTaskIds.contains(event.taskId) &&
        streamPhase == DownloadStreamPhase.failed) {
      return;
    }
    // 主动替换旧任务产生的取消事件不代表用户取消业务任务。
    if (streamPhase == DownloadStreamPhase.canceled &&
        (_refreshingEngineTaskIds.contains(event.taskId) ||
            _ignoredCanceledEngineTaskIds.remove(event.taskId))) {
      return;
    }
    // 新任务开始排队、下载或完成说明刷新提交已经被引擎接受。
    if (streamPhase == DownloadStreamPhase.queued ||
        streamPhase == DownloadStreamPhase.downloading ||
        streamPhase == DownloadStreamPhase.completed) {
      _refreshingEngineTaskIds.remove(event.taskId);
    }
    if (streamPhase == DownloadStreamPhase.completed ||
        streamPhase == DownloadStreamPhase.canceled) {
      // 终态分流结束后清理本进程内的自动刷新计数，避免未来同 ID 手动重试继承旧次数。
      _automaticUrlRefreshCountsByEngineTaskId.remove(event.taskId);
    }
    // 更新字节进度、错误和分流状态。
    await _repository.updateStreamProgress(
      engineTaskId: event.taskId,
      phase: streamPhase,
      downloadedBytes: event.downloadedBytes,
      totalBytes: event.totalBytes,
      downloadSpeedBytesPerSecond: event.downloadSpeedBytesPerSecond,
      errorCode: downloadErrorCodeFor(
        event.errorMessage,
        aria2ErrorCode: event.errorCode,
      ),
      errorMessage: event.errorMessage,
    );
    // 已暂停分流可以记录真实完成字节，但必须等用户继续后才推进合并流程。
    if (isPersistentlyPaused && streamPhase == DownloadStreamPhase.completed) {
      return;
    }

    // 分流失败时优先尝试刷新过期地址或发生协议错误的 CDN 地址。
    if (streamPhase == DownloadStreamPhase.failed) {
      // 提取稳定错误码用于判断是否值得请求新的临时地址和 CDN 列表。
      final errorCode = downloadErrorCodeFor(
        event.errorMessage,
        aria2ErrorCode: event.errorCode,
      );
      // 鉴权失败与网络/CDN 错误执行有限自动刷新，其他本地错误直接反馈。
      if ((errorCode == '401' ||
              errorCode == '403' ||
              errorCode == '404' ||
              errorCode == 'http_error' ||
              errorCode == 'no_uri' ||
              errorCode == 'protocol_error' ||
              errorCode == 'certificate_revocation_unavailable' ||
              errorCode == 'network_error') &&
          await _tryRefreshExpiredStream(
            stream,
            rotateCdn:
                errorCode == 'protocol_error' ||
                errorCode == 'certificate_revocation_unavailable' ||
                errorCode == 'network_error' ||
                errorCode == 'http_error' ||
                errorCode == 'no_uri',
          )) {
        return;
      }
      // 不可刷新或刷新失败时把主任务转为失败，保留错误等待用户处理。
      await _transitionIfAllowed(
        stream.taskId,
        DownloadTaskPhase.failed,
        errorCode: errorCode ?? 'download_failed',
        errorMessage: downloadErrorMessageFor(
          event.errorMessage,
          errorCode: errorCode,
        ),
      );
      return;
    }
    // 外部取消分流时同步取消主任务，但不覆盖已经失败或完成的任务。
    if (streamPhase == DownloadStreamPhase.canceled) {
      // 下载失败后的回滚取消不能覆盖 failed，终态迟到事件也应忽略。
      final current = await _repository.findTask(stream.taskId);
      if (current == null ||
          current.phase == DownloadTaskPhase.failed ||
          current.phase == DownloadTaskPhase.completed ||
          current.phase == DownloadTaskPhase.canceled) {
        return;
      }
      await _transitionIfAllowed(stream.taskId, DownloadTaskPhase.canceled);
      return;
    }
    // 暂停事件需要等待两条未完成分流都暂停后再更新主任务。
    if (streamPhase == DownloadStreamPhase.paused) {
      await _pauseTaskWhenAllStreamsPaused(stream.taskId);
      return;
    }
    // 任一分流完成后检查视频和音频是否都已完成。
    if (streamPhase == DownloadStreamPhase.completed) {
      await _handleStreamsCompleted(stream.taskId);
    }
  }

  /// 重新解析一条过期分流，并使用稳定引擎任务 ID 重新提交。
  Future<bool> _tryRefreshExpiredStream(
    DownloadStreamRecord stream, {
    required bool rotateCdn,
  }) async {
    // 查询最新主任务，确保分流仍属于一个存在的业务任务。
    final task = await _repository.findTask(stream.taskId);
    // 已删除任务交由普通失败流程处理。
    if (task == null) return false;
    // 分流必须已经拥有稳定引擎任务 ID 才能安全替换。
    final engineTaskId = stream.engineTaskId;
    if (engineTaskId == null || engineTaskId.isEmpty) return false;
    // URL 自动刷新是下载中自愈能力，不能被手动启动失败次数提前耗尽。
    final automaticRefreshCount =
        _automaticUrlRefreshCountsByEngineTaskId[engineTaskId] ?? 0;
    if (automaticRefreshCount >= _maximumAutomaticUrlRefreshes) return false;
    // 防止重复失败回调同时启动多次播放接口请求。
    if (!_refreshingEngineTaskIds.add(engineTaskId)) return true;
    try {
      // 只重新解析失败分流，另一条正常下载不受影响。
      final source = await _expiredMediaUrlResolver.refresh(
        taskId: stream.taskId,
        kind: stream.kind,
      );
      // 刷新器必须返回与失败记录相同的分流类型。
      if (source.kind != stream.kind) {
        throw StateError('Expired media resolver returned wrong stream kind.');
      }
      // TLS、DNS 和断连错误优先轮换备用 CDN；401/403 保持刷新后的主地址。
      final orderedUrls = orderedCdnRetryUrls(
        primary: source.url,
        backups: source.backupUrls,
        retryCount: task.retryCount,
        rotate: rotateCdn,
      );
      // 排序函数始终至少保留主地址，首项是本轮真正提交的 URL。
      final selectedUrl = orderedUrls.first;
      // 先把新 URL 和清理后的错误信息写入数据库，保证崩溃恢复可用。
      await _repository.refreshStreamUrl(
        stream.streamId,
        selectedUrl.toString(),
      );
      // 将分流恢复为排队状态并保留已有字节统计。
      await _repository.updateStreamProgress(
        engineTaskId: engineTaskId,
        phase: DownloadStreamPhase.queued,
        downloadedBytes: stream.downloadedBytes,
        totalBytes: stream.totalBytes,
      );
      // 同阶段更新用于原子增加自动刷新次数和清除主任务旧错误。
      await _repository.transitionTask(
        stream.taskId,
        DownloadTaskPhase.downloading,
        incrementRetry: true,
      );
      // 只有刷新地址和阶段写库成功后才增加本进程自动刷新次数。
      _automaticUrlRefreshCountsByEngineTaskId[engineTaskId] =
          automaticRefreshCount + 1;
      try {
        // 主动清理旧 GID 会广播 canceled，必须先登记忽略，避免迟到事件覆盖重试状态。
        _ignoredCanceledEngineTaskIds.add(engineTaskId);
        // 清理失败后端中的旧任务占位，允许复用稳定 ID。
        await _downloadEngine.cancel(engineTaskId);
      } catch (_) {
        // 部分后端已经自动移除失败任务，取消不存在任务不阻止重新提交。
        _ignoredCanceledEngineTaskIds.remove(engineTaskId);
      }
      // 使用新地址、新 Cookie 和原临时路径重新排队。
      await _downloadEngine.enqueue(
        DownloadRequest(
          taskId: engineTaskId,
          url: selectedUrl,
          backupUrls: orderedUrls.skip(1).toList(growable: false),
          destinationPath: source.temporaryPath,
          headers: source.headers,
        ),
      );
      // 提交完成后允许新任务的真实失败立即触发下一次有限刷新。
      _refreshingEngineTaskIds.remove(engineTaskId);
      return true;
    } catch (error, stackTrace) {
      // 刷新或重新提交失败后允许后续人工重试重新进入该流程。
      _refreshingEngineTaskIds.remove(engineTaskId);
      // 重新提交失败时清除主动取消标记，避免未来用户取消被误忽略。
      _ignoredCanceledEngineTaskIds.remove(engineTaskId);
      // 单独广播刷新错误，主任务随后由调用方写入原下载失败状态。
      _emitError(stream.taskId, error, stackTrace);
      return false;
    }
  }

  /// 手动重试失败任务前清理旧分流在下载引擎中的占位。
  Future<void> _clearExistingEngineStreamsForRetry(String taskId) async {
    // 读取旧分流记录，旧任务可能没有任何分流，此时直接让新计划继续。
    final streams = await _repository.loadStreams(taskId);
    for (final stream in streams) {
      // 引擎任务 ID 是清理 aria2 GID 或系统任务的唯一入口。
      final engineTaskId = stream.engineTaskId;
      if (engineTaskId == null || engineTaskId.isEmpty) continue;
      // 手动重试代表用户重新开始，旧自动刷新次数不应影响新一轮下载。
      _automaticUrlRefreshCountsByEngineTaskId.remove(engineTaskId);
      try {
        // 主动取消旧占位会产生 canceled 事件，必须忽略以免覆盖新重试状态。
        _ignoredCanceledEngineTaskIds.add(engineTaskId);
        await _downloadEngine.cancel(engineTaskId);
      } catch (error) {
        // 旧占位可能已由引擎清掉；清理失败不应阻止新解析地址继续提交。
        _ignoredCanceledEngineTaskIds.remove(engineTaskId);
        AppDebugLog.aria2(
          'Retry cleanup skipped task=$taskId engineTask=$engineTaskId '
          'error=$error',
        );
      }
    }
  }

  /// 两条分流全部暂停时把主任务推进到暂停阶段。
  Future<void> _pauseTaskWhenAllStreamsPaused(String taskId) async {
    // 查询同一任务最新的两条分流状态。
    final streams = await _repository.loadStreams(taskId);
    // 完成分流无需暂停，其余分流必须全部已经 paused。
    final allInactive =
        streams.isNotEmpty &&
        streams.every(
          (stream) =>
              stream.phase == DownloadStreamPhase.completed ||
              stream.phase == DownloadStreamPhase.paused,
        );
    // 仍有排队或下载分流时等待后续事件。
    if (!allInactive) return;
    // 使用安全转换避免重复暂停事件引发异常。
    await _transitionIfAllowed(taskId, DownloadTaskPhase.paused);
  }

  /// 两条分流全部完成后进入等待合并或自动合并。
  Future<void> _handleStreamsCompleted(String taskId) async {
    // 查询最新分流状态，避免只根据单条完成事件做判断。
    final streams = await _repository.loadStreams(taskId);
    // 单流和双流任务都以当前实际分流全部完成作为后处理条件。
    final allCompleted =
        streams.isNotEmpty &&
        streams.every(
          (stream) => stream.phase == DownloadStreamPhase.completed,
        );
    // 条件未满足时继续等待另一条分流。
    if (!allCompleted) return;
    // 读取主任务最新阶段，失败、取消、完成或暂停任务不能被迟到事件自动重新启动。
    final task = await _repository.findTask(taskId);
    if (task == null ||
        (task.phase != DownloadTaskPhase.downloading &&
            task.phase != DownloadTaskPhase.waitingForMerge &&
            task.phase != DownloadTaskPhase.merging)) {
      return;
    }
    // iOS 等平台不保证后台合并窗口，先持久化等待状态。
    if (!autoMergeCompletedStreams) {
      await _transitionIfAllowed(taskId, DownloadTaskPhase.waitingForMerge);
      return;
    }
    // 允许自动合并的平台把任务加入串行合并队列。
    unawaited(_scheduleMergeSilently(taskId));
  }

  /// 执行单个任务的文件校验、FFmpeg 合并和最终状态写入。
  Future<void> _mergeTask(String taskId) async {
    // 读取主任务和两条分流的最新持久化数据。
    final task = await _requireTask(taskId);
    // 只允许下载完成、等待合并或恢复中断合并的任务进入 FFmpeg。
    if (task.phase != DownloadTaskPhase.downloading &&
        task.phase != DownloadTaskPhase.waitingForMerge &&
        task.phase != DownloadTaskPhase.merging) {
      throw StateError('Task $taskId cannot merge from ${task.phase.name}.');
    }
    final streams = await _repository.loadStreams(taskId);
    // 当前实际选择的一条或两条分流都必须完成后才能进入媒体或附加资源后处理。
    if (streams.isEmpty ||
        streams.length > 2 ||
        streams.any(
          (stream) => stream.phase != DownloadStreamPhase.completed,
        )) {
      throw StateError('Task $taskId does not have completed media streams.');
    }
    // 非音频附加资源不进入 FFmpeg；下载完成后按类型复制或转换为最终文件。
    final extraResource = downloadExtraResourceFromCode(task.contentType);
    if (extraResource != null && extraResource != DownloadExtraResource.audio) {
      await _standaloneExtraResourceFinalizer.finalize(
        task,
        streams,
        extraResource,
        transitionIfAllowed: _transitionIfAllowed,
        reportCleanupError: _emitError,
      );
      return;
    }
    // 转换仓库记录为不含数据库依赖的合并规划输入。
    final mergeInputs = resolveCompletedMediaInputs(
      taskId: taskId,
      streams: streams.map(
        (stream) => (
          kind: stream.kind,
          phase: stream.phase,
          temporaryPath: stream.temporaryPath,
        ),
      ),
    );
    // 最终输出路径必须由解析和命名流程提前确定。
    final outputPath = task.outputPath;
    if (outputPath == null || outputPath.isEmpty) {
      throw StateError('Task $taskId has no output path.');
    }
    // 把下载或等待状态推进到合并，并把阶段进度重置为零。
    await _transitionIfAllowed(taskId, DownloadTaskPhase.merging);
    // Android 默认任务在 `.temp/<taskId>` 合并，其他情况直接使用最终文件路径。
    final workingOutputPath = await _mediaOutputPublisher.prepareOutputPath(
      requestedOutputPath: outputPath,
      temporaryDirectory: task.temporaryDirectory,
    );
    // 保存活动任务 ID，使 FFmpeg 统计回调能够写入对应任务。
    _activeMergeTaskId = taskId;
    try {
      // 调用跨平台合并器执行无损封装。
      await _mediaMerger.merge(
        MediaMergeRequest(
          videoPath: mergeInputs.videoPath,
          audioPath: mergeInputs.audioPath,
          outputPath: workingOutputPath,
          expectedDuration: task.durationMilliseconds == null
              ? null
              : Duration(milliseconds: task.durationMilliseconds!),
        ),
      );
      // 等待此前收到的 FFmpeg 进度全部写库，避免完成后迟到进度降低百分之百状态。
      await _mergeProgressQueue;
      // 发布前读取真实文件大小，用于产物记录和完整性检查。
      final outputFile = File(workingOutputPath);
      final outputSize = await outputFile.length();
      // 附加资源必须在主视频登记和临时音频流清理前完成，失败时不会留下半成品记录。
      await _extraResourceProcessor.process(task: task, streams: streams);
      // 全部资源成功后登记最终真实路径，删除和转换都基于这条路径。
      final publishedOutput = await _mediaOutputPublisher.publish(
        workingOutputPath: workingOutputPath,
        requestedOutputPath: outputPath,
      );
      // 全部附加资源成功后再登记主视频，避免资源失败任务被启动一致性扫描误判为完成。
      await _repository.upsertArtifact(
        DownloadArtifactDraft(
          taskId: taskId,
          kind: DownloadArtifactKind.output,
          path: publishedOutput.storageIdentifier,
          sizeBytes: outputSize,
          retained: true,
        ),
      );
      // 所有文件操作成功后才能写入 completed 终态。
      await _transitionIfAllowed(taskId, DownloadTaskPhase.completed);
      // 覆盖同名成品成功后移除旧终态记录，避免旧卡片继续指向并删除新文件。
      await _completionCleanup.cleanupSupersededOutputRecords(
        outputPath,
        keepingTaskId: taskId,
        newStorageIdentifier: publishedOutput.storageIdentifier,
      );
      // 成品和产物记录均已落地后删除当前任务分流目录，避免 `.temp` 长期堆积。
      await _completionCleanup.cleanupCompletedTaskTemporaryDirectory(
        task,
        reportError: _emitError,
      );
    } on MediaMergeCanceledException {
      // 用户取消整个任务时保留 canceled；应用销毁中断则回到等待合并。
      final current = await _repository.findTask(taskId);
      if (current != null && current.phase != DownloadTaskPhase.canceled) {
        // 合并阶段不再提供暂停，意外中断统一回到等待合并以便后续恢复。
        await _transitionIfAllowed(taskId, DownloadTaskPhase.waitingForMerge);
      }
      rethrow;
    } catch (error) {
      // FFmpeg 或文件操作失败时保存错误，输入临时流仍保留供重试。
      await _transitionIfAllowed(
        taskId,
        DownloadTaskPhase.failed,
        errorCode: 'merge_failed',
        errorMessage: biliUserMessage(error, fallback: '合并或保存文件失败，请重试。'),
      );
      rethrow;
    } finally {
      // 只清除当前同一任务，避免旧回调覆盖下一项合并。
      if (_activeMergeTaskId == taskId) _activeMergeTaskId = null;
    }
  }

  /// 自动调度合并并消费显式 Future 错误，诊断信息仍由错误流保留。
  Future<void> _scheduleMergeSilently(String taskId) async {
    try {
      // 复用公开合并排队逻辑。
      await mergeTaskNow(taskId);
    } catch (_) {
      // 自动流程没有直接调用方，异常已经由 mergeTaskNow 广播，无需重复抛出。
    }
  }

  /// 仅在状态机允许时更新任务阶段，适合处理重复或迟到的引擎事件。
  Future<void> _transitionIfAllowed(
    String taskId,
    DownloadTaskPhase next, {
    String? errorCode,
    String? errorMessage,
  }) async {
    // 读取最新状态，避免使用事件入队时的旧快照。
    final task = await _repository.findTask(taskId);
    // 已经清理的任务不再处理迟到事件。
    if (task == null) return;
    // 非法或终态之后的迟到事件直接忽略。
    if (!DownloadTaskStateMachine.canTransition(task.phase, next)) return;
    // 调用仓库事务执行最终校验和写入。
    await _repository.transitionTask(
      taskId,
      next,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }

  /// 查询必须存在的主任务。
  Future<DownloadTaskRecord> _requireTask(String taskId) async {
    // 从 Drift 主表读取最新任务。
    final task = await _repository.findTask(taskId);
    // 不存在时抛出明确错误，阻止后续文件或引擎操作。
    if (task == null) throw StateError('Unknown download task: $taskId');
    // 返回已经通过空检查的任务记录。
    return task;
  }

  /// 向诊断流广播异步错误。
  void _emitError(String? taskId, Object error, StackTrace stackTrace) {
    // 协调器释放后错误流已经关闭，不再发送新事件。
    if (_errors.isClosed) return;
    // 保存任务关联、原始异常和堆栈供日志模块处理。
    _errors.add(
      DownloadCoordinatorError(
        taskId: taskId,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  /// 确保公开操作不会在协调器释放后执行。
  void _ensureNotDisposed() {
    // 释放后的订阅、错误流和队列均不可继续使用。
    if (_disposed) throw StateError('DownloadTaskCoordinator is disposed.');
  }
}
