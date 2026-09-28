part of '../dialogs/account_dialog.dart';

/// 账号弹窗底部双操作在桌面横排、手机纵向排列。
final class AccountActions extends StatelessWidget {
  /// 创建主操作和次操作的响应式布局。
  const AccountActions({
    super.key,
    required this.primary,
    required this.secondary,
  });

  /// 登录、取消或刷新等当前阶段主操作。
  final Widget primary;

  /// 版权使用说明等不会改变账号阶段的次操作。
  final Widget secondary;

  /// 根据全屏断点构建等宽横排或全宽纵排按钮。
  @override
  Widget build(BuildContext context) {
    // 手机按钮需要完整宽度，桌面按钮则共享同一行。
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.dialogFullscreen;
    if (mobile) {
      // 手机纵向按钮保留触控间距。
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[primary, const SizedBox(height: 10), secondary],
      );
    }
    // PC 两个操作等宽，状态切换时按钮区尺寸保持不变。
    return Row(
      children: <Widget>[
        Expanded(child: primary),
        const SizedBox(width: 10),
        Expanded(child: secondary),
      ],
    );
  }
}
