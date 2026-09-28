import 'package:flutter/material.dart';

import '../../application/parser_controller.dart';
import 'parser_input_area.dart';

/// 解析页顶部固定输入区。
final class ParserInputSection extends StatelessWidget {
  /// 创建解析输入区。
  const ParserInputSection({
    required this.controller,
    required this.state,
    required this.horizontalPadding,
    required this.sectionSpacing,
    required this.onChanged,
    required this.onClear,
    required this.onParse,
    super.key,
  });

  /// 输入框文本控制器。
  final TextEditingController controller;

  /// 当前解析状态。
  final ParserState state;

  /// 页面水平留白。
  final double horizontalPadding;

  /// 输入区上下间距。
  final double sectionSpacing;

  /// 输入内容变化回调。
  final ValueChanged<String> onChanged;

  /// 清空输入回调。
  final VoidCallback onClear;

  /// 提交解析回调。
  final VoidCallback onParse;

  /// 构建固定在页面顶部的解析输入区。
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        sectionSpacing,
        horizontalPadding,
        sectionSpacing,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: ParserInputArea(
            controller: controller,
            state: state,
            onChanged: onChanged,
            onClear: onClear,
            onParse: onParse,
          ),
        ),
      ),
    );
  }
}
