import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../../../core/notifications/app_notification_service.dart';
import '../../../../core/sound/app_sound_service.dart';
import '../../domain/download_task_phase.dart';
import '../../data/download_task_repository.dart';
import '../lifecycle/automatic_shutdown_controller.dart';

/// 启动应用级下载状态声音观察器。
final downloadSoundObserverProvider = Provider<DownloadSoundObserver>((
  Ref ref,
) {
  // 注入持久任务流和统一音效服务，页面是否打开不影响状态声音。
  final notificationService = ref.watch(appNotificationServiceProvider);
  final observer = DownloadSoundObserver(
    ref.watch(downloadTaskRepositoryProvider).watchTaskPhaseSnapshots(),
    ref.watch(appSoundServiceProvider),
    onTasksFailed: (int count) =>
        unawaited(notificationService.showTasksFailed(count)),
    onBatchCompleted: (Set<String> taskIds) {
      // 完成通知和自动关机共享同一批次成功事件，但各自失败互不影响。
      unawaited(notificationService.showBatchCompleted());
      unawaited(
        ref
            .read(automaticShutdownControllerProvider.notifier)
            .scheduleAfterCompletedBatch(taskIds),
      );
    },
    onBatchAborted: (Set<String> taskIds) {
      // 失败、取消或删除会撤销命中的一次性计划，不能沿用到后续批次。
      ref.read(automaticShutdownPlanProvider.notifier).disarmForBatch(taskIds);
    },
  );
  // 应用退出或数据库重建时取消 Drift 监听。
  ref.onDispose(() => unawaited(observer.dispose()));
  return observer;
});

/// 观察任务阶段跃迁，去重播放下载成功和失败声音。
final class DownloadSoundObserver {
  /// 创建观察器并立即订阅任务快照。
  DownloadSoundObserver(
    Stream<List<DownloadTaskPhaseSnapshot>> tasks,
    this._soundService, {
    this.onTasksFailed,
    this.onBatchCompleted,
    this.onBatchAborted,
  }) {
    // Drift 快照串行发出，可直接用前后阶段判断真实跃迁。
    _subscription = tasks.listen(_handleTasks);
  }

  /// 播放状态音且实时遵循设置开关。
  final AppSoundService _soundService;

  /// 同一快照中新进入失败状态的任务数量回调。
  final void Function(int count)? onTasksFailed;

  /// 整轮任务全部成功后触发自动关机等应用级后续动作。
  final void Function(Set<String> taskIds)? onBatchCompleted;

  /// 整轮任务包含失败、取消或删除时通知安全层撤销一次性计划。
  final void Function(Set<String> taskIds)? onBatchAborted;

  /// 持久任务流订阅。
  late final StreamSubscription<List<DownloadTaskPhaseSnapshot>> _subscription;

  /// 上一份任务阶段，用于识别首次进入 failed 而不是历史失败记录。
  Map<String, DownloadTaskPhase> _previousPhases =
      <String, DownloadTaskPhase>{};

  /// 本轮曾进入非暂停活动状态的任务 ID。
  final Set<String> _trackedTaskIds = <String>{};

  /// 本轮失败且尚未通过重试重新进入活动状态的任务 ID。
  final Set<String> _failedTaskIds = <String>{};

  /// 首份数据库快照只建立基线，不为历史完成或失败记录播放声音。
  bool _initialized = false;

  /// 处理一份完整任务快照并判断错误或整轮成功。
  void _handleTasks(List<DownloadTaskPhaseSnapshot> tasks) {
    // 当前任务按稳定业务 ID 建索引，后续集合判断无需反复遍历。
    final current = <String, DownloadTaskPhase>{
      for (final task in tasks) task.taskId: task.phase,
    };
    // 首份快照记录当前活动任务，使应用恢复后仍能在完成时提示。
    if (!_initialized) {
      _previousPhases = <String, DownloadTaskPhase>{
        for (final task in tasks) task.taskId: task.phase,
      };
      _trackedTaskIds.addAll(
        tasks
            .where(_isActive)
            .map((DownloadTaskPhaseSnapshot task) => task.taskId),
      );
      _initialized = true;
      return;
    }

    // 新进入活动状态的任务加入同一轮完成判断；暂停和 queued 不参与。
    for (final task in tasks.where(_isActive)) {
      _trackedTaskIds.add(task.taskId);
      // 失败任务重试后重新具备成功资格。
      _failedTaskIds.remove(task.taskId);
    }

    // 仅阶段从非 failed 进入 failed 时播放一次错误音。
    final newlyFailed = tasks
        .where((DownloadTaskPhaseSnapshot task) {
          // 当前必须为失败，历史阶段缺失或已失败都不重复提示。
          return task.phase == DownloadTaskPhase.failed &&
              _previousPhases[task.taskId] != DownloadTaskPhase.failed;
        })
        .toList(growable: false);
    if (newlyFailed.isNotEmpty) {
      // 同一数据库快照包含多个失败时只播放一次，避免声音叠加。
      _soundService.play(AppSoundEffect.error);
      // 记录本轮失败任务；重试进入活动后会移除。
      _failedTaskIds.addAll(
        newlyFailed.map((DownloadTaskPhaseSnapshot task) => task.taskId),
      );
      // 系统通知与错误音复用相同去重结果，同一失败阶段只提示一次。
      onTasksFailed?.call(newlyFailed.length);
    }

    // 暂停任务明确不属于“非暂停的所有任务”，恢复后会作为新活动任务重新加入。
    final pausedTaskIds = _trackedTaskIds
        .where((String taskId) {
          // 任务仍存在且阶段为 paused 时从本轮成功判断中排除。
          return current[taskId] == DownloadTaskPhase.paused;
        })
        .toList(growable: false);
    // 先移除暂停任务，避免它阻止其他仍运行任务完成后的 success 音。
    _trackedTaskIds.removeAll(pausedTaskIds);
    _failedTaskIds.removeAll(pausedTaskIds);

    // 只有实际观察过活动任务时才可能播放整轮成功音。
    if (_trackedTaskIds.isNotEmpty) {
      // 被删除的任务视为未成功终止，不能触发 success。
      final trackedPhases = _trackedTaskIds
          .map((String taskId) => current[taskId])
          .toList(growable: false);
      // 所有非暂停活动任务最终都 completed，且失败均已成功重试，才播放一次成功音。
      final allCompleted = trackedPhases.every(
        (DownloadTaskPhase? phase) => phase == DownloadTaskPhase.completed,
      );
      if (allCompleted && _failedTaskIds.isEmpty) {
        _soundService.play(AppSoundEffect.success);
        // 回调使用不可修改快照，清理内部集合后仍可精确校验已确认批次。
        final completedTaskIds = Set<String>.unmodifiable(_trackedTaskIds);
        // 成功音与批次完成回调共享同一去重判定，每轮只触发一次。
        onBatchCompleted?.call(completedTaskIds);
        _clearBatch();
      } else {
        // 全部已进入终态但包含失败、取消或删除时结束本轮且不播放成功音。
        final allTerminal = trackedPhases.every(_isTerminalOrMissing);
        if (allTerminal) {
          // 先通知计划层当前终止批次，再清空用于匹配的任务 ID。
          onBatchAborted?.call(Set<String>.unmodifiable(_trackedTaskIds));
          _clearBatch();
        }
      }
    }

    // 保存当前阶段作为下一次 Drift 快照的比较基线。
    _previousPhases = <String, DownloadTaskPhase>{
      for (final task in tasks) task.taskId: task.phase,
    };
  }

  /// 判断任务是否属于下载中且非暂停的活动阶段。
  bool _isActive(DownloadTaskPhaseSnapshot task) => switch (task.phase) {
    DownloadTaskPhase.waitingToStart ||
    DownloadTaskPhase.resolving ||
    DownloadTaskPhase.downloading ||
    DownloadTaskPhase.waitingForMerge ||
    DownloadTaskPhase.merging => true,
    _ => false,
  };

  /// 判断本轮任务是否已经结束且不再等待暂停任务恢复。
  bool _isTerminalOrMissing(DownloadTaskPhase? phase) => switch (phase) {
    null ||
    DownloadTaskPhase.completed ||
    DownloadTaskPhase.failed ||
    DownloadTaskPhase.canceled => true,
    _ => false,
  };

  /// 清除本轮任务与失败标记，为下一批活动任务重新计数。
  void _clearBatch() {
    // 两个集合必须同时清理，否则下一批会继承旧失败状态。
    _trackedTaskIds.clear();
    _failedTaskIds.clear();
  }

  /// 取消数据库任务流监听。
  Future<void> dispose() => _subscription.cancel();
}
