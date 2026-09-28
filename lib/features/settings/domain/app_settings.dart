import '../../../services/bilibili/models/bili_dash_manifest.dart';

/// 关闭桌面窗口时采用的行为。
enum AppExitBehavior {
  /// 直接结束应用进程。
  exitApplication,

  /// 隐藏窗口并保留托盘后台任务。
  minimizeToTray,
}

/// 最终输出文件与现有文件重名时采用的处理方式。
enum OutputConflictStrategy {
  /// 保留现有文件，并为新文件追加递增序号。
  autoRename,

  /// 保留现有文件，不创建本次冲突任务。
  skip,

  /// 使用原始名称发布新文件，并替换已有成品。
  overwrite,
}

/// 可由设置中心控制的下载附加内容。
enum DownloadContentOption {
  /// 同时保存视频封面。
  cover,

  /// 同时下载并合并音频。
  audio,

  /// 保存 XML 弹幕。
  danmakuXml,

  /// 保存 ASS 弹幕。
  danmakuAss,

  /// 保存人工字幕文件。
  subtitles,

  /// 保存 B 站已经生成的 AI 字幕文件。
  aiSubtitles,

  /// 自动识别剪贴板中的 B 站链接。
  monitorClipboard,
}

/// 设置中心提供的默认音质档位。
enum DefaultAudioQuality {
  /// 64K 普通音轨。
  low64(30216, '64K', 0),

  /// 132K 普通音轨。
  medium132(30232, '132K', 1),

  /// 192K 普通音轨。
  high192(30280, '192K', 2),

  /// 杜比全景声音轨。
  dolby(30250, '杜比全景声', 3),

  /// Hi-Res 无损音轨。
  hiRes(30251, 'Hi-Res 无损', 4);

  /// 创建稳定的音频质量配置。
  const DefaultAudioQuality(this.dashId, this.label, this.rank);

  /// B 站 DASH 音频流 ID。
  final int dashId;

  /// 设置页展示文案。
  final String label;

  /// 从低到高的产品质量顺序。
  final int rank;
}

/// 设置中心提供的默认视频画质档位。
enum DefaultVideoQuality {
  /// 360P 流畅。
  p360(16, '360P', 0),

  /// 480P 清晰。
  p480(32, '480P', 1),

  /// 720P 高清。
  p720(64, '720P', 2),

  /// 1080P 高清。
  p1080(80, '1080P', 3),

  /// 1080P 高码率。
  p1080HighBitrate(112, '1080高码', 4),

  /// 1080P 高帧率。
  p1080HighFrameRate(116, '1080高帧', 5),

  /// 4K 超清。
  p4k(120, '4K', 6),

  /// HDR 真彩。
  hdr(125, 'HDR', 7),

  /// 杜比视界。
  dolbyVision(126, '杜比', 8),

  /// 8K 超高清。
  p8k(127, '8K', 9);

  /// 创建稳定的视频质量配置。
  const DefaultVideoQuality(this.qualityId, this.label, this.rank);

  /// B 站播放接口清晰度代码。
  final int qualityId;

  /// 设置页展示文案。
  final String label;

  /// 从低到高的产品质量顺序。
  final int rank;
}

/// 应用中所有可持久化的普通设置快照。
final class AppSettings {
  /// 创建不可变设置快照。
  AppSettings({
    required this.systemSoundEnabled,
    required this.tapSoundEnabled,
    required this.exitBehavior,
    required this.downloadDirectoryPath,
    required this.folderTemplate,
    required Set<DownloadContentOption> downloadContents,
    required this.defaultAudioQuality,
    required this.defaultVideoQuality,
    required this.preferredVideoCodec,
    required this.namingTemplate,
    required this.outputConflictStrategy,
    required this.concurrentDownloads,
    required this.downloadSpeedLimitMegabytesPerSecond,
  }) : downloadContents = Set<DownloadContentOption>.unmodifiable(
         downloadContents,
       );

  /// 首次启动时与参考设计一致的默认设置。
  factory AppSettings.defaults() {
    // 附加下载内容默认全部不勾选，避免用户首次下载时生成额外文件。
    const defaultContents = <DownloadContentOption>{};
    // 返回不会依赖异步目录解析的立即可用设置。
    return AppSettings(
      systemSoundEnabled: true,
      tapSoundEnabled: true,
      exitBehavior: AppExitBehavior.exitApplication,
      downloadDirectoryPath: null,
      folderTemplate: '%collection%',
      downloadContents: defaultContents,
      defaultAudioQuality: DefaultAudioQuality.low64,
      defaultVideoQuality: DefaultVideoQuality.p360,
      preferredVideoCodec: BiliVideoCodec.avc,
      namingTemplate: '%title%',
      outputConflictStrategy: OutputConflictStrategy.autoRename,
      concurrentDownloads: 1,
      downloadSpeedLimitMegabytesPerSecond: 100,
    );
  }

  /// 是否播放任务完成和错误提示音。
  final bool systemSoundEnabled;

  /// 是否播放按钮和其他可点击控件的 tap 提示音。
  final bool tapSoundEnabled;

  /// 桌面端关闭窗口时的处理方式。
  final AppExitBehavior exitBehavior;

  /// 用户自定义下载目录；为空时使用当前系统默认下载目录。
  final String? downloadDirectoryPath;

  /// 下载根目录下的动态子文件夹模板；空值表示直接保存到根目录。
  final String folderTemplate;

  /// 用户选择的下载附加内容集合。
  final Set<DownloadContentOption> downloadContents;

  /// 解析入队时请求的默认音质。
  final DefaultAudioQuality defaultAudioQuality;

  /// 解析入队时请求的默认视频画质。
  final DefaultVideoQuality defaultVideoQuality;

  /// 同画质下优先使用的视频编码。
  final BiliVideoCodec preferredVideoCodec;

  /// 输出文件命名模板。
  final String namingTemplate;

  /// 最终输出路径已经被占用时的用户处理偏好。
  final OutputConflictStrategy outputConflictStrategy;

  /// 允许同时启动的业务下载任务数量。
  final int concurrentDownloads;

  /// aria2 全局下载速度上限，单位为 MB/s。
  final int downloadSpeedLimitMegabytesPerSecond;

  /// 复制当前设置并替换指定字段。
  AppSettings copyWith({
    bool? systemSoundEnabled,
    bool? tapSoundEnabled,
    AppExitBehavior? exitBehavior,
    String? downloadDirectoryPath,
    bool clearDownloadDirectoryPath = false,
    String? folderTemplate,
    Set<DownloadContentOption>? downloadContents,
    DefaultAudioQuality? defaultAudioQuality,
    DefaultVideoQuality? defaultVideoQuality,
    BiliVideoCodec? preferredVideoCodec,
    String? namingTemplate,
    OutputConflictStrategy? outputConflictStrategy,
    int? concurrentDownloads,
    int? downloadSpeedLimitMegabytesPerSecond,
  }) {
    // 清空标记用于区分“保持原值”和“恢复系统目录”。
    final nextDirectoryPath = clearDownloadDirectoryPath
        ? null
        : downloadDirectoryPath ?? this.downloadDirectoryPath;
    // 返回包含全部最终值的新快照。
    return AppSettings(
      systemSoundEnabled: systemSoundEnabled ?? this.systemSoundEnabled,
      tapSoundEnabled: tapSoundEnabled ?? this.tapSoundEnabled,
      exitBehavior: exitBehavior ?? this.exitBehavior,
      downloadDirectoryPath: nextDirectoryPath,
      folderTemplate: folderTemplate ?? this.folderTemplate,
      downloadContents: downloadContents ?? this.downloadContents,
      defaultAudioQuality: defaultAudioQuality ?? this.defaultAudioQuality,
      defaultVideoQuality: defaultVideoQuality ?? this.defaultVideoQuality,
      preferredVideoCodec: preferredVideoCodec ?? this.preferredVideoCodec,
      namingTemplate: namingTemplate ?? this.namingTemplate,
      outputConflictStrategy:
          outputConflictStrategy ?? this.outputConflictStrategy,
      concurrentDownloads: concurrentDownloads ?? this.concurrentDownloads,
      downloadSpeedLimitMegabytesPerSecond:
          downloadSpeedLimitMegabytesPerSecond ??
          this.downloadSpeedLimitMegabytesPerSecond,
    );
  }
}
