import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/downloads/data/download_task_repository.dart';
import '../logging/app_debug_log.dart';
import 'app_database.dart';

/// 提供应用级 Drift 数据库单例。
final appDatabaseProvider = Provider<AppDatabase>((Ref ref) {
  // 创建跨平台后台 SQLite 连接。
  final database = AppDatabase();
  // Provider 容器销毁时异步关闭数据库连接和后台 isolate。
  ref.onDispose(() => unawaited(database.close()));
  // 返回供各业务仓库复用的数据库实例。
  return database;
});

/// 应用启动阶段主动打开数据库并完成建表或版本迁移。
final appDatabaseReadyProvider = FutureProvider<void>((Ref ref) async {
  // 监听应用级数据库单例，保证就绪状态存续期间连接不会被释放。
  final database = ref.watch(appDatabaseProvider);
  AppDebugLog.database('Database readiness check started');
  // 轻量查询会触发延迟连接、迁移策略和 beforeOpen 初始化。
  await database.customSelect('SELECT 1 AS ready').getSingle();
  AppDebugLog.database('Database readiness check completed');
});

/// 提供下载任务持久化仓库。
final downloadTaskRepositoryProvider = Provider<DownloadTaskRepository>((
  Ref ref,
) {
  // 监听数据库 Provider，数据库实例替换时同步重建仓库。
  final database = ref.watch(appDatabaseProvider);
  // 创建只封装下载任务相关表操作的仓库。
  return DownloadTaskRepository(database);
});
