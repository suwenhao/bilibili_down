import 'package:flutter/material.dart';

/// 列表底部状态行的展示类型。
enum _AppListFooterType {
  /// 正在加载下一页。
  loading,

  /// 可主动加载下一页。
  action,

  /// 列表已经结束。
  text,
}

/// 列表底部的轻量分页状态行。
final class AppListFooter extends StatelessWidget {
  /// 创建“继续加载中”状态，展示小型进度圈和说明文案。
  const AppListFooter.loading({super.key, required this.label})
    : _type = _AppListFooterType.loading,
      icon = null,
      onPressed = null;

  /// 创建可点击的“加载更多”状态。
  const AppListFooter.action({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  }) : _type = _AppListFooterType.action;

  /// 创建只读的列表结束文案。
  const AppListFooter.text({super.key, required this.label})
    : _type = _AppListFooterType.text,
      icon = null,
      onPressed = null;

  /// 当前状态行的展示类型。
  final _AppListFooterType _type;

  /// 状态行展示的说明文案。
  final String label;

  /// 可点击状态使用的图标。
  final IconData? icon;

  /// 非空时整行响应点击，用于主动请求下一页。
  final VoidCallback? onPressed;

  /// 构建无背景、无边框的 20 像素高状态行。
  @override
  Widget build(BuildContext context) {
    // 高度固定为 20，避免分页提示在列表末尾形成额外卡片感。
    const height = 20.0;
    final content = SizedBox(
      height: height,
      width: double.infinity,
      child: Center(child: _buildContent(context)),
    );
    if (onPressed == null) return content;
    return MouseRegion(
      // 可点击分页行在桌面和 Web 上保持明确的手型反馈。
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        // 透明区域也可点击，让整行都是加载更多入口。
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: content,
      ),
    );
  }

  /// 按状态类型构建紧凑的图标、进度或文字内容。
  Widget _buildContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (_type) {
      _AppListFooterType.loading => Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const SizedBox.square(
            dimension: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      _AppListFooterType.action => Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      _AppListFooterType.text => Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    };
  }
}
