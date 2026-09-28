import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/logging/app_debug_log.dart';
import '../../../../core/platform/android_app_permissions.dart';
import '../../../../core/platform/output_path_policy.dart';
import '../../../../core/platform/platform_providers.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../services/media_output/media_output_publisher.dart';
import '../../../settings/application/app_settings_controller.dart';
import '../../../settings/application/download_directory_selection_service.dart';
import '../../application/lifecycle/automatic_shutdown_controller.dart';
import '../../application/maintenance/download_file_deletion_planner.dart';
import '../../application/queue/download_queue_service.dart';
import '../../application/resources/batch_extra_resource_export_service.dart';
import '../../application/runtime/download_task_coordinator.dart';
import '../../application/runtime/download_task_coordinator_provider.dart';
import '../../application/runtime/download_task_launch_service.dart';
import '../../application/runtime/download_task_scheduler.dart';
import '../../application/ui_state/download_task_quality_service.dart';
import '../../application/ui_state/download_task_query_providers.dart';
import '../../domain/download_extra_resource.dart';
import '../../domain/download_task_phase.dart';
import '../../domain/stored_dash_options.dart';
import '../dialogs/download_batch_export_dialog.dart';
import '../dialogs/download_custom_batch_dialog.dart';
import '../dialogs/download_deletion_dialogs.dart';
import '../dialogs/download_retry_dialog.dart';
import '../dialogs/download_shutdown_dialog.dart';
import '../download_custom_batch_page.dart';
import '../models/download_custom_batch_result.dart';
import '../utils/download_task_error_messages.dart';
import '../utils/download_task_formatters.dart';
import '../../../../core/platform/default_download_directory.dart';

/// 下载任务页页面级状态和操作入口。
final downloadTasksPageControllerProvider =
    NotifierProvider<DownloadTasksPageController, DownloadTasksPageState>(
      DownloadTasksPageController.new,
    );

/// 启动任务后通知页面切换到下载中并跟踪完成状态的事件。
final class DownloadTasksSubmittedBatch {
  /// 创建一次任务提交事件。
  const DownloadTasksSubmittedBatch({
    required this.revision,
    required this.taskIds,
    required this.trackSubmittedTasks,
  });

  /// 单调递增事件序号，用于区分相同任务集合的重复提交。
  final int revision;

  /// 本次提交涉及的任务 ID。
  final Set<String> taskIds;

  /// 是否可以把提交任务纳入完成跟踪。
  final bool trackSubmittedTasks;
}

/// 下载任务页工具栏和卡片所需的忙碌状态。
final class DownloadTasksPageState {
  /// 创建下载任务页控制状态。
  const DownloadTasksPageState({
    required this.startingTaskIds,
    required this.togglingTaskIds,
    required this.startingAll,
    required this.togglingActiveTasks,
    required this.clearingActiveTasks,
    required this.clearingCompletedTasks,
    required this.completedDeletionProcessed,
    required this.completedDeletionTotal,
    this.submittedBatch,
  });

  /// 初始状态没有任何页面操作进行中。
  factory DownloadTasksPageState.initial() {
    return const DownloadTasksPageState(
      startingTaskIds: <String>{},
      togglingTaskIds: <String>{},
      startingAll: false,
      togglingActiveTasks: false,
      clearingActiveTasks: false,
      clearingCompletedTasks: false,
      completedDeletionProcessed: 0,
      completedDeletionTotal: 0,
    );
  }

  /// 正在启动的任务 ID。
  final Set<String> startingTaskIds;

  /// 正在等待暂停或继续结束的任务 ID。
  final Set<String> togglingTaskIds;

  /// 是否正在批量启动。
  final bool startingAll;

  /// 是否正在批量暂停或继续。
  final bool togglingActiveTasks;

  /// 是否正在清空下载中任务。
  final bool clearingActiveTasks;

  /// 是否正在清空已下载任务。
  final bool clearingCompletedTasks;

  /// 当前已下载清理进度。
  final int completedDeletionProcessed;

  /// 当前已下载清理总数。
  final int completedDeletionTotal;

  /// 最近一次成功提交下载任务的事件。
  final DownloadTasksSubmittedBatch? submittedBatch;

  /// 返回更新部分字段后的新状态。
  DownloadTasksPageState copyWith({
    Set<String>? startingTaskIds,
    Set<String>? togglingTaskIds,
    bool? startingAll,
    bool? togglingActiveTasks,
    bool? clearingActiveTasks,
    bool? clearingCompletedTasks,
    int? completedDeletionProcessed,
    int? completedDeletionTotal,
    DownloadTasksSubmittedBatch? submittedBatch,
  }) {
    return DownloadTasksPageState(
      startingTaskIds: startingTaskIds ?? this.startingTaskIds,
      togglingTaskIds: togglingTaskIds ?? this.togglingTaskIds,
      startingAll: startingAll ?? this.startingAll,
      togglingActiveTasks: togglingActiveTasks ?? this.togglingActiveTasks,
      clearingActiveTasks: clearingActiveTasks ?? this.clearingActiveTasks,
      clearingCompletedTasks:
          clearingCompletedTasks ?? this.clearingCompletedTasks,
      completedDeletionProcessed:
          completedDeletionProcessed ?? this.completedDeletionProcessed,
      completedDeletionTotal:
          completedDeletionTotal ?? this.completedDeletionTotal,
      submittedBatch: submittedBatch ?? this.submittedBatch,
    );
  }
}

/// 管理下载任务页中的业务动作和 busy 状态。
final class DownloadTasksPageController
    extends Notifier<DownloadTasksPageState> {
  /// 暂停或继续按钮最短禁用时间，防止快速连点穿透到底层下载后端。
  static const Duration _pauseToggleMinimumBusyDuration = Duration(
    milliseconds: 450,
  );

  /// 等待 Drift 任务阶段确认的最长时间，避免异常后端让按钮永久 loading。
  static const Duration _pauseToggleConfirmTimeout = Duration(seconds: 6);

  /// 暂停或继续后轮询任务阶段的间隔，保持界面响应和数据库压力平衡。
  static const Duration _pauseTogglePollInterval = Duration(milliseconds: 80);

  /// 待下载启动按钮最短 loading 时间，防止快速连点重复提交入队。
  static const Duration _startTaskMinimumBusyDuration = Duration(
    milliseconds: 450,
  );

  /// 等待待下载任务离开 queued/failed 的最长时间，避免异常状态永久锁住按钮。
  static const Duration _startTaskConfirmTimeout = Duration(seconds: 6);

  /// 启动后确认任务阶段的轮询间隔，复用轻量数据库读取即可。
  static const Duration _startTaskPollInterval = Duration(milliseconds: 80);

  /// 最近一次提交事件序号。
  int _submittedRevision = 0;

  /// 创建初始页面控制状态。
  @override
  DownloadTasksPageState build() => DownloadTasksPageState.initial();

  /// 快捷选择新的下载根目录并迁移尚未启动任务的目标路径。
  Future<void> changeStorage(BuildContext context) async {
    // 目录选择和任务路径同步都可能失败，统一在外层捕获并提示。
    try {
      AppDebugLog.download('Task storage change started');
      // 读取设置中心当前实际根目录作为选择器初始位置。
      final oldRoot = await ref.read(effectiveDownloadDirectoryProvider.future);
      // 两个页面共用同一套真实目录选择逻辑。
      final changed = await ref
          .read(downloadDirectorySelectionServiceProvider)
          .chooseAndSave(
            controller: ref.read(appSettingsControllerProvider.notifier),
            currentDisplayPath: oldRoot,
          );
      // 用户取消或选择原目录时无需更新任务。
      if (!changed) {
        AppDebugLog.download('Task storage change unchanged');
        return;
      }
      // 重新应用命名与高级存储规则并更新所有 queued 任务路径。
      final result = await ref
          .read(downloadQueueServiceProvider)
          .synchronizeQueuedTasks(refreshQuality: false);
      AppDebugLog.download(
        'Task storage changed synchronizeFailed=${result.failed}',
      );
      // 部分失败时保留成功任务结果并给出准确提示。
      if (context.mounted) {
        _showMessage(
          context,
          result.failed == 0
              ? '下载目录已更改。'
              : '下载目录已更改，${result.failed} 个待下载任务路径同步失败。',
          type: result.failed == 0
              ? AppSnackBarType.success
              : AppSnackBarType.warning,
        );
      }
    } catch (error) {
      AppDebugLog.download('Task storage change failed error=$error');
      // 页面仍存在时显示目录选择或迁移错误。
      if (context.mounted) {
        _showMessage(context, '更改下载目录失败：$error', type: AppSnackBarType.error);
      }
    }
  }

  /// 保存任务音频候选。
  Future<void> selectAudioQuality(
    BuildContext context,
    DownloadTaskRecord task,
    StoredAudioOption option,
  ) async {
    // 音质写库可能因候选失效或数据库异常失败。
    try {
      // 质量服务负责把候选写回任务记录并保持待下载路径不变。
      await ref
          .read(downloadTaskQualityServiceProvider)
          .selectAudio(task.taskId, option);
      AppDebugLog.download('Audio quality selected task=${task.taskId}');
    } catch (error) {
      AppDebugLog.download(
        'Audio quality select failed task=${task.taskId} error=$error',
      );
      // 页面还存在时才显示设置失败提示。
      if (context.mounted) {
        _showMessage(context, '音质设置失败：$error', type: AppSnackBarType.error);
      }
    }
  }

  /// 把任务音频选择设为无。
  Future<void> clearAudioQuality(
    BuildContext context,
    DownloadTaskRecord task,
  ) async {
    // 清空音质会触发底层组合校验，失败时保持旧选择。
    try {
      // 清除音频后任务会变为纯视频或无效组合，底层服务负责校验。
      await ref
          .read(downloadTaskQualityServiceProvider)
          .clearAudio(task.taskId);
      AppDebugLog.download('Audio quality cleared task=${task.taskId}');
    } catch (error) {
      AppDebugLog.download(
        'Audio quality clear failed task=${task.taskId} error=$error',
      );
      // 页面还存在时才显示设置失败提示。
      if (context.mounted) {
        _showMessage(context, '音质设置失败：$error', type: AppSnackBarType.error);
      }
    }
  }

  /// 保存任务视频候选。
  Future<void> selectVideoQuality(
    BuildContext context,
    DownloadTaskRecord task,
    StoredVideoOption option,
  ) async {
    // 画质写库可能因候选失效或数据库异常失败。
    try {
      // 质量服务负责把候选写回任务记录并保持待下载路径不变。
      await ref
          .read(downloadTaskQualityServiceProvider)
          .selectVideo(task.taskId, option);
      AppDebugLog.download('Video quality selected task=${task.taskId}');
    } catch (error) {
      AppDebugLog.download(
        'Video quality select failed task=${task.taskId} error=$error',
      );
      // 页面还存在时才显示设置失败提示。
      if (context.mounted) {
        _showMessage(context, '画质设置失败：$error', type: AppSnackBarType.error);
      }
    }
  }

  /// 把任务视频选择设为无。
  Future<void> clearVideoQuality(
    BuildContext context,
    DownloadTaskRecord task,
  ) async {
    // 清空画质会触发底层组合校验，失败时保持旧选择。
    try {
      // 清除视频后任务会变为纯音频或无效组合，底层服务负责校验。
      await ref
          .read(downloadTaskQualityServiceProvider)
          .clearVideo(task.taskId);
      AppDebugLog.download('Video quality cleared task=${task.taskId}');
    } catch (error) {
      AppDebugLog.download(
        'Video quality clear failed task=${task.taskId} error=$error',
      );
      // 页面还存在时才显示设置失败提示。
      if (context.mounted) {
        _showMessage(context, '画质设置失败：$error', type: AppSnackBarType.error);
      }
    }
  }

  /// 启动一条待下载或失败重试任务。
  Future<void> startTask(BuildContext context, DownloadTaskRecord task) async {
    // 已经解析中的任务不重复调用播放地址接口。
    if (state.startingAll || state.startingTaskIds.contains(task.taskId)) {
      return;
    }
    // 普通待下载默认按并发排队；失败任务让用户明确选择本次重试策略。
    var retryStrategy = DownloadManualRetryStrategy.queued;
    if (task.phase == DownloadTaskPhase.failed) {
      // 失败任务需要用户选择是回队列还是立即刷新地址重试。
      final selected = await showDownloadRetryDialog(
        context: context,
        errorCode: task.errorCode,
      );
      // 用户取消弹窗时保留失败状态和临时文件。
      if (selected == null || !context.mounted) return;
      // 保存弹窗选择，后续分支按策略走调度器或立即启动服务。
      retryStrategy = selected;
    }
    // 记录操作开始时间，用于 finally 中补足最短 loading 时长。
    final startedAt = DateTime.now();
    AppDebugLog.download(
      'Start task requested task=${task.taskId} phase=${task.phase.name} '
      'strategy=${retryStrategy.name}',
    );
    // 单任务 busy 状态先写入页面状态，防止重复点击进入下载后端。
    _addStartingTask(task.taskId);
    // 启动流程涉及调度器、启动服务和数据库确认，统一捕获异常。
    try {
      // 只有调度器或立即启动服务实际接受任务后才切换页签并开始完成跟踪。
      var submitted = false;
      // 普通启动走并发调度器；立即重试绕过队列直接刷新地址。
      if (retryStrategy == DownloadManualRetryStrategy.queued) {
        // 推荐策略原子移入等待队列，由调度器按并发和网络状态启动。
        final queuedCount = await ref
            .read(downloadTaskSchedulerProvider)
            .startBatch(<String>[task.taskId]);
        submitted = queuedCount == 1;
      } else {
        // 用户明确选择立即重试时刷新 DASH/CDN 并直接交给协调器。
        await ref.read(downloadTaskLaunchServiceProvider).start(task.taskId);
        submitted = true;
      }
      // 页面仍存在时才处理提交结果和提示。
      if (context.mounted) {
        // 实际提交成功后才等待阶段变化并发布页面事件。
        if (submitted) {
          // 入队成功后等待任务阶段离开待下载，防止按钮立刻恢复后被重复点击。
          await _waitForStartState(task.taskId);
          AppDebugLog.download('Start task submitted task=${task.taskId}');
          _publishSubmitted(<String>{task.taskId}, trackSubmittedTasks: true);
        } else {
          AppDebugLog.download('Start task not submitted task=${task.taskId}');
          // 返回零通常表示点击期间任务阶段已变化，必须反馈而不是保持静默。
          _showMessage(
            context,
            '任务状态已变化，未能加入下载队列。',
            type: AppSnackBarType.warning,
          );
        }
      }
    } catch (error) {
      AppDebugLog.download(
        'Start task failed task=${task.taskId} error=$error',
      );
      // 页面仍存在时展示可重试错误。
      if (context.mounted) {
        _showMessage(
          context,
          '启动下载失败：${startDownloadErrorMessage(error)}',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      // 保持最短启动 loading 时间，避免快速入队时用户看不到禁用反馈。
      await _holdStartMinimumBusyDuration(startedAt);
      _removeStartingTask(task.taskId);
    }
  }

  /// 更新待下载主任务附加资源复选项，不创建额外任务卡片。
  Future<void> updateExtraResources(
    BuildContext context,
    DownloadTaskRecord task,
    Set<DownloadExtraResource> resources,
  ) async {
    // 附加资源写库可能因任务已删除或数据库异常失败。
    try {
      // JSON 由队列服务写入，统一标题目录路径不会随资源开关变化。
      await ref
          .read(downloadQueueServiceProvider)
          .updateTaskExtraResources(task: task, resources: resources);
      AppDebugLog.download(
        'Extra resources updated task=${task.taskId} count=${resources.length}',
      );
      // 页面仍存在时才展示保存成功提示。
      if (context.mounted) {
        _showMessage(
          context,
          resources.isEmpty ? '已取消附加资源。' : '附加资源选择已保存。',
          type: AppSnackBarType.success,
        );
      }
    } catch (error) {
      AppDebugLog.download(
        'Extra resources update failed task=${task.taskId} error=$error',
      );
      // 页面仍存在时才展示保存失败提示。
      if (context.mounted) {
        _showMessage(context, '附加资源保存失败：$error', type: AppSnackBarType.error);
      }
    }
  }

  /// 打开自定义批量弹窗，根据页签执行批量设置或附加资源直下。
  Future<void> startCustomBatch(
    BuildContext context,
    List<DownloadTaskRecord> sourceTasks,
  ) async {
    // 已有待下载启动流程时不再弹出批量配置，避免同一任务被重复提交。
    if (state.startingAll || state.startingTaskIds.isNotEmpty) return;
    // 批量弹窗与卡片共用设置白名单，关闭的资源类型不会进入批量候选。
    final settings = ref.read(appSettingsControllerProvider);
    // 根据设置中心的下载内容开关生成本次可批量选择的附加资源。
    final availableResources = automaticExtraResources(
      settings.downloadContents,
    );
    AppDebugLog.download(
      'Custom batch dialog opened tasks=${sourceTasks.length} '
      'resources=${availableResources.length}',
    );
    // 手机端使用任务页二级页面，桌面端继续保持居中弹窗体验。
    final compact =
        MediaQuery.sizeOf(context).width < AppBreakpoints.navigationRail;
    final result = compact
        ? await context.push<DownloadCustomBatchResult>(
            '/tasks/custom-batch',
            extra: DownloadCustomBatchPageArguments(
              taskCount: sourceTasks.length,
              availableResources: availableResources,
              initialAudioQuality: settings.defaultAudioQuality,
              initialVideoQuality: settings.defaultVideoQuality,
            ),
          )
        : await showDownloadCustomBatchDialog(
            context: context,
            taskCount: sourceTasks.length,
            availableResources: availableResources,
            initialAudioQuality: settings.defaultAudioQuality,
            initialVideoQuality: settings.defaultVideoQuality,
          );
    // 用户取消或页面被销毁时不写入设置，也不启动直下流程。
    if (result == null || !context.mounted) {
      AppDebugLog.download('Custom batch cancelled');
      return;
    }
    // 按弹窗结果类型分发，避免批量设置和附加资源直下混在一个流程。
    switch (result) {
      case DownloadBatchSettingsResult():
        AppDebugLog.download('Custom batch settings selected');
        await _applyBatchSettings(context, sourceTasks, result);
      case DownloadBatchDirectExportResult():
        AppDebugLog.download(
          'Custom batch direct export selected resources=${result.resources.length}',
        );
        await _runBatchExtraResourceExport(
          context,
          sourceTasks,
          result.resources,
        );
    }
  }

  /// 从下载中列表选择延迟并绑定当前非暂停任务，创建本次会话的一次性关机计划。
  Future<void> configureAutomaticShutdown(
    BuildContext context,
    List<DownloadTaskRecord> visibleTasks,
  ) async {
    // 只绑定正在处理的任务，暂停项必须由用户恢复后重新确认自动关机。
    final activeTaskIds = visibleTasks
        .where(
          (DownloadTaskRecord task) => task.phase != DownloadTaskPhase.paused,
        )
        .map((DownloadTaskRecord task) => task.taskId)
        .toSet();
    // 列表阶段可能在点击和弹窗之间变化，没有活动项时不创建脱离任务的计划。
    if (activeTaskIds.isEmpty) {
      AppDebugLog.download('Automatic shutdown ignored activeTasks=0');
      return;
    }
    AppDebugLog.download(
      'Automatic shutdown dialog opened activeTasks=${activeTaskIds.length}',
    );
    // 等待用户明确选择时间并确认，取消或关闭弹窗返回空值。
    final confirmedDelay = await showDownloadShutdownDialog(
      context: context,
      activeTaskCount: activeTaskIds.length,
    );
    // 页面销毁或用户取消时不能创建计划。
    if (!context.mounted || confirmedDelay == null) {
      AppDebugLog.download('Automatic shutdown cancelled');
      return;
    }
    // 自动关机计划需要数据库复核和进程内状态写入，统一捕获异常。
    try {
      // 弹窗停留期间任务可能完成或暂停，确认前重新读取数据库中的真实阶段。
      final repository = ref.read(downloadTaskRepositoryProvider);
      // 确认时仍有效的任务 ID 集合，用于和弹窗打开时的快照比对。
      final confirmedActiveTaskIds = <String>{};
      // 逐条复核任务阶段，保证自动关机只绑定当前仍活动的任务。
      for (final taskId in activeTaskIds) {
        // 任务不存在、已完成、失败、取消或暂停时不再具备本次授权资格。
        final task = await repository.findTask(taskId);
        // 只有仍存在、未暂停且属于活动页签的任务才能进入本次关机计划。
        if (task != null &&
            task.phase != DownloadTaskPhase.paused &&
            taskPhasesForFilter(TaskFilter.active).contains(task.phase)) {
          confirmedActiveTaskIds.add(taskId);
        }
      }
      // 任务集合发生任何变化都要求用户重新打开弹窗确认，不能沿用旧快照。
      final listUnchanged =
          confirmedActiveTaskIds.length == activeTaskIds.length &&
          confirmedActiveTaskIds.every(activeTaskIds.contains);
      // 页面卸载或任务集合变化时取消创建计划，避免沿用过期授权。
      if (!context.mounted || !listUnchanged) {
        AppDebugLog.download(
          'Automatic shutdown rejected taskSnapshotChanged=true',
        );
        // 页面仍存在时给用户明确反馈，关闭页面则静默退出。
        if (context.mounted) {
          _showMessage(
            context,
            '下载任务状态已变化，请重新设置自动关机。',
            type: AppSnackBarType.warning,
          );
        }
        return;
      }
      // 计划仅保存在当前进程内，并绑定弹窗打开时的任务 ID 快照。
      ref
          .read(automaticShutdownPlanProvider.notifier)
          .arm(delay: confirmedDelay, taskIds: confirmedActiveTaskIds);
      AppDebugLog.download(
        'Automatic shutdown armed tasks=${confirmedActiveTaskIds.length} '
        'delayMinutes=${confirmedDelay.inMinutes}',
      );
      _showMessage(
        context,
        '已为当前 ${activeTaskIds.length} 个任务开启自动关机：完成后等待 '
        '${confirmedDelay.inMinutes} 分钟。',
        type: AppSnackBarType.success,
      );
    } catch (error) {
      AppDebugLog.download('Automatic shutdown configure failed error=$error');
      // 数据库复核失败时不创建缺少可靠任务边界的关机计划。
      if (context.mounted) {
        _showMessage(context, '自动关机设置失败：$error', type: AppSnackBarType.error);
      }
    }
  }

  /// 用户从下载中工具栏明确解除当前进程的一次性自动关机计划。
  void disableAutomaticShutdown(BuildContext context) {
    // 解除计划后后续任何任务完成事件都不能再使用本次授权。
    ref.read(automaticShutdownPlanProvider.notifier).disarm();
    // 若完成事件刚好已创建倒计时，同时取消根级遮罩和系统调用计时器。
    ref.read(automaticShutdownControllerProvider.notifier).cancel();
    AppDebugLog.download('Automatic shutdown disabled by user');
    // 给出即时反馈，避免按钮恢复默认文案但用户不确定是否已关闭。
    _showMessage(context, '已关闭自动关机。', type: AppSnackBarType.success);
  }

  /// 根据当前阶段暂停运行任务或恢复已暂停任务。
  Future<void> toggleTaskPause(
    BuildContext context,
    DownloadTaskRecord task,
  ) async {
    // 合并阶段、批量切换期间或同一任务尚未返回时忽略重复点击。
    if (state.togglingActiveTasks ||
        state.togglingTaskIds.contains(task.taskId) ||
        !canToggleDownloadTaskPause(task.phase)) {
      return;
    }
    // 记录开始时间，确保快速暂停或继续时按钮也有可见禁用反馈。
    final startedAt = DateTime.now();
    // 任务当前是暂停态时，本次期望恢复；其他可切换状态则期望进入暂停。
    final expectResumed = task.phase == DownloadTaskPhase.paused;
    AppDebugLog.download(
      'Task pause toggle requested task=${task.taskId} '
      'expectResumed=$expectResumed',
    );
    // 写入单项切换 busy 状态，避免同一任务重复调用协调器。
    _addTogglingTask(task.taskId);
    try {
      // 协调器负责同时处理音视频分流和可能运行中的媒体合并。
      final coordinator = await ref.read(
        downloadTaskCoordinatorProvider.future,
      );
      // 根据当前阶段调用恢复或暂停，保持按钮语义和后端动作一致。
      if (task.phase == DownloadTaskPhase.paused) {
        await coordinator.resumeTask(task.taskId);
      } else {
        await coordinator.pauseTask(task.taskId);
      }
      // 协调器返回后继续等 Drift 记录进入目标阶段，防止界面还没刷新就解锁。
      await _waitForPauseToggleState(task.taskId, expectResumed: expectResumed);
      AppDebugLog.download(
        'Task pause toggle completed task=${task.taskId} '
        'expectResumed=$expectResumed',
      );
    } catch (error) {
      AppDebugLog.download(
        'Task pause toggle failed task=${task.taskId} error=$error',
      );
      // 页面仍存在时才展示单项暂停或继续失败提示。
      if (context.mounted) {
        _showMessage(
          context,
          task.phase == DownloadTaskPhase.paused
              ? '继续任务失败，请稍后重试。'
              : '暂停任务失败，请稍后重试。',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      // 最短 loading 时间能挡住连续点按，也避免按钮没有可见反馈。
      await _holdPauseToggleMinimumBusyDuration(startedAt);
      _removeTogglingTask(task.taskId);
    }
  }

  /// 批量暂停当前活动任务，全部已暂停时则批量恢复。
  Future<void> toggleAllActiveTasks(
    BuildContext context,
    List<DownloadTaskRecord> tasks,
  ) async {
    // 批量流程运行期间不重复进入；单项正在切换的任务会在目标过滤里跳过。
    if (state.togglingActiveTasks || tasks.isEmpty) return;
    // 记录开始时间，批量操作完成后仍保持最短禁用窗口。
    final startedAt = DateTime.now();
    // 全部处于暂停态时本次操作为恢复，否则只暂停仍在运行的任务。
    final shouldResume = tasks.every(
      (DownloadTaskRecord task) => task.phase == DownloadTaskPhase.paused,
    );
    // 只对符合本次目标方向且没有单项 busy 的任务发起协调器调用。
    final targetTasks = tasks
        .where(
          (DownloadTaskRecord task) =>
              shouldResume == (task.phase == DownloadTaskPhase.paused) &&
              !state.togglingTaskIds.contains(task.taskId),
        )
        .toList(growable: false);
    // 批量状态只保存目标任务 ID，方便完成后一次性从 busy 集合移除。
    final taskIds = targetTasks
        .map((DownloadTaskRecord task) => task.taskId)
        .toSet();
    // 点击时可能所有任务都被别的操作锁定，此时不进入协调器。
    if (taskIds.isEmpty) {
      AppDebugLog.download('Toggle all active tasks ignored targets=0');
      return;
    }
    AppDebugLog.download(
      'Toggle all active tasks started count=${taskIds.length} '
      'shouldResume=$shouldResume',
    );
    // 页面级批量 busy 状态用于禁用工具栏批量按钮。
    state = state.copyWith(togglingActiveTasks: true);
    // 记录单项失败数，批量流程不因单个任务失败而整体中断。
    var failed = 0;
    try {
      // 批量操作共用一个协调器实例，避免重复初始化下载引擎。
      final coordinator = await ref.read(
        downloadTaskCoordinatorProvider.future,
      );
      // 批量任务逐条执行，单条失败不会阻断后续任务。
      for (final task in targetTasks) {
        try {
          // 本次是恢复还是暂停由 shouldResume 统一决定。
          if (shouldResume) {
            await coordinator.resumeTask(task.taskId);
          } else {
            await coordinator.pauseTask(task.taskId);
          }
          await _waitForPauseToggleState(
            task.taskId,
            expectResumed: shouldResume,
          );
        } catch (error) {
          AppDebugLog.download(
            'Toggle all active task item failed task=${task.taskId} error=$error',
          );
          // 保存失败数量，继续处理列表中的后续任务。
          failed++;
        }
      }
      AppDebugLog.download(
        'Toggle all active tasks completed count=${taskIds.length} failed=$failed',
      );
      // 页面仍存在时汇总批量结果，包含部分失败情况。
      if (context.mounted) {
        _showMessage(
          context,
          failed == 0
              ? (shouldResume ? '已继续全部下载任务。' : '已暂停全部下载任务。')
              : '${shouldResume ? '继续' : '暂停'}任务时有 $failed 项失败。',
          type: failed == 0 ? AppSnackBarType.success : AppSnackBarType.warning,
        );
      }
    } catch (error) {
      AppDebugLog.download('Toggle all active tasks failed error=$error');
      // 页面仍存在时展示批量协调器级错误。
      if (context.mounted) {
        _showMessage(
          context,
          '批量切换任务状态失败：${userErrorMessage(error, fallback: '请稍后重试。')}',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      // 批量操作同样保持最短禁用窗口，防止快速连点重复进入协调器。
      await _holdPauseToggleMinimumBusyDuration(startedAt);
      state = state.copyWith(togglingActiveTasks: false);
    }
  }

  /// 二次确认后停止并清空当前下载中列表。
  Future<void> clearActiveTasks(
    BuildContext context,
    List<DownloadTaskRecord> tasks,
  ) async {
    // 清空流程运行期间不重复弹窗或操作数据库。
    if (state.clearingActiveTasks || tasks.isEmpty) return;
    // 清空活动任务会停止后端并删除临时文件，必须先得到用户确认。
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: const Text('清空下载中任务？'),
      content: const Text('将停止并移除全部下载中和已暂停任务，同时清理未完成的临时文件。此操作无法撤销。'),
      confirmLabel: '清空',
    );
    // 用户取消时不修改任务或文件。
    if (!confirmed || !context.mounted) {
      AppDebugLog.download('Clear active tasks cancelled');
      return;
    }
    AppDebugLog.download('Clear active tasks started count=${tasks.length}');
    // 页面级 busy 状态用于禁用清空按钮，避免重复删除同一批临时目录。
    state = state.copyWith(clearingActiveTasks: true);
    // 统计每条任务的失败数，成功项仍会被正常移除。
    var failed = 0;
    try {
      // 下载任务仓库负责把已经取消或完成的记录从列表中移除。
      final repository = ref.read(downloadTaskRepositoryProvider);
      // 活动任务逐条停止和删除，单项失败不阻断后续清理。
      for (final task in tasks) {
        try {
          // 先尽量停止 aria2 或 FFmpeg，失败时仍把记录转为可删除终态。
          await _cancelTaskForDeletion(task);
          await _deleteTaskFiles(task);
          await repository.deleteRemovableTask(task.taskId);
        } catch (error) {
          AppDebugLog.download(
            'Clear active task item failed task=${task.taskId} error=$error',
          );
          // 单项失败保留记录供用户重试，继续清理其余任务。
          failed++;
        }
      }
      AppDebugLog.download(
        'Clear active tasks completed count=${tasks.length} failed=$failed',
      );
      // 页面仍存在时汇总清空结果。
      if (context.mounted) {
        _showMessage(
          context,
          failed == 0 ? '已清空 ${tasks.length} 个下载中任务。' : '清空完成，其中 $failed 项失败。',
          type: failed == 0 ? AppSnackBarType.success : AppSnackBarType.warning,
        );
      }
    } catch (error) {
      AppDebugLog.download('Clear active tasks failed error=$error');
      // 页面仍存在时展示清空流程的顶层错误。
      if (context.mounted) {
        _showMessage(context, '清空下载中任务失败：$error', type: AppSnackBarType.error);
      }
    } finally {
      state = state.copyWith(clearingActiveTasks: false);
    }
  }

  /// 二次确认后批量清空已下载记录，并按用户选择决定是否删除成品文件。
  Future<void> clearCompletedTasks(BuildContext context, int totalCount) async {
    // 清空流程运行期间不重复弹窗或执行文件删除。
    if (state.clearingCompletedTasks || totalCount <= 0) return;
    // 先进入 busy 状态，防止慢速数据库读取期间用户重复点击清空。
    state = state.copyWith(clearingCompletedTasks: true);
    try {
      // 从数据库重新读取已完成任务，避免使用页面传入数量作为删除依据。
      final repository = ref.read(downloadTaskRepositoryProvider);
      // 只处理 completed 阶段，失败或取消记录不参与“已下载”清空。
      final tasks = await repository.loadTasksByPhases(
        const <DownloadTaskPhase>[DownloadTaskPhase.completed],
      );
      // 任务在点击后可能已经被其他操作清空，页面销毁时也不能继续弹窗。
      if (tasks.isEmpty || !context.mounted) {
        AppDebugLog.download('Clear completed tasks ignored count=0');
        return;
      }
      AppDebugLog.download(
        'Clear completed tasks dialog opened count=${tasks.length}',
      );
      // 预先规划文件和目录范围，用于确认弹窗展示删除影响。
      final deletionPlan = await ref
          .read(downloadFileDeletionPlannerProvider)
          .build(tasks);
      // 文件规划完成后页面可能已经卸载，不能继续弹窗。
      if (!context.mounted) return;
      // 桌面端使用系统回收站，移动端直接走媒体库或文件删除。
      final usesSystemTrash = ref.read(runtimePlatformProvider).isDesktop;
      // 确认弹窗只展示前几条范围，避免大量文件夹撑爆弹窗。
      final visibleScopes = deletionPlan.scopeDescriptions.take(4).toList();
      // 记录隐藏范围数量，让用户知道还有更多文件位置会被处理。
      final hiddenScopeCount =
          deletionPlan.scopeDescriptions.length - visibleScopes.length;
      // 用户在弹窗内决定是否连同成品文件一起删除。
      final deletionChoice = await showClearCompletedDownloadsDialog(
        context: context,
        taskCount: tasks.length,
        fileCount: deletionPlan.fileCount,
        directoryCount: deletionPlan.directoryCount,
        totalSizeLabel: fileSizeLabel(deletionPlan.totalBytes),
        visibleScopes: visibleScopes,
        hiddenScopeCount: hiddenScopeCount,
        canDeleteFiles: deletionPlan.storageIdentifiers.isNotEmpty,
        usesSystemTrash: usesSystemTrash,
      );
      // 取消弹窗时只退出 busy，不删除记录或文件。
      if (deletionChoice == null || !context.mounted) {
        AppDebugLog.download('Clear completed tasks cancelled');
        return;
      }
      // 把用户选择保存为局部变量，后续记录和文件删除分支共用。
      final deleteCompletedFiles = deletionChoice.deleteFiles;
      AppDebugLog.download(
        'Clear completed tasks started count=${tasks.length} '
        'deleteFiles=$deleteCompletedFiles trash=$usesSystemTrash',
      );
      // 初始化进度弹窗所需计数，下一帧让 UI 有机会先显示 0 / total。
      state = state.copyWith(
        completedDeletionProcessed: 0,
        completedDeletionTotal: tasks.length,
      );
      await WidgetsBinding.instance.endOfFrame;
      // 等待一帧后页面可能已关闭，必须再次确认再继续删除文件。
      if (!context.mounted) return;
      // 只有用户选择删除成品文件时才规划和执行文件删除。
      if (deleteCompletedFiles) {
        // Android 删除公共下载目录文件前必须具备完整文件管理授权。
        final canManageFiles = await _ensureAndroidFileManagementPermission(
          context,
          '清空已下载文件',
        );
        if (!canManageFiles) {
          return;
        }
        // 删除前重新规划一次文件范围，防止确认期间任务文件或路径变化。
        final executionPlan = await ref
            .read(downloadFileDeletionPlannerProvider)
            .build(tasks);
        // 文件范围重建是异步操作，之后再次确认页面仍存在才展示提示或调用平台删除。
        if (!context.mounted) return;
        // 用户确认后文件范围变化时取消执行，避免删除未确认的路径。
        if (!deletionPlan.matches(executionPlan)) {
          AppDebugLog.download(
            'Clear completed tasks rejected scopeChanged=true',
          );
          _showMessage(
            context,
            '下载文件范围已经变化，请重新点击清空并确认。',
            type: AppSnackBarType.warning,
          );
          return;
        }
        // 桌面端需要先把全部成品文件交给回收站处理。
        if (usesSystemTrash) {
          // 桌面端成品文件先整体交给系统回收站，记录删除循环只清理临时目录。
          final platform = ref.read(runtimePlatformProvider);
          // 当前平台对应的 Publisher 负责调用系统回收站能力。
          final publisher = createMediaOutputPublisher(platform);
          await publisher.deleteAll(executionPlan.storageIdentifiers);
        }
      }
      // 记录删除和移动端文件删除逐条执行，便于进度显示和部分失败保留。
      var failed = 0;
      // 逐条删除记录和平台文件，配合进度条展示当前处理数量。
      for (final task in tasks) {
        try {
          // 根据用户选择决定是否触碰成品文件。
          if (deleteCompletedFiles) {
            if (usesSystemTrash) {
              // 桌面端成品已进入回收站，这里只清理应用专属临时目录。
              await _deleteTaskTemporaryDirectory(task);
            } else {
              // 移动端或无回收站平台需要逐条删除成品、空目录和临时目录。
              await _deleteTaskFiles(task);
            }
          }
          // 文件处理完成后再删除记录，失败时保留记录供用户重试。
          await repository.deleteRemovableTask(task.taskId);
        } catch (error) {
          AppDebugLog.download(
            'Clear completed task item failed task=${task.taskId} error=$error',
          );
          // 单项失败保留原记录，最终用 warning 提示用户。
          failed++;
        } finally {
          // 每个任务完成或失败都推进一次进度，避免长批次看起来像界面卡住。
          state = state.copyWith(
            completedDeletionProcessed: state.completedDeletionProcessed + 1,
          );
        }
      }
      // 页面仍存在时展示最终清理结果。
      if (context.mounted) {
        // 成功数由总数减失败数得到，用于最终提示。
        final succeeded = tasks.length - failed;
        AppDebugLog.download(
          'Clear completed tasks completed succeeded=$succeeded failed=$failed',
        );
        _showMessage(
          context,
          _completedDeletionMessage(
            succeeded: succeeded,
            failed: failed,
            deleteCompletedFiles: deleteCompletedFiles,
            usesSystemTrash: usesSystemTrash,
          ),
          type: failed == 0 ? AppSnackBarType.success : AppSnackBarType.warning,
        );
      }
    } catch (error) {
      AppDebugLog.download('Clear completed tasks failed error=$error');
      // 页面仍存在时展示清空已下载流程的顶层错误。
      if (context.mounted) {
        _showMessage(
          context,
          '清空已下载记录失败：${deletionErrorMessage(error)}',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      state = state.copyWith(
        clearingCompletedTasks: false,
        completedDeletionProcessed: 0,
        completedDeletionTotal: 0,
      );
    }
  }

  /// 原子移动当前待下载列表，并交给应用级并发调度器处理。
  Future<void> startAll(
    BuildContext context,
    List<DownloadTaskRecord> tasks,
  ) async {
    // 批量流程运行期间禁止再次触发。
    if (state.startingAll || state.startingTaskIds.isNotEmpty) return;
    // 只筛选仍在待下载或失败阶段的任务，下载中和已完成任务不能重复入队。
    final targetTasks = tasks
        .where(
          (DownloadTaskRecord task) =>
              task.phase == DownloadTaskPhase.queued ||
              task.phase == DownloadTaskPhase.failed,
        )
        .toList(growable: false);
    // 点击时列表可能已经没有可启动任务，直接返回避免空批量提示。
    if (targetTasks.isEmpty) {
      AppDebugLog.download('Start all ignored targets=0');
      return;
    }
    // 记录批量启动开始时间，用于 finally 中补足最短 loading。
    final startedAt = DateTime.now();
    // 目标任务 ID 集合同时用于调度器提交和 busy 状态清理。
    final taskIds = targetTasks
        .map((DownloadTaskRecord task) => task.taskId)
        .toSet();
    AppDebugLog.download('Start all requested count=${taskIds.length}');
    // 批量启动时把所有目标任务写入 busy 集合，卡片按钮立即禁用。
    state = state.copyWith(
      startingAll: true,
      startingTaskIds: <String>{...state.startingTaskIds, ...taskIds},
    );
    // 调度器提交、阶段确认和提示统一捕获，失败时恢复 busy 状态。
    try {
      // 调度器负责按并发配置原子移动任务并启动可运行项。
      final queuedCount = await ref
          .read(downloadTaskSchedulerProvider)
          .startBatch(taskIds);
      AppDebugLog.download(
        'Start all scheduler accepted count=$queuedCount total=${taskIds.length}',
      );
      // 至少有任务被接受时等待数据库阶段变化，避免按钮闪回可点击。
      if (queuedCount > 0) {
        await _waitForStartStates(taskIds);
      }
      // 页面仍存在时发布提交事件并展示批量启动结果。
      if (context.mounted) {
        // 有任务被调度器接受时才通知页面切换页签和跟踪完成。
        if (queuedCount > 0) {
          // 完整提交才跟踪全部完成；部分提交只切页，不等待缺失项完成。
          _publishSubmitted(
            taskIds,
            trackSubmittedTasks: queuedCount == taskIds.length,
          );
        }
        _showMessage(
          context,
          queuedCount == taskIds.length
              ? '已将 $queuedCount 个任务加入下载队列。'
              : '已将 $queuedCount / ${taskIds.length} 个任务加入下载队列。',
          type: queuedCount == taskIds.length
              ? AppSnackBarType.success
              : AppSnackBarType.warning,
        );
      }
    } catch (error) {
      AppDebugLog.download('Start all failed error=$error');
      // 页面仍存在时展示批量启动错误。
      if (context.mounted) {
        _showMessage(
          context,
          '批量加入下载队列失败：${userErrorMessage(error, fallback: '请稍后重试。')}',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      await _holdStartMinimumBusyDuration(startedAt);
      state = state.copyWith(
        startingAll: false,
        startingTaskIds: state.startingTaskIds.difference(taskIds),
      );
    }
  }

  /// 二次确认后清空所有尚未启动的任务。
  Future<void> clearQueuedTasks(BuildContext context) async {
    // 待下载任务只删除数据库记录，不触碰下载中临时文件。
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: const Text('清空待下载任务？'),
      content: const Text('将删除所有尚未开始的任务，下载中、已完成和失败记录不会受影响。'),
      confirmLabel: '清空',
    );
    // 用户取消或页面已卸载时不能继续写库。
    if (!confirmed || !context.mounted) {
      AppDebugLog.download('Clear queued tasks cancelled');
      return;
    }
    AppDebugLog.download('Clear queued tasks started');
    // 数据库删除可能失败，统一捕获后保留现有列表。
    try {
      // 仓库只删除 queued 阶段，防止误删下载中或已完成记录。
      final count = await ref
          .read(downloadTaskRepositoryProvider)
          .deleteAllQueuedTasks();
      AppDebugLog.download('Clear queued tasks completed count=$count');
      // 页面仍存在时反馈实际删除数量。
      if (context.mounted) {
        _showMessage(
          context,
          '已清空 $count 个待下载任务。',
          type: AppSnackBarType.success,
        );
      }
    } catch (error) {
      AppDebugLog.download('Clear queued tasks failed error=$error');
      // 页面仍存在时反馈清空待下载失败原因。
      if (context.mounted) {
        _showMessage(context, '清空待下载任务失败：$error', type: AppSnackBarType.error);
      }
    }
  }

  /// 根据任务阶段删除待下载、活动任务或已完成记录。
  Future<void> deleteTaskRecord(
    BuildContext context,
    DownloadTaskRecord task,
  ) async {
    // 待下载任务没有临时文件和后端进程，只需走轻量移除确认。
    if (task.phase == DownloadTaskPhase.queued) {
      AppDebugLog.download('Delete queued task requested task=${task.taskId}');
      await _deleteQueuedTask(context, task);
      return;
    }
    // 已经进入可删除中间态的任务不重复执行删除流程。
    if (task.phase == DownloadTaskPhase.canceled) {
      AppDebugLog.download('Delete task ignored canceled task=${task.taskId}');
      return;
    }
    // 已完成任务允许用户选择是否同时删除成品文件。
    final completed = task.phase == DownloadTaskPhase.completed;
    // 桌面端删除成品优先进入系统回收站，文案和确认内容需要区分。
    final usesSystemTrash = ref.read(runtimePlatformProvider).isDesktop;
    // 弹窗根据任务阶段展示不同风险说明和文件删除选项。
    final deletionChoice = await showDeleteDownloadTaskDialog(
      context: context,
      taskTitle: task.title,
      completed: completed,
      usesSystemTrash: usesSystemTrash,
    );
    // 用户关闭确认弹窗时保留记录和文件。
    if (deletionChoice == null) {
      AppDebugLog.download('Delete task cancelled task=${task.taskId}');
      return;
    }
    // 弹窗返回后页面可能已经退出，不能再使用失效的 BuildContext 展示授权提示。
    if (!context.mounted) return;
    // 记录用户是否勾选成品文件删除，后续文案和文件处理共用。
    final deleteCompletedFile = deletionChoice.deleteFiles;
    // 已完成且勾选文件、或未完成任务清理临时和残留文件时，需要 Android 文件管理授权。
    if (deleteCompletedFile || !completed) {
      final canManageFiles = await _ensureAndroidFileManagementPermission(
        context,
        '删除任务文件',
      );
      if (!canManageFiles) return;
    }
    AppDebugLog.download(
      'Delete task started task=${task.taskId} phase=${task.phase.name} '
      'deleteFiles=$deleteCompletedFile',
    );
    try {
      if (!completed) {
        // 未完成任务必须先停止后端，再清理临时目录和可能已生成的文件。
        await _cancelTaskForDeletion(task);
        await _deleteTaskFiles(task);
      } else if (deleteCompletedFile) {
        // 已完成任务只有用户勾选时才触碰成品文件。
        await _deleteTaskFiles(task);
      }
      // 文件处理完成后再删除记录，失败时保留记录以便用户重试。
      await ref
          .read(downloadTaskRepositoryProvider)
          .deleteRemovableTask(task.taskId);
      AppDebugLog.download('Delete task completed task=${task.taskId}');
      // 页面仍存在时展示单条删除成功文案。
      if (context.mounted) {
        _showMessage(
          context,
          _singleDeletionMessage(
            completed: completed,
            deleteCompletedFile: deleteCompletedFile,
            usesSystemTrash: usesSystemTrash,
          ),
          type: AppSnackBarType.success,
        );
      }
    } catch (error) {
      AppDebugLog.download(
        'Delete task failed task=${task.taskId} error=$error',
      );
      // 页面仍存在时展示删除失败原因。
      if (context.mounted) {
        _showMessage(
          context,
          '删除记录失败：${deletionErrorMessage(error)}',
          type: AppSnackBarType.error,
        );
      }
    }
  }

  /// 应用批量设置到当前待下载主任务。
  Future<void> _applyBatchSettings(
    BuildContext context,
    List<DownloadTaskRecord> sourceTasks,
    DownloadBatchSettingsResult result,
  ) async {
    // 记录批量设置开始时间，确保按钮禁用反馈稳定。
    final startedAt = DateTime.now();
    // 本次批量设置涉及的任务 ID 用于页面 busy 状态和 finally 清理。
    final taskIds = sourceTasks
        .map((DownloadTaskRecord task) => task.taskId)
        .toSet();
    // 批量设置与批量启动共用 startingAll 状态，避免同时改设置和提交下载。
    state = state.copyWith(
      startingAll: true,
      startingTaskIds: <String>{...state.startingTaskIds, ...taskIds},
    );
    AppDebugLog.download(
      'Batch settings started count=${taskIds.length} '
      'resources=${result.resources.length} mode=${result.mediaMode.name}',
    );
    // 批量设置包含资源写入和候选解码，任何顶层异常都进入统一提示。
    try {
      // 队列服务负责更新附加资源 JSON，并保持主任务结构不拆分。
      final queueService = ref.read(downloadQueueServiceProvider);
      // 质量服务负责校验并写入单条任务的音视频候选。
      final qualityService = ref.read(downloadTaskQualityServiceProvider);
      // 设置中的默认编码用于批量选择视频候选时做 codec 偏好。
      final settings = ref.read(appSettingsControllerProvider);
      // 先统一写入附加资源，音画质失败时也能保留资源更新结果。
      final updatedResources = await queueService.updateTasksExtraResources(
        tasks: sourceTasks,
        resources: result.resources,
      );
      AppDebugLog.download(
        'Batch settings resources updated count=$updatedResources',
      );
      // 成功更新音画质的任务数量，用于最终反馈。
      var updatedQualities = 0;
      // 缺少候选或单条异常的任务数量，用于提示用户单独调整。
      var skippedQualities = 0;
      // 每条任务独立解码和写入，单条失败不影响整批。
      for (final task in sourceTasks) {
        // 单条候选异常只计入跳过数量，保留其他任务的批量结果。
        try {
          // 缺少 DASH 候选清单时无法安全批量改音画质。
          final dashOptionsJson = task.dashOptionsJson;
          if (dashOptionsJson == null || dashOptionsJson.trim().isEmpty) {
            skippedQualities++;
            continue;
          }
          // 解码任务保存的 DASH 候选，后续按批量模式选出音频或视频。
          final options = StoredDashOptions.decode(dashOptionsJson);
          // 根据用户选择的媒体模式写入不同的音视频组合。
          switch (result.mediaMode) {
            case DownloadBatchMediaMode.audioVideo:
              // 音视频模式同时选择视频和音频，保持普通视频下载。
              final video = options.selectVideo(
                qualityId: result.videoQuality.qualityId,
                preferredCodec: settings.preferredVideoCodec,
              );
              // 音频候选来自批量弹窗中的目标音质。
              final audio = options.selectAudio(
                qualityId: result.audioQuality.dashId,
              );
              await qualityService.selectVideo(task.taskId, video);
              await qualityService.selectAudio(task.taskId, audio);
            case DownloadBatchMediaMode.videoOnly:
              // 纯视频模式清空音频候选，避免后续仍合并音轨。
              final video = options.selectVideo(
                qualityId: result.videoQuality.qualityId,
                preferredCodec: settings.preferredVideoCodec,
              );
              await qualityService.selectVideo(task.taskId, video);
              await qualityService.clearAudio(task.taskId);
            case DownloadBatchMediaMode.audioOnly:
              // 纯音频模式清空视频候选，输出扩展名由队列服务后续处理。
              final audio = options.selectAudio(
                qualityId: result.audioQuality.dashId,
              );
              await qualityService.selectAudio(task.taskId, audio);
              await qualityService.clearVideo(task.taskId);
          }
          updatedQualities++;
        } catch (error) {
          AppDebugLog.download(
            'Batch settings quality skipped task=${task.taskId} error=$error',
          );
          // 单条任务候选异常不阻断整批，用户仍可在该行单独调整。
          skippedQualities++;
        }
      }
      AppDebugLog.download(
        'Batch settings completed resources=$updatedResources '
        'qualities=$updatedQualities skipped=$skippedQualities',
      );
      // 页面卸载后不再弹提示，批量设置结果已经写入数据库。
      if (!context.mounted) return;
      _showMessage(
        context,
        skippedQualities == 0
            ? '已批量更新 $updatedResources 条任务设置。'
            : '已更新 $updatedResources 条附加资源，$updatedQualities 条音画质已更新，$skippedQualities 条需单独调整。',
        type: skippedQualities == 0
            ? AppSnackBarType.success
            : AppSnackBarType.warning,
      );
    } catch (error) {
      AppDebugLog.download('Batch settings failed error=$error');
      if (context.mounted) {
        _showMessage(
          context,
          '批量设置失败：${userErrorMessage(error, fallback: '请稍后重试。')}',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      await _holdStartMinimumBusyDuration(startedAt);
      state = state.copyWith(
        startingAll: false,
        startingTaskIds: state.startingTaskIds.difference(taskIds),
      );
    }
  }

  /// 在进度弹窗内直接导出附加资源。
  Future<void> _runBatchExtraResourceExport(
    BuildContext context,
    List<DownloadTaskRecord> sourceTasks,
    Set<DownloadExtraResource> resources,
  ) async {
    // 读取当前下载目录配置，导出服务需要按设置计算输出根目录。
    final settings = ref.read(appSettingsControllerProvider);
    // 附加资源导出服务负责解析封面、字幕等资源并写入时间戳目录。
    final service = ref.read(batchExtraResourceExportServiceProvider);
    AppDebugLog.download(
      'Batch extra resource export started tasks=${sourceTasks.length} '
      'resources=${resources.length}',
    );
    // 进度弹窗托管异步任务生命周期，返回成功结果或异常对象。
    final outcome = await showDownloadBatchExportDialog(
      context: context,
      runExport: (onProgress) => service.export(
        tasks: sourceTasks,
        resources: resources,
        downloadDirectoryPath: settings.downloadDirectoryPath,
        onProgress: onProgress,
      ),
      errorMessageBuilder: (Object error) =>
          userErrorMessage(error, fallback: '请稍后重试。'),
    );
    // 成功结果包含失败资源数，用于决定 success 或 warning。
    final result = outcome.result;
    // 异常结果保留原始错误对象，统一转成用户可读文案。
    final failure = outcome.failure;
    // 弹窗关闭后页面可能已卸载，不能再访问 Overlay。
    if (!context.mounted) return;
    // 成功结果优先展示，失败对象只在没有结果时处理。
    if (result != null) {
      AppDebugLog.download(
        'Batch extra resource export completed '
        'failedResources=${result.failedResources}',
      );
      _showMessage(
        context,
        result.failedResources == 0
            ? '附加资源已下载到时间戳文件夹。'
            : '附加资源部分下载完成，${result.failedResources} 项失败。',
        type: result.failedResources == 0
            ? AppSnackBarType.success
            : AppSnackBarType.warning,
      );
    } else if (failure != null) {
      AppDebugLog.download('Batch extra resource export failed error=$failure');
      _showMessage(
        context,
        '批量下载失败：${userErrorMessage(failure, fallback: '请稍后重试。')}',
        type: AppSnackBarType.error,
      );
    }
  }

  /// 等待暂停或继续操作在任务表中呈现出目标状态。
  Future<void> _waitForPauseToggleState(
    String taskId, {
    required bool expectResumed,
  }) async {
    // 仓库查询是轮询来源，用于确认 Drift 表已经收到后端阶段变化。
    final repository = ref.read(downloadTaskRepositoryProvider);
    // 超时时间防止底层下载引擎异常导致按钮永久 loading。
    final deadline = DateTime.now().add(_pauseToggleConfirmTimeout);
    while (true) {
      // 每轮读取当前任务记录，任务被删除时也视为无需继续等待。
      final current = await repository.findTask(taskId);
      if (current == null) return;
      if (expectResumed) {
        // 恢复任务只要离开 paused 即认为 UI 可解锁。
        if (current.phase != DownloadTaskPhase.paused) return;
      } else {
        // 暂停任务需要进入 paused，或进入不可暂停阶段时停止等待。
        if (current.phase == DownloadTaskPhase.paused ||
            !canToggleDownloadTaskPause(current.phase)) {
          return;
        }
      }
      // 超时后交还界面控制权，后续数据库流仍会刷新真实状态。
      if (DateTime.now().isAfter(deadline)) return;
      await Future<void>.delayed(_pauseTogglePollInterval);
    }
  }

  /// 保持暂停/继续按钮最短 loading 时长，挡住连续点按和无反馈闪烁。
  Future<void> _holdPauseToggleMinimumBusyDuration(DateTime startedAt) async {
    // 计算已经展示 busy 的时间，只补足不足的部分。
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed >= _pauseToggleMinimumBusyDuration) return;
    await Future<void>.delayed(_pauseToggleMinimumBusyDuration - elapsed);
  }

  /// 等待单个待下载或失败任务离开待下载页可见阶段。
  Future<void> _waitForStartState(String taskId) async {
    await _waitForStartStates(<String>{taskId});
  }

  /// 等待一批任务离开 queued/failed，确认 Drift 快照已经体现启动结果。
  Future<void> _waitForStartStates(Set<String> taskIds) async {
    // 空集合没有可等待对象，直接返回避免无意义轮询。
    if (taskIds.isEmpty) return;
    // 仓库按任务 ID 读取最新阶段，避免依赖旧页面快照。
    final repository = ref.read(downloadTaskRepositoryProvider);
    // 启动确认同样设置超时，底层异常时按钮不能永久锁住。
    final deadline = DateTime.now().add(_startTaskConfirmTimeout);
    while (true) {
      // 每轮重新统计仍停留在待下载或失败页签的任务数量。
      var pendingCount = 0;
      for (final taskId in taskIds) {
        // 任务若已被删除，视为不再需要等待启动确认。
        final current = await repository.findTask(taskId);
        if (current == null) continue;
        if (current.phase == DownloadTaskPhase.queued ||
            current.phase == DownloadTaskPhase.failed) {
          pendingCount++;
        }
      }
      // 全部离开待下载可见阶段后，页面按钮可以恢复。
      if (pendingCount == 0) return;
      // 超时后放弃等待，数据库流后续仍会呈现真实阶段。
      if (DateTime.now().isAfter(deadline)) return;
      await Future<void>.delayed(_startTaskPollInterval);
    }
  }

  /// 保持待下载启动按钮最短 loading 时长，挡住连续点击。
  Future<void> _holdStartMinimumBusyDuration(DateTime startedAt) async {
    // 计算已经展示启动 busy 的时间，只延迟不足的部分。
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed >= _startTaskMinimumBusyDuration) return;
    await Future<void>.delayed(_startTaskMinimumBusyDuration - elapsed);
  }

  /// 二次确认后删除一条未启动任务。
  Future<void> _deleteQueuedTask(
    BuildContext context,
    DownloadTaskRecord task,
  ) async {
    // 单条待下载任务删除仍需要确认，避免误触卡片关闭按钮。
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: const Text('移除待下载任务？'),
      content: Text('将从列表移除“${task.title}”，不会删除已经完成的文件。'),
      confirmLabel: '移除',
    );
    // 用户取消时不修改数据库。
    if (!confirmed) {
      AppDebugLog.download('Delete queued task cancelled task=${task.taskId}');
      return;
    }
    try {
      // queued 任务只删除记录，不需要调用下载协调器或文件清理。
      await ref
          .read(downloadTaskRepositoryProvider)
          .deleteQueuedTask(task.taskId);
      AppDebugLog.download('Delete queued task completed task=${task.taskId}');
    } catch (error) {
      AppDebugLog.download(
        'Delete queued task failed task=${task.taskId} error=$error',
      );
      if (context.mounted) {
        _showMessage(context, '移除失败：$error', type: AppSnackBarType.error);
      }
    }
  }

  /// 删除前尽量取消后端任务，失败时兜底写入可删除终态。
  Future<void> _cancelTaskForDeletion(
    DownloadTaskRecord task, {
    DownloadTaskCoordinator? coordinator,
  }) async {
    // 已完成任务没有运行中的后端进程，取消步骤直接跳过。
    if (task.phase == DownloadTaskPhase.completed) return;
    // 仓库用于在协调器失败时把记录兜底转为可移除状态。
    final repository = ref.read(downloadTaskRepositoryProvider);
    if (task.phase == DownloadTaskPhase.failed ||
        task.phase == DownloadTaskPhase.waitingToStart ||
        task.phase == DownloadTaskPhase.resolving) {
      // 这些阶段通常没有稳定后端任务，直接标记取消即可进入删除流程。
      await repository.markTaskCanceledForRemoval(task.taskId);
      return;
    }
    try {
      // 外部批量调用可传入同一个协调器，避免每条任务重复解析 provider。
      final DownloadTaskCoordinator resolvedCoordinator =
          coordinator ?? await ref.read(downloadTaskCoordinatorProvider.future);
      // 协调器负责停止 aria2、FFmpeg 或合并队列中的运行状态。
      await resolvedCoordinator.cancelTask(task.taskId);
    } catch (_) {
      // 协调器失败时仍把记录转为可移除，防止卡在不可删除阶段。
      await repository.markTaskCanceledForRemoval(task.taskId);
    }
  }

  /// 删除任务最终文件和应用专属临时目录。
  Future<void> _deleteTaskFiles(DownloadTaskRecord task) async {
    // 删除计划统一收集成品文件和可安全回收的空目录。
    final deletionPlan = await ref
        .read(downloadFileDeletionPlannerProvider)
        .build(<DownloadTaskRecord>[task]);
    // 运行平台决定桌面回收站和移动端真实路径删除语义。
    final platform = ref.read(runtimePlatformProvider);
    // Publisher 只接收真实文件路径，旧版非文件标识已在删除计划中过滤。
    final publisher = createMediaOutputPublisher(platform);
    // 先删除成品文件，再处理可能残留的标题目录和临时目录。
    await publisher.deleteAll(deletionPlan.storageIdentifiers);
    if (!platform.isDesktop) {
      // 移动端全文件权限删除后可能留下空标题目录，需要额外安全清理。
      await _deleteEmptyTaskTitleDirectory(task);
    }
    // 应用专属临时目录不属于系统媒体库，最后用本地文件接口清理。
    await _deleteTaskTemporaryDirectory(task);
  }

  /// 确保 Android 文件管理授权可用，非 Android 平台直接允许继续。
  Future<bool> _ensureAndroidFileManagementPermission(
    BuildContext context,
    String actionName,
  ) async {
    final granted = await AndroidAppPermissions.ensureAllFilesAccess();
    if (granted) return true;
    if (!context.mounted) return false;
    _showMessage(
      context,
      '请开启文件管理授权后再$actionName。',
      type: AppSnackBarType.error,
    );
    return false;
  }

  /// 删除移动端真实文件处理后留下的安全空标题目录。
  Future<void> _deleteEmptyTaskTitleDirectory(DownloadTaskRecord task) async {
    // 没有输出路径时无法推导标题目录，直接跳过目录清理。
    final outputPath = task.outputPath;
    if (outputPath == null || outputPath.trim().isEmpty) return;
    // Android 已经持有文件管理权限，直接检查真实输出文件父目录。
    final outputDirectory = Directory(p.dirname(outputPath));
    // 只清理应用可能创建的任务边界目录，避免删除用户手动选择的普通目录。
    final safeTitleDirectory = _isSafeEmptyTaskBoundaryDirectory(
      directory: outputDirectory,
      outputPath: outputPath,
      task: task,
    );
    // 不满足安全目录形态或目录不存在时不做任何文件系统操作。
    if (!safeTitleDirectory || !await outputDirectory.exists()) return;
    try {
      // 非空目录可能包含用户文件，必须保留。
      if (!await outputDirectory.list().isEmpty) return;
      // 只在所有安全检查通过后删除空标题目录。
      await outputDirectory.delete();
    } on FileSystemException {
      // 目录可能已被前一次重试或系统清理移除，缺失时视为清理完成。
      if (!await outputDirectory.exists()) return;
      rethrow;
    }
  }

  /// 判断输出文件父目录是否属于当前任务可以安全回收的空边界目录。
  bool _isSafeEmptyTaskBoundaryDirectory({
    required Directory directory,
    required String outputPath,
    required DownloadTaskRecord task,
  }) {
    // 父目录名来自真实路径，后续只允许匹配应用生成的标题目录或合集目录。
    final directoryName = p.basename(directory.path);
    // 有附加资源时应用会创建“视频名/视频名.mp4”的标题目录。
    final safeNames = <String>{p.basenameWithoutExtension(outputPath)};
    // 合集或多 P 下载常把视频平铺在“合集名”目录下，删除最后一个文件后也要清空。
    final collectionTitle = task.collectionTitle?.trim();
    if (collectionTitle != null && collectionTitle.isNotEmpty) {
      safeNames.add(sanitizeOutputPathSegment(collectionTitle));
    }
    // 只有目录名完全命中应用可生成的边界名称时，才允许继续检查空目录并删除。
    return safeNames.contains(directoryName);
  }

  /// 永久清理经过任务 ID 与专属根名称双重校验的临时目录。
  Future<void> _deleteTaskTemporaryDirectory(DownloadTaskRecord task) async {
    // 旧任务或异常任务可能没有临时目录，直接跳过。
    final temporaryPath = task.temporaryDirectory;
    if (temporaryPath == null || temporaryPath.isEmpty) return;
    // 归一化临时目录，避免相对路径或大小写差异绕过安全校验。
    final normalizedPath = p.normalize(p.absolute(temporaryPath));
    // 只有应用专属下载临时目录且包含当前任务 ID 时才允许递归删除。
    final safeTemporaryDirectory = isDownloadTemporaryTaskDirectory(
      directoryPath: normalizedPath,
      taskId: task.taskId,
    );
    if (!safeTemporaryDirectory) {
      throw StateError('临时目录不在应用专属目录中，已停止删除文件。');
    }
    // 文件系统对象只在通过安全校验后创建并检查存在性。
    final temporaryDirectory = Directory(normalizedPath);
    if (await temporaryDirectory.exists()) {
      try {
        // 临时目录只保存当前任务中间文件，可以安全递归删除。
        await temporaryDirectory.delete(recursive: true);
      } on FileSystemException {
        // 并发清理或重试时目录可能已经消失，缺失不应阻塞记录删除。
        if (!await temporaryDirectory.exists()) return;
        rethrow;
      }
    }
  }

  /// 发布任务提交事件给页面处理页签切换和完成跟踪。
  void _publishSubmitted(
    Set<String> taskIds, {
    required bool trackSubmittedTasks,
  }) {
    // 事件对象必须变化，页面 ref.listen 才能处理相同任务集合的连续提交。
    state = state.copyWith(
      submittedBatch: DownloadTasksSubmittedBatch(
        revision: ++_submittedRevision,
        taskIds: Set<String>.unmodifiable(taskIds),
        trackSubmittedTasks: trackSubmittedTasks,
      ),
    );
  }

  /// 添加一条正在启动的任务 ID。
  void _addStartingTask(String taskId) {
    // 使用新 Set 触发 Riverpod 状态更新，不能原地修改旧集合。
    state = state.copyWith(
      startingTaskIds: <String>{...state.startingTaskIds, taskId},
    );
  }

  /// 移除一条启动 busy 状态。
  void _removeStartingTask(String taskId) {
    // difference 生成新集合，保持状态对象不可变。
    state = state.copyWith(
      startingTaskIds: state.startingTaskIds.difference(<String>{taskId}),
    );
  }

  /// 添加一条正在暂停或继续的任务 ID。
  void _addTogglingTask(String taskId) {
    // 使用新 Set 触发卡片级按钮刷新。
    state = state.copyWith(
      togglingTaskIds: <String>{...state.togglingTaskIds, taskId},
    );
  }

  /// 移除一条暂停或继续 busy 状态。
  void _removeTogglingTask(String taskId) {
    // 只移除当前任务，其他正在切换的任务保持禁用。
    state = state.copyWith(
      togglingTaskIds: state.togglingTaskIds.difference(<String>{taskId}),
    );
  }

  /// 返回批量清空已下载任务后的用户反馈文案。
  String _completedDeletionMessage({
    required int succeeded,
    required int failed,
    required bool deleteCompletedFiles,
    required bool usesSystemTrash,
  }) {
    // 失败时优先告知未全部完成，避免文件处理方式造成误解。
    if (failed > 0) return '已清空 $succeeded 条记录，其中 $failed 项失败。';
    // 不删除文件时明确说明仅清理记录。
    if (!deleteCompletedFiles) return '已清空 $succeeded 条记录，下载文件已保留。';
    // 系统回收站可恢复，文案需区别于永久删除。
    if (usesSystemTrash) return '已清空 $succeeded 条记录，下载文件已移入回收站。';
    // 无回收站能力时说明文件已经被删除。
    return '已清空 $succeeded 条记录并删除下载文件。';
  }

  /// 返回删除单个任务后的用户反馈文案。
  String _singleDeletionMessage({
    required bool completed,
    required bool deleteCompletedFile,
    required bool usesSystemTrash,
  }) {
    // 未完成任务走取消和临时文件清理流程。
    if (!completed) return '已停止任务并清理未完成文件。';
    // 已完成任务可以只删记录并保留成品文件。
    if (!deleteCompletedFile) return '已删除任务记录，下载文件已保留。';
    // 系统回收站可恢复，文案需区别于永久删除。
    if (usesSystemTrash) return '已删除任务记录，下载文件已移入回收站。';
    // 无回收站能力时说明文件已经被删除。
    return '已删除任务记录和下载文件。';
  }

  /// 在根 Overlay 顶部展示简短操作反馈。
  void _showMessage(
    BuildContext context,
    String message, {
    AppSnackBarType type = AppSnackBarType.normal,
  }) {
    // 应用级提示会替换旧提示，并能覆盖页面内弹窗。
    AppSnackBar.show(
      context,
      message: message,
      type: type,
      position: AppSnackBarPosition.top,
    );
  }
}
