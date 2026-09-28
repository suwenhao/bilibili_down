import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/platform/default_download_directory.dart';
import '../../../services/bilibili/models/bili_dash_manifest.dart';
import '../domain/app_settings.dart';

/// 提供全应用唯一的普通设置快照。
final appSettingsControllerProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

/// 解析设置页和下载页共同展示的实际下载目录。
final effectiveDownloadDirectoryProvider = FutureProvider<String>((
  Ref ref,
) async {
  // 监听目录设置，用户更改后立即重新计算展示值。
  final settings = ref.watch(appSettingsControllerProvider);
  // iOS 仅使用应用沙箱目录，普通路径无法跨启动可靠恢复安全作用域授权。
  final customPath = Platform.isIOS ? null : settings.downloadDirectoryPath;
  if (customPath != null && customPath.trim().isNotEmpty) {
    return customPath.trim();
  }
  // 默认目录和实际写入目录保持一致。
  return resolveDefaultDownloadDisplayPath();
});

/// 使用 SharedPreferences 管理非敏感下载与桌面设置。
final class AppSettingsController extends Notifier<AppSettings> {
  /// 各字段在本地偏好中的稳定键名。
  static const String _systemSoundKey = 'settings.system_sound';
  static const String _tapSoundKey = 'settings.tap_sound';
  static const String _exitBehaviorKey = 'settings.exit_behavior';
  static const String _downloadDirectoryKey = 'settings.download_directory';
  static const String _legacyAndroidDirectoryUriKey =
      'settings.android_download_directory_uri';
  static const String _legacyAndroidDirectoryLabelKey =
      'settings.android_download_directory_label';
  static const String _folderTemplateKey = 'settings.folder_template';
  static const String _downloadContentsKey = 'settings.download_contents';
  static const String _audioQualityKey = 'settings.default_audio_quality';
  static const String _videoQualityKey = 'settings.default_video_quality';
  static const String _videoCodecKey = 'settings.preferred_video_codec';
  static const String _namingTemplateKey = 'settings.naming_template';
  static const String _outputConflictStrategyKey =
      'settings.output_conflict_strategy';
  static const String _concurrencyKey = 'settings.concurrent_downloads';
  static const String _downloadSpeedLimitKey =
      'settings.download_speed_limit_megabytes_per_second';

  /// 用户修改次数用于阻止较晚完成的恢复覆盖新设置。
  int _changeRevision = 0;

  /// 当前异步恢复任务，下载入队会等待它完成后再读取设置。
  Future<void>? _restoreFuture;

  /// 串行执行本地写入，避免用户快速选择时旧快照最后覆盖新快照。
  Future<void> _saveQueue = Future<void>.value();

  /// 先返回默认值，再异步恢复本地设置。
  @override
  AppSettings build() {
    // 创建一次恢复任务并保存给业务服务等待。
    final restoreFuture = _restore();
    // 保存恢复任务引用。
    _restoreFuture = restoreFuture;
    // 恢复过程不阻塞首帧。
    unawaited(restoreFuture);
    // 设置页和入队服务在恢复前使用产品默认值。
    return AppSettings.defaults();
  }

  /// 等待本地恢复完成并返回不会被默认首帧值覆盖的当前设置。
  Future<AppSettings> loadReadySettings() async {
    // Provider 完成 build 后恢复任务一定存在，空值仅作为生命周期保护。
    await (_restoreFuture ?? Future<void>.value());
    // 返回恢复完成时或用户最新修改后的设置快照。
    return state;
  }

  /// 更新系统提示音开关。
  Future<void> setSystemSoundEnabled(bool enabled) {
    // 只替换提示音字段并持久化完整快照。
    return _save(state.copyWith(systemSoundEnabled: enabled));
  }

  /// 更新按钮提示音开关。
  Future<void> setTapSoundEnabled(bool enabled) {
    // 只替换 tap 提示音字段，任务状态提示音保持原值。
    return _save(state.copyWith(tapSoundEnabled: enabled));
  }

  /// 更新桌面关闭窗口行为。
  Future<void> setExitBehavior(AppExitBehavior behavior) {
    // 只替换退出行为并持久化完整快照。
    return _save(state.copyWith(exitBehavior: behavior));
  }

  /// 保存用户选择的下载目录。
  Future<void> setDownloadDirectoryPath(String path) {
    // 去除首尾空白，空值等同恢复系统目录。
    final normalizedPath = path.trim();
    // 根据规范化结果更新目录覆盖值。
    return _save(
      normalizedPath.isEmpty
          ? state.copyWith(clearDownloadDirectoryPath: true)
          : state.copyWith(downloadDirectoryPath: normalizedPath),
    );
  }

  /// 恢复使用当前系统默认下载目录。
  Future<void> resetDownloadDirectoryPath() async {
    // 清空自定义路径，恢复各平台默认真实目录。
    await _save(state.copyWith(clearDownloadDirectoryPath: true));
  }

  /// 保存下载根目录下的动态子文件夹模板。
  Future<void> setFolderTemplate(String template) {
    // 去除首尾空白，空模板表示不创建额外子目录。
    final normalizedTemplate = template.trim();
    // 保存规范化后的文件夹模板。
    return _save(state.copyWith(folderTemplate: normalizedTemplate));
  }

  /// 打开或关闭一种下载附加内容。
  Future<void> setDownloadContent(DownloadContentOption option, bool enabled) {
    // 复制集合，避免直接修改当前不可变快照。
    final nextContents = Set<DownloadContentOption>.of(state.downloadContents);
    // 按开关状态增删指定选项。
    if (enabled) {
      nextContents.add(option);
    } else {
      nextContents.remove(option);
    }
    // 保存新的附加内容集合。
    return _save(state.copyWith(downloadContents: nextContents));
  }

  /// 更新默认音质。
  Future<void> setDefaultAudioQuality(DefaultAudioQuality quality) {
    // 保存新的音质目标。
    return _save(state.copyWith(defaultAudioQuality: quality));
  }

  /// 更新默认视频画质。
  Future<void> setDefaultVideoQuality(DefaultVideoQuality quality) {
    // 保存新的画质目标。
    return _save(state.copyWith(defaultVideoQuality: quality));
  }

  /// 根据账号登录级别设置进入该状态时使用的默认音画质。
  Future<void> setAccountQualityDefaults({required bool isLoggedIn}) async {
    // 等待原有偏好恢复，防止账号检查较快时覆盖目录、命名等无关设置。
    await loadReadySettings();
    // 登录后使用常用高质量档位，游客状态回落到接口稳定提供的最低档位。
    final audioQuality = isLoggedIn
        ? DefaultAudioQuality.high192
        : DefaultAudioQuality.low64;
    // 登录后的默认画质为 1080P，游客默认使用 360P。
    final videoQuality = isLoggedIn
        ? DefaultVideoQuality.p1080
        : DefaultVideoQuality.p360;
    // 已处于目标值时跳过本地写入，避免刷新账号资料造成无效持久化。
    if (state.defaultAudioQuality == audioQuality &&
        state.defaultVideoQuality == videoQuality) {
      return;
    }
    // 两项一次性发布并保存，避免界面短暂出现音质和画质不同步。
    await _save(
      state.copyWith(
        defaultAudioQuality: audioQuality,
        defaultVideoQuality: videoQuality,
      ),
    );
  }

  /// 更新同画质下优先使用的视频编码。
  Future<void> setPreferredVideoCodec(BiliVideoCodec codec) {
    // 保存新的编码偏好。
    return _save(state.copyWith(preferredVideoCodec: codec));
  }

  /// 更新输出文件命名模板。
  Future<void> setNamingTemplate(String template) {
    // 空模板回退产品默认标题变量。
    final normalizedTemplate = template.trim().isEmpty
        ? '%title%'
        : template.trim();
    // 保存规范化模板。
    return _save(state.copyWith(namingTemplate: normalizedTemplate));
  }

  /// 更新最终文件重名时采用的处理方式。
  Future<void> setOutputConflictStrategy(OutputConflictStrategy strategy) {
    // 重名策略只影响后续创建或同步的待下载任务，不改写活动任务。
    return _save(state.copyWith(outputConflictStrategy: strategy));
  }

  /// 更新允许同时运行的下载任务数量。
  Future<void> setConcurrentDownloads(int count) {
    // 设置页只允许一到四个并发任务。
    final normalizedCount = count.clamp(1, 4);
    // 保存经过范围限制的并发数。
    return _save(state.copyWith(concurrentDownloads: normalizedCount));
  }

  /// 更新 aria2 全局下载速度上限。
  Future<void> setDownloadSpeedLimitMegabytesPerSecond(int megabytes) {
    // 设置页和手动输入都限制在一到一百 MB/s。
    final normalizedMegabytes = megabytes.clamp(1, 100);
    // 保存经过范围限制的 aria2 全局限速。
    return _save(
      state.copyWith(downloadSpeedLimitMegabytesPerSecond: normalizedMegabytes),
    );
  }

  /// 立即更新内存状态并把完整快照保存到本地。
  Future<void> _save(AppSettings nextState) {
    // 每次用户操作增加修订号。
    _changeRevision++;
    // 先更新界面和依赖服务。
    state = nextState;
    // 把本次完整快照排到已有写入之后。
    _saveQueue = _saveQueue.then((_) => _persist(nextState));
    // 返回本次排队写入的完成信号。
    return _saveQueue;
  }

  /// 把一份完整设置快照写入 SharedPreferences。
  Future<void> _persist(AppSettings nextState) async {
    // 获取跨平台本地偏好实例。
    final preferences = await SharedPreferences.getInstance();
    // 保存布尔和枚举字段。
    await preferences.setBool(_systemSoundKey, nextState.systemSoundEnabled);
    await preferences.setBool(_tapSoundKey, nextState.tapSoundEnabled);
    await preferences.setString(_exitBehaviorKey, nextState.exitBehavior.name);
    // 自定义目录为空时移除旧键，保留系统目录语义。
    if (nextState.downloadDirectoryPath == null) {
      await preferences.remove(_downloadDirectoryKey);
    } else {
      await preferences.setString(
        _downloadDirectoryKey,
        nextState.downloadDirectoryPath!,
      );
    }
    // Android 旧 URI 字段不再写入，持久化时顺手移除历史授权引用。
    await preferences.remove(_legacyAndroidDirectoryUriKey);
    await preferences.remove(_legacyAndroidDirectoryLabelKey);
    // 文件夹模板允许为空，空值仍需覆盖旧配置。
    await preferences.setString(_folderTemplateKey, nextState.folderTemplate);
    // 集合与其余枚举使用稳定名称保存。
    await preferences.setStringList(
      _downloadContentsKey,
      nextState.downloadContents
          .map((DownloadContentOption option) => option.name)
          .toList(growable: false),
    );
    await preferences.setString(
      _audioQualityKey,
      nextState.defaultAudioQuality.name,
    );
    await preferences.setString(
      _videoQualityKey,
      nextState.defaultVideoQuality.name,
    );
    await preferences.setString(
      _videoCodecKey,
      nextState.preferredVideoCodec.name,
    );
    await preferences.setString(_namingTemplateKey, nextState.namingTemplate);
    await preferences.setString(
      _outputConflictStrategyKey,
      nextState.outputConflictStrategy.name,
    );
    await preferences.setInt(_concurrencyKey, nextState.concurrentDownloads);
    await preferences.setInt(
      _downloadSpeedLimitKey,
      nextState.downloadSpeedLimitMegabytesPerSecond,
    );
  }

  /// 从 SharedPreferences 恢复上次保存的有效设置。
  Future<void> _restore() async {
    // 记录恢复开始时的用户修改修订号。
    final startedRevision = _changeRevision;
    // 读取本地偏好实例。
    final preferences = await SharedPreferences.getInstance();
    // 用户已在恢复期间修改设置时丢弃旧快照。
    if (startedRevision != _changeRevision) return;
    // 从产品默认值开始，只覆盖能被当前版本识别的字段。
    final defaults = AppSettings.defaults();
    // 解析附加内容名称并过滤未来版本或损坏值。
    final savedContentNames = preferences.getStringList(_downloadContentsKey);
    // 没有旧值时使用当前版本默认附加内容；当前默认是不额外勾选。
    final restoredContents = savedContentNames == null
        ? defaults.downloadContents
        : DownloadContentOption.values
              .where(
                (DownloadContentOption option) =>
                    savedContentNames.contains(option.name),
              )
              .toSet();
    // 解析全部枚举字段，未知名称回退当前版本默认值。
    final exitBehavior = _enumByName(
      AppExitBehavior.values,
      preferences.getString(_exitBehaviorKey),
      defaults.exitBehavior,
    );
    final audioQuality = _enumByName(
      DefaultAudioQuality.values,
      preferences.getString(_audioQualityKey),
      defaults.defaultAudioQuality,
    );
    final videoQuality = _enumByName(
      DefaultVideoQuality.values,
      preferences.getString(_videoQualityKey),
      defaults.defaultVideoQuality,
    );
    final videoCodec = _enumByName(
      BiliVideoCodec.values.where(
        (BiliVideoCodec codec) => codec != BiliVideoCodec.unknown,
      ),
      preferences.getString(_videoCodecKey),
      defaults.preferredVideoCodec,
    );
    final outputConflictStrategy = _enumByName(
      OutputConflictStrategy.values,
      preferences.getString(_outputConflictStrategyKey),
      defaults.outputConflictStrategy,
    );
    // 读取并限制并发数，防止旧数据超出当前界面范围。
    final concurrentDownloads = (preferences.getInt(_concurrencyKey) ?? 1)
        .clamp(1, 4);
    // 读取并限制 aria2 全局限速，损坏值回退当前版本默认上限。
    final downloadSpeedLimitMegabytesPerSecond =
        (preferences.getInt(_downloadSpeedLimitKey) ??
                defaults.downloadSpeedLimitMegabytesPerSecond)
            .clamp(1, 100);
    // 恢复完成前再次确认没有新的用户操作。
    if (startedRevision != _changeRevision) return;
    // 一次性发布完整设置，避免依赖服务观察到半恢复状态。
    state = AppSettings(
      systemSoundEnabled:
          preferences.getBool(_systemSoundKey) ?? defaults.systemSoundEnabled,
      // 新开关首次出现时继承旧版总开关，避免升级后意外重新播放 tap 音。
      tapSoundEnabled:
          preferences.getBool(_tapSoundKey) ??
          preferences.getBool(_systemSoundKey) ??
          defaults.tapSoundEnabled,
      exitBehavior: exitBehavior,
      downloadDirectoryPath: preferences.getString(_downloadDirectoryKey),
      folderTemplate:
          preferences.getString(_folderTemplateKey) ?? defaults.folderTemplate,
      downloadContents: restoredContents,
      defaultAudioQuality: audioQuality,
      defaultVideoQuality: videoQuality,
      preferredVideoCodec: videoCodec,
      namingTemplate:
          preferences.getString(_namingTemplateKey) ?? defaults.namingTemplate,
      outputConflictStrategy: outputConflictStrategy,
      concurrentDownloads: concurrentDownloads,
      downloadSpeedLimitMegabytesPerSecond:
          downloadSpeedLimitMegabytesPerSecond,
    );
  }

  /// 按稳定名称查找枚举值，找不到时返回默认值。
  T _enumByName<T extends Enum>(
    Iterable<T> values,
    String? savedName,
    T fallback,
  ) {
    // 逐项比较名称以兼容枚举新增和旧设置。
    for (final value in values) {
      if (value.name == savedName) return value;
    }
    // 未保存或名称失效时使用当前版本默认值。
    return fallback;
  }
}
