part of '../user_center_page.dart';

/// 视频分页列表区块。
final class VideoSection extends StatelessWidget {
  /// 创建可展示加载、错误、空态和视频列表的区块。
  const VideoSection({
    super.key,
    required this.state,
    required this.mobile,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.onParse,
    required this.selecting,
    required this.selectedKeys,
    required this.selectionLocked,
    required this.itemKeyOf,
    required this.onToggleSelection,
    required this.onRetry,
    required this.onLoadMore,
    this.canSelectItem,
  });

  /// 当前分页状态。
  final VideoPagingState state;

  /// 是否使用移动端长条布局。
  final bool mobile;

  /// 空态标题。
  final String emptyTitle;

  /// 空态说明。
  final String emptyDescription;

  /// 点击解析按钮后的回调。
  final ValueChanged<BiliUserVideoItem> onParse;

  /// 当前是否处于选择模式。
  final bool selecting;

  /// 当前已经选中的视频稳定键。
  final Set<String> selectedKeys;

  /// 批量执行期间锁定选择控件。
  final bool selectionLocked;

  /// 生成视频稳定键。
  final String Function(BiliUserVideoItem item) itemKeyOf;

  /// 切换视频选择状态。
  final ValueChanged<BiliUserVideoItem> onToggleSelection;

  /// 判断条目在选择模式下是否可勾选；为空时沿用可直接入队规则。
  final bool Function(BiliUserVideoItem item)? canSelectItem;

  /// 失败重试回调。
  final VoidCallback onRetry;

  /// 用户主动继续加载下一页的回调。
  final VoidCallback onLoadMore;

  /// 构建列表内容。
  @override
  Widget build(BuildContext context) {
    if (state.loading && state.items.isEmpty) {
      return SliverToBoxAdapter(
        child: UserLoadingState(label: state.loadingLabel),
      );
    }
    if (state.errorMessage != null && state.items.isEmpty) {
      return SliverToBoxAdapter(
        child: UserErrorState(message: state.errorMessage!, onRetry: onRetry),
      );
    }
    if (state.items.isEmpty) {
      return SliverToBoxAdapter(
        child: Column(
          children: <Widget>[
            UserEmptyState(
              icon: Icons.video_library_outlined,
              title: emptyTitle,
              description: emptyDescription,
            ),
            if (state.hasMore) ...<Widget>[
              // 收藏夹详情可能前一页都被过滤掉，仍需要给用户继续请求下一页的入口。
              const SizedBox(height: 12),
              AppListFooter.action(
                label: '加载更多',
                icon: Icons.expand_more_rounded,
                onPressed: selectionLocked ? null : onLoadMore,
              ),
            ],
          ],
        ),
      );
    }
    return SliverMainAxisGroup(
      slivers: <Widget>[
        BiliVideoList(
          items: state.items,
          mobile: mobile,
          onParse: onParse,
          selecting: selecting,
          selectedKeys: selectedKeys,
          selectionLocked: selectionLocked,
          itemKeyOf: itemKeyOf,
          onToggleSelection: onToggleSelection,
          canSelectItem: canSelectItem,
        ),
        if (state.loadingMore) ...<Widget>[
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: AppListFooter.loading(label: state.loadingLabel ?? '继续加载中…'),
          ),
        ] else if (state.hasMore) ...<Widget>[
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: AppListFooter.action(
              label: '加载更多',
              icon: Icons.expand_more_rounded,
              onPressed: selectionLocked ? null : onLoadMore,
            ),
          ),
        ] else if (!state.hasMore) ...<Widget>[
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          const SliverToBoxAdapter(child: AppListFooter.text(label: '没有更多了')),
        ],
      ],
    );
  }
}

/// 收藏夹列表区块。
final class FavoriteFolderSection extends StatelessWidget {
  /// 创建收藏夹区块。
  const FavoriteFolderSection({
    super.key,
    required this.state,
    required this.mobile,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.onRetry,
    required this.onOpen,
  });

  /// 收藏夹加载状态。
  final FavoriteFolderState state;

  /// 是否使用移动端布局。
  final bool mobile;

  /// 空态标题。
  final String emptyTitle;

  /// 空态说明。
  final String emptyDescription;

  /// 失败重试回调。
  final VoidCallback onRetry;

  /// 打开收藏夹详情回调。
  final ValueChanged<BiliFavoriteFolder> onOpen;

  /// 构建收藏夹列表。
  @override
  Widget build(BuildContext context) {
    if (state.loading && state.items.isEmpty) {
      return const SliverToBoxAdapter(child: UserLoadingState());
    }
    if (state.errorMessage != null && state.items.isEmpty) {
      return SliverToBoxAdapter(
        child: UserErrorState(message: state.errorMessage!, onRetry: onRetry),
      );
    }
    if (state.items.isEmpty) {
      return SliverToBoxAdapter(
        child: UserEmptyState(
          icon: Icons.folder_off_outlined,
          title: emptyTitle,
          description: emptyDescription,
        ),
      );
    }
    final spacing = mobile ? 10.0 : 12.0;
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        // 虚拟网格只创建视口附近收藏夹，桌面端按内容区宽度均分两列。
        final columns = mobile ? 1 : 2;
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 80,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            // 按视口位置读取收藏夹，避免一次性构建全部卡片。
            final folder = state.items[index];
            return BiliFavoriteFolderCard(folder: folder, onOpen: onOpen);
          }, childCount: state.items.length),
        );
      },
    );
  }
}

/// 收藏夹详情标题。
final class FavoriteDetailHeader extends StatelessWidget {
  /// 创建收藏详情头部。
  const FavoriteDetailHeader({
    super.key,
    required this.folder,
    required this.onBack,
  });

  /// 当前收藏夹。
  final BiliFavoriteFolder folder;

  /// 返回收藏夹列表回调。
  final VoidCallback onBack;

  /// 构建标题和返回按钮。
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: <Widget>[
          AppCircleIconButton(
            onPressed: onBack,
            tooltip: '返回收藏夹',
            dimension: 36,
            iconSize: 21,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              folder.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text(
            '${folder.mediaCount} 项',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
