import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/logging/app_debug_log.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/widgets/app_floating_progress.dart';
import '../../../core/widgets/app_icon_buttons.dart';
import '../../../core/widgets/app_navigation_icon_badge.dart';
import '../../../core/widgets/app_scroll_to_top_button.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_tooltip.dart';
import '../../../services/image_cache/cover_cache_manager.dart';
import '../../downloads/application/maintenance/pending_dash_option_refresh_service.dart';
import '../../downloads/application/ui_state/download_task_badge_provider.dart';
import '../../downloads/application/ui_state/download_tasks_scroll_controller.dart';
import '../../parser/application/parser_scroll_controller.dart';
import '../../settings/presentation/controllers/settings_page_controller.dart';
import '../../user/application/account_controller.dart';
import '../../user/application/user_center_scroll_controller.dart';

part 'widgets/app_header.dart';
part 'widgets/desktop_navigation_item.dart';
part 'widgets/desktop_navigation_sidebar.dart';
part 'widgets/mobile_navigation_bar.dart';
part 'widgets/settings_mobile_header.dart';
part 'widgets/shell_account_buttons.dart';

/// 为一级页面提供桌面侧栏、移动底栏和移动端顶栏。
final class AppShell extends ConsumerWidget {
  /// 创建承载三个可保留状态分支的应用外壳。
  const AppShell({super.key, required this.navigationShell});

  /// GoRouter 管理的有状态分支容器，内部使用 IndexedStack 保留非当前页面。
  final StatefulNavigationShell navigationShell;

  /// 顶栏收起时长贴近 MaterialPage 默认 push 动画，让解析历史进入时同步过渡。
  static const Duration _mobileHeaderResizeDuration = Duration(
    milliseconds: 300,
  );

  /// 构建响应式导航框架。
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 导航角标实时读取 queued 数量，数据库尚未返回首个快照时按零处理。
    final queuedTaskCount = ref.watch(queuedDownloadTaskCountProvider);
    // 桌面头像实时读取登录资料，扫码成功或退出后无需重建外壳。
    final accountState = ref.watch(accountControllerProvider);
    // 登录成功后待下载任务重新解析进度由 Shell 顶层统一显示，覆盖所有一级页面。
    final pendingDashRefreshProgress = ref.watch(
      pendingDashRefreshProgressProvider,
    );
    // 使用内容宽度而不是操作系统名称判断导航布局。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 720 像素以上使用侧栏，避免平板横屏仍显示拥挤底栏。
        final useSideNavigation =
            constraints.maxWidth >= AppBreakpoints.navigationRail;
        // 分支索引是侧栏、底栏和当前内容的唯一选中状态来源。
        final selectedIndex = navigationShell.currentIndex;
        // 个人中心的当前滚动状态决定手机底栏是否显示“顶部”入口。
        final userCenterScrolledBeyondTop = ref.watch(
          userCenterScrolledBeyondTopProvider,
        );
        // 解析结果深滚动时，手机底栏的解析入口临时切换为回顶部。
        final parserScrolledBeyondTop = ref.watch(
          parserScrolledBeyondTopProvider,
        );
        // 当前任务页签深滚动时，手机底栏和桌面浮动按钮提供回顶部入口。
        final tasksScrolledBeyondTop = ref.watch(
          downloadTasksScrolledBeyondTopProvider,
        );
        // 主题切换回调同时供桌面侧栏和移动端顶栏使用。
        void toggleTheme() {
          // 根据当前实际亮度在亮色和暗色之间快捷切换。
          final brightness = Theme.of(context).brightness;
          // 计算与当前亮度相反的目标主题。
          final targetMode = brightness == Brightness.dark
              ? ThemeMode.light
              : ThemeMode.dark;
          AppDebugLog.app('Theme toggle requested target=${targetMode.name}');
          // 持久化切换结果，不阻塞按钮反馈。
          unawaited(
            ref
                .read(themeModeControllerProvider.notifier)
                .setThemeMode(targetMode)
                .catchError((Object error) {
                  AppDebugLog.app('Theme toggle failed error=$error');
                  // 外壳仍挂载时提示主题只在当前会话生效，避免持久化失败被静默忽略。
                  if (context.mounted) {
                    AppSnackBar.show(
                      context,
                      message: '保存主题失败，重启后可能不会保留：$error',
                      type: AppSnackBarType.error,
                    );
                  }
                }),
          );
        }

        // 账号入口回调在桌面侧栏和移动端顶栏复用。
        void openAccount() {
          // 外壳账号入口只切到个人分支，真正登录动作由个人页里的“去登录”触发。
          AppDebugLog.account('Account entry opened user center branch');
          _goToIndex(3, ref);
        }

        // 手机底栏个人入口在用户中心深滚动时复用为“回到顶部”。
        void openAccountOrUserTop() {
          if (accountState.profile?.isLoggedIn == true &&
              selectedIndex == 3 &&
              userCenterScrolledBeyondTop) {
            // 只递增事件信号，不直接持有页面控制器，避免 Shell 侵入用户中心状态。
            ref.read(userCenterScrollTopRequestProvider.notifier).request();
            return;
          }
          openAccount();
        }

        // 手机底栏解析入口在结果列表深滚动时改为回顶部操作。
        void openParserOrTop() {
          if (selectedIndex == 0 && parserScrolledBeyondTop) {
            // 页面自己持有滚动控制器，Shell 只发送一次事件信号。
            ref.read(parserScrollTopRequestProvider.notifier).request();
            return;
          }
          _goToIndex(0, ref);
        }

        // 任务入口在当前列表深滚动时改为回顶部，否则切换到任务页。
        void openTasksOrTop() {
          if (selectedIndex == 1 && tasksScrolledBeyondTop) {
            // Shell 只发事件，当前页签控制器由任务页面自行管理。
            ref.read(downloadTasksScrollTopRequestProvider.notifier).request();
            return;
          }
          _goToIndex(1, ref);
        }

        // 桌面浮动按钮按当前一级页面发送回顶部请求。
        void scrollCurrentDesktopPageToTop() {
          if (selectedIndex == 0) {
            // 解析分支包括解析结果、UP 页和二级详情，统一由分支页面响应。
            ref.read(parserScrollTopRequestProvider.notifier).request();
            return;
          }
          if (selectedIndex == 1) {
            // 任务页只滚动当前选中的任务页签。
            ref.read(downloadTasksScrollTopRequestProvider.notifier).request();
            return;
          }
          if (selectedIndex == 3) {
            // 用户中心只滚动当前选中的内容页签或已打开的收藏详情。
            ref.read(userCenterScrollTopRequestProvider.notifier).request();
          }
        }

        // 当前路由路径用于区分一级页和分支内二级页面。
        final currentPath = GoRouterState.of(context).uri.path;
        // 普通解析页已有页面内桌面回顶部按钮，Shell 只补解析分支二级页。
        final parserBranchUsesShellScrollToTop =
            selectedIndex == 0 &&
            parserScrolledBeyondTop &&
            currentPath != '/parse';
        // 解析历史、自定义批量等二级页面自带返回标题栏，不能再叠加 Shell 品牌顶栏。
        final hideBranchHeader = _shouldHideBranchHeader(
          selectedIndex: selectedIndex,
          currentPath: currentPath,
          mobileLayout: !useSideNavigation,
        );
        // 设置页、个人中心和二级页本身不再叠加品牌顶栏，避免手机端出现重复头部。
        final Widget? mobileHeader = switch (selectedIndex) {
          0 when hideBranchHeader => null,
          1 when hideBranchHeader => null,
          2 => const SettingsMobileHeader(),
          3 => null,
          _ => AppHeader(
            accountState: accountState,
            onToggleTheme: toggleTheme,
            onOpenAccount: openAccount,
          ),
        };
        // 移动端顶部结构由当前一级页面决定，桌面端仍由侧栏承载操作。
        final mobileContent = Column(
          children: <Widget>[
            AnimatedSize(
              duration: _mobileHeaderResizeDuration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: mobileHeader ?? const SizedBox.shrink(),
            ),
            // 当前页面占满顶栏下方剩余空间。
            Expanded(child: navigationShell),
          ],
        );
        // 桌面与宽平板使用单层 Material 图标侧栏。
        if (useSideNavigation) {
          return Scaffold(
            body: Row(
              children: <Widget>[
                SafeArea(
                  right: false,
                  child: DesktopNavigationSidebar(
                    selectedIndex: selectedIndex,
                    queuedTaskCount: queuedTaskCount,
                    accountState: accountState,
                    onOpenAccount: openAccount,
                    onToggleTheme: toggleTheme,
                    onDestinationSelected: (int index) {
                      // 点击侧栏时切换到已缓存的一级页面分支。
                      _goToIndex(index, ref);
                    },
                  ),
                ),
                // 细分隔线明确导航和内容层级。
                VerticalDivider(
                  width: 1,
                  color: Theme.of(context).dividerColor,
                ),
                // 主内容叠加右下角回顶按钮，不改变各页面自身布局。
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(child: navigationShell),
                      if (pendingDashRefreshProgress != null)
                        _buildPendingDashRefreshProgressOverlay(
                          pendingDashRefreshProgress,
                        ),
                      if (parserBranchUsesShellScrollToTop ||
                          (selectedIndex == 1 && tasksScrolledBeyondTop) ||
                          (selectedIndex == 3 && userCenterScrolledBeyondTop))
                        Positioned(
                          right: 20,
                          bottom: 20,
                          child: AppScrollToTopButton(
                            onPressed: scrollCurrentDesktopPageToTop,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        // 手机使用自绘底栏，避免 Material NavigationBar 默认胶囊和悬停状态层。
        return Scaffold(
          body: Stack(
            children: <Widget>[
              Positioned.fill(
                child: SafeArea(bottom: false, child: mobileContent),
              ),
              if (pendingDashRefreshProgress != null)
                _buildPendingDashRefreshProgressOverlay(
                  pendingDashRefreshProgress,
                ),
            ],
          ),
          bottomNavigationBar: MobileBottomNavigationBar(
            selectedIndex: selectedIndex,
            queuedTaskCount: queuedTaskCount,
            parserShowsTop: selectedIndex == 0 && parserScrolledBeyondTop,
            taskShowsTop: selectedIndex == 1 && tasksScrolledBeyondTop,
            userCenterShowsTop:
                selectedIndex == 3 && userCenterScrolledBeyondTop,
            onOpenParser: openParserOrTop,
            onOpenTasks: openTasksOrTop,
            onOpenAccount: openAccountOrUserTop,
            onDestinationSelected: (int index) {
              // 点击底栏时切换一级页面。
              _goToIndex(index, ref);
            },
          ),
        );
      },
    );
  }

  /// 根据当前路由决定是否隐藏分支内二级页的 Shell 品牌顶栏。
  bool _shouldHideBranchHeader({
    required int selectedIndex,
    required String currentPath,
    required bool mobileLayout,
  }) {
    // 手机二级页进入动画开始时同步收起顶栏，避免页面和 Shell 分两段运动。
    if (!mobileLayout) return false;
    return switch (selectedIndex) {
      0 => currentPath != '/parse',
      1 => currentPath != '/tasks',
      _ => false,
    };
  }

  /// 按导航索引跳转一级路由。
  void _goToIndex(int index, WidgetRef ref) {
    // 非法索引不交给路由器，避免导航组件异常值破坏分支状态。
    if (index < 0 || index >= 4) return;
    if (index == 2) {
      // 设置页会被 IndexedStack 保留；重新进入时必须重新统计缓存大小。
      ref.invalidate(settingsAppCacheSizeProvider);
    }
    // goBranch 复用已经创建的分支 Navigator，不销毁其中页面和滚动状态。
    navigationShell.goBranch(index);
  }

  /// 构建登录后待下载 DASH 重新解析时的 Shell 顶层进度浮层。
  Widget _buildPendingDashRefreshProgressOverlay(
    PendingDashRefreshProgress progress,
  ) {
    return Positioned(
      top: 10,
      left: 0,
      right: 0,
      child: IgnorePointer(
        // 进度提示只用于反馈，不阻挡登录弹窗或页面按钮。
        child: Center(
          child: AppFloatingProgress(
            message: '正在解析多个视频',
            current: progress.current,
            total: progress.total,
          ),
        ),
      ),
    );
  }
}
