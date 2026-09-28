import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../../../core/logging/app_debug_log.dart';
import '../../../../core/platform/platform_providers.dart';
import '../../../../core/platform/default_download_directory.dart';
import '../../../../core/platform/runtime_platform.dart';
import '../../../../services/download_engine/download_engine_providers.dart';
import '../../../../services/media_merge/media_merge_providers.dart';
import '../../../../services/media_output/media_output_publisher.dart';
import '../../../../services/bilibili/bili_expired_media_url_resolver_provider.dart';
import '../../../../services/bilibili/bilibili_providers.dart';
import '../../../settings/application/app_settings_controller.dart';
import 'download_task_coordinator.dart';
import '../maintenance/download_completion_cleanup_service.dart';
import '../maintenance/completed_output_integrity_service.dart';
import '../maintenance/orphan_temporary_directory_cleaner.dart';
import '../resources/embedded_extra_resource_processor.dart';
import '../resources/standalone_extra_resource_finalizer.dart';

/// 创建并恢复应用级双流下载协调器。
final downloadTaskCoordinatorProvider = FutureProvider<DownloadTaskCoordinator>((
  Ref ref,
) async {
  // 标记应用级协调器异步初始化开始。
  AppDebugLog.aria2('Coordinator initialization started.');
  // 在首次异步等待前监听全部依赖，保证 Riverpod 正确管理生命周期。
  final platform = ref.watch(runtimePlatformProvider);
  final repository = ref.watch(downloadTaskRepositoryProvider);
  final expiredMediaUrlResolver = ref.watch(expiredMediaUrlResolverProvider);
  // 附加资源处理器复用同一解析服务，登录状态只影响可获取的资源质量和字幕轨道。
  final parser = ref.watch(bilibiliParserServiceProvider);
  final settingsController = ref.watch(appSettingsControllerProvider.notifier);
  final downloadEngineFuture = ref.watch(downloadEngineProvider.future);
  final mediaMergerFuture = ref.watch(mediaMergerProvider.future);
  // 等待当前平台下载引擎完成原生工具和恢复初始化。
  final downloadEngine = await downloadEngineFuture;
  // 下载引擎已经完成 aria2 或系统后端恢复。
  AppDebugLog.aria2('Coordinator download engine ready.');
  // 等待当前平台媒体合并器完成后端选择。
  final mediaMerger = await mediaMergerFuture;
  // 合并器已经完成 FFmpeg 后端选择。
  AppDebugLog.ffmpeg('Coordinator media merger ready.');
  // 成品发布器同时供协调器和启动一致性检查使用，统一使用真实文件路径。
  final mediaOutputPublisher = createMediaOutputPublisher(platform);
  // 完成清理服务集中处理覆盖旧记录和临时目录删除，避免协调器直接操作文件树。
  final completionCleanup = DownloadCompletionCleanupService(
    repository,
    mediaOutputPublisher,
  );
  // 创建协调器；iOS 后台下载完成后先等待应用显式继续合并。
  final coordinator = DownloadTaskCoordinator(
    downloadEngine,
    mediaMerger,
    mediaOutputPublisher,
    repository,
    EmbeddedExtraResourceProcessor(
      parser,
      mediaMerger,
      mediaOutputPublisher,
      repository,
    ),
    autoMergeCompletedStreams:
        platform.operatingSystem != HostOperatingSystem.ios,
    expiredMediaUrlResolver: expiredMediaUrlResolver,
    completionCleanup: completionCleanup,
    standaloneExtraResourceFinalizer: StandaloneExtraResourceFinalizer(
      repository,
      mediaOutputPublisher,
      completionCleanup,
    ),
  );
  // Provider 销毁时取消监听和活动合并，并等待队列完成清理。
  ref.onDispose(() => unawaited(coordinator.dispose()));
  try {
    // 下载引擎恢复业务任务前先修复终态，避免已发布成品的任务再次进入合并队列。
    final integrityResult = await CompletedOutputIntegrityService(
      repository,
      mediaOutputPublisher,
    ).repair();
    AppDebugLog.aria2(
      'Output integrity: checked=${integrityResult.checked}, '
      'completed=${integrityResult.repairedCompleted}, '
      'invalid=${integrityResult.markedInvalid}, failed=${integrityResult.failed}.',
    );
  } catch (error) {
    // 整体检查异常不能阻止协调器启动，保留现有数据库状态等待下次修复。
    AppDebugLog.aria2('Output integrity check skipped: $error');
  }
  // 在监听已经建立后重放下载引擎状态并恢复待合并任务。
  await coordinator.restore();
  try {
    // 协调器恢复完成后读取数据库白名单，避免误删活动、失败或可恢复任务文件。
    final protectedTemporaryDirectories = await repository
        .loadProtectedTemporaryDirectories();
    // 默认工作目录始终可能保留上次异常退出产生的孤立任务目录。
    final cleanupRoots = <Directory>[await resolveDefaultDownloadDirectory()];
    final settings = await settingsController.loadReadySettings();
    final customDownloadPath = settings.downloadDirectoryPath?.trim();
    if (customDownloadPath != null && customDownloadPath.isNotEmpty) {
      // 当前桌面自定义目录也纳入扫描，但清理器会去重并限制在 `.temp` 内。
      cleanupRoots.add(Directory(customDownloadPath));
    }
    // 清理器内部隔离单目录错误，并返回统计用于启动诊断。
    final cleanupResult = await const OrphanTemporaryDirectoryCleaner().cleanup(
      downloadRoots: cleanupRoots,
      protectedTemporaryDirectories: protectedTemporaryDirectories,
    );
    AppDebugLog.aria2(
      'Temporary cleanup: deleted=${cleanupResult.deleted}, '
      'protected=${cleanupResult.protected}, recent=${cleanupResult.tooRecent}, '
      'failed=${cleanupResult.failed}.',
    );
  } catch (error) {
    // 白名单或根目录解析失败时完整跳过清理，下载恢复结果仍然有效。
    AppDebugLog.aria2('Temporary cleanup skipped: $error');
  }
  // 恢复流程结束后协调器可以接收新任务。
  AppDebugLog.aria2('Coordinator initialization completed.');
  // 返回已经完成初始恢复的协调器。
  return coordinator;
});
