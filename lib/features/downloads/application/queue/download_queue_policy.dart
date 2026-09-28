import 'package:path/path.dart' as p;

import '../../../settings/domain/app_settings.dart';
import '../../domain/download_extra_resource.dart';
import '../../domain/download_task_phase.dart';

/// 构造“父目录/标题/标题.扩展名”的统一主任务输出路径。
String buildTaskOutputPath({
  required String parentDirectory,
  required String baseName,
  String extension = '.mp4',
}) {
  // 目录名与最终文件基础名保持一致，自动编号后也能形成独立任务边界。
  return p.join(parentDirectory, baseName, '$baseName$extension');
}

/// 重名检查完成后对当前精确输出路径采取的动作。
enum OutputConflictDecision {
  /// 使用未占用的原始路径，或按覆盖策略复用终态历史路径。
  useExact,

  /// 不创建会与现有文件或活动任务冲突的新任务。
  skip,

  /// 保留现有内容并继续寻找带递增序号的可用路径。
  autoRename,
}

/// 根据设置、磁盘占用和数据库任务阶段决定精确路径处理方式。
OutputConflictDecision decideOutputConflict({
  required OutputConflictStrategy strategy,
  required bool fileExists,
  required Iterable<DownloadTaskPhase> conflictingPhases,
}) {
  // 固化阶段集合，调用方可能传入依赖查询结果的延迟迭代。
  final phases = conflictingPhases.toList(growable: false);
  // 没有磁盘文件和任务记录时，所有策略都应使用用户原始名称。
  if (!fileExists && phases.isEmpty) return OutputConflictDecision.useExact;
  // 自动编号始终保留已有文件和全部任务记录。
  if (strategy == OutputConflictStrategy.autoRename) {
    return OutputConflictDecision.autoRename;
  }
  // 跳过策略遇到任何占用都停止创建本次任务。
  if (strategy == OutputConflictStrategy.skip) {
    return OutputConflictDecision.skip;
  }
  // 覆盖只能替换 completed/canceled 历史；其他阶段仍可能写入该路径。
  final hasActiveTask = phases.any(
    (DownloadTaskPhase phase) =>
        phase != DownloadTaskPhase.completed &&
        phase != DownloadTaskPhase.canceled,
  );
  return hasActiveTask
      ? OutputConflictDecision.skip
      : OutputConflictDecision.useExact;
}

/// “跳过重名文件”策略阻止手动派生任务时抛出的可识别异常。
final class OutputConflictSkippedException implements Exception {
  /// 创建不携带外部文件名的稳定业务异常。
  const OutputConflictSkippedException();

  /// 为页面错误提示提供简短中文原因。
  @override
  String toString() => '目标文件已存在，已按重名设置跳过。';
}

/// 把默认下载内容设置转换为随主任务保存的附加资源集合。
Set<DownloadExtraResource> automaticExtraResources(
  Set<DownloadContentOption> options,
) {
  // 使用枚举集合保持稳定顺序，并自动去除重复设置。
  final resources = <DownloadExtraResource>{};
  for (final option in options) {
    // 文件选项映射资源类型，运行时行为映射为空并由其他服务处理。
    final resource = switch (option) {
      DownloadContentOption.cover => DownloadExtraResource.cover,
      DownloadContentOption.audio => DownloadExtraResource.audio,
      DownloadContentOption.danmakuXml => DownloadExtraResource.danmakuXml,
      DownloadContentOption.danmakuAss => DownloadExtraResource.danmakuAss,
      DownloadContentOption.subtitles => DownloadExtraResource.subtitles,
      DownloadContentOption.aiSubtitles => DownloadExtraResource.aiSubtitles,
      DownloadContentOption.monitorClipboard => null,
    };
    // 剪贴板监听属于运行时行为，不能创建伪下载任务。
    if (resource != null) resources.add(resource);
  }
  // 调用方只读使用本次映射结果。
  return Set<DownloadExtraResource>.unmodifiable(resources);
}
