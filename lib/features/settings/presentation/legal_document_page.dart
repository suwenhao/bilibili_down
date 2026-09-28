import 'package:flutter/material.dart';

import '../../../core/legal/legal_information_dialogs.dart';

/// 设置中心移动端法律文档详情页。
final class SettingsLegalDocumentPage extends StatelessWidget {
  /// 创建与设置页同级的法律文档页面。
  const SettingsLegalDocumentPage({required this.document, super.key});

  /// 当前展示的法律文档内容。
  final LegalDocumentData document;

  /// 构建可返回的移动端文档页。
  @override
  Widget build(BuildContext context) {
    // 法律文档作为 Shell 内二级页面展示，背景需要和滚动内容区保持同一层级。
    final pageBackground = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: pageBackground,
        surfaceTintColor: Colors.transparent,
        title: Text(
          document.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: LegalDocumentBody(document: document),
        ),
      ),
    );
  }
}
