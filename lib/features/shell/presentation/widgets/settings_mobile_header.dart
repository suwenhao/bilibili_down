part of '../app_shell.dart';

/// 设置页手机端专用的居中标题栏。
final class SettingsMobileHeader extends StatelessWidget {
  /// 创建与设置设计稿一致的简洁标题栏。
  const SettingsMobileHeader({super.key});

  /// 构建固定高度、底部分隔线和居中标题。
  @override
  Widget build(BuildContext context) {
    // 设置中心不重复展示品牌、主题和账号入口，操作都在页面设置项中完成。
    return Container(
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Text(
        '设置中心',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
