import '../../../../core/database/app_database.dart';
import '../../domain/download_extra_resource.dart';
import '../../domain/download_task_phase.dart';
import '../../domain/stored_dash_options.dart';

/// 从当前任务同步解码解析阶段保存的 DASH 候选。
StoredDashOptions? storedDashOptionsForTask(DownloadTaskRecord task) {
  // 候选 JSON 已经包含在 Drift 列表记录中，不执行额外数据库查询。
  final source = task.dashOptionsJson;
  // 旧任务没有候选时返回空并禁用下拉。
  if (source == null || source.isEmpty) return null;
  try {
    // 同步恢复紧凑候选对象，通常只包含少量音视频元数据。
    return StoredDashOptions.decode(source);
  } on FormatException {
    // 损坏的旧数据不能阻断整个任务列表渲染。
    return null;
  }
}

/// 生成音频下拉候选短文案。
String audioOptionLabel(StoredAudioOption option) {
  // RFC 6381 编码只展示主编码名，例如 mp4a.40.2 显示为 mp4a。
  final codec = option.codec.split('.').first;
  // 使用竖线分隔音质和编码，与参考下拉一致。
  return '${option.qualityLabel} | $codec';
}

/// 生成视频下拉候选短文案。
String videoOptionLabel(StoredVideoOption option) {
  // 视频编码使用稳定枚举大写名称。
  return '${option.qualityLabel} | ${option.codec.name.toUpperCase()}';
}

/// 生成任务当前音质与短编码文案。
String audioLabel(DownloadTaskRecord task) {
  // 音频质量 ID 为空表示用户明确选择不下载音频。
  if (task.audioQualityId == null) return '无';
  // 旧数据只有 ID 没有文案时使用自动选择。
  final value = task.audioCodec;
  if (value == null || value.isEmpty) return '自动选择';
  // 分离音质和 RFC 6381 编码。
  final parts = value.split('|');
  // 旧数据没有分隔符时原样展示。
  if (parts.length < 2) return value;
  // 只展示编码主名称并清理空格。
  final codec = parts.last.trim().split('.').first;
  // 返回参考设计中的紧凑形式。
  return '${parts.first.trim()} | $codec';
}

/// 生成视频画质与编码组合文案。
String videoLabel(DownloadTaskRecord task) {
  // 视频质量 ID 为空表示用户明确选择纯音频任务。
  if (task.qualityId == null) return '无';
  // 旧数据没有文案时使用自动选择，已有编码统一转换为大写便于识别。
  final quality = task.qualityLabel ?? '自动选择';
  // 未保存编码时只显示画质。
  if (task.videoCodec == null || task.videoCodec!.isEmpty) return quality;
  // 使用竖线分隔画质和编码，与设计稿一致。
  return '$quality | ${task.videoCodec!.toUpperCase()}';
}

/// 根据任务实际音视频选择生成稳定任务类型。
String mediaTaskTypeLabel(DownloadTaskRecord task) {
  // 独立附加资源任务优先显示真实资源类型，不套用音视频组合规则。
  final extraResource = downloadExtraResourceFromCode(task.contentType);
  if (extraResource != null) return downloadExtraResourceLabel(extraResource);
  // 音质和画质同时存在时下载并封装为有声视频。
  if (task.audioQualityId != null && task.qualityId != null) return '有声视频';
  // 只有视频流时生成无声视频。
  if (task.qualityId != null) return '无声视频';
  // 合法任务剩余情况为纯音频。
  if (task.audioQualityId != null) return '音频';
  // 损坏旧数据使用未知类型，不伪造媒体内容。
  return '未知类型';
}

/// 返回独立资源分流当前可确认的文件大小。
int resourceSizeBytes(List<DownloadStreamRecord> streams) {
  // 每条资源任务当前只有一条分流，累加写法仍兼容未来拆分资源。
  return streams.fold<int>(0, (int total, DownloadStreamRecord stream) {
    // 服务端总大小可用时优先展示最终大小，否则显示已经接收的字节数。
    final bytes = (stream.totalBytes ?? 0) > 0
        ? stream.totalBytes!
        : stream.downloadedBytes;
    return total + bytes;
  });
}

/// 将解析时保存的预计字节数转换为任务卡短文本。
String fileSizeLabel(int? bytes) {
  // 旧任务或接口未提供有效码率时明确显示未知，不再显示等待下载。
  if (bytes == null || bytes <= 0) return '未知';
  // 小于一 KB 时直接展示整数 B。
  if (bytes < 1024) return '$bytes B';
  // 使用二进制进位，与下载引擎常见文件大小显示保持一致。
  const units = <String>['KB', 'MB', 'GB', 'TB'];
  // 从字节转换到 KB 起始值。
  var value = bytes / 1024;
  // 保存当前单位索引。
  var unitIndex = 0;
  // 数值达到下一单位且仍有更高单位时继续换算。
  while (value >= 1024 && unitIndex < units.length - 1) {
    // 除以 1024 进入下一文件大小单位。
    value /= 1024;
    // 同步推进单位索引。
    unitIndex++;
  }
  // 保留两位小数，便于音频等较小分流比较质量差异。
  return '${value.toStringAsFixed(2)} ${units[unitIndex]}';
}

/// 将毫秒时长转换为时分秒。
String durationLabel(int? milliseconds) {
  // 未知或无效时长显示占位符。
  if (milliseconds == null || milliseconds <= 0) return '--:--';
  // 转换为完整秒数。
  final totalSeconds = Duration(milliseconds: milliseconds).inSeconds;
  // 计算小时、分钟和秒。
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  // 秒固定两位。
  final secondText = seconds.toString().padLeft(2, '0');
  // 一小时以上显示三段，否则显示常用的分秒。
  if (hours > 0) {
    // 分钟在小时格式中固定两位。
    return '$hours:${minutes.toString().padLeft(2, '0')}:$secondText';
  }
  // 普通视频显示分钟和秒。
  return '${minutes.toString().padLeft(2, '0')}:$secondText';
}

/// 将时间转换为任务列表短日期。
String dateLabel(DateTime value) {
  // 月日时分均补齐两位，桌面和手机使用相同格式。
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  // 返回稳定的本地时间文本。
  return '${value.year}/$month/$day $hour:$minute';
}

/// 将任务阶段转换为中文说明。
String phaseLabel(DownloadTaskPhase phase) {
  // 所有领域阶段都必须有稳定页面文案。
  return switch (phase) {
    DownloadTaskPhase.queued => '待下载',
    DownloadTaskPhase.waitingToStart => '等待开始',
    DownloadTaskPhase.resolving => '正在解析播放地址',
    DownloadTaskPhase.downloading => '下载中',
    DownloadTaskPhase.waitingForMerge => '等待合并',
    DownloadTaskPhase.merging => 'FFmpeg 正在合并音视频',
    DownloadTaskPhase.paused => '已暂停',
    DownloadTaskPhase.completed => '已下载',
    DownloadTaskPhase.failed => '下载失败',
    DownloadTaskPhase.canceled => '已取消',
  };
}
