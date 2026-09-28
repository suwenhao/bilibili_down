import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controllers/onboarding_page_controller.dart';
import 'models/onboarding_step.dart';
import 'widgets/onboarding_page_layout.dart';

/// 移动端首次使用引导，按真实产品流程说明解析、保存与权限边界。
final class OnboardingPage extends ConsumerStatefulWidget {
  /// 创建由根组件全屏承载的四步引导页。
  const OnboardingPage({super.key});

  /// 创建并持有 PageController 与当前页码。
  @override
  ConsumerState<OnboardingPage> createState() => OnboardingPageWidgetState();
}

/// 管理引导翻页、返回和完成状态。
final class OnboardingPageWidgetState extends ConsumerState<OnboardingPage>
    with WidgetsBindingObserver {
  /// 控制四页横向滑动，并在按钮翻页时提供平滑动画。
  final PageController _pageController = PageController();

  /// 当前显示页从零开始，用于进度条、返回按钮和完成按钮文案。
  int _currentIndex = 0;

  /// 注册生命周期监听并刷新权限状态，保证系统设置返回后按钮能更新。
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// 释放 PageController，避免引导退出后保留滚动监听。
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  /// 从 Android 系统授权页返回后重新读取权限状态。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 只有恢复前台时才刷新，避免暂停或隐藏阶段触发无意义平台通道。
    if (state != AppLifecycleState.resumed) return;
    ref
        .read(onboardingPageControllerProvider.notifier)
        .refreshPermissionStatus();
  }

  /// 构建适配竖屏与横屏安全区的卡片式引导。
  @override
  Widget build(BuildContext context) {
    // 最后一页把主按钮从“下一步”切换为“开始使用”。
    final isLastPage = _currentIndex == onboardingSteps.length - 1;
    // 完成保存动作交由页面控制器管理，避免本地 setState 和持久化耦合。
    final pageState = ref.watch(onboardingPageControllerProvider);
    // 展示布局交给独立组件，页面 State 只负责当前页和动作编排。
    return OnboardingPageLayout(
      pageController: _pageController,
      currentIndex: _currentIndex,
      completing: pageState.completing,
      fileManagementGranted: pageState.fileManagementGranted,
      notificationGranted: pageState.notificationGranted,
      requestingFileManagement: pageState.requestingFileManagement,
      requestingNotification: pageState.requestingNotification,
      isLastPage: isLastPage,
      onPageChanged: (int index) {
        // 手势翻页完成后同步按钮和进度条状态。
        setState(() => _currentIndex = index);
        // 进入最后一步时主动刷新权限，避免授权状态显示过期。
        if (index == onboardingSteps.length - 1) {
          ref
              .read(onboardingPageControllerProvider.notifier)
              .refreshPermissionStatus();
        }
      },
      onBack: _backAction(completing: pageState.completing),
      onPrimary: _primaryAction(
        completing: pageState.completing,
        isLastPage: isLastPage,
        requiredPermissionsGranted: pageState.requiredPermissionsGranted,
      ),
      onRequestFileManagement: pageState.requestingFileManagement
          ? null
          : () => unawaited(
              ref
                  .read(onboardingPageControllerProvider.notifier)
                  .requestFileManagementPermission(context),
            ),
      onRequestNotification: pageState.requestingNotification
          ? null
          : () => unawaited(
              ref
                  .read(onboardingPageControllerProvider.notifier)
                  .requestNotificationPermission(context),
            ),
    );
  }

  /// 平滑切换到下一步，不允许越过最后一页。
  void _next() {
    // 最后一页由完成按钮处理持久化，不再发起无效翻页。
    if (_currentIndex >= onboardingSteps.length - 1) return;
    // PageController 执行动画，页码由 onPageChanged 在结束时统一更新。
    unawaited(
      _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  /// 平滑返回上一步，第一页不显示返回语义。
  void _previous() {
    // 第一页左侧按钮是跳过，不执行负索引翻页。
    if (_currentIndex <= 0) return;
    // PageController 执行动画，保留用户对步骤方向的感知。
    unawaited(
      _pageController.previousPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  /// 跳过与完成使用同一持久化语义，避免下次启动再次强制显示。
  void _skip() {
    // 异步保存期间由 _complete 负责禁用按钮和错误反馈。
    unawaited(_complete());
  }

  /// 保存当前引导版本已完成，并在失败时留在原页提示用户。
  Future<void> _complete() async {
    // 完成保存和错误提示统一由页面控制器负责。
    await ref.read(onboardingPageControllerProvider.notifier).complete(context);
  }

  /// 返回左侧按钮当前动作。
  VoidCallback? _backAction({required bool completing}) {
    // 保存中禁用所有导航动作，避免状态写入时切页。
    if (completing) return null;
    // 第一页左侧按钮是跳过。
    if (_currentIndex == 0) return _skip;
    // 其他页面左侧按钮返回上一步。
    return _previous;
  }

  /// 返回右侧主按钮当前动作。
  VoidCallback? _primaryAction({
    required bool completing,
    required bool isLastPage,
    required bool requiredPermissionsGranted,
  }) {
    // 保存中禁用主按钮，防止重复写入。
    if (completing) return null;
    // 最后一页必须完成两项授权后才允许进入主应用。
    if (isLastPage && !requiredPermissionsGranted) return null;
    // 最后一页主按钮完成引导。
    if (isLastPage) return () => unawaited(_complete());
    // 其他页面主按钮进入下一步。
    return _next;
  }
}
