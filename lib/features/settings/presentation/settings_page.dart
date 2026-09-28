import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/platform/platform_providers.dart';
import '../../../core/platform/runtime_platform.dart';
import '../../../core/theme/theme_accent_controller.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../user/application/account_controller.dart';
import '../application/app_settings_controller.dart';
import 'controllers/settings_page_controller.dart';
import 'widgets/settings_download_preference_rows.dart';
import 'widgets/settings_maintenance_rows.dart';
import 'widgets/settings_row.dart';
import 'widgets/settings_system_rows.dart';
import 'widgets/storage_setting.dart';
import 'widgets/theme_accent_controls.dart';
import 'widgets/theme_appearance_setting.dart';

/// 设置中心，负责展示并持久化下载、外观和桌面行为设置。
final class SettingsPage extends ConsumerWidget {
  /// 创建设置中心。
  const SettingsPage({super.key});

  /// 构建桌面横向设置行和手机纵向设置行。
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听普通设置快照，任一选择变化后立即刷新全部依赖控件。
    final settings = ref.watch(appSettingsControllerProvider);
    // 登录资料存在时保留登录权限；网络刷新失败不能误降级已知账号。
    final account = ref.watch(accountControllerProvider);
    // 仅明确登录或仍持有有效资料时开放登录档位。
    final isLoggedIn =
        account.phase == AccountPhase.loggedIn ||
        account.profile?.isLoggedIn == true;
    // 监听独立主题设置，切换亮暗色时保持页面状态。
    final themeMode = ref.watch(themeModeControllerProvider);
    // 监听全局品牌主题色，使选择器与应用当前颜色保持同步。
    final themeAccent = ref.watch(themeAccentControllerProvider);
    // 监听主题色明暗级别，使滑块与全局实时颜色保持同步。
    final themeAccentBrightness = ref.watch(
      themeAccentBrightnessControllerProvider,
    );
    // 读取当前下载后端，限速控件只对 aria2 有即时控制意义。
    final runtimePlatform = ref.watch(runtimePlatformProvider);
    // 系统下载后端不支持 aria2 全局选项，避免显示无效设置。
    final supportsAria2DownloadLimit =
        runtimePlatform.primaryDownloadBackend == DownloadBackendKind.aria2;
    // 读取与下载服务一致的实际目录展示值。
    final directory = ref.watch(effectiveDownloadDirectoryProvider);
    // 读取安装包版本并在加载期间使用短占位。
    final version = ref.watch(settingsPackageVersionProvider).value ?? '—';
    // 缓存大小用于设置行和清除确认弹窗，加载期间展示占位文本。
    final appCacheSize = ref.watch(settingsAppCacheSizeProvider);
    // 保存当前设置控制器，所有回调复用同一实例。
    final settingsController = ref.read(appSettingsControllerProvider.notifier);
    // 页面级弹窗、缓存、目录和任务同步动作集中交给控制器。
    final pageState = ref.watch(settingsPageControllerProvider);
    // 读取页面控制器，布局回调只负责传递用户动作。
    final pageController = ref.read(settingsPageControllerProvider.notifier);
    // iOS 当前仅使用应用沙箱，避免提供无法跨启动持久授权的普通目录入口。
    final supportsCustomDirectory = !Platform.isIOS;
    // 自定义目录选择必须等待上一次系统选择器关闭。
    final canChooseDirectory =
        supportsCustomDirectory && !pageState.choosingDirectory;
    // 有实际路径时才允许打开目录，避免对加载占位发起平台调用。
    final canOpenDirectory = supportsCustomDirectory && directory.hasValue;
    // 只有存在自定义目录配置时才提供恢复默认目录入口。
    final canResetDirectory =
        supportsCustomDirectory &&
        !pageState.resettingDirectory &&
        settings.downloadDirectoryPath != null;
    // 内容独立滚动，缩放窗口时设置行按实际宽度换行。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 侧栏桌面布局提供更宽内容区，手机布局使用紧凑间距。
        final compact = constraints.maxWidth < AppBreakpoints.navigationRail;
        // 返回完整设置列表。
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SettingsNotificationRow(
                    compact: compact,
                    settings: settings,
                    pageController: pageController,
                    settingsController: settingsController,
                  ),
                  if (!compact)
                    SettingsExitBehaviorRow(
                      compact: compact,
                      settings: settings,
                      pageController: pageController,
                      settingsController: settingsController,
                    ),
                  SettingsRow(
                    compact: compact,
                    label: '存储',
                    child: StorageSetting(
                      compact: compact,
                      directory: directory.value ?? '正在读取系统下载目录…',
                      showChange: supportsCustomDirectory,
                      onChange: canChooseDirectory
                          ? () => pageController.chooseDirectory(context)
                          : null,
                      onAdvanced: () => pageController.showDirectoryDialog(
                        context,
                        compact: compact,
                      ),
                      onOpen: canOpenDirectory
                          ? () => pageController.openDirectory(
                              context,
                              directory.value!,
                            )
                          : null,
                      onReset: canResetDirectory
                          ? () => pageController.resetDirectory(context)
                          : null,
                    ),
                  ),
                  SettingsDownloadPreferenceRows(
                    compact: compact,
                    settings: settings,
                    isLoggedIn: isLoggedIn,
                    supportsAria2DownloadLimit: supportsAria2DownloadLimit,
                    pageController: pageController,
                    settingsController: settingsController,
                  ),
                  SettingsRow(
                    compact: compact,
                    label: '主题',
                    child: ThemeAppearanceSetting(
                      compact: compact,
                      themeMode: themeMode,
                      themeAccent: themeAccent,
                      onThemeModeSelected: (ThemeMode value) {
                        // 亮暗模式选择后立即应用并持久化。
                        unawaited(
                          pageController.saveSettingWithFeedback(
                            context,
                            () => ref
                                .read(themeModeControllerProvider.notifier)
                                .setThemeMode(value),
                          ),
                        );
                      },
                      onThemeAccentSelected: (ThemeAccent value) {
                        // 品牌色选择后立即刷新整个应用并持久化。
                        unawaited(
                          pageController.saveSettingWithFeedback(
                            context,
                            () => ref
                                .read(themeAccentControllerProvider.notifier)
                                .setThemeAccent(value),
                          ),
                        );
                      },
                    ),
                  ),
                  SettingsRow(
                    compact: compact,
                    compactStacked: compact,
                    label: '主题色明暗',
                    child: ThemeAccentBrightnessSlider(
                      value: themeAccentBrightness,
                      onChanged: (double value) {
                        // 拖动时即时更新主题，控制器会合并高频持久化写入。
                        ref
                            .read(
                              themeAccentBrightnessControllerProvider.notifier,
                            )
                            .setBrightness(value);
                      },
                    ),
                  ),
                  SettingsMaintenanceRows(
                    compact: compact,
                    version: version,
                    appCacheSize: appCacheSize,
                    pageState: pageState,
                    pageController: pageController,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
