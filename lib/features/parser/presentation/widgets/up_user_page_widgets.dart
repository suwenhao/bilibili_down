part of '../up_user_page.dart';

/// UP 收藏夹或合集详情标题。
final class _UpDetailHeader extends StatelessWidget {
  /// 创建详情头部。
  const _UpDetailHeader({
    required this.title,
    required this.mediaCount,
    required this.onBack,
  });

  /// 当前详情页标题。
  final String title;

  /// 服务端返回的资源数量。
  final int mediaCount;

  /// 返回上一级 UP 页回调。
  final VoidCallback onBack;

  /// 构建与个人收藏详情一致的标题行。
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: <Widget>[
          AppCircleIconButton(
            onPressed: onBack,
            tooltip: '返回 UP 页',
            dimension: 36,
            iconSize: 21,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text(
            '$mediaCount 项',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// UP 页签和批量操作工具栏。
final class _UpToolbar extends StatelessWidget {
  /// 创建 UP 页签、批量解析和选择入口。
  const _UpToolbar({
    required this.selected,
    required this.selecting,
    required this.batchQueuing,
    required this.batchProgressCurrent,
    required this.batchProgressTotal,
    required this.selectedCount,
    required this.selectableCount,
    required this.mobile,
    required this.onSelected,
    required this.onRefresh,
    required this.onSearch,
    required this.onToggleSelecting,
    required this.onToggleAllSelection,
    required this.onBatchQueue,
  });

  /// 当前选中的页签。
  final _UpContentTab selected;

  /// 当前是否处于选择模式。
  final bool selecting;

  /// 是否正在批量解析入队。
  final bool batchQueuing;

  /// 批量解析当前处理的一基序号。
  final int batchProgressCurrent;

  /// 批量解析本轮需要处理的视频条目总数。
  final int batchProgressTotal;

  /// 当前选中数量。
  final int selectedCount;

  /// 当前页签可选择视频数量。
  final int selectableCount;

  /// 是否使用移动端纵向工具栏。
  final bool mobile;

  /// 点击页签后的回调。
  final ValueChanged<_UpContentTab> onSelected;

  /// 刷新当前页签。
  final VoidCallback onRefresh;

  /// 打开 UP 主视频搜索子页。
  final VoidCallback onSearch;

  /// 开启或退出选择模式。
  final VoidCallback onToggleSelecting;

  /// 全选或清空当前页签可解析视频。
  final VoidCallback onToggleAllSelection;

  /// 批量解析入队回调。
  final VoidCallback? onBatchQueue;

  /// 构建与用户中心一致的页签和操作按钮。
  @override
  Widget build(BuildContext context) {
    final tabs = <_UpContentTab, String>{
      _UpContentTab.uploads: '投稿',
      _UpContentTab.favorites: '收藏',
      _UpContentTab.collections: '合集',
    };
    final tabBar = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.entries
            .map((entry) {
              // 当前页签只负责选择状态，视觉交给公共选择芯片。
              final active = selected == entry.key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AppSelectionChip(
                  selected: active,
                  label: entry.value,
                  enabled: !batchQueuing,
                  onSelected: (_) => onSelected(entry.key),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
    return _UpToolbarLayout(
      mobile: mobile,
      forceStack: selecting,
      tabBar: tabBar,
      controls: _UpBatchControls(
        selecting: selecting,
        batchQueuing: batchQueuing,
        batchProgressCurrent: batchProgressCurrent,
        batchProgressTotal: batchProgressTotal,
        selectedCount: selectedCount,
        selectableCount: selectableCount,
        mobile: mobile,
        onRefresh: onRefresh,
        onSearch: onSearch,
        onToggleSelecting: onToggleSelecting,
        onToggleAllSelection: onToggleAllSelection,
        onBatchQueue: onBatchQueue,
      ),
    );
  }
}

/// UP 页工具栏布局。
final class _UpToolbarLayout extends StatelessWidget {
  /// 创建页签和按钮布局。
  const _UpToolbarLayout({
    required this.mobile,
    required this.forceStack,
    required this.tabBar,
    required this.controls,
  });

  /// 是否使用移动端纵向布局。
  final bool mobile;

  /// 是否强制拆成上下两行。
  final bool forceStack;

  /// 左侧页签内容。
  final Widget tabBar;

  /// 右侧批量操作内容。
  final Widget controls;

  /// 构建响应式工具栏。
  @override
  Widget build(BuildContext context) {
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[tabBar, const SizedBox(height: 10), controls],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // 选择模式按钮数量和文字长度不可预测，固定拆行避免两侧内容互相裁剪。
        final shouldStackToolbar = forceStack;
        if (shouldStackToolbar) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[tabBar, const SizedBox(height: 10), controls],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: tabBar),
            ),
            const SizedBox(width: 12),
            Flexible(
              fit: FlexFit.loose,
              child: Align(alignment: Alignment.centerRight, child: controls),
            ),
          ],
        );
      },
    );
  }
}

/// UP 页批量和选择按钮组。
final class _UpBatchControls extends StatelessWidget {
  /// 创建批量操作按钮组。
  const _UpBatchControls({
    required this.selecting,
    required this.batchQueuing,
    required this.batchProgressCurrent,
    required this.batchProgressTotal,
    required this.selectedCount,
    required this.selectableCount,
    required this.mobile,
    required this.onRefresh,
    required this.onSearch,
    required this.onToggleSelecting,
    required this.onToggleAllSelection,
    required this.onBatchQueue,
  });

  /// 当前是否处于选择模式。
  final bool selecting;

  /// 是否正在批量解析入队。
  final bool batchQueuing;

  /// 批量解析当前处理的一基序号。
  final int batchProgressCurrent;

  /// 批量解析本轮需要处理的视频条目总数。
  final int batchProgressTotal;

  /// 当前选中数量。
  final int selectedCount;

  /// 当前列表可选择数量。
  final int selectableCount;

  /// 是否使用移动端纵向布局。
  final bool mobile;

  /// 刷新当前 UP 页签。
  final VoidCallback onRefresh;

  /// 打开 UP 视频搜索页。
  final VoidCallback onSearch;

  /// 开启或退出选择模式。
  final VoidCallback onToggleSelecting;

  /// 全选或清空当前列表。
  final VoidCallback onToggleAllSelection;

  /// 批量解析入队回调。
  final VoidCallback? onBatchQueue;

  /// 构建按钮组。
  @override
  Widget build(BuildContext context) {
    final canSelect = selectableCount > 0 && !batchQueuing;
    final batchButton = AppActionButton(
      variant: AppActionButtonVariant.filled,
      onPressed: onBatchQueue,
      loading: batchQueuing,
      loadingLabel: userBatchLoadingLabel(
        batchProgressCurrent,
        batchProgressTotal,
      ),
      icon: Icons.playlist_add_check_rounded,
      label: '批量解析下载',
    );
    final selectButton = AppActionButton(
      variant: AppActionButtonVariant.outlined,
      highlighted: selecting,
      onPressed: canSelect ? onToggleSelecting : null,
      icon: selecting ? Icons.close_rounded : Icons.checklist_rounded,
      label: selecting ? '取消选择' : '选择',
    );
    final summary = selecting
        ? _UpSelectionSummary(
            selectedCount: selectedCount,
            selectableCount: selectableCount,
            enabled: canSelect,
            onToggleAll: onToggleAllSelection,
          )
        : null;
    final searchButton = AppCircleIconButton(
      onPressed: batchQueuing ? null : onSearch,
      tooltip: '搜索 UP 视频',
      variant: AppCircleIconButtonVariant.outlined,
      dimension: 36,
      iconSize: 18,
      icon: const Icon(Icons.search_rounded),
    );
    final refreshButton = AppCircleIconButton(
      onPressed: batchQueuing ? null : onRefresh,
      tooltip: '刷新当前页签',
      variant: AppCircleIconButtonVariant.outlined,
      dimension: 36,
      iconSize: 18,
      icon: const Icon(Icons.refresh_rounded),
    );
    final actionButtons = <Widget>[
      searchButton,
      refreshButton,
      batchButton,
      selectButton,
    ];
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              searchButton,
              const SizedBox(width: 8),
              Expanded(child: batchButton),
              const SizedBox(width: 8),
              selectButton,
            ],
          ),
          if (summary != null) ...<Widget>[const SizedBox(height: 6), summary],
        ],
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _spacedUpToolbarActions(<Widget>[
          ?summary,
          ...actionButtons,
        ], gap: 8),
      ),
    );
  }
}

/// UP 详情页批量和选择按钮组。
final class _UpDetailBatchControls extends StatelessWidget {
  /// 创建收藏夹或合集详情的批量操作按钮组。
  const _UpDetailBatchControls({
    required this.selecting,
    required this.batchQueuing,
    required this.batchProgressCurrent,
    required this.batchProgressTotal,
    required this.selectedCount,
    required this.selectableCount,
    required this.mobile,
    required this.onToggleSelecting,
    required this.onToggleAllSelection,
    required this.onBatchQueue,
  });

  /// 当前详情页是否处于选择模式。
  final bool selecting;

  /// 当前是否正在批量解析入队。
  final bool batchQueuing;

  /// 批量解析当前处理的一基序号。
  final int batchProgressCurrent;

  /// 批量解析本轮需要处理的视频条目总数。
  final int batchProgressTotal;

  /// 已选择的视频数量。
  final int selectedCount;

  /// 当前已加载且可选择的视频数量。
  final int selectableCount;

  /// 是否使用移动端纵向按钮布局。
  final bool mobile;

  /// 开启或退出选择模式。
  final VoidCallback onToggleSelecting;

  /// 全选或清空当前详情页可解析视频。
  final VoidCallback onToggleAllSelection;

  /// 执行批量解析入队。
  final VoidCallback? onBatchQueue;

  /// 构建与个人收藏详情一致的按钮布局。
  @override
  Widget build(BuildContext context) {
    final canSelect = selectableCount > 0 && !batchQueuing;
    final batchButton = AppActionButton(
      variant: AppActionButtonVariant.filled,
      onPressed: onBatchQueue,
      loading: batchQueuing,
      loadingLabel: userBatchLoadingLabel(
        batchProgressCurrent,
        batchProgressTotal,
      ),
      icon: Icons.playlist_add_check_rounded,
      label: '批量解析下载',
    );
    final selectButton = AppActionButton(
      variant: AppActionButtonVariant.outlined,
      highlighted: selecting,
      onPressed: canSelect ? onToggleSelecting : null,
      icon: selecting ? Icons.close_rounded : Icons.checklist_rounded,
      label: selecting ? '取消选择' : '选择',
    );
    final summary = selecting
        ? _UpSelectionSummary(
            selectedCount: selectedCount,
            selectableCount: selectableCount,
            enabled: canSelect,
            onToggleAll: onToggleAllSelection,
          )
        : null;
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: batchButton),
              const SizedBox(width: 8),
              selectButton,
            ],
          ),
          if (summary != null) ...<Widget>[const SizedBox(height: 6), summary],
        ],
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _spacedUpToolbarActions(<Widget>[
          batchButton,
          selectButton,
          ?summary,
        ], gap: 8),
      ),
    );
  }
}

/// 给 UP 页工具栏按钮插入固定间距，避免滚动按钮组在窄宽度下粘连。
List<Widget> _spacedUpToolbarActions(
  List<Widget> children, {
  required double gap,
}) {
  final spaced = <Widget>[];
  for (var index = 0; index < children.length; index += 1) {
    // 非首个控件前插入间距，保证横向滚动时各按钮仍能清楚分辨。
    if (index > 0) spaced.add(SizedBox(width: gap));
    spaced.add(children[index]);
  }
  return spaced;
}

/// UP 页选择摘要。
final class _UpSelectionSummary extends StatelessWidget {
  /// 创建选择摘要。
  const _UpSelectionSummary({
    required this.selectedCount,
    required this.selectableCount,
    required this.enabled,
    required this.onToggleAll,
  });

  /// 当前选中数量。
  final int selectedCount;

  /// 可选择总数。
  final int selectableCount;

  /// 是否允许切换全选。
  final bool enabled;

  /// 全选或清空回调。
  final VoidCallback onToggleAll;

  /// 构建三态选择摘要。
  @override
  Widget build(BuildContext context) {
    final checkboxValue = _checkboxValue;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox.square(
          dimension: 32,
          child: Checkbox(
            value: checkboxValue,
            tristate: true,
            mouseCursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.forbidden,
            onChanged: enabled ? (_) => onToggleAll() : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '已选择 $selectedCount / $selectableCount',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// 根据已选数量返回未选、半选或全选状态。
  bool? get _checkboxValue {
    if (selectableCount <= 0 || selectedCount <= 0) return false;
    if (selectedCount >= selectableCount) return true;
    return null;
  }
}

/// UP 主资料头图。
final class _UpProfileHero extends StatelessWidget {
  /// 创建带背景、头像、昵称和简介的头图。
  const _UpProfileHero({
    required this.profile,
    required this.fallbackName,
    required this.mid,
    required this.loading,
    required this.mobile,
    required this.onBack,
  });

  /// 已加载的 UP 资料。
  final BiliUpProfile? profile;

  /// 路由传入的 UP 名称兜底。
  final String? fallbackName;

  /// UP 主 UID。
  final int mid;

  /// 资料是否仍在加载。
  final bool loading;

  /// 是否使用移动端紧凑布局。
  final bool mobile;

  /// 返回解析页回调。
  final VoidCallback onBack;

  /// 构建类 B 站空间头图。
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 展示名优先使用接口资料，接口未返回时使用解析结果携带的发布者名称。
    final displayName = _displayName;
    // 简介优先使用接口签名，缺失时给出稳定的空间说明。
    final description = profile?.description?.trim().isNotEmpty == true
        ? profile!.description!.trim()
        : loading
        ? '正在加载 UP 资料…'
        : '暂无简介';
    // 移动端头图降低高度，避免首屏只看到背景。
    final height = mobile ? 150.0 : 188.0;
    // 头像尺寸按平台分级，桌面端更接近 B 站空间页视觉。
    final avatarSize = mobile ? 58.0 : 82.0;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset('assets/images/up_header_bg.jpg', fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.black.withValues(alpha: 0.08),
                  Colors.black.withValues(alpha: 0.42),
                ],
              ),
            ),
          ),
          Positioned(
            left: mobile ? 8 : 12,
            top: mobile ? 8 : 12,
            child: AppCircleIconButton(
              onPressed: onBack,
              tooltip: '返回解析页',
              dimension: 38,
              iconSize: 21,
              backgroundColor: Colors.black.withValues(alpha: 0.22),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          Positioned(
            left: mobile ? 18 : 34,
            right: mobile ? 18 : 34,
            bottom: mobile ? 18 : 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                _UpAvatar(url: profile?.avatarUrl, size: avatarSize),
                SizedBox(width: mobile ? 12 : 18),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: mobile ? 2 : 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              (mobile
                                      ? Theme.of(context).textTheme.titleLarge
                                      : Theme.of(
                                          context,
                                        ).textTheme.headlineMedium)
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          maxLines: mobile ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                                shadows: <Shadow>[
                                  Shadow(
                                    color: colorScheme.scrim.withValues(
                                      alpha: 0.45,
                                    ),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 解析可展示昵称。
  String get _displayName {
    final profileName = profile?.name.trim();
    if (profileName != null && profileName.isNotEmpty) return profileName;
    final fallback = fallbackName?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return 'UP $mid';
  }
}

/// UP 主头像。
final class _UpAvatar extends StatelessWidget {
  /// 创建头像。
  const _UpAvatar({required this.url, required this.size});

  /// 头像 URL。
  final String? url;

  /// 头像尺寸。
  final double size;

  /// 构建圆形头像。
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedUrl = url;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        color: colorScheme.surfaceContainerHighest,
      ),
      clipBehavior: Clip.antiAlias,
      child: resolvedUrl == null || resolvedUrl.isEmpty
          ? Icon(
              Icons.person_rounded,
              size: size * 0.52,
              color: colorScheme.onSurfaceVariant,
            )
          : CachedNetworkImage(
              imageUrl: resolvedUrl,
              cacheManager: CoverCacheManager.instance,
              fit: BoxFit.cover,
              httpHeaders: const <String, String>{
                'User-Agent': BiliNetworkClient.userAgent,
                'Referer': BiliNetworkClient.defaultReferer,
              },
              errorWidget: (context, url, error) => Icon(
                Icons.person_rounded,
                size: size * 0.52,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}

/// UP 页视频 Sliver 区块。
final class _VideoSliverSection extends StatelessWidget {
  /// 创建视频区块。
  const _VideoSliverSection({
    required this.state,
    required this.mobile,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.onParse,
    required this.selecting,
    required this.selectedKeys,
    required this.selectionLocked,
    required this.onToggleSelection,
    required this.onRetry,
    required this.onLoadMore,
    this.allowDirectParse = false,
    this.detailNavigationOnly = false,
  });

  /// 当前分页状态。
  final _VideoPagingState state;

  /// 是否移动端布局。
  final bool mobile;

  /// 空态标题。
  final String emptyTitle;

  /// 空态说明。
  final String emptyDescription;

  /// 点击解析回调。
  final ValueChanged<BiliUserVideoItem> onParse;

  /// 当前是否处于选择模式。
  final bool selecting;

  /// 当前选中视频稳定键。
  final Set<String> selectedKeys;

  /// 是否锁定选择控件。
  final bool selectionLocked;

  /// 切换选择状态。
  final ValueChanged<BiliUserVideoItem> onToggleSelection;

  /// 是否允许普通模式下显示解析或详情入口。
  final bool allowDirectParse;

  /// 是否只为需要详情展开的条目显示普通模式入口。
  final bool detailNavigationOnly;

  /// 失败重试回调。
  final VoidCallback onRetry;

  /// 加载更多回调。
  final VoidCallback onLoadMore;

  /// 构建加载、错误、空态和列表。
  @override
  Widget build(BuildContext context) {
    if (state.loading && state.items.isEmpty) {
      return SliverToBoxAdapter(
        child: _UpLoadingState(label: state.loadingLabel),
      );
    }
    if (state.errorMessage != null && state.items.isEmpty) {
      return SliverToBoxAdapter(
        child: _UpErrorState(message: state.errorMessage!, onRetry: onRetry),
      );
    }
    if (state.items.isEmpty) {
      return SliverToBoxAdapter(
        child: _UpEmptyState(
          icon: Icons.video_library_outlined,
          title: emptyTitle,
          description: emptyDescription,
        ),
      );
    }
    return SliverMainAxisGroup(
      slivers: <Widget>[
        BiliVideoList(
          items: state.items,
          mobile: mobile,
          onParse: onParse,
          allowDirectParse: allowDirectParse,
          detailNavigationOnly: detailNavigationOnly,
          selecting: selecting,
          selectedKeys: selectedKeys,
          selectionLocked: selectionLocked,
          itemKeyOf: _videoIdentity,
          onToggleSelection: onToggleSelection,
        ),
        _PagingFooter(
          loadingMore: state.loadingMore,
          loadingLabel: state.loadingLabel,
          hasMore: state.hasMore,
          onLoadMore: onLoadMore,
        ),
      ],
    );
  }
}

/// UP 页公开收藏夹 Sliver 区块。
final class _FavoriteFolderSliverSection extends StatelessWidget {
  /// 创建收藏夹区块。
  const _FavoriteFolderSliverSection({
    required this.state,
    required this.mobile,
    required this.onRetry,
    required this.onOpen,
  });

  /// 收藏夹加载状态。
  final _FolderState state;

  /// 是否移动端布局。
  final bool mobile;

  /// 失败重试回调。
  final VoidCallback onRetry;

  /// 打开收藏夹回调。
  final ValueChanged<BiliFavoriteFolder> onOpen;

  /// 构建收藏夹列表。
  @override
  Widget build(BuildContext context) {
    if ((!state.requested || state.loading) && state.items.isEmpty) {
      return const SliverToBoxAdapter(child: _UpLoadingState());
    }
    if (state.errorMessage != null && state.items.isEmpty) {
      return SliverToBoxAdapter(
        child: _UpErrorState(message: state.errorMessage!, onRetry: onRetry),
      );
    }
    if (state.items.isEmpty) {
      return const SliverToBoxAdapter(
        child: _UpEmptyState(
          icon: Icons.folder_off_outlined,
          title: '暂无公开收藏',
          description: '只有 UP 主公开展示的收藏夹才能在这里读取。',
        ),
      );
    }
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: mobile ? 1 : 2,
        mainAxisExtent: 80,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        // 收藏夹卡片来自公共组件，UP 页和用户页共用同一套视觉。
        final folder = state.items[index];
        return BiliFavoriteFolderCard(folder: folder, onOpen: onOpen);
      }, childCount: state.items.length),
    );
  }
}

/// UP 页合集 Sliver 区块。
final class _CollectionSliverSection extends StatelessWidget {
  /// 创建合集区块。
  const _CollectionSliverSection({
    required this.state,
    required this.mobile,
    required this.onRetry,
    required this.onLoadMore,
    required this.onOpen,
  });

  /// 合集分页状态。
  final _CollectionPagingState state;

  /// 是否移动端布局。
  final bool mobile;

  /// 失败重试回调。
  final VoidCallback onRetry;

  /// 加载更多回调。
  final VoidCallback onLoadMore;

  /// 打开合集回调。
  final ValueChanged<BiliUserCollection> onOpen;

  /// 构建合集列表。
  @override
  Widget build(BuildContext context) {
    if ((!state.requested || state.loading) && state.items.isEmpty) {
      return const SliverToBoxAdapter(child: _UpLoadingState());
    }
    if (state.errorMessage != null && state.items.isEmpty) {
      return SliverToBoxAdapter(
        child: _UpErrorState(message: state.errorMessage!, onRetry: onRetry),
      );
    }
    if (state.items.isEmpty) {
      return const SliverToBoxAdapter(
        child: _UpEmptyState(
          icon: Icons.video_collection_outlined,
          title: '暂无公开合集',
          description: '没有读取到这个 UP 的公开合集或系列。',
        ),
      );
    }
    return SliverMainAxisGroup(
      slivers: <Widget>[
        SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: mobile ? 1 : 2,
            mainAxisExtent: 96,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            // 合集卡片来自公共组件，点击后进入合集视频列表。
            final collection = state.items[index];
            return BiliUserCollectionCard(
              collection: collection,
              onOpen: onOpen,
            );
          }, childCount: state.items.length),
        ),
        _PagingFooter(
          loadingMore: state.loadingMore,
          loadingLabel: null,
          hasMore: state.hasMore,
          onLoadMore: onLoadMore,
        ),
      ],
    );
  }
}

/// 分页底部状态。
final class _PagingFooter extends StatelessWidget {
  /// 创建分页底部。
  const _PagingFooter({
    required this.loadingMore,
    required this.loadingLabel,
    required this.hasMore,
    required this.onLoadMore,
  });

  /// 是否正在加载下一页。
  final bool loadingMore;

  /// 加载更多时展示的进度文案。
  final String? loadingLabel;

  /// 是否还有下一页。
  final bool hasMore;

  /// 加载更多回调。
  final VoidCallback onLoadMore;

  /// 构建分页提示。
  @override
  Widget build(BuildContext context) {
    if (loadingMore) {
      final resolvedLabel = loadingLabel?.trim();
      return SliverMainAxisGroup(
        slivers: <Widget>[
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: AppListFooter.loading(
              label: resolvedLabel == null || resolvedLabel.isEmpty
                  ? '继续加载视频列表…'
                  : resolvedLabel,
            ),
          ),
        ],
      );
    }
    if (hasMore) {
      return SliverMainAxisGroup(
        slivers: <Widget>[
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: AppListFooter.action(
              label: '加载更多',
              icon: Icons.expand_more_rounded,
              onPressed: onLoadMore,
            ),
          ),
        ],
      );
    }
    return const SliverMainAxisGroup(
      slivers: <Widget>[
        SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(child: AppListFooter.text(label: '没有更多了')),
      ],
    );
  }
}

/// UP 页加载态。
final class _UpLoadingState extends StatelessWidget {
  /// 创建加载态。
  const _UpLoadingState({this.label});

  /// 加载时展示的补充说明。
  final String? label;

  /// 构建加载指示器。
  @override
  Widget build(BuildContext context) {
    final resolvedLabel = label?.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            if (resolvedLabel != null && resolvedLabel.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                resolvedLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// UP 页错误态。
final class _UpErrorState extends StatelessWidget {
  /// 创建错误态。
  const _UpErrorState({required this.message, required this.onRetry});

  /// 错误文案。
  final String message;

  /// 重试回调。
  final VoidCallback onRetry;

  /// 构建错误提示。
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 42),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          AppListFooter.action(
            label: '重试',
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// UP 页空态。
final class _UpEmptyState extends StatelessWidget {
  /// 创建空态。
  const _UpEmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  /// 空态图标。
  final IconData icon;

  /// 空态标题。
  final String title;

  /// 空态说明。
  final String description;

  /// 构建空态。
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: colorScheme.onSurfaceVariant, size: 44),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
