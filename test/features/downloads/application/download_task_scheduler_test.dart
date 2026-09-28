import 'dart:async';

import 'package:bilibili_down/core/database/app_database.dart';
import 'package:bilibili_down/features/downloads/application/runtime/download_task_scheduler.dart';
import 'package:bilibili_down/features/downloads/data/download_task_draft.dart';
import 'package:bilibili_down/features/downloads/data/download_task_repository.dart';
import 'package:bilibili_down/features/downloads/domain/download_task_phase.dart';
import 'package:bilibili_down/features/settings/domain/app_settings.dart';
import 'package:bilibili_down/services/bilibili/bili_api_exception.dart';
import 'package:bilibili_down/services/download_engine/aria2/aria2_process_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 验证后台恢复会等待 Drift 首份快照并提交持久化等待任务。
  test('可等待恢复泵提交 waitingToStart 任务', () async {
    // 内存数据库模拟 WorkManager isolate 打开的独立 Drift 连接。
    final database = AppDatabase(NativeDatabase.memory());
    final repository = DownloadTaskRepository(database);
    // 预先保存系统后台需要恢复的等待任务。
    await repository.createTask(
      const DownloadTaskDraft(
        taskId: 'waiting-task',
        sourceInput: 'BV1nfj86AEAo',
        title: '后台恢复测试',
        phase: DownloadTaskPhase.waitingToStart,
      ),
    );
    // 假启动回调只记录提交，不触碰网络或原生下载插件。
    final launchedTaskIds = <String>[];
    final scheduler = DownloadTaskScheduler.withLaunchCallback(repository, (
      String taskId,
    ) async {
      // 记录 WorkManager 本轮真实认领的业务任务 ID。
      launchedTaskIds.add(taskId);
    }, () async => AppSettings.defaults());
    addTearDown(() async {
      // 先停止调度订阅，再关闭测试数据库。
      await scheduler.dispose();
      await database.close();
    });
    // 恢复方法必须等到本轮泵和启动回调都完成后才返回成功。
    await scheduler.runRecoveryPass();
    expect(launchedTaskIds, <String>['waiting-task']);
  });

  /// 验证未授权错误只影响当前任务，不把整个下载队列绑定到登录状态。
  test('未授权失败不冻结后续游客任务', () async {
    // 两条等待任务用于确认第一条失败后调度器仍继续释放和分配槽位。
    final database = AppDatabase(NativeDatabase.memory());
    final repository = DownloadTaskRepository(database);
    for (final id in const <String>['auth-task-1', 'auth-task-2']) {
      await repository.createTask(
        DownloadTaskDraft(
          taskId: id,
          sourceInput: 'BV-auth',
          title: id,
          phase: DownloadTaskPhase.waitingToStart,
        ),
      );
      // 保证创建时间排序稳定，第二条不会与第一条共享同一毫秒。
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    final launchedTaskIds = <String>[];
    final scheduler = DownloadTaskScheduler.withLaunchCallback(repository, (
      String taskId,
    ) async {
      launchedTaskIds.add(taskId);
      throw const BiliApiException(
        kind: BiliApiErrorKind.unauthorized,
        message: '登录已过期',
        apiCode: -101,
      );
    }, () async => AppSettings.defaults());
    addTearDown(() async {
      // 调度器停止后再关闭内存数据库，避免监听回调访问已释放连接。
      await scheduler.dispose();
      await database.close();
    });

    await scheduler.runRecoveryPass();

    // 数据库创建时间精度允许同一批任务顺序互换，业务只要求两条都继续调度。
    expect(
      launchedTaskIds,
      unorderedEquals(<String>['auth-task-1', 'auth-task-2']),
    );
    // 两条未授权失败都保留数据库记录并进入可见失败态，不会被退出账号删除。
    for (final taskId in launchedTaskIds) {
      expect(
        (await repository.findTask(taskId))?.phase,
        DownloadTaskPhase.failed,
      );
    }
  });

  /// 验证 aria2 全局启动失败时只失败当前任务，其余等待任务退回待下载。
  test('下载引擎启动失败会止损等待队列', () async {
    // 三条等待任务模拟用户并发启动多个待下载任务后的持久化队列。
    final database = AppDatabase(NativeDatabase.memory());
    final repository = DownloadTaskRepository(database);
    for (final id in const <String>['engine-1', 'engine-2', 'engine-3']) {
      await repository.createTask(
        DownloadTaskDraft(
          taskId: id,
          sourceInput: 'BV-engine',
          title: id,
          phase: DownloadTaskPhase.waitingToStart,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    final launchedTaskIds = <String>[];
    final scheduler = DownloadTaskScheduler.withLaunchCallback(
      repository,
      (String taskId) async {
        // 进程启动异常代表下载后端整体不可用，不能继续消费后面的等待队列。
        launchedTaskIds.add(taskId);
        throw const Aria2ProcessException('下载引擎启动失败');
      },
      () async => AppSettings.defaults().copyWith(concurrentDownloads: 3),
    );
    addTearDown(() async {
      // 停止调度器后关闭数据库，避免监听器读取已释放连接。
      await scheduler.dispose();
      await database.close();
    });

    await scheduler.runRecoveryPass();

    expect(launchedTaskIds, <String>['engine-1']);
    expect(
      (await repository.findTask('engine-1'))?.phase,
      DownloadTaskPhase.failed,
    );
    expect(
      (await repository.findTask('engine-1'))?.errorMessage,
      '下载引擎启动失败，请重启应用或稍后重试。',
    );
    expect(
      (await repository.findTask('engine-2'))?.phase,
      DownloadTaskPhase.queued,
    );
    expect(
      (await repository.findTask('engine-3'))?.phase,
      DownloadTaskPhase.queued,
    );
  });

  /// 验证启动服务因用户暂停而正常返回时，调度器不会把任务错误标记为失败。
  test('启动期间被用户暂停不会被调度器改成失败', () async {
    // 等待任务模拟已经批量加入下载中队列、尚未完成解析提交的状态。
    final database = AppDatabase(NativeDatabase.memory());
    final repository = DownloadTaskRepository(database);
    await repository.createTask(
      const DownloadTaskDraft(
        taskId: 'pause-during-launch',
        sourceInput: 'BV-pause',
        title: '启动中暂停',
        phase: DownloadTaskPhase.waitingToStart,
      ),
    );
    final launchedTaskIds = <String>[];
    final scheduler = DownloadTaskScheduler.withLaunchCallback(repository, (
      String taskId,
    ) async {
      // 启动服务复读数据库阶段后会安静返回；这里模拟用户刚好点击暂停。
      launchedTaskIds.add(taskId);
      await repository.transitionTask(taskId, DownloadTaskPhase.paused);
    }, () async => AppSettings.defaults());
    addTearDown(() async {
      // 停止订阅后关闭数据库，避免测试结束时仍有 Drift 监听。
      await scheduler.dispose();
      await database.close();
    });

    await scheduler.runRecoveryPass();

    expect(launchedTaskIds, <String>['pause-during-launch']);
    final task = await repository.findTask('pause-during-launch');
    expect(task?.phase, DownloadTaskPhase.paused);
    expect(task?.resumePhase, DownloadTaskPhase.waitingToStart);
    expect(task?.errorCode, isNull);
    expect(task?.errorMessage, isNull);
  });

  /// 验证多并发只扩大下载名额，不允许靠后的任务抢先完成启动提交。
  test('多并发任务按队列顺序依次提交', () async {
    // 内存数据库保存三条顺序明确的等待任务，模拟批量下载后的持久队列。
    final database = AppDatabase(NativeDatabase.memory());
    final repository = DownloadTaskRepository(database);
    for (final id in const <String>['queue-1', 'queue-2', 'queue-3']) {
      // 每条任务使用不同创建时间，明确表达用户在页面看到的队列顺序。
      await repository.createTask(
        DownloadTaskDraft(
          taskId: id,
          sourceInput: 'BV-queue',
          title: id,
          phase: DownloadTaskPhase.waitingToStart,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    // 每条启动闸门用于证明后一条不会在前一条提交完成前进入回调。
    final launchGates = <String, Completer<void>>{
      for (final id in const <String>['queue-1', 'queue-2', 'queue-3'])
        id: Completer<void>(),
    };
    // 记录回调进入顺序，结果必须始终与页面队列一致。
    final launchedTaskIds = <String>[];
    final scheduler = DownloadTaskScheduler.withLaunchCallback(
      repository,
      (String taskId) async {
        // 回调进入即代表该任务开始解析并准备提交下载引擎。
        launchedTaskIds.add(taskId);
        await launchGates[taskId]!.future;
      },
      () async => AppSettings.defaults().copyWith(concurrentDownloads: 3),
    );
    addTearDown(() async {
      // 释放全部闸门后再销毁调度器，避免测试清理等待未完成启动。
      for (final gate in launchGates.values) {
        if (!gate.isCompleted) gate.complete();
      }
      await scheduler.dispose();
      await database.close();
    });

    // 恢复泵在全部启动提交完成前保持等待，测试可逐个观察认领边界。
    final recovery = scheduler.runRecoveryPass();
    await _waitForLaunchCount(launchedTaskIds, 1);
    expect(launchedTaskIds, <String>['queue-1']);

    // 第一条提交后才允许第二条进入启动回调。
    launchGates['queue-1']!.complete();
    await _waitForLaunchCount(launchedTaskIds, 2);
    expect(launchedTaskIds, <String>['queue-1', 'queue-2']);

    // 第二条提交后才允许第三条进入，三条随后仍可同时占用下载名额。
    launchGates['queue-2']!.complete();
    await _waitForLaunchCount(launchedTaskIds, 3);
    expect(launchedTaskIds, <String>['queue-1', 'queue-2', 'queue-3']);
    launchGates['queue-3']!.complete();
    await recovery;
  });
}

/// 等待调度回调达到指定数量，避免测试依赖固定机器速度。
Future<void> _waitForLaunchCount(
  List<String> launchedTaskIds,
  int count,
) async {
  // 使用短轮询等待异步 Drift 快照与调度泵推进，超过时限则由测试明确失败。
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (launchedTaskIds.length < count && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  // 超时仍未达到目标时输出实际数量，便于定位队列停滞位置。
  expect(launchedTaskIds.length, greaterThanOrEqualTo(count));
}
