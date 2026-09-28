import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_selection_controls.dart';
import '../../application/app_settings_controller.dart';
import '../../domain/app_settings.dart';
import '../controllers/settings_page_controller.dart';
import 'settings_row.dart';

/// 系统提示音和按钮提示音设置行。
final class SettingsNotificationRow extends StatelessWidget {
  /// 创建通知相关设置行。
  const SettingsNotificationRow({
    required this.compact,
    required this.settings,
    required this.pageController,
    required this.settingsController,
    super.key,
  });

  /// 当前是否使用手机紧凑排版。
  final bool compact;

  /// 当前应用设置快照。
  final AppSettings settings;

  /// 页面级反馈控制器。
  final SettingsPageController pageController;

  /// 应用设置持久化控制器。
  final AppSettingsController settingsController;

  /// 构建系统提示音和点击提示音设置行。
  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      compact: compact,
      label: '通知',
      child: Wrap(
        spacing: 22,
        runSpacing: 10,
        children: <Widget>[
          SoundToggle(
            label: '系统提示音',
            value: settings.systemSoundEnabled,
            onChanged: (bool enabled) {
              // 保存任务完成和错误提示音开关。
              unawaited(
                pageController.saveSettingWithFeedback(
                  context,
                  () => settingsController.setSystemSoundEnabled(enabled),
                ),
              );
            },
          ),
          SoundToggle(
            label: '按钮提示音',
            value: settings.tapSoundEnabled,
            onChanged: (bool enabled) {
              // 单独保存按钮 tap 提示音开关。
              unawaited(
                pageController.saveSettingWithFeedback(
                  context,
                  () => settingsController.setTapSoundEnabled(enabled),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 桌面端退出程序或最小化到托盘设置行。
final class SettingsExitBehaviorRow extends StatelessWidget {
  /// 创建退出行为设置行。
  const SettingsExitBehaviorRow({
    required this.compact,
    required this.settings,
    required this.pageController,
    required this.settingsController,
    super.key,
  });

  /// 当前是否使用手机紧凑排版。
  final bool compact;

  /// 当前应用设置快照。
  final AppSettings settings;

  /// 页面级反馈控制器。
  final SettingsPageController pageController;

  /// 应用设置持久化控制器。
  final AppSettingsController settingsController;

  /// 构建桌面端退出行为设置行。
  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      compact: compact,
      label: '退出',
      child: Wrap(
        spacing: 22,
        runSpacing: 10,
        children: AppExitBehavior.values
            .map(
              (AppExitBehavior behavior) => AppRadioChoice<AppExitBehavior>(
                value: behavior,
                groupValue: settings.exitBehavior,
                label: _exitBehaviorLabel(behavior),
                onSelected: (AppExitBehavior value) {
                  // 退出行为只影响桌面窗口关闭，手机端没有托盘入口所以隐藏整行。
                  unawaited(
                    pageController.saveSettingWithFeedback(
                      context,
                      () => settingsController.setExitBehavior(value),
                    ),
                  );
                },
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  /// 返回退出行为在设置页中的短文案。
  String _exitBehaviorLabel(AppExitBehavior behavior) {
    if (behavior == AppExitBehavior.exitApplication) return '退出程序';
    return '最小化到托盘';
  }
}
