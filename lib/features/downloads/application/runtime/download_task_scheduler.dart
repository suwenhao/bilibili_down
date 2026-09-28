import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/logging/app_debug_log.dart';
import '../../../../core/network/network_availability_provider.dart';
import '../../../../services/bilibili/bili_api_exception.dart';
import '../../../../services/download_engine/aria2/aria2_error_policy.dart';
import '../../../../services/download_engine/aria2/aria2_process_controller.dart';
import '../../../../services/download_engine/aria2/aria2_rpc_client.dart';
import '../../../settings/application/app_settings_controller.dart';
import '../../../settings/domain/app_settings.dart';
import '../../data/download_task_repository.dart';
import '../../domain/download_task_phase.dart';
import 'download_task_launch_service.dart';

/// 在任何调度器启动前暂停上次进程遗留的活动任务，禁止应用重启后自动续传。
final downloadTaskStartupPauseProvider = FutureProvider<int>((Ref ref) async {
  // 启动恢复只修改持久化状态，不会创建 aria2、FFmpeg 或系统下载任务。
  final repository = ref.watch(downloadTaskRepositoryProvider);
  // 原子保存暂停状态和原恢复阶段，后续必须由用户点击继续。
  final pausedCount = await repository.pauseInterruptedTasks();
  // 日志只记录数量，不包含任务标题、地址或本地路径。
  AppDebugLog.aria2('Startup paused interrupted tasks count=$pausedCount.');
  // 返回数量便于启动界面确认恢复事务已经完成。
  return pausedCount;
});

/// 提供跨页面持续运行的业务下载并发调度器。
final downloadTaskSchedulerProvider = Provider<DownloadTaskScheduler>((
  Ref ref,
) {
  // 调度器复用应用级仓库、启动服务和设置控制器。
  final repository = ref.watch(downloadTaskRepositoryProvider);
  final launchService = ref.watch(downloadTaskLaunchServiceProvider);
  final settingsController = ref.read(appSettingsControllerProvider.notifier);
  // 设置加载器确保应用首帧不会用默认并发数覆盖已保存值。
  final scheduler = DownloadTaskScheduler(
    repository,
    launchService,
    settingsController.loadReadySettings,
  );
  // 用户修改并发数后立即尝试补充空闲启动名额。
  ref.listen<AppSettings>(appSettingsControllerProvider, (_, _) {
    scheduler.notifyConcurrencyChanged();
  });
  // 网络接口断开时停止认领新任务，恢复后立即继续等待队列。
  ref.listen<AsyncValue<bool>>(networkAvailabilityProvider, (_, next) {
    next.whenData(scheduler.setNetworkAvailable);
  }, fireImmediately: true);
  // Provider 销毁时停止数据库监听，不再启动新的等待任务。
  ref.onDispose(() => unawaited(scheduler.dispose()));
  return scheduler;
});

/// 把持久化等待任务按用户设置的业务并发数交给启动服务。
final class DownloadTaskScheduler {
  /// 创建调度器并立即监听任务阶段变化。
  DownloadTaskScheduler(
    this._repository,
    DownloadTaskLaunchService launchService,
    this._settingsLoader,
  ) : _launchTask = launchService.start {
    _listenToTasks();
  }

  /// 创建使用可替换启动回调的调度器，供后台恢复和单元测试验证提交边界。
  DownloadTaskScheduler.withLaunchCallback(
    this._repository,
    Future<void> Function(String taskId) launchTask,
    this._settingsLoader,
  ) : _launchTask = launchTask {
    _listenToTasks();
  }

  /// 建立唯一 Drift 任务快照订阅。
  void _listenToTasks() {
    // 调度只依赖等待、解析、下载和可恢复暂停阶段，不加载失败与完成历史。
    _taskSubscription = _repository
        .watchTasksByPhases(const <DownloadTaskPhase>[
          DownloadTaskPhase.waitingToStart,
          DownloadTaskPhase.resolving,
          DownloadTaskPhase.downloading,
          DownloadTaskPhase.paused,
        ], sortOrder: DownloadTaskSortOrder.oldestCreated)
        .listen(
          _handleTasks,
          onError: (Object error, StackTrace stackTrace) {
            // 数据库监听失败无法继续调度，记录错误供诊断但不影响现有下载。
            AppDebugLog.aria2('Scheduler task stream error=$error');
          },
        );
  }

  /// 持久化任务和阶段转换仓库。
  final DownloadTaskRepository _repository;

  /// 负责刷新 DASH 地址并提交单个业务任务的可等待回调。
  final Future<void> Function(String taskId) _launchTask;

  /// 返回已经恢复本地偏好的最新设置。
  final Future<AppSettings> Function() _settingsLoader;

  /// 实时任务快照，用于统计运行槽位和等待顺序。
  List<DownloadTaskRecord> _tasks = const <DownloadTaskRecord>[];

  /// 首份 Drift 快照到达信号，后台恢复不能在空初始列表上提前结束。
  final Completer<void> _firstSnapshot = Completer<void>();

  /// 已被本次进程认领的等待任务，防止 Drift 快照延迟导致重复启动。
  final Set<String> _claimedTaskIds = <String>{};

  /// 正在执行 DASH 解析和引擎提交的任务 ID。
  final Set<String> _launchingTaskIds = <String>{};

  /// 正在运行的启动任务，应用退出时需要等待它们结束清理。
  final Set<Future<void>> _launchFutures = <Future<void>>{};

  /// 后台恢复任务等待本轮泵和提交调用全部结束的完成信号。
  final Set<Completer<void>> _idleWaiters = <Completer<void>>{};

  /// Drift 全任务监听订阅。
  late final StreamSubscription<List<DownloadTaskRecord>> _taskSubscription;

  /// 是否已有一轮槽位计算正在运行。
  bool _pumping = false;

  /// 当前泵运行期间是否又收到需要重算的事件。
  bool _pumpRequested = false;

  /// Provider 已销毁后禁止继续分配新任务。
  bool _disposed = false;

  /// 当前是否存在网络接口；该信号不替代真实请求可用性判断。
  bool _networkAvailable = true;

  /// 下载引擎全局启动失败后暂停自动泵送，避免批量任务连续变失败。
  bool _launchBlockedByGlobalFailure = false;

  /// 原子移动一批待下载任务，并立即触发并发调度。
  Future<int> startBatch(Iterable<String> taskIds) async {
    // 仓库事务保证界面只看到一次完整的页签迁移。
    final queuedTaskIds = await _repository.queueTasksForStart(taskIds);
    // 用户显式再次启动时解除上次全局失败止损，允许重新探测后端状态。
    if (queuedTaskIds.isNotEmpty) _launchBlockedByGlobalFailure = false;
    // 显式重试的任务需要清除本进程旧认领标记，允许重新启动。
    _claimedTaskIds.removeAll(queuedTaskIds);
    // 事务提交后主动调度，无需等待 Drift 查询流再次发出。
    _requestPump();
    // 返回真实成功进入下载中队列的数量供页面反馈。
    return queuedTaskIds.length;
  }

  /// 设置中的并发数变化后重新计算可用槽位。
  void notifyConcurrencyChanged() {
    // 只触发重算，不直接读取设置或修改任何任务阶段。
    _requestPump();
  }

  /// 更新网络接口状态，恢复联网时重新泵送持久化等待队列。
  void setNetworkAvailable(bool available) {
    // 相同状态不重复输出日志或触发无意义泵送。
    if (_networkAvailable == available) return;
    _networkAvailable = available;
    // 日志只记录布尔状态，不包含 Wi-Fi 名称或网络隐私信息。
    AppDebugLog.aria2('Scheduler network available=$available');
    if (available) {
      // 网络恢复代表上次连接类全局失败可能已经解除，允许等待队列重新探测。
      _launchBlockedByGlobalFailure = false;
      // 恢复网络后立即尝试认领此前保留在 waitingToStart 的任务。
      _requestPump();
    }
  }

  /// 执行一次可等待的恢复泵，供 WorkManager 短时后台任务调用。
  Future<void> runRecoveryPass() async {
    // 已释放调度器不能再创建后台恢复等待器。
    if (_disposed) return;
    // 等待首份真实数据库快照，避免后台 isolate 刚创建就误判没有任务。
    await _firstSnapshot.future.timeout(const Duration(seconds: 5));
    // 每个调用使用独立完成信号，允许前台和后台恢复安全复用。
    final completer = Completer<void>();
    _idleWaiters.add(completer);
    // 触发最新任务快照和并发槽位计算。
    _requestPump();
    _completeIdleWaitersIfNeeded();
    // iOS 后台执行时间有限，异常卡住时主动结束并交给系统下次重试。
    await completer.future.timeout(const Duration(seconds: 20));
  }

  /// 保存最新 Drift 快照并触发下一轮槽位计算。
  void _handleTasks(List<DownloadTaskRecord> tasks) {
    // 保存不可修改快照，避免监听源后续复用列表产生意外变化。
    _tasks = List<DownloadTaskRecord>.unmodifiable(tasks);
    // 首份快照建立后唤醒等待执行恢复泵的 WorkManager 任务。
    if (!_firstSnapshot.isCompleted) _firstSnapshot.complete();
    // 已离开等待阶段的认领记录无需长期保留，显式失败重试仍可再次排队。
    final waitingIds = tasks
        .where(
          (DownloadTaskRecord task) =>
              task.phase == DownloadTaskPhase.waitingToStart,
        )
        .map((DownloadTaskRecord task) => task.taskId)
        .toSet();
    _claimedTaskIds.removeWhere(
      (String taskId) =>
          !waitingIds.contains(taskId) && !_launchingTaskIds.contains(taskId),
    );
    // 任何阶段变化都可能释放或占用下载并发槽位。
    _requestPump();
  }

  /// 合并高频任务事件，保证同一时刻只有一个泵读取设置和分配槽位。
  void _requestPump() {
    // 生命周期结束后忽略数据库迟到事件。
    if (_disposed) return;
    // 标记至少还需要执行一轮最新状态计算。
    _pumpRequested = true;
    if (_pumping) return;
    // 后台调度失败会在任务级启动流程中转换为 failed，不抛到界面事件循环。
    unawaited(_runPump());
  }

  /// 持续处理泵运行期间累积的状态变化。
  Future<void> _runPump() async {
    // 锁定泵生命周期，避免多个异步设置读取交叉分配同一槽位。
    _pumping = true;
    try {
      while (_pumpRequested && !_disposed) {
        // 消费当前请求；运行期间的新事件会再次把它设为 true。
        _pumpRequested = false;
        await _pumpOnce();
      }
    } catch (error) {
      // 设置读取等全局异常只中止本轮，后续任务变化仍可再次触发。
      AppDebugLog.aria2('Scheduler pump error=$error');
    } finally {
      // 解锁后若恰好收到新请求，立即开始下一轮。
      _pumping = false;
      if (_pumpRequested && !_disposed) _requestPump();
      // 没有后续泵时唤醒等待本次恢复提交完成的后台任务。
      _completeIdleWaitersIfNeeded();
    }
  }

  /// 根据真实活动任务数为最早等待的任务分配启动名额。
  Future<void> _pumpOnce() async {
    // 明确离线时保留 waitingToStart，不发起 DASH 或下载请求。
    if (!_networkAvailable) return;
    // 后端进程或 RPC 不可用时等待用户重新触发，不能继续消费等待队列。
    if (_launchBlockedByGlobalFailure) return;
    // 等待设置恢复并读取当前业务任务并发上限。
    final settings = await _settingsLoader();
    // 设置等待期间 Provider 可能已经进入退出清理，不能再认领任务。
    if (_disposed || !_networkAvailable) return;
    // resolving 和 downloading 占用网络启动槽位；等待合并后即可让下一项下载。
    final activeTaskIds = _tasks
        .where((DownloadTaskRecord task) {
          return task.phase == DownloadTaskPhase.resolving ||
              task.phase == DownloadTaskPhase.downloading ||
              // 已暂停的解析或下载保留原槽位，恢复时不会突破并发上限。
              (task.phase == DownloadTaskPhase.paused &&
                  (task.resumePhase == DownloadTaskPhase.resolving ||
                      task.resumePhase == DownloadTaskPhase.downloading));
        })
        .map((DownloadTaskRecord task) => task.taskId)
        .toSet();
    // 尚未写入活动阶段的启动调用占用槽位；已经进入 resolving 的调用不能重复计数。
    final preparingLaunchCount = _launchingTaskIds
        .where((String taskId) => !activeTaskIds.contains(taskId))
        .length;
    final availableSlots =
        settings.concurrentDownloads -
        activeTaskIds.length -
        preparingLaunchCount;
    // 没有空闲槽位时等待后续阶段变化。
    if (availableSlots <= 0) return;
    // 等待任务使用与下载中页面一致的稳定顺序，确保界面队首就是下一条启动任务。
    final waitingTasks =
        _tasks
            .where(
              (DownloadTaskRecord task) =>
                  task.phase == DownloadTaskPhase.waitingToStart &&
                  !_claimedTaskIds.contains(task.taskId),
            )
            .toList(growable: false)
          ..sort((DownloadTaskRecord left, DownloadTaskRecord right) {
            // 创建时间不同优先按加入时间处理，保持标准先进先出语义。
            final createdAtComparison = left.createdAt.compareTo(
              right.createdAt,
            );
            if (createdAtComparison != 0) return createdAtComparison;
            // 批量写入可能共享时间戳，任务 ID 与仓库查询使用同一升序兜底。
            return left.taskId.compareTo(right.taskId);
          });
    // 只认领当前空闲名额数量，剩余任务继续持久化等待。
    for (final task in waitingTasks.take(availableSlots)) {
      // 认领必须先于异步启动，避免同一泵中的后续任务重复选择。
      _claimedTaskIds.add(task.taskId);
      _launchingTaskIds.add(task.taskId);
      // 按队列逐条解析并提交，防止后面的任务因接口响应更快而抢先进入下载引擎。
      final launchFuture = _launch(task.taskId);
      // 保存 Future 供退出链路等待，完成后立即释放引用。
      _launchFutures.add(launchFuture);
      try {
        // 这里只串行化启动提交；任务进入下载引擎后仍由并发设置同时下载。
        await launchFuture;
      } finally {
        // 启动提交结束后释放引用，并检查后台恢复是否可以返回。
        _launchFutures.remove(launchFuture);
        _completeIdleWaitersIfNeeded();
      }
      // 全局下载引擎失败会让等待队列回退，当前快照里的后续任务不能继续启动。
      if (_launchBlockedByGlobalFailure) break;
    }
  }

  /// 在调度器没有泵或启动提交时完成全部后台等待器。
  void _completeIdleWaitersIfNeeded() {
    // 任一泵、重算请求或启动 Future 存在时仍有恢复工作未结束。
    if (_pumping || _pumpRequested || _launchFutures.isNotEmpty) return;
    // 使用快照完成信号，回调可能同步触发集合修改。
    final waiters = _idleWaiters.toList(growable: false);
    _idleWaiters.clear();
    for (final waiter in waiters) {
      // 防止超时或释放路径已经完成同一信号。
      if (!waiter.isCompleted) waiter.complete();
    }
  }

  /// 启动单个已认领任务，并把准备阶段异常持久化为失败。
  Future<void> _launch(String taskId) async {
    // 记录是否需要在启动失败后主动补充空闲槽位。
    var failed = false;
    // 全局后端故障需要停止继续泵送，不能让并发队列批量进入失败态。
    var globalFailure = false;
    try {
      // 启动服务负责刷新临时 URL、生成计划并提交下载引擎。
      await _launchTask(taskId);
    } catch (error) {
      // 失败任务不会继续占用并发名额，清理完成后需要重新运行调度泵。
      failed = true;
      globalFailure = _isGlobalLaunchFailure(error);
      if (globalFailure) {
        // 先设置止损开关，防止失败阶段事件触发的新泵继续认领后续任务。
        _launchBlockedByGlobalFailure = true;
      }
      // 解析器在协调器接管前失败时，任务可能仍停留在等待或解析阶段。
      try {
        // 重新读取最新阶段，协调器已经写入 failed 时不重复转换。
        final current = await _repository.findTask(taskId);
        if (current != null &&
            (current.phase == DownloadTaskPhase.waitingToStart ||
                current.phase == DownloadTaskPhase.resolving)) {
          // 启动错误只影响当前任务；账号失效已由网络层尝试游客回退。
          await _repository.transitionTask(
            taskId,
            DownloadTaskPhase.failed,
            errorCode: 'scheduled_start_failed',
            errorMessage: _launchFailureMessage(error),
          );
        }
        if (globalFailure) {
          // 后端不可用属于全局问题，其他尚未真正启动的任务退回待下载等待用户重试。
          final requeued = await _repository.requeueWaitingToStartTasks(
            exceptTaskId: taskId,
          );
          // 清理内存认领标记，避免回退任务下次显式启动时被旧标记拦住。
          _claimedTaskIds.clear();
          AppDebugLog.aria2(
            'Scheduler launch blocked after global failure task=$taskId '
            'requeued=$requeued',
          );
        }
      } catch (persistError) {
        // 数据库关闭或阶段竞争不能制造未处理 Future，保留诊断后交给恢复流程。
        AppDebugLog.aria2(
          'Scheduler failure persistence task=$taskId error=$persistError',
        );
      }
      // 日志只记录业务 ID 和错误，不包含临时媒体地址。
      AppDebugLog.aria2('Scheduler launch failed task=$taskId error=$error');
    } finally {
      // 当前启动调用结束后释放内存标记；主任务阶段变化会触发下一轮泵。
      _launchingTaskIds.remove(taskId);
      // 失败阶段事件可能早于内存标记清理，显式重算避免等待队列停滞。
      if (failed && !globalFailure) _requestPump();
    }
  }

  /// 判断失败是否来自下载引擎整体不可用，而不是单个视频或网络请求失败。
  bool _isGlobalLaunchFailure(Object error) {
    // aria2 进程无法启动时，继续启动后续任务只会批量失败。
    if (error is Aria2ProcessException) return true;
    if (error is Aria2RpcException) {
      // 业务级 RPC 错误只影响当前任务，连接或协议根因才需要暂停整条队列。
      final kind = classifyAria2Error(error);
      if (kind == Aria2ErrorKind.noUri ||
          kind == Aria2ErrorKind.gidConflict ||
          kind == Aria2ErrorKind.gidMissing ||
          kind == Aria2ErrorKind.httpStatus ||
          kind == Aria2ErrorKind.busyState) {
        return false;
      }
      return error.cause != null || isAria2TransportFailure(error);
    }
    // Dio 等底层异常可能从 aria2 JSON-RPC 直抛，只识别连接层不可用特征。
    final message = error.toString().toLowerCase();
    return message.contains('/jsonrpc') ||
        message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('connection timed out') ||
        message.contains('failed host lookup');
  }

  /// 生成持久化到任务卡片的启动失败文案。
  String _launchFailureMessage(Object error) {
    // 全局后端错误对用户说处理方式，不暴露 RPC、Dio 或进程类名。
    if (_isGlobalLaunchFailure(error)) {
      return '下载引擎启动失败，请重启应用或稍后重试。';
    }
    final aria2Message = aria2UserMessage(error, fallback: '');
    if (aria2Message.isNotEmpty) return aria2Message;
    // 单任务解析或接口错误使用 B 站服务层转换后的业务文案。
    return biliUserMessage(error, fallback: '下载准备失败，请重试。');
  }

  /// 停止监听并阻止新的等待任务进入启动流程。
  Future<void> dispose() async {
    // 重复释放保持幂等，退出链路和 Provider 销毁可以安全复用。
    if (_disposed) return;
    _disposed = true;
    // 数据库首快照尚未到达时也必须允许退出流程结束等待。
    if (!_firstSnapshot.isCompleted) _firstSnapshot.complete();
    // 退出时唤醒所有后台恢复等待器，不能让 WorkManager isolate 悬挂。
    for (final waiter in _idleWaiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _idleWaiters.clear();
    // 取消 Drift 订阅后不再响应数据库阶段变化。
    await _taskSubscription.cancel();
    // 已经认领的启动仍需完成或写入失败，避免协调器先于它们被释放。
    await Future.wait<void>(_launchFutures.toList(growable: false));
  }
}
