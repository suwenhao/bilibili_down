part of '../dialogs/account_dialog.dart';

/// 根据账号阶段选择页面内容。
final class AccountContent extends ConsumerWidget {
  /// 创建账号内容切换器。
  const AccountContent({
    super.key,
    required this.state,
    required this.mobile,
    required this.onOpenCopyrightUsage,
  });

  /// 当前账号状态。
  final AccountState state;

  /// 当前账号内容是否使用手机布局。
  final bool mobile;

  /// 打开版权使用说明的页面级回调。
  final VoidCallback onOpenCopyrightUsage;

  /// 构建检查、登录、二维码、资料或错误卡片。
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 弹窗自身已提供主表面，账号状态只保留内容内边距，避免出现双层卡片。
    return Padding(
      padding: const EdgeInsets.all(20),
      child: switch (state.phase) {
        AccountPhase.checking => const CheckingAccount(),
        AccountPhase.loggedOut => LoggedOutAccount(
          mobile: mobile,
          onOpenCopyrightUsage: onOpenCopyrightUsage,
          onAppLogin: () {
            // 手机端默认路径会生成二维码会话并自动拉起 B 站 App 授权。
            unawaited(
              ref.read(accountControllerProvider.notifier).startQrLogin(),
            );
          },
          onQrLogin: () {
            // 扫码入口使用同一套二维码会话，但手机端也保留二维码画面。
            unawaited(
              ref
                  .read(accountControllerProvider.notifier)
                  .startQrLogin(showQrCodeOnMobile: true),
            );
          },
        ),
        AccountPhase.generatingQr => GeneratingQrCode(
          mobile: mobile,
          showQrCodeOnMobile: state.showQrCodeOnMobile,
        ),
        AccountPhase.waitingQr => QrLoginAccount(
          request: state.qrRequest!,
          result: state.qrPollResult!,
          mobile: mobile,
          showQrCodeOnMobile: state.showQrCodeOnMobile,
          onOpenCopyrightUsage: onOpenCopyrightUsage,
          onCancel: () {
            // 取消当前二维码轮询并回到未登录页。
            ref.read(accountControllerProvider.notifier).cancelQrLogin();
          },
          onRefresh: () {
            // 二维码过期后重新生成并建立新轮询链。
            unawaited(
              ref
                  .read(accountControllerProvider.notifier)
                  .startQrLogin(showQrCodeOnMobile: state.showQrCodeOnMobile),
            );
          },
        ),
        AccountPhase.loggedIn => LoggedInAccount(
          profile: state.profile!,
          onLogout: () => _confirmLogout(context, ref),
        ),
        AccountPhase.failed => AccountError(
          message: state.errorMessage ?? '账号服务暂时不可用。',
          onRetry: () {
            // 错误页重试优先重新检查当前 Cookie 状态。
            unawaited(
              ref.read(accountControllerProvider.notifier).refreshProfile(),
            );
          },
        ),
      },
    );
  }

  /// 显示退出登录二次确认。
  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    // 弹窗明确退出只清理本地凭据，不删除任务和文件。
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: const Text('退出登录？'),
      content: const Text('将清除本机保存的 B 站登录凭据，不会删除下载任务和已有文件。'),
      confirmLabel: '退出登录',
    );
    // 用户取消时不修改安全存储。
    if (!confirmed) return;
    try {
      // 只退出当前软件，等待本机安全存储删除完成。
      await ref.read(accountControllerProvider.notifier).logout();
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        message: '已清除本机登录凭据。',
        type: AppSnackBarType.success,
      );
    } catch (error) {
      // 安全存储或默认设置更新失败时不能让用户误以为退出流程已经完整完成。
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        message: '退出登录处理失败，请重新打开账号中心确认：$error',
        type: AppSnackBarType.error,
      );
    }
  }
}
