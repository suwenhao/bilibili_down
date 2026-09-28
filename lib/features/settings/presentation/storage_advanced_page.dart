import 'package:flutter/material.dart';

import 'dialogs/storage_advanced_dialog.dart';

/// 设置中心移动端存储高级设置页。
final class StorageAdvancedPage extends StatelessWidget {
  /// 创建移动端入栈展示的存储高级设置页面。
  const StorageAdvancedPage({
    required this.baseDirectory,
    required this.initialTemplate,
    required this.onSave,
    super.key,
  });

  /// “更改”按钮选择的实际下载根目录。
  final String baseDirectory;

  /// 当前保存的动态子文件夹模板。
  final String initialTemplate;

  /// 保存动态子文件夹模板回调。
  final Future<void> Function(String template) onSave;

  /// 构建真正的路由页面，而不是全屏 Dialog。
  @override
  Widget build(BuildContext context) {
    return StorageAdvancedDialog(
      baseDirectory: baseDirectory,
      initialTemplate: initialTemplate,
      onSave: onSave,
      pageMode: true,
    );
  }
}
