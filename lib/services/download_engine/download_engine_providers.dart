import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/platform/application_data_directory.dart';
import '../../core/platform/platform_providers.dart';
import '../../core/platform/runtime_platform.dart';
import '../../core/logging/app_debug_log.dart';
import '../../features/settings/application/app_settings_controller.dart';
import '../../features/settings/domain/app_settings.dart';
import 'aria2/aria2_download_engine.dart';
import 'aria2/aria2_runtime.dart';
import 'download_engine.dart';
import 'download_engine_factory.dart';
import 'system/system_download_engine.dart';

/// 创建并管理当前平台的 aria2 运行时。
final aria2RuntimeProvider = FutureProvider<Aria2Runtime>((ref) async {
  // 等待原生工具路径解析完成后再构造进程运行时。
  final paths = await ref.watch(nativeToolPathsProvider.future);
  // 只有已经选中 aria2 的平台才能使用该 Provider。
  if (paths.downloadBackend != DownloadBackendKind.aria2) {
    throw UnsupportedError('aria2 is not the primary engine on this platform.');
  }
  // 应用数据目录用于保存 aria2 会话、日志和默认下载文件，并与数据库目录保持一致。
  final supportDirectory = await resolveApplicationDataDirectory();
  // 初次构造运行时时读取已恢复设置，确保新进程启动参数就是用户当前限速。
  final settings = await ref
      .read(appSettingsControllerProvider.notifier)
      .loadReadySettings();
  // 组装 aria2 运行时所需的工具路径与数据目录。
  final runtime = Aria2Runtime(
    toolPaths: paths,
    supportDirectory: supportDirectory,
    downloadDirectory: Directory(p.join(supportDirectory.path, 'downloads')),
    initialMaxOverallDownloadLimitMegabytesPerSecond:
        settings.downloadSpeedLimitMegabytesPerSecond,
  );
  // Provider 销毁时异步关闭 aria2，避免残留后台进程。
  ref.onDispose(() => unawaited(runtime.stop()));
  return runtime;
});

/// 创建能够恢复任务映射的 aria2 下载引擎。
final aria2DownloadEngineProvider = FutureProvider<Aria2DownloadEngine>((
  ref,
) async {
  // 运行时初始化前先注册设置监听；未创建 runtime 时不会主动启动 aria2。
  Aria2Runtime? runtime;
  ref.listen<AppSettings>(appSettingsControllerProvider, (
    AppSettings? previous,
    AppSettings next,
  ) {
    // 只在限速字段变化时刷新 aria2，避免质量、目录等设置触发无关 RPC。
    if (previous?.downloadSpeedLimitMegabytesPerSecond ==
        next.downloadSpeedLimitMegabytesPerSecond) {
      return;
    }
    // 下载引擎尚未初始化时不启动进程，后续构造会读取最新持久化设置。
    final currentRuntime = runtime;
    if (currentRuntime == null) return;
    // aria2 全局选项更新失败只进入日志，下载任务的错误处理仍由调度器负责。
    unawaited(
      currentRuntime
          .updateMaxOverallDownloadLimit(
            next.downloadSpeedLimitMegabytesPerSecond,
          )
          .catchError((Object error, StackTrace stackTrace) {
            // 限速 RPC 失败不能让 Provider 生命周期崩溃，后续启动会再次应用。
            AppDebugLog.aria2('Download limit update failed error=$error');
          }),
    );
  });
  // 复用已经初始化的平台运行时。
  final initializedRuntime = await ref.watch(aria2RuntimeProvider.future);
  // 保存给设置监听回调，后续限速变化可以直接同步到当前运行时。
  runtime = initializedRuntime;
  // 每个 Provider 生命周期只创建一个任务引擎实例。
  final engine = Aria2DownloadEngine(initializedRuntime);
  // Provider 销毁时关闭轮询、事件流和底层运行时。
  ref.onDispose(() => unawaited(engine.dispose()));
  // 读取本地任务映射，使应用重启后能继续观察 aria2 任务。
  await engine.restore();
  return engine;
});

/// 创建并恢复由平台原生后台传输 API 管理的下载引擎。
final systemDownloadEngineProvider = FutureProvider<SystemDownloadEngine>((
  ref,
) async {
  // 构造时立即监听 background_downloader 的状态和进度广播流。
  final engine = SystemDownloadEngine();
  // Provider 销毁时取消监听并关闭业务事件流，但不杀死系统后台任务。
  ref.onDispose(() => unawaited(engine.dispose()));
  // 启用插件数据库跟踪并恢复应用挂起期间的任务状态。
  await engine.restore();
  // 返回已经完成恢复的系统下载引擎。
  return engine;
});

/// 业务层唯一使用的下载引擎 Provider，页面不判断平台或具体实现。
final downloadEngineProvider = FutureProvider<DownloadEngine>((ref) async {
  // 在首次异步等待前监听平台和工具路径，保证 Riverpod 能稳定记录全部依赖。
  final platform = ref.watch(runtimePlatformProvider);
  final pathsFuture = ref.watch(nativeToolPathsProvider.future);
  // 只监听当前平台选中的具体引擎，避免在 iOS 上误初始化 aria2 运行时。
  final (aria2Future, systemFuture) = switch (platform.primaryDownloadBackend) {
    DownloadBackendKind.aria2 => (
      ref.watch(aria2DownloadEngineProvider.future),
      null,
    ),
    DownloadBackendKind.system => (
      null,
      ref.watch(systemDownloadEngineProvider.future),
    ),
  };
  // 等待原生工具解析完成，工厂将再次校验最终后端选择。
  final paths = await pathsFuture;
  // 在组合根注入两种异步构造器，工厂只负责按后端类型分派。
  final factory = DownloadEngineFactory(
    aria2Builder: (_) {
      // aria2 平台复用异步等待前已经监听的具体引擎 Future。
      final engineFuture = aria2Future;
      // 平台检测与工具解析结果不一致时拒绝错误构造。
      if (engineFuture == null) {
        throw StateError('Aria2 engine was not selected for this platform.');
      }
      // 返回已经由 Riverpod 管理生命周期的 aria2 引擎。
      return engineFuture;
    },
    systemBuilder: (_) {
      // 系统下载平台复用异步等待前已经监听的具体引擎 Future。
      final engineFuture = systemFuture;
      // 平台检测与工具解析结果不一致时拒绝错误构造。
      if (engineFuture == null) {
        throw StateError('System engine was not selected for this platform.');
      }
      // 返回由 Riverpod 管理生命周期的系统后台下载引擎。
      return engineFuture;
    },
  );
  // 调用工厂创建当前平台唯一下载引擎。
  return factory.create(paths);
});
