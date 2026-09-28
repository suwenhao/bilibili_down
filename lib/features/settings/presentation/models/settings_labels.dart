import 'package:flutter/material.dart';

import '../../../../services/bilibili/models/bili_dash_manifest.dart';
import '../../domain/app_settings.dart';

/// 返回下载附加内容的中文标签。
String downloadContentLabel(DownloadContentOption option) => switch (option) {
  DownloadContentOption.cover => '封面',
  DownloadContentOption.audio => '音频',
  DownloadContentOption.danmakuXml => 'XML弹幕',
  DownloadContentOption.danmakuAss => 'ASS弹幕',
  DownloadContentOption.subtitles => '字幕',
  DownloadContentOption.aiSubtitles => 'AI 字幕',
  DownloadContentOption.monitorClipboard => '监听剪切板',
};

/// 返回视频编码的设置页短标签。
String videoCodecLabel(BiliVideoCodec codec) => switch (codec) {
  BiliVideoCodec.avc => 'AVC',
  BiliVideoCodec.av1 => 'AV1',
  BiliVideoCodec.hevc => 'HEVC',
  BiliVideoCodec.unknown => '自动',
};

/// 返回视频编码在设置页信息图标中的说明。
String? videoCodecTooltip(BiliVideoCodec codec) => switch (codec) {
  BiliVideoCodec.avc =>
    'AVC 视频可广泛兼容各种设备和播放器，适用于大多数场景。\n但它相对较老，压缩效率不如一些新的视频编码标准。',
  BiliVideoCodec.av1 => 'AV1 视频格式能显著减小文件大小的同时保持相对较高的质量。\n但它相对较新，支持有限的播放器和设备。',
  BiliVideoCodec.hevc => 'HEVC 视频格式能减小文件大小的同时保持相对较高的质量。\n但它相对较新，支持有限的播放器和设备。',
  BiliVideoCodec.unknown => null,
};

/// 把重名处理枚举转换为设置页简短文案。
String outputConflictStrategyLabel(OutputConflictStrategy strategy) =>
    switch (strategy) {
      OutputConflictStrategy.autoRename => '自动编号',
      OutputConflictStrategy.skip => '跳过',
      OutputConflictStrategy.overwrite => '覆盖',
    };

/// 返回主题模式的设置页短标签。
String themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => '跟随系统',
  ThemeMode.light => '亮色',
  ThemeMode.dark => '暗色',
};

/// 将缓存字节数转换为设置页紧凑文本。
String formatCacheSize(int bytes) {
  // 小于一 KB 时直接显示整数 B。
  if (bytes < 1024) return '$bytes B';
  // 小于一 MB 时保留一位 KB，便于确认小型缓存。
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  // 常见封面缓存使用 MB 展示，避免文本挤压手机按钮。
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  // 极大缓存使用 GB，仍保持相同精度。
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
