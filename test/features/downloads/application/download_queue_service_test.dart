import 'dart:io';

import 'package:bilibili_down/core/database/app_database.dart';
import 'package:bilibili_down/core/network/bili_network_client.dart';
import 'package:bilibili_down/core/platform/runtime_platform.dart';
import 'package:bilibili_down/features/downloads/application/queue/download_queue_service.dart';
import 'package:bilibili_down/features/downloads/data/download_task_draft.dart';
import 'package:bilibili_down/features/downloads/data/download_task_repository.dart';
import 'package:bilibili_down/features/downloads/domain/download_extra_resource.dart';
import 'package:bilibili_down/features/downloads/domain/download_task_phase.dart';
import 'package:bilibili_down/features/settings/domain/app_settings.dart';
import 'package:bilibili_down/services/bilibili/bili_input_normalizer.dart';
import 'package:bilibili_down/services/bilibili/bilibili_parser_service.dart';
import 'package:bilibili_down/services/bilibili/wbi_signer.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  /// 验证待下载卡片修改附加资源时只更新数据库，不落地任何任务目录。
  test('待下载附加资源更新不创建标题目录或临时目录', () async {
    // 临时根目录隔离本测试的路径规划，测试结束后完整清理。
    final root = await Directory.systemTemp.createTemp(
      'bilidown_queue_directory_test_',
    );
    // 内存数据库保存一条尚未开始的主任务。
    final database = AppDatabase(NativeDatabase.memory());
    final repository = DownloadTaskRepository(database);
    // 任务路径只写入数据库，合集目录和临时目录初始均不存在。
    final outputPath = p.join(root.path, '测试合集', '视频标题.mp4');
    final temporaryPath = p.join(root.path, '.temp', 'queued-task');
    await repository.createTask(
      DownloadTaskDraft(
        taskId: 'queued-task',
        sourceInput: 'BV-queued',
        title: '视频标题',
        collectionTitle: '测试合集',
        bvid: 'BVqueued',
        cid: 100,
        outputPath: outputPath,
        temporaryDirectory: temporaryPath,
        phase: DownloadTaskPhase.queued,
      ),
    );
    addTearDown(() async {
      // 先关闭数据库连接，再清除测试自行创建的临时根目录。
      await database.close();
      if (await root.exists()) await root.delete(recursive: true);
    });
    // Windows 平台描述只决定后端类型，本测试不会启动真实下载组件。
    const platform = RuntimePlatform(
      operatingSystem: HostOperatingSystem.windows,
      architecture: CpuArchitecture.x64,
    );
    // 构造真实但不会发起请求的解析依赖，本次数据库更新不会调用网络方法。
    final networkClient = BiliNetworkClient();
    final parser = BilibiliParserService(
      networkClient,
      BiliInputNormalizer(networkClient),
      WbiSigner(networkClient),
    );
    // 设置加载器返回测试根路径，保证服务依赖完整且不接触用户目录。
    final service = DownloadQueueService(
      repository,
      platform,
      parser,
      () async =>
          AppSettings.defaults().copyWith(downloadDirectoryPath: root.path),
    );
    // 从数据库读取真实记录，模拟用户在待下载卡片勾选封面。
    final task = (await repository.findTask('queued-task'))!;
    await service.updateTaskExtraResources(
      task: task,
      resources: const <DownloadExtraResource>{DownloadExtraResource.cover},
    );

    final withResource = (await repository.findTask('queued-task'))!;
    expect(
      withResource.outputPath,
      p.join(root.path, '测试合集', '视频标题', '视频标题.mp4'),
    );

    await service.updateTaskExtraResources(
      task: withResource,
      resources: const <DownloadExtraResource>{},
    );

    final withoutResource = (await repository.findTask('queued-task'))!;
    expect(withoutResource.outputPath, p.join(root.path, '测试合集', '视频标题.mp4'));

    // 待下载阶段只能产生数据库变化，规划目录和临时目录都必须继续不存在。
    expect(await Directory(p.dirname(outputPath)).exists(), isFalse);
    expect(
      await Directory(p.join(root.path, '测试合集', '视频标题')).exists(),
      isFalse,
    );
    expect(await Directory(temporaryPath).exists(), isFalse);
  });
}
