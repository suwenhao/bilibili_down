import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/database_providers.dart';
import '../core/logging/app_debug_log.dart';
import '../features/downloads/application/runtime/download_task_coordinator_provider.dart';
import '../features/downloads/application/runtime/download_task_scheduler.dart';
import '../services/download_engine/download_engine_providers.dart';
import '../services/media_merge/media_merge_providers.dart';

/// 按固定顺序释放下载、合并、原生进程和数据库资源。
final class DesktopShutdownCoordinator {
  /// 创建一次桌面退出资源协调器。
  const DesktopShutdownCoordinator({
    required this.ref,
    required this.onDetailChanged,
  });

  /// 已初始化 Provider 的读取入口，退出时不会主动创建未使用资源。
  final WidgetRef ref;

  /// 单个资源开始清理前更新退出遮罩说明的回调。
  final ValueChanged<String> onDetailChanged;

  /// 仅释放已经初始化的调度器、协调器、原生进程和数据库。
  Future<void> shutdownDownloadResources() async {
    // 退出日志用于确认关闭请求确实进入应用级清理链路。
    AppDebugLog.app('Application shutdown started.');
    // 先停止并发调度并等待已经认领的启动任务，防止协调器清理期间继续提交。
    if (ref.exists(downloadTaskSchedulerProvider)) {
      await runStep('download-scheduler', () async {
        // 调度器释放后不会再把持久化等待任务交给启动服务。
        final scheduler = ref.read(downloadTaskSchedulerProvider);
        await scheduler.dispose();
      }, detail: '正在停止下载调度…');
    }
    // 协调器已创建时先向真实下载和合并后端发送暂停，保存可继续使用的断点。
    if (ref.exists(downloadTaskCoordinatorProvider)) {
      await runStep('pause-downloads', () async {
        // 等待协调器初始化完成后统一暂停当前下载中页签的活动任务。
        final coordinator = await ref.read(
          downloadTaskCoordinatorProvider.future,
        );
        // 返回值只用于日志确认本轮覆盖数量，不改变退出流程。
        final pausedCount = await coordinator.pauseAllForShutdown();
        AppDebugLog.app(
          'Application shutdown requested pause count=$pausedCount.',
        );
      }, detail: '正在暂停下载任务…');
    }
    // 无论原生暂停是否成功，都把残留活动状态原子写成暂停供下次手动继续。
    if (ref.exists(downloadTaskRepositoryProvider)) {
      await runStep('persist-paused-downloads', () async {
        // 仓库兜底不删除任务、临时文件或断点，只保存原恢复阶段。
        final repository = ref.read(downloadTaskRepositoryProvider);
        // 正常暂停成功的任务已不在活动集合中，此处只处理遗漏或失败项。
        final pausedCount = await repository.pauseInterruptedTasks();
        AppDebugLog.app(
          'Application shutdown persisted pause count=$pausedCount.',
        );
      }, detail: '正在保存暂停状态…');
    }
    // 状态落盘后停止协调器接收事件，避免 aria2 关闭期间继续写入任务状态。
    if (ref.exists(downloadTaskCoordinatorProvider)) {
      await runStep('coordinator', () async {
        // Provider 已存在时等待其初始化完成，再关闭订阅和活动合并。
        final coordinator = await ref.read(
          downloadTaskCoordinatorProvider.future,
        );
        await coordinator.dispose();
      }, detail: '正在停止下载任务…');
    }
    // 独立 FFmpeg 合并进程需要在 aria2 前取消并等待退出。
    if (ref.exists(mediaMergerProvider)) {
      await runStep('media-merger', () async {
        // 已初始化的合并器负责取消活动会话或子进程。
        final merger = await ref.read(mediaMergerProvider.future);
        await merger.dispose();
      }, detail: '正在停止 FFmpeg 合并…');
    }
    // 引擎释放会停止轮询、保存 aria2 会话并终止底层进程。
    if (ref.exists(aria2DownloadEngineProvider)) {
      await runStep('aria2-engine', () async {
        // 只读取已经存在的 Provider，退出时不会凭空启动 aria2。
        final engine = await ref.read(aria2DownloadEngineProvider.future);
        await engine.dispose();
      }, detail: '正在关闭 aria2 下载引擎…');
    }
    // 引擎初始化失败时运行时仍可能已经拉起进程，因此再次兜底停止。
    if (ref.exists(aria2RuntimeProvider)) {
      await runStep('aria2-runtime', () async {
        // Runtime.stop 可重复调用，确保异常初始化路径也不会残留进程。
        final runtime = await ref.read(aria2RuntimeProvider.future);
        await runtime.stop();
      }, detail: '正在回收 aria2 进程…');
    }
    // 下载与合并均停止后再关闭 SQLite，确保最后一批任务状态已经落盘。
    if (ref.exists(appDatabaseProvider)) {
      await runStep('database', () async {
        // 显式等待 Drift 关闭连接和后台 isolate，再允许 Runner 销毁窗口。
        final database = ref.read(appDatabaseProvider);
        await database.close();
      }, detail: '正在关闭任务数据库…');
    }
    // 所有可用资源都已经完成关闭或记录了不阻断退出的错误。
    AppDebugLog.app('Application shutdown completed.');
  }

  /// 执行单个退出步骤，失败时记录原因并继续回收其他资源。
  Future<void> runStep(
    String name,
    Future<void> Function() action, {
    String? detail,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    // 有可见说明时在执行动作前刷新退出弹窗，便于定位具体停留阶段。
    if (detail != null) onDetailChanged(detail);
    try {
      // 每一步最多等待固定时长，单个插件无响应不能永久阻断退出。
      await action().timeout(timeout);
    } on TimeoutException {
      // 超时后继续下一项回收，最终由应用级看门狗保证进程结束。
      AppDebugLog.app(
        'Application shutdown step=$name timed out after ${timeout.inSeconds}s.',
      );
    } catch (error) {
      // 单个 Provider 初始化或清理失败不能阻止后续 aria2 兜底回收。
      AppDebugLog.app('Application shutdown step=$name error=$error');
    }
  }
}
