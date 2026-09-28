import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_selection_controls.dart';
import '../../../../services/bilibili/models/bili_dash_manifest.dart';
import '../../application/app_settings_controller.dart';
import '../../domain/app_settings.dart';
import '../controllers/settings_page_controller.dart';
import '../models/settings_labels.dart';
import 'adaptive_settings_choice_wrap.dart';
import 'download_speed_limit_control.dart';
import 'download_content_choices.dart';
import 'settings_row.dart';

/// 下载内容、清晰度、编码、命名和并发相关设置行。
final class SettingsDownloadPreferenceRows extends StatelessWidget {
  /// 创建下载偏好设置分组。
  const SettingsDownloadPreferenceRows({
    required this.compact,
    required this.settings,
    required this.isLoggedIn,
    required this.supportsAria2DownloadLimit,
    required this.pageController,
    required this.settingsController,
    super.key,
  });

  /// 当前是否使用手机紧凑排版。
  final bool compact;

  /// 当前应用设置快照。
  final AppSettings settings;

  /// 当前账号是否允许选择高等级音画质。
  final bool isLoggedIn;

  /// 当前平台是否使用 aria2 下载后端。
  final bool supportsAria2DownloadLimit;

  /// 页面级反馈控制器。
  final SettingsPageController pageController;

  /// 应用设置持久化控制器。
  final AppSettingsController settingsController;

  /// 构建下载偏好设置行。
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingsRow(
          compact: compact,
          compactStacked: true,
          label: '工具',
          child: ToolChoices(
            compact: compact,
            selected: settings.downloadContents.contains(
              DownloadContentOption.monitorClipboard,
            ),
            onSelected: (bool selected) {
              // 工具类开关仍复用下载内容设置字段，保持剪切板监听运行时兼容。
              unawaited(
                pageController.saveSettingWithFeedback(
                  context,
                  () => settingsController.setDownloadContent(
                    DownloadContentOption.monitorClipboard,
                    selected,
                  ),
                ),
              );
            },
          ),
        ),
        SettingsRow(
          compact: compact,
          compactStacked: true,
          label: '下载内容',
          child: DownloadContentChoices(
            compact: compact,
            selected: settings.downloadContents,
            onSelected: (DownloadContentOption option, bool selected) {
              // 保存当前附加内容开关。
              unawaited(
                pageController.saveSettingWithFeedback(
                  context,
                  () => settingsController.setDownloadContent(option, selected),
                ),
              );
            },
          ),
        ),
        SettingsRow(
          compact: compact,
          compactStacked: true,
          label: '默认音质',
          child: AdaptiveSettingsChoiceWrap<DefaultAudioQuality>(
            compact: compact,
            values: DefaultAudioQuality.values,
            selected: settings.defaultAudioQuality,
            enabledBuilder: (DefaultAudioQuality value) {
              // 游客只能选择普通音轨，杜比和 Hi-Res 需要登录后开放。
              return isLoggedIn || value.rank < DefaultAudioQuality.dolby.rank;
            },
            disabledTooltip: '请登录',
            labelBuilder: (DefaultAudioQuality value) => value.label,
            onSelected: (DefaultAudioQuality value) {
              // 保存目标音质并同步所有尚未启动任务。
              unawaited(
                pageController.saveQualityAndSynchronize(
                  context,
                  () => settingsController.setDefaultAudioQuality(value),
                ),
              );
            },
          ),
        ),
        SettingsRow(
          compact: compact,
          compactStacked: true,
          label: '默认画质',
          child: AdaptiveSettingsChoiceWrap<DefaultVideoQuality>(
            compact: compact,
            values: DefaultVideoQuality.values,
            selected: settings.defaultVideoQuality,
            enabledBuilder: (DefaultVideoQuality value) {
              // 游客保留 360P/480P，720P 及以上需要登录后开放。
              return isLoggedIn || value.rank <= DefaultVideoQuality.p480.rank;
            },
            disabledTooltip: '请登录',
            labelBuilder: (DefaultVideoQuality value) => value.label,
            onSelected: (DefaultVideoQuality value) {
              // 保存目标画质并同步所有尚未启动任务。
              unawaited(
                pageController.saveQualityAndSynchronize(
                  context,
                  () => settingsController.setDefaultVideoQuality(value),
                ),
              );
            },
          ),
        ),
        SettingsRow(
          compact: compact,
          label: '编码',
          child: AdaptiveSettingsChoiceWrap<BiliVideoCodec>(
            compact: compact,
            values: const <BiliVideoCodec>[
              BiliVideoCodec.avc,
              BiliVideoCodec.av1,
              BiliVideoCodec.hevc,
            ],
            selected: settings.preferredVideoCodec,
            labelBuilder: videoCodecLabel,
            infoTooltipBuilder: videoCodecTooltip,
            onSelected: (BiliVideoCodec value) {
              // 编码切换会影响未开始任务的默认选择，需要同步队列。
              unawaited(
                pageController.saveQualityAndSynchronize(
                  context,
                  () => settingsController.setPreferredVideoCodec(value),
                ),
              );
            },
          ),
        ),
        SettingsRow(
          compact: compact,
          label: '命名',
          child: Wrap(
            spacing: 22,
            runSpacing: 10,
            children: <Widget>[
              AppRadioChoice<bool>(
                value: false,
                groupValue: settings.namingTemplate != '%title%',
                label: '%title%',
                onSelected: (bool value) {
                  // 恢复使用分集标题命名。
                  unawaited(
                    pageController.saveSettingWithFeedback(
                      context,
                      () => settingsController.setNamingTemplate('%title%'),
                    ),
                  );
                },
              ),
              AppRadioChoice<bool>(
                value: true,
                groupValue: settings.namingTemplate != '%title%',
                label: '自定义',
                onSelected: (bool value) {
                  // 手机端进入命名设置页，PC 端保留弹窗编辑模板。
                  unawaited(
                    pageController.showNamingDialog(context, compact: compact),
                  );
                },
              ),
            ],
          ),
        ),
        SettingsRow(
          compact: compact,
          label: '重名',
          child: AdaptiveSettingsChoiceWrap<OutputConflictStrategy>(
            compact: compact,
            values: OutputConflictStrategy.values,
            selected: settings.outputConflictStrategy,
            labelBuilder: outputConflictStrategyLabel,
            onSelected: (OutputConflictStrategy value) {
              // 覆盖已有文件属于破坏性选择，控制器会先弹确认再持久化。
              unawaited(
                pageController.saveSettingWithFeedback(
                  context,
                  () => pageController.selectOutputConflictStrategy(
                    context,
                    value,
                  ),
                ),
              );
            },
          ),
        ),
        SettingsRow(
          compact: compact,
          label: '并发',
          child: AdaptiveSettingsChoiceWrap<int>(
            compact: compact,
            values: const <int>[1, 2, 3, 4],
            selected: settings.concurrentDownloads,
            labelBuilder: (int value) => '$value个',
            onSelected: (int value) {
              // 并发数影响调度器取任务数量，保存后由运行时读取新上限。
              unawaited(
                pageController.saveSettingWithFeedback(
                  context,
                  () => settingsController.setConcurrentDownloads(value),
                ),
              );
            },
          ),
        ),
        if (supportsAria2DownloadLimit)
          SettingsRow(
            compact: compact,
            compactStacked: compact,
            label: '限速',
            child: DownloadSpeedLimitControl(
              compact: compact,
              value: settings.downloadSpeedLimitMegabytesPerSecond,
              onChanged: (int value) {
                // 限速保存后由 aria2 引擎 Provider 监听并同步全局选项。
                unawaited(
                  pageController.saveSettingWithFeedback(
                    context,
                    () => settingsController
                        .setDownloadSpeedLimitMegabytesPerSecond(value),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
