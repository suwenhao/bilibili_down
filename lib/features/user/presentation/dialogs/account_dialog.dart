import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/logging/app_debug_log.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_icon_buttons.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../services/bilibili/models/bili_auth_models.dart';
import '../../application/account_controller.dart';

part '../widgets/account_dialog_actions.dart';
part '../widgets/account_dialog_content.dart';
part '../widgets/account_dialog_states.dart';
part '../widgets/account_profile_views.dart';
part '../widgets/account_qr_login.dart';

/// 在当前页面上方展示统一账号弹窗。
Future<void> showAccountDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => const AccountDialog(),
  );
}

/// 打开账号中心复用的版权使用说明页面。
void openAccountCopyrightUsagePage(
  BuildContext context, {
  required bool closeAccountDialog,
}) {
  AppDebugLog.account('Copyright usage page opened from account center');
  // 版权说明统一进入设置分支子页，桌面端保留侧栏，手机端保留底栏。
  final router = GoRouter.of(context);
  if (!closeAccountDialog) {
    router.go('/settings/copyright-usage');
    return;
  }
  // 桌面登录弹窗属于根导航浮层，先关闭浮层再切到设置子页。
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  unawaited(
    rootNavigator.maybePop().then((_) {
      // 弹窗关闭后再改路由，避免页面被压在 ModalBarrier 下面。
      router.go('/settings/copyright-usage');
    }),
  );
}

/// 手机端个人分支内的账号登录子页。
final class AccountCenterPage extends ConsumerWidget {
  /// 创建保留 Shell 底部导航的账号中心页面。
  const AccountCenterPage({super.key});

  /// 构建账号登录流程页面。
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 子页读取同一份账号状态，二维码和 App 授权流程与桌面弹窗保持一致。
    final state = ref.watch(accountControllerProvider);
    ref.listen<AccountState>(accountControllerProvider, (
      AccountState? previous,
      AccountState next,
    ) {
      // 二维码或 App 授权成功后回到个人页，由个人页自动展示登录后的内容。
      if (next.autoCloseOnLoggedIn &&
          next.phase == AccountPhase.loggedIn &&
          context.mounted) {
        Navigator.of(context).maybePop();
      }
    });
    return PopScope(
      onPopInvokedWithResult: (bool didPop, void result) {
        // 退出登录子页时取消仍在进行的二维码轮询，避免后台继续请求。
        if (!didPop ||
            (state.phase != AccountPhase.generatingQr &&
                state.phase != AccountPhase.waitingQr)) {
          return;
        }
        ref.read(accountControllerProvider.notifier).cancelQrLogin();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    AppCircleIconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: '返回',
                      dimension: 40,
                      iconSize: 22,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '账号中心',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          // 短内容垂直居中，二维码等长内容超过高度时允许滚动。
                          final minimumContentHeight = math.max(
                            0.0,
                            constraints.maxHeight - 16,
                          );
                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: minimumContentHeight,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 560,
                                  ),
                                  child: AccountContent(
                                    state: state,
                                    mobile: true,
                                    onOpenCopyrightUsage: () =>
                                        openAccountCopyrightUsagePage(
                                          context,
                                          closeAccountDialog: false,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 账号状态、扫码登录和本地退出响应式弹窗。
final class AccountDialog extends ConsumerWidget {
  /// 创建桌面居中的账号中心弹窗。
  const AccountDialog({super.key});

  /// 构建响应式标题栏和账号状态内容。
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听登录检查和二维码轮询状态。
    final state = ref.watch(accountControllerProvider);
    // 扫码登录成功后直接关闭当前弹窗，避免成功资料页继续覆盖在主界面上。
    ref.listen<AccountState>(accountControllerProvider, (
      AccountState? previous,
      AccountState next,
    ) {
      // 只有二维码登录成功后的资料刷新会要求关闭弹窗，普通打开账号中心不会被抢走。
      if (next.autoCloseOnLoggedIn &&
          next.phase == AccountPhase.loggedIn &&
          context.mounted) {
        Navigator.of(context).maybePop();
      }
    });
    // 手机账号中心与大型设置弹窗使用相同的全屏断点。
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.dialogFullscreen;
    // 桌面账号弹窗使用稳定高度，登录阶段切换时外框不跟随内容跳动。
    final desktopHeight = math.min(
      520.0,
      MediaQuery.sizeOf(context).height * 0.82,
    );
    // 账号状态在固定内容区内居中，内容过高时再启用滚动。
    final content = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 手机和桌面沿用各自的顶部留白，同时计算可居中的最小内容高度。
        final topPadding = mobile ? 8.0 : 12.0;
        // 扣除滚动视口上下边距，确保短内容垂直居中但不会出现负约束。
        final minimumContentHeight = math.max(
          0.0,
          constraints.maxHeight - topPadding - 8,
        );
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(8, topPadding, 8, 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minimumContentHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: AccountContent(
                  state: state,
                  mobile: mobile,
                  onOpenCopyrightUsage: () => openAccountCopyrightUsagePage(
                    context,
                    closeAccountDialog: true,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    // 所有关闭方式都经过同一路由回调，扫码期间关闭等同于取消登录。
    return PopScope(
      onPopInvokedWithResult: (bool didPop, void result) {
        // 未真正关闭时不改变账号状态；已登录和普通未登录页也无需取消。
        if (!didPop ||
            (state.phase != AccountPhase.generatingQr &&
                state.phase != AccountPhase.waitingQr)) {
          return;
        }
        // 取消网络请求并恢复弹窗下次打开时的原始未登录内容。
        ref.read(accountControllerProvider.notifier).cancelQrLogin();
      },
      // 统一弹窗负责桌面圆角和表面层级；手机端登录入口改由分支子页承载。
      child: AppResponsiveDialog(
        maxWidth: 640,
        child: SizedBox(
          height: mobile ? null : desktopHeight,
          child: Padding(
            padding: mobile
                ? const EdgeInsets.fromLTRB(16, 12, 16, 12)
                : const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (mobile) ...<Widget>[
                      AppCircleIconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: '返回',
                        dimension: 40,
                        iconSize: 22,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        '账号中心',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    if (!mobile)
                      AppCircleIconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: '关闭',
                        dimension: 40,
                        iconSize: 22,
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // 手机和桌面都让状态内容占满同一区域，溢出时由内部滚动处理。
                Expanded(child: content),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
