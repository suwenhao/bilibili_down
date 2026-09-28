import 'package:bilibili_down/features/downloads/application/queue/download_queue_service.dart';
import 'package:bilibili_down/features/downloads/domain/download_extra_resource.dart';
import 'package:bilibili_down/features/downloads/domain/download_task_phase.dart';
import 'package:bilibili_down/features/settings/domain/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  /// 验证所有主任务统一使用标题目录，自动编号可同时作用于目录和文件名。
  test('主任务输出路径统一使用同名标题目录', () {
    // 构造函数不依赖真实文件系统，Windows 分隔符由显式父路径保持可预测。
    final outputPath = buildTaskOutputPath(
      parentDirectory: p.join('downloads', '合集'),
      baseName: '视频标题 (2)',
    );
    expect(outputPath, p.join('downloads', '合集', '视频标题 (2)', '视频标题 (2).mp4'));
  });

  /// 验证没有磁盘或数据库占用时不会无故改名或跳过。
  test('未占用路径始终使用原始名称', () {
    // 即使选择跳过，未发生冲突时也必须正常创建任务。
    final decision = decideOutputConflict(
      strategy: OutputConflictStrategy.skip,
      fileExists: false,
      conflictingPhases: const <DownloadTaskPhase>[],
    );
    expect(decision, OutputConflictDecision.useExact);
  });

  /// 验证三种用户策略在普通同名文件上的分支结果。
  test('同名磁盘文件按设置自动编号跳过或覆盖', () {
    // 自动编号保留旧文件，并要求路径解析器继续寻找新名称。
    expect(
      decideOutputConflict(
        strategy: OutputConflictStrategy.autoRename,
        fileExists: true,
        conflictingPhases: const <DownloadTaskPhase>[],
      ),
      OutputConflictDecision.autoRename,
    );
    // 跳过不能创建本次冲突任务。
    expect(
      decideOutputConflict(
        strategy: OutputConflictStrategy.skip,
        fileExists: true,
        conflictingPhases: const <DownloadTaskPhase>[],
      ),
      OutputConflictDecision.skip,
    );
    // 覆盖磁盘成品时复用用户原始名称。
    expect(
      decideOutputConflict(
        strategy: OutputConflictStrategy.overwrite,
        fileExists: true,
        conflictingPhases: const <DownloadTaskPhase>[],
      ),
      OutputConflictDecision.useExact,
    );
  });

  /// 验证覆盖策略只能替换终态历史，不能抢占仍会写文件的任务。
  test('覆盖策略保护活动任务并允许替换终态历史', () {
    // 已完成和已取消记录不会再次写入，可由新成品安全取代。
    expect(
      decideOutputConflict(
        strategy: OutputConflictStrategy.overwrite,
        fileExists: true,
        conflictingPhases: const <DownloadTaskPhase>[
          DownloadTaskPhase.completed,
          DownloadTaskPhase.canceled,
        ],
      ),
      OutputConflictDecision.useExact,
    );
    // 等待启动的任务仍将写入该路径，覆盖必须拒绝共享路径。
    expect(
      decideOutputConflict(
        strategy: OutputConflictStrategy.overwrite,
        fileExists: false,
        conflictingPhases: const <DownloadTaskPhase>[
          DownloadTaskPhase.waitingToStart,
        ],
      ),
      OutputConflictDecision.skip,
    );
  });

  /// 验证默认内容只映射真实文件资源，不创建运行时行为伪任务。
  test('默认下载内容只映射可独立写入的资源', () {
    // 混合文件选项和剪贴板监听，覆盖文件资源与运行时行为的过滤边界。
    final resources = automaticExtraResources(<DownloadContentOption>{
      DownloadContentOption.cover,
      DownloadContentOption.audio,
      DownloadContentOption.danmakuXml,
      DownloadContentOption.danmakuAss,
      DownloadContentOption.subtitles,
      DownloadContentOption.aiSubtitles,
      DownloadContentOption.monitorClipboard,
    });
    // 结果顺序与设置枚举输入一致，且不包含任何运行时行为。
    expect(resources, <DownloadExtraResource>{
      DownloadExtraResource.cover,
      DownloadExtraResource.audio,
      DownloadExtraResource.danmakuXml,
      DownloadExtraResource.danmakuAss,
      DownloadExtraResource.subtitles,
      DownloadExtraResource.aiSubtitles,
    });
  });
}
