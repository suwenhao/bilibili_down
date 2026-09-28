part of '../dialogs/account_dialog.dart';

/// 登录状态检查占位。
final class CheckingAccount extends StatelessWidget {
  /// 创建检查中内容。
  const CheckingAccount({super.key});

  /// 构建进度和说明。
  @override
  Widget build(BuildContext context) {
    // 居中显示登录校验进度。
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CircularProgressIndicator(),
        SizedBox(height: 18),
        Text('正在检查登录状态…'),
      ],
    );
  }
}

/// 未登录账号操作。
final class LoggedOutAccount extends StatelessWidget {
  /// 创建未登录内容。
  const LoggedOutAccount({
    super.key,
    required this.mobile,
    required this.onOpenCopyrightUsage,
    required this.onAppLogin,
    required this.onQrLogin,
  });

  /// 当前是否处于手机端账号中心布局。
  final bool mobile;

  /// 打开版权使用说明的页面级回调。
  final VoidCallback onOpenCopyrightUsage;

  /// 手机端拉起 B 站 App 登录回调。
  final VoidCallback onAppLogin;

  /// 展示二维码扫码登录回调。
  final VoidCallback onQrLogin;

  /// 构建登录说明和操作。
  @override
  Widget build(BuildContext context) {
    // 登录按钮在手机端会进入 App 授权流程，桌面端继续展示二维码。
    final appLoginButton = AppActionButton(
      variant: AppActionButtonVariant.filled,
      onPressed: onAppLogin,
      icon: mobile ? Icons.open_in_new_rounded : Icons.qr_code_scanner_rounded,
      label: mobile ? '打开 B站 App 登录' : 'B站扫码登录',
    );
    // 手机端额外提供扫码入口，用另一台设备扫描当前屏幕二维码。
    final qrLoginButton = AppActionButton(
      variant: AppActionButtonVariant.outlined,
      onPressed: onQrLogin,
      icon: Icons.qr_code_scanner_rounded,
      label: 'B站扫码登录',
    );
    // 版权说明按钮始终打开设置页复用的同一份合规内容。
    final statementButton = AppActionButton(
      variant: AppActionButtonVariant.outlined,
      onPressed: onOpenCopyrightUsage,
      icon: Icons.info_outline_rounded,
      label: '版权使用说明',
    );
    // 未登录页只展示声明、扫码和隐私说明。
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Icon(
          Icons.account_circle_outlined,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          '登录 B 站账号',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        Text(
          mobile
              ? '将拉起 B站 App 完成授权，Cookie 与刷新令牌仅保存在系统安全存储中。'
              : '扫码登录可解析账号有权访问的清晰度。Cookie 与刷新令牌仅保存在系统安全存储中。',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 24),
        if (mobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              appLoginButton,
              const SizedBox(height: 10),
              qrLoginButton,
              const SizedBox(height: 10),
              statementButton,
            ],
          )
        else
          AccountActions(primary: appLoginButton, secondary: statementButton),
      ],
    );
  }
}

/// 二维码生成进度。
final class GeneratingQrCode extends StatelessWidget {
  /// 创建二维码生成状态。
  const GeneratingQrCode({
    super.key,
    required this.mobile,
    required this.showQrCodeOnMobile,
  });

  /// 当前是否处于手机端账号中心布局。
  final bool mobile;

  /// 手机端是否即将展示二维码而不是外部授权入口。
  final bool showQrCodeOnMobile;

  /// 构建进度说明。
  @override
  Widget build(BuildContext context) {
    // 手机扫码入口和桌面端一样生成可扫描二维码。
    final showQrCode = !mobile || showQrCodeOnMobile;
    // 生成期间不展示旧二维码，避免用户扫描已取消请求。
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const CircularProgressIndicator(),
        const SizedBox(height: 18),
        Text(showQrCode ? '正在生成登录二维码…' : '正在准备 B站授权…'),
      ],
    );
  }
}
