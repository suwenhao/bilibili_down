part of '../parse_history_page.dart';

/// 解析历史列表。
final class ParseHistoryList extends StatelessWidget {
  /// 创建响应式历史列表。
  const ParseHistoryList({
    super.key,
    required this.entries,
    required this.mobile,
    required this.horizontalPadding,
    required this.onSelected,
    required this.onDelete,
  });

  /// 当前可展示的历史条目。
  final List<ParseHistoryEntry> entries;

  /// 是否使用移动端单列布局。
  final bool mobile;

  /// 列表左右留白。
  final double horizontalPadding;

  /// 点击历史条目后的恢复回调。
  final ValueChanged<ParseHistoryEntry> onSelected;

  /// 点击历史条目删除按钮后的回调。
  final ValueChanged<ParseHistoryEntry> onDelete;

  /// 构建单列或双列历史卡片。
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          sliver: mobile
              ? SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    // 移动端按需构建可见历史，末项不额外增加间距。
                    final entry = entries[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == entries.length - 1 ? 0 : 10,
                      ),
                      child: ParseHistoryCard(
                        entry: entry,
                        onSelected: onSelected,
                        onDelete: onDelete,
                      ),
                    );
                  }, childCount: entries.length),
                )
              : SliverLayoutBuilder(
                  builder: (context, constraints) {
                    // 桌面端复用用户中心视频列表的双列阈值。
                    const spacing = 12.0;
                    const minDesktopCardWidth = 520.0;
                    final useTwoColumns =
                        constraints.crossAxisExtent >=
                        minDesktopCardWidth * 2 + spacing;
                    final columns = useTwoColumns ? 2 : 1;
                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: 98,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        // 桌面端网格只创建视口附近卡片。
                        final entry = entries[index];
                        return ParseHistoryCard(
                          entry: entry,
                          onSelected: onSelected,
                          onDelete: onDelete,
                        );
                      }, childCount: entries.length),
                    );
                  },
                ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        const SliverToBoxAdapter(child: AppListFooter.text(label: '没有更多了')),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}
