part of '../parse_history_page.dart';

/// 解析历史顶部栏。
final class ParseHistoryTopBar extends StatelessWidget {
  /// 创建返回按钮和标题。
  const ParseHistoryTopBar({super.key, required this.onBack, this.onClear});

  /// 返回解析页回调。
  final VoidCallback onBack;

  /// 清空全部解析历史回调；无历史时不展示按钮。
  final VoidCallback? onClear;

  /// 构建顶部标题栏。
  @override
  Widget build(BuildContext context) {
    final onClear = this.onClear;
    return Row(
      children: <Widget>[
        AppCircleIconButton(
          onPressed: onBack,
          tooltip: '返回解析页',
          dimension: 40,
          iconSize: 22,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '解析历史',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (onClear != null) ...<Widget>[
          const SizedBox(width: 12),
          AppActionButton(
            label: '清空',
            icon: Icons.delete_sweep_rounded,
            variant: AppActionButtonVariant.destructiveOutlined,
            size: AppActionButtonSize.small,
            onPressed: onClear,
          ),
        ],
      ],
    );
  }
}
