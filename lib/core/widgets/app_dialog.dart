import 'package:flutter/material.dart';

import '../layout/app_breakpoints.dart';
import '../theme/app_theme.dart';
import 'app_action_button.dart';

/// 使用设计稿统一短确认弹窗的圆角、边距、排版和操作区。
final class AppAlertDialog extends StatelessWidget {
  /// 创建带标题、正文和操作按钮的标准确认弹窗。
  const AppAlertDialog({
    required this.title,
    required this.content,
    required this.actions,
    this.width = 400,
    super.key,
  });

  /// 弹窗标题。
  final Widget title;

  /// 弹窗正文或表单内容。
  final Widget content;

  /// 底部操作按钮。
  final List<Widget> actions;

  /// 桌面端期望使用的弹窗宽度；窄窗口仍受屏幕安全边距约束。
  final double width;

  /// 构建设计稿约定的 12dp 弹窗和全局统一操作按钮。
  @override
  Widget build(BuildContext context) {
    // 手机确认弹窗保留 16dp 屏幕安全边距，桌面使用更宽的 24dp。
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.dialogFullscreen;
    // 统一按钮字号，不改变应用其他页面的按钮主题。
    final scopedTheme = _dialogControlTheme(context);
    return Theme(
      data: scopedTheme,
      child: AlertDialog(
        // 业务可按内容传入宽度，Flutter 会在窄窗口中按可用空间收缩。
        constraints: BoxConstraints.tightFor(width: width),
        // 所有非全屏确认弹窗都在可用窗口内垂直、水平居中；
        // 只有 AppResponsiveDialog 负责手机端全屏业务弹窗。
        alignment: Alignment.center,
        insetPadding: EdgeInsets.fromLTRB(
          mobile ? 16 : 24,
          24,
          mobile ? 16 : 24,
          mobile ? 16 : 24,
        ),
        titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
        contentPadding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
        actionsPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        buttonPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: title,
        content: content,
        actions: actions,
      ),
    );
  }
}

/// 展示只有取消和确认两个动作的标准确认弹窗。
Future<bool> showAppConfirmationDialog({
  required BuildContext context,
  required Widget title,
  required Widget content,
  required String confirmLabel,
  String cancelLabel = '取消',
  double width = 400,
}) async {
  // 所有破坏性或高风险操作都通过同一弹窗返回布尔值，调用方只处理业务副作用。
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AppAlertDialog(
      width: width,
      title: title,
      content: content,
      actions: <Widget>[
        AppActionButton(
          variant: AppActionButtonVariant.text,
          onPressed: () {
            // 取消只关闭弹窗，不让调用方继续执行外部文件、账号或数据库操作。
            Navigator.of(dialogContext).pop(false);
          },
          label: cancelLabel,
        ),
        AppActionButton(
          variant: AppActionButtonVariant.filled,
          onPressed: () {
            // 确认结果交回调用方，由业务层决定后续异步流程和错误提示。
            Navigator.of(dialogContext).pop(true);
          },
          label: confirmLabel,
        ),
      ],
    ),
  );
  // 点击遮罩或系统返回都按取消处理，避免空值被误认为确认。
  return confirmed == true;
}

/// 大型设置内容在手机全屏、平板和桌面居中显示。
final class AppResponsiveDialog extends StatelessWidget {
  /// 创建具有最大宽度和独立内容布局的大型弹窗。
  const AppResponsiveDialog({
    required this.child,
    this.maxWidth = 800,
    super.key,
  });

  /// 弹窗内部固定头尾和滚动主体。
  final Widget child;

  /// 非手机布局允许使用的最大内容宽度。
  final double maxWidth;

  /// 按设计规则构建手机全屏页或桌面 12dp 圆角模态框。
  @override
  Widget build(BuildContext context) {
    // 小于 600dp 的大型设置弹窗必须全屏，不能缩放桌面弹窗。
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.dialogFullscreen;
    // 桌面弹窗最多占窗口高度的 88%，主体内部自行滚动。
    final maximumHeight = MediaQuery.sizeOf(context).height * 0.88;
    // 中等窗口按规范限制为 560dp，宽桌面才允许使用业务提供的最大宽度。
    final effectiveMaxWidth =
        MediaQuery.sizeOf(context).width < AppBreakpoints.dialogWide
        ? 560.0
        : maxWidth;
    // 手机矩形表面由设备屏幕承载圆角，桌面沿用全局 12dp 弹窗圆角。
    final shape = mobile
        ? const RoundedRectangleBorder(borderRadius: BorderRadius.zero)
        : null;
    return Theme(
      data: _dialogControlTheme(context),
      child: Dialog(
        insetPadding: mobile
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: mobile
            ? SizedBox.expand(child: SafeArea(child: child))
            : ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: effectiveMaxWidth,
                  maxHeight: maximumHeight,
                ),
                child: child,
              ),
      ),
    );
  }
}

/// 在弹窗子树中统一按钮排版和高度，同时保留原主题的状态颜色。
ThemeData _dialogControlTheme(BuildContext context) {
  // 基础主题提供原有颜色、圆角和状态样式。
  final base = Theme.of(context);
  // 弹窗操作也使用全局标准按钮排版，避免同一操作在页面和弹窗中粗细不同。
  const textStyle = AppTextStyles.selectableControlLabel;
  // 在保留现有按钮颜色和状态的基础上统一排版与尺寸。
  ButtonStyle withDialogControlStyle(ButtonStyle? style) {
    return (style ?? const ButtonStyle()).copyWith(
      textStyle: WidgetStatePropertyAll<TextStyle?>(textStyle),
      minimumSize: const WidgetStatePropertyAll<Size>(
        Size(44, AppControlSizes.standardHeight),
      ),
    );
  }

  // 三类常用弹窗按钮共用同一字号，颜色和禁用状态仍由原主题负责。
  return base.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: withDialogControlStyle(base.filledButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: withDialogControlStyle(base.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: withDialogControlStyle(base.textButtonTheme.style),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: (base.iconButtonTheme.style ?? const ButtonStyle()).copyWith(
        minimumSize: const WidgetStatePropertyAll<Size>(Size(44, 44)),
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      labelStyle: base.textTheme.bodySmall,
      hintStyle: base.textTheme.bodySmall?.copyWith(
        color: base.colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
