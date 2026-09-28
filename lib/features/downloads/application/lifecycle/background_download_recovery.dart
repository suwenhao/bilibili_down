import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/logging/app_debug_log.dart';
import '../../../../core/network/network_availability_provider.dart';
import '../runtime/download_task_scheduler.dart';

/// WorkManager 回调识别的后台下载恢复任务名。
const String backgroundDownloadRecoveryTask =
    'bilidown.background_download_recovery';

/// 周期恢复任务的唯一系统注册名称。
const String periodicRecoveryUniqueName = 'bilidown.periodic_download_recovery';

/// 断网后等待网络恢复的一次性任务唯一名称。
const String networkRecoveryUniqueName = 'bilidown.network_download_recovery';

/// 判断系统回调任务是否属于 BiliDown 下载恢复流程。
bool isBackgroundDownloadRecoveryTask(String task) {
  // Android 的周期/一次性任务及 iOS Background Fetch 共用同一安全入口。
  return task == backgroundDownloadRecoveryTask ||
      task == periodicRecoveryUniqueName ||
      task == networkRecoveryUniqueName ||
      task == Workmanager.iOSBackgroundTask;
}

/// 判断网络状态变化是否需要注册一次联网后恢复任务。
bool shouldRegisterNetworkRecovery({
  required bool? previousAvailability,
  required bool? currentAvailability,
}) {
  // 首次未知状态按在线处理，只有明确从非离线进入离线才注册一次。
  final wasAvailable = previousAvailability ?? true;
  return wasAvailable && currentAvailability == false;
}

/// WorkManager 独立 isolate 的顶层入口。
@pragma('vm:entry-point')
void backgroundDownloadRecoveryDispatcher() {
  // 插件负责建立后台 Flutter 绑定并把系统任务交给异步处理器。
  Workmanager().executeTask((
    String task,
    Map<String, dynamic>? inputData,
  ) async {
    // 只处理本应用注册的恢复任务和 iOS 系统 Background Fetch 回调。
    if (!isBackgroundDownloadRecoveryTask(task)) {
      return true;
    }
    // 后台 isolate 必须创建自己的 Provider 容器和数据库连接。
    final container = ProviderContainer();
    DownloadTaskScheduler? scheduler;
    AppDatabase? database;
    try {
      // 轻量查询确保 Drift 建表或迁移已经完成。
      await container.read(appDatabaseReadyProvider.future);
      database = container.read(appDatabaseProvider);
      // 后台 isolate 也是新的应用执行上下文，先把遗留活动任务安全降级为暂停。
      await container.read(downloadTaskStartupPauseProvider.future);
      // 调度器只提交当前并发槽位允许的等待任务，真正传输交给原生下载器。
      final activeScheduler = container.read(downloadTaskSchedulerProvider);
      scheduler = activeScheduler;
      await activeScheduler.runRecoveryPass();
      return true;
    } catch (error) {
      // 返回 false 让 Android WorkManager 按系统策略稍后重试。
      AppDebugLog.aria2('Background recovery failed task=$task error=$error');
      return false;
    } finally {
      // 先停止调度和事件订阅，再关闭后台 isolate 的 Drift 连接。
      await scheduler?.dispose();
      await database?.close();
      container.dispose();
    }
  });
}

/// 在移动端初始化 WorkManager 并注册周期网络恢复兜底。
Future<void> initializeBackgroundDownloadRecovery() async {
  // 桌面平台由常驻进程和 aria2 恢复，不注册不支持的移动后台 API。
  if (!Platform.isAndroid && !Platform.isIOS) return;
  // 初始化顶层回调入口，后台系统任务会在独立 isolate 执行。
  await Workmanager().initialize(backgroundDownloadRecoveryDispatcher);
  // 周期任务只在有网络、电量和存储空间正常时短暂提交等待任务。
  await Workmanager().registerPeriodicTask(
    periodicRecoveryUniqueName,
    backgroundDownloadRecoveryTask,
    frequency: const Duration(hours: 1),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: true,
      requiresStorageNotLow: true,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
}

/// 前台发现断网时为 Android 注册等待联网的一次性恢复兜底。
final backgroundDownloadRecoveryRegistrationProvider = Provider<void>((
  Ref ref,
) {
  // 只有 Android WorkManager 能可靠使用联网约束立即调度一次性任务。
  if (!Platform.isAndroid) return;
  ref.listen<AsyncValue<bool>>(networkAvailabilityProvider, (previous, next) {
    // 仅从非离线状态进入明确离线时注册，避免网络事件抖动重复写系统队列。
    // 将 AsyncValue 快照转换为可测试的纯状态迁移判断。
    final shouldRegister = shouldRegisterNetworkRecovery(
      previousAvailability: previous?.value,
      currentAvailability: next.value,
    );
    if (shouldRegister) {
      // 系统会等待网络连接后唤醒短任务，不在断网时空跑 Flutter isolate。
      unawaited(
        Workmanager().registerOneOffTask(
          networkRecoveryUniqueName,
          backgroundDownloadRecoveryTask,
          initialDelay: const Duration(seconds: 15),
          constraints: Constraints(
            networkType: NetworkType.connected,
            requiresBatteryNotLow: true,
            requiresStorageNotLow: true,
          ),
          existingWorkPolicy: ExistingWorkPolicy.replace,
          backoffPolicy: BackoffPolicy.exponential,
          backoffPolicyDelay: const Duration(minutes: 1),
        ),
      );
    }
  });
});
