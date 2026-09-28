import 'package:flutter/material.dart';

/// 命名变量的显示名称与稳定占位符。
final class NamingVariable {
  /// 创建一个可插入命名变量。
  const NamingVariable(this.label, this.token);

  /// 面向用户的变量说明。
  final String label;

  /// 保存到命名模板中的稳定占位符。
  final String token;
}

/// 一组带标题且可自动换行的命名变量按钮。
final class NamingVariableSection extends StatelessWidget {
  /// 创建变量分区。
  const NamingVariableSection({
    required this.title,
    required this.variables,
    required this.enabled,
    required this.onInsert,
    super.key,
  });

  /// 分区标题。
  final String title;

  /// 当前分区变量。
  final List<NamingVariable> variables;

  /// 保存期间是否允许继续插入变量。
  final bool enabled;

  /// 插入变量回调。
  final ValueChanged<String> onInsert;

  /// 构建标题和流式变量按钮。
  @override
  Widget build(BuildContext context) {
    // 获取主题主色用于突出变量占位符。
    final primaryColor = Theme.of(context).colorScheme.primary;
    // 变量按钮随弹窗宽度自然换行。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: variables
              .map(
                (NamingVariable variable) => ActionChip(
                  onPressed: enabled ? () => onInsert(variable.token) : null,
                  mouseCursor: enabled
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.forbidden,
                  label: Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(text: '${variable.label}  '),
                        TextSpan(
                          text: variable.token,
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}
