import 'package:flutter/material.dart';

import 'dialogs/naming_template_dialog.dart';

/// 设置中心移动端自定义文件命名设置页。
final class NamingTemplatePage extends StatelessWidget {
  /// 创建移动端入栈展示的命名模板页面。
  const NamingTemplatePage({
    required this.initialTemplate,
    required this.onSave,
    super.key,
  });

  /// 当前文件名模板。
  final String initialTemplate;

  /// 保存文件名模板回调。
  final Future<void> Function(String value) onSave;

  /// 构建真正的路由页面，而不是全屏 Dialog。
  @override
  Widget build(BuildContext context) {
    return NamingTemplateDialog(
      initialTemplate: initialTemplate,
      onSave: onSave,
      pageMode: true,
    );
  }
}
