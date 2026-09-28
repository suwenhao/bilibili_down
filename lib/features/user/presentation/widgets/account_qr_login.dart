part of '../dialogs/account_dialog.dart';

/// 二维码登录状态卡片。
final class QrLoginAccount extends StatefulWidget {
  /// 创建二维码、状态和操作。
  const QrLoginAccount({
    super.key,
    required this.request,
    required this.result,
    required this.mobile,
    required this.showQrCodeOnMobile,
    required this.onOpenCopyrightUsage,
    required this.onCancel,
    required this.onRefresh,
  });

  /// 当前二维码请求。
  final BiliQrLoginRequest request;

  /// 最近扫码状态。
  final BiliQrLoginPollResult result;

  /// 当前是否处于手机端账号中心布局。
  final bool mobile;

  /// 手机端是否强制显示二维码而不是外部授权入口。
  final bool showQrCodeOnMobile;

  /// 打开版权使用说明的页面级回调。
  final VoidCallback onOpenCopyrightUsage;

  /// 取消登录回调。
  final VoidCallback onCancel;

  /// 重新生成回调。
  final VoidCallback onRefresh;

  @override
  State<QrLoginAccount> createState() => QrLoginAccountState();
}

/// 管理手机端外部授权链接的自动拉起和手动重试。
final class QrLoginAccountState extends State<QrLoginAccount> {
  /// 当前二维码请求是否已经触发过一次外部 App 拉起。
  bool _openedCurrentRequest = false;

  /// 初始化时根据手机端布局尝试拉起 B 站 App。
  @override
  void initState() {
    super.initState();
    _openLoginUrlAfterFrameIfNeeded();
  }

  /// 二维码刷新后允许新的请求再次自动拉起 B 站 App。
  @override
  void didUpdateWidget(covariant QrLoginAccount oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 二维码键变化代表一次新的登录会话，旧自动拉起状态不能复用。
    if (oldWidget.request.qrCodeKey != widget.request.qrCodeKey) {
      _openedCurrentRequest = false;
    }
    _openLoginUrlAfterFrameIfNeeded();
  }

  /// 手机端首次进入等待状态后，延迟到首帧结束再调用系统外部打开。
  void _openLoginUrlAfterFrameIfNeeded() {
    // 用户明确选择扫码时，本机只展示二维码，不主动唤起 B 站 App。
    final autoOpenExternalLogin = widget.mobile && !widget.showQrCodeOnMobile;
    // 桌面端继续展示二维码，过期二维码也不能再主动拉起授权页。
    if (!autoOpenExternalLogin ||
        _openedCurrentRequest ||
        widget.result.status == BiliQrLoginStatus.expired) {
      return;
    }
    _openedCurrentRequest = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 弹窗被关闭后不能继续使用失效上下文。
      if (!mounted) return;
      unawaited(_openLoginUrl());
    });
  }

  /// 打开 B 站登录授权链接，系统会优先交给已安装的 B 站 App 处理。
  Future<void> _openLoginUrl() async {
    try {
      // 外部应用模式让 Android/iOS 根据已安装 App 和浏览器自行处理该授权 URL。
      final opened = await launchUrl(
        widget.request.qrCodeUrl,
        mode: LaunchMode.externalApplication,
      );
      AppDebugLog.account('External Bilibili login opened=$opened');
      // 系统没有可处理应用时给出可恢复提示，用户仍可换设备扫码桌面二维码。
      if (!opened && mounted) {
        AppSnackBar.show(
          context,
          message: '没有找到可打开的 B站客户端，请确认已安装 B站 App。',
          type: AppSnackBarType.warning,
        );
      }
    } catch (error) {
      AppDebugLog.account('External Bilibili login failed error=$error');
      // 外部拉起失败不取消轮询，用户可以点击按钮重试或返回。
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: '打开 B站 App 失败：$error',
        type: AppSnackBarType.error,
      );
    }
  }

  /// 构建真实二维码或手机授权入口和状态反馈。
  @override
  Widget build(BuildContext context) {
    // 手机端扫码入口复用桌面二维码区域，普通手机登录仍显示外部授权提示。
    final useMobileLauncher = widget.mobile && !widget.showQrCodeOnMobile;
    // 过期状态决定主操作是刷新还是取消。
    final expired = widget.result.status == BiliQrLoginStatus.expired;
    // 未扫码轮询状态使用明确加载反馈，不能继续显示接口返回的“未扫码”。
    final waitingForScan =
        widget.result.status == BiliQrLoginStatus.waitingForScan;
    // 使用中心布局突出二维码。
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (waitingForScan)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 10),
              Text('等待扫描中...', style: Theme.of(context).textTheme.titleMedium),
            ],
          )
        else
          Text(
            widget.result.message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        const SizedBox(height: 20),
        if (useMobileLauncher)
          MobileQrLoginLauncher(result: widget.result)
        else
          DesktopQrCode(request: widget.request),
        const SizedBox(height: 20),
        if (useMobileLauncher && !expired) ...<Widget>[
          AccountActions(
            primary: AppActionButton(
              variant: AppActionButtonVariant.filled,
              onPressed: _openLoginUrl,
              icon: Icons.open_in_new_rounded,
              label: '重新打开 B站 App',
            ),
            secondary: AppActionButton(
              variant: AppActionButtonVariant.outlined,
              onPressed: widget.onCancel,
              icon: Icons.close_rounded,
              label: '取消登录',
            ),
          ),
          const SizedBox(height: 8),
          AppActionButton(
            variant: AppActionButtonVariant.text,
            onPressed: widget.onOpenCopyrightUsage,
            icon: Icons.info_outline_rounded,
            label: '版权使用说明',
          ),
        ] else
          AccountActions(
            primary: AppActionButton(
              variant: AppActionButtonVariant.filled,
              onPressed: expired ? widget.onRefresh : widget.onCancel,
              icon: expired ? Icons.refresh_rounded : Icons.close_rounded,
              label: expired ? '刷新二维码' : '取消登录',
            ),
            secondary: AppActionButton(
              variant: AppActionButtonVariant.outlined,
              onPressed: widget.onOpenCopyrightUsage,
              icon: Icons.info_outline_rounded,
              label: '版权使用说明',
            ),
          ),
      ],
    );
  }
}

/// 桌面端展示真实二维码，供另一台手机扫码确认。
final class DesktopQrCode extends StatelessWidget {
  /// 创建桌面端二维码区域。
  const DesktopQrCode({super.key, required this.request});

  /// 当前二维码请求。
  final BiliQrLoginRequest request;

  /// 构建带白底和主题色二维码的登录图形。
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 二维码最大 220，窄窗口按剩余宽度缩小并为边框内边距留出空间。
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth - 24
            : 220.0;
        // 二维码不超过当前可用宽度；窗口极窄时宁可缩小，也不能制造布局溢出。
        final qrSize = math.min(220.0, math.max(0.0, availableWidth));
        // 使用中心布局突出二维码。
        return Center(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 3,
              ),
            ),
            // QR 使用登录接口返回地址，不在本地拼接凭据。
            child: QrImageView(
              data: request.qrCodeUrl.toString(),
              version: QrVersions.auto,
              size: qrSize,
              backgroundColor: Colors.white,
              eyeStyle: QrEyeStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
              dataModuleStyle: QrDataModuleStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 手机端展示外部授权入口，不再要求用户扫描本机二维码。
final class MobileQrLoginLauncher extends StatelessWidget {
  /// 创建手机授权状态说明。
  const MobileQrLoginLauncher({super.key, required this.result});

  /// 最近一次二维码登录轮询状态。
  final BiliQrLoginPollResult result;

  /// 构建授权说明卡片。
  @override
  Widget build(BuildContext context) {
    // 不同轮询状态使用不同主文案，帮助用户知道是否需要回到 B 站确认。
    final message = switch (result.status) {
      BiliQrLoginStatus.waitingForScan => '已尝试打开 B站 App',
      BiliQrLoginStatus.waitingForConfirmation => '请在 B站 App 内确认授权',
      BiliQrLoginStatus.expired => '授权已过期，请重新生成',
      BiliQrLoginStatus.success => '登录成功',
    };
    // 卡片使用主题容器色，避免手机端出现突兀白色二维码块。
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.mobile_friendly_rounded,
            size: 52,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '如果没有自动跳转，请点击下方按钮重新打开 B站 App；授权完成后本页会自动刷新登录状态。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
