import 'package:flutter/material.dart';

import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_icon_buttons.dart';

/// 设置模板类弹窗的统一响应式外壳。
final class SettingsTemplateDialogScaffold extends StatelessWidget {
  /// 创建带标题、说明、滚动主体和保存底栏的模板编辑弹窗。
  const SettingsTemplateDialogScaffold({
    required this.title,
    required this.description,
    required this.saving,
    required this.clearLabel,
    required this.onClear,
    required this.onSave,
    required this.child,
    this.pageMode = false,
    super.key,
  });

  /// 弹窗标题。
  final String title;

  /// 标题下方的说明文案。
  final String description;

  /// 是否正在保存，用于锁定返回、清空和保存按钮。
  final bool saving;

  /// 清空或恢复默认按钮文案。
  final String clearLabel;

  /// 用户点击清空或恢复默认时的业务回调。
  final VoidCallback onClear;

  /// 用户点击保存时的业务回调。
  final VoidCallback onSave;

  /// 变量区、输入区和预览区等业务主体。
  final Widget child;

  /// 是否作为移动端页面内容展示，而不是 Dialog 子树。
  final bool pageMode;

  /// 构建手机全屏、桌面弹窗共用的模板编辑布局。
  @override
  Widget build(BuildContext context) {
    // 手机大型弹窗使用全屏页，桌面继续居中展示。
    final mobile =
        pageMode ||
        MediaQuery.sizeOf(context).width < AppBreakpoints.dialogFullscreen;
    // 获取主题颜色，说明文案要弱于标题和主要操作。
    final colorScheme = Theme.of(context).colorScheme;
    // 保存按钮供手机全宽底栏和桌面右侧操作共同复用。
    final saveButton = AppActionButton(
      variant: AppActionButtonVariant.filled,
      onPressed: saving ? null : onSave,
      loading: saving,
      icon: Icons.save_outlined,
      label: saving ? '保存中' : '保存',
    );
    final content = Padding(
      padding: mobile
          ? const EdgeInsets.fromLTRB(16, 12, 16, 12)
          : const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (mobile) ...<Widget>[
                AppCircleIconButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: '返回',
                  dimension: 40,
                  iconSize: 22,
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (mobile)
                AppActionButton(
                  variant: AppActionButtonVariant.text,
                  onPressed: saving ? null : onClear,
                  label: clearLabel,
                ),
              if (!mobile)
                AppCircleIconButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: '关闭',
                  dimension: 40,
                  iconSize: 22,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(child: SingleChildScrollView(child: child)),
          const SizedBox(height: 18),
          if (mobile)
            SizedBox(width: double.infinity, child: saveButton)
          else
            Row(
              children: <Widget>[
                AppActionButton(
                  variant: AppActionButtonVariant.text,
                  onPressed: saving ? null : onClear,
                  label: clearLabel,
                ),
                const Spacer(),
                saveButton,
              ],
            ),
        ],
      ),
    );
    // 移动端页面模式使用真正路由页面承载，避免表现为全屏 Dialog。
    if (pageMode) {
      return PopScope(
        canPop: !saving,
        child: Scaffold(body: SafeArea(child: content)),
      );
    }
    return AppResponsiveDialog(child: content);
  }
}

/// 模板输入框与随机生成按钮的响应式组合。
final class SettingsTemplateInputRow extends StatelessWidget {
  /// 创建窄屏纵向、宽屏横向的输入操作行。
  const SettingsTemplateInputRow({
    required this.controller,
    required this.enabled,
    required this.labelText,
    required this.hintText,
    required this.onGenerate,
    this.errorText,
    super.key,
  });

  /// 当前模板输入控制器。
  final TextEditingController controller;

  /// 是否允许编辑和随机生成。
  final bool enabled;

  /// 输入框标签。
  final String labelText;

  /// 输入框占位提示。
  final String hintText;

  /// 输入框错误提示。
  final String? errorText;

  /// 随机生成按钮回调。
  final VoidCallback onGenerate;

  /// 构建和两个模板弹窗一致的输入行。
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 窄窗口把随机生成按钮移动到输入框下方。
        final compact =
            constraints.maxWidth < AppBreakpoints.settingsDialogFieldStack;
        // 输入框由调用方决定标签、占位和校验文案。
        final input = TextField(
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            labelText: labelText,
            hintText: hintText,
            errorText: errorText,
            border: const OutlineInputBorder(),
          ),
        );
        // 随机按钮从调用方提供的安全推荐模板中选择。
        final randomButton = AppActionButton(
          variant: AppActionButtonVariant.outlined,
          onPressed: enabled ? onGenerate : null,
          icon: Icons.casino_outlined,
          label: '随机生成',
        );
        // 手机使用上下结构，避免按钮压缩输入内容。
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[input, const SizedBox(height: 10), randomButton],
          );
        }
        // 桌面由输入框实际高度决定整行高度，校验文案出现时按钮也同步拉伸。
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: input),
              const SizedBox(width: 12),
              randomButton,
            ],
          ),
        );
      },
    );
  }
}

/// 模板弹窗中弱层级的建议说明。
final class SettingsTemplateTip extends StatelessWidget {
  /// 创建“建议：”前缀加正文的说明。
  const SettingsTemplateTip({required this.text, super.key});

  /// 建议正文。
  final String text;

  /// 构建和两个模板弹窗一致的富文本说明。
  @override
  Widget build(BuildContext context) {
    // 正文使用次级颜色，避免抢占输入和预览的视觉层级。
    final colorScheme = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          const TextSpan(
            text: '建议：',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text: text,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
