import 'package:flutter/material.dart';

import '../models/onboarding_step.dart';
import 'onboarding_footer.dart';
import 'onboarding_progress.dart';
import 'onboarding_step_content.dart';

/// 引导页的整体响应式布局，负责安全区、宽度限制和分页内容排版。
final class OnboardingPageLayout extends StatelessWidget {
  /// 创建完整引导页面布局。
  const OnboardingPageLayout({
    required this.pageController,
    required this.currentIndex,
    required this.completing,
    required this.fileManagementGranted,
    required this.notificationGranted,
    required this.requestingFileManagement,
    required this.requestingNotification,
    required this.isLastPage,
    required this.onPageChanged,
    required this.onBack,
    required this.onPrimary,
    required this.onRequestFileManagement,
    required this.onRequestNotification,
    super.key,
  });

  /// 外部持有的分页控制器，保证页面 State 统一管理生命周期。
  final PageController pageController;

  /// 当前步骤索引，用于进度、按钮文案和第一页判断。
  final int currentIndex;

  /// 是否正在保存完成状态，用于禁用按钮和显示加载。
  final bool completing;

  /// 文件管理授权是否已满足。
  final bool fileManagementGranted;

  /// 通知授权是否已满足。
  final bool notificationGranted;

  /// 文件管理授权按钮是否正在等待系统流程。
  final bool requestingFileManagement;

  /// 通知授权按钮是否正在等待系统流程。
  final bool requestingNotification;

  /// 当前是否在最后一步，用于切换主按钮文案。
  final bool isLastPage;

  /// 用户手势或动画翻页完成后的索引回调。
  final ValueChanged<int> onPageChanged;

  /// 左侧跳过或上一步动作。
  final VoidCallback? onBack;

  /// 右侧下一步或开始使用动作。
  final VoidCallback? onPrimary;

  /// 文件管理授权行的点击动作。
  final VoidCallback? onRequestFileManagement;

  /// 通知授权行的点击动作。
  final VoidCallback? onRequestNotification;

  /// 构建适配竖屏、横屏和小高度设备的引导布局。
  @override
  Widget build(BuildContext context) {
    // 页面背景沿用主题最底层表面，不强制覆盖用户亮暗模式。
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    // 当前主题颜色确保用户切换品牌色后引导仍与主应用一致。
    final colorScheme = Theme.of(context).colorScheme;
    // SafeArea 避开刘海、状态栏和系统手势区域。
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // 平板或横屏限制内容宽度，避免卡片和文案被过度拉伸。
            final contentWidth = constraints.maxWidth.clamp(0, 520).toDouble();
            // 低高度设备压缩上下留白，正文仍可在每页内独立滚动。
            final compactHeight = constraints.maxHeight < 700;
            // 居中容器让手机和平板共享同一视觉节奏。
            return Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        compactHeight ? 12 : 22,
                        24,
                        0,
                      ),
                      child: OnboardingProgress(
                        currentIndex: currentIndex,
                        total: onboardingSteps.length,
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: pageController,
                        itemCount: onboardingSteps.length,
                        onPageChanged: onPageChanged,
                        itemBuilder: (BuildContext context, int index) {
                          // 每个索引对应一份稳定产品文案与视觉类型。
                          final step = onboardingSteps[index];
                          // 页面正文可纵向滚动，横屏或系统大字体下不会遮挡操作。
                          return SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              24,
                              compactHeight ? 18 : 32,
                              24,
                              20,
                            ),
                            child: OnboardingStepContent(
                              step: step,
                              compactHeight: compactHeight,
                              fileManagementGranted: fileManagementGranted,
                              notificationGranted: notificationGranted,
                              requestingFileManagement:
                                  requestingFileManagement,
                              requestingNotification: requestingNotification,
                              onRequestFileManagement: onRequestFileManagement,
                              onRequestNotification: onRequestNotification,
                            ),
                          );
                        },
                      ),
                    ),
                    OnboardingFooter(
                      colorScheme: colorScheme,
                      completing: completing,
                      isFirstPage: currentIndex == 0,
                      isLastPage: isLastPage,
                      onBack: onBack,
                      onPrimary: onPrimary,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
