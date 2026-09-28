part of 'user_center_page.dart';

/// 收藏视频搜索子页。
final class FavoriteSearchPage extends ConsumerStatefulWidget {
  /// 创建收藏视频搜索页。
  const FavoriteSearchPage({super.key, required this.onParse});

  /// 点击视频下载按钮后交给个人中心执行解析的回调。
  final ValueChanged<BiliUserVideoItem> onParse;

  /// 创建搜索页状态。
  @override
  ConsumerState<FavoriteSearchPage> createState() => _FavoriteSearchPageState();
}

/// 管理收藏搜索、分页和批量解析。
final class _FavoriteSearchPageState extends ConsumerState<FavoriteSearchPage> {
  /// 搜索输入框控制器。
  final TextEditingController _keywordController = TextEditingController();

  /// 搜索结果滚动控制器。
  late final ScrollController _scrollController;

  /// 当前已经提交给接口的关键词。
  String _submittedKeyword = '';

  /// 搜索结果分页状态。
  VideoPagingState _state = const VideoPagingState(hasMore: false);

  /// 搜索结果是否处于选择模式。
  bool _selectionMode = false;

  /// 搜索结果是否正在批量解析入队。
  bool _batchQueuing = false;

  /// 批量解析当前处理的一基序号。
  int _batchProgressCurrent = 0;

  /// 批量解析本轮需要处理的视频条目总数。
  int _batchProgressTotal = 0;

  /// 搜索结果已选中的视频稳定键。
  final Set<String> _selectedVideoKeys = <String>{};

  /// 初始化滚动监听。
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      onAttach: (ScrollPosition position) {
        // 收藏搜索页可能恢复旧滚动位置，挂载后一帧同步 Shell 的回顶部入口。
        _scheduleScrollTopStateSync();
      },
    );
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(userCenterScrolledBeyondTopProvider.notifier)
          .setBeyondTop(false);
    });
  }

  /// 释放输入和滚动控制器。
  @override
  void dispose() {
    _keywordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 构建搜索输入、批量操作和搜索结果。
  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.navigationRail;
    final horizontalPadding = mobile ? 16.0 : 24.0;
    ref.listen<int>(userCenterScrollTopRequestProvider, (
      int? previous,
      int next,
    ) {
      if (previous == next) return;
      _scrollToTop();
    });
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    mobile ? 8 : 8,
                    horizontalPadding,
                    0,
                  ),
                  child: _FavoriteSearchHeader(
                    count: _state.total ?? _state.items.length,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    10,
                    horizontalPadding,
                    0,
                  ),
                  child: _FavoriteSearchInputBar(
                    controller: _keywordController,
                    enabled: !_batchQueuing,
                    loading: _state.loading,
                    onSubmitted: _submitSearch,
                  ),
                ),
                if (_submittedKeyword.isNotEmpty) ...<Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      10,
                      horizontalPadding,
                      0,
                    ),
                    child: FavoriteDetailToolbar(
                      selecting: _selectionMode,
                      batchQueuing: _batchQueuing,
                      batchProgressCurrent: _batchProgressCurrent,
                      batchProgressTotal: _batchProgressTotal,
                      selectedCount: _selectedVideoKeys.length,
                      selectableCount: _currentSelectableItems.length,
                      mobile: mobile,
                      onToggleSelecting: _toggleSelectionMode,
                      onToggleAllSelection: _toggleAllSelection,
                      onBatchQueue: _selectedVideoKeys.isEmpty || _batchQueuing
                          ? null
                          : () => _queueSelectedVideos(context),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: _buildSearchScrollView(
                    mobile: mobile,
                    horizontalPadding: horizontalPadding,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建搜索结果滚动容器，移动端支持下拉刷新当前关键词。
  Widget _buildSearchScrollView({
    required bool mobile,
    required double horizontalPadding,
  }) {
    final scrollView = CustomScrollView(
      controller: _scrollController,
      physics: mobile ? const AlwaysScrollableScrollPhysics() : null,
      slivers: <Widget>[
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          sliver: _buildResultSliver(mobile),
        ),
        SliverToBoxAdapter(child: SizedBox(height: mobile ? 24 : 32)),
      ],
    );
    if (!mobile) return scrollView;
    return RefreshIndicator(
      onRefresh: _submittedKeyword.trim().isEmpty
          ? () async {}
          : () => _loadSearch(refresh: true),
      child: scrollView,
    );
  }

  /// 根据搜索状态构建结果列表或初始空态。
  Widget _buildResultSliver(bool mobile) {
    if (_submittedKeyword.trim().isEmpty) {
      return const SliverToBoxAdapter(
        child: UserEmptyState(
          icon: Icons.search_rounded,
          title: '搜索收藏视频',
          description: '输入标题关键词后开始搜索。',
        ),
      );
    }
    return VideoSection(
      state: _state,
      mobile: mobile,
      emptyTitle: '没有搜到视频',
      emptyDescription: '换个关键词再试试，或确认收藏里是否包含相关视频。',
      onParse: widget.onParse,
      selecting: _selectionMode,
      selectedKeys: _selectedVideoKeys,
      selectionLocked: _batchQueuing,
      itemKeyOf: _videoIdentity,
      onToggleSelection: _toggleVideoSelection,
      onRetry: () => _loadSearch(refresh: true),
      onLoadMore: () => _loadSearch(refresh: false),
    );
  }

  /// 提交搜索关键词并从第一页重新加载。
  void _submitSearch() {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty || _batchQueuing) return;
    setState(() {
      // 新关键词会替换整组结果，分页和旧选择都必须重置。
      _submittedKeyword = keyword;
      _selectionMode = false;
      _selectedVideoKeys.clear();
    });
    unawaited(_loadSearch(refresh: true));
  }

  /// 搜索列表滚动时同步回顶部入口并接近底部加载。
  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _syncScrollTopState();
    if (position.extentAfter > 360) return;
    unawaited(_loadSearch(refresh: false));
  }

  /// 同步当前收藏搜索页是否需要显示回顶部入口。
  void _syncScrollTopState() {
    final beyondTop =
        _scrollController.hasClients && _scrollController.offset > 300;
    ref
        .read(userCenterScrolledBeyondTopProvider.notifier)
        .setBeyondTop(beyondTop);
  }

  /// 等待列表挂载或结果重建完成后同步回顶部状态。
  void _scheduleScrollTopStateSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncScrollTopState();
    });
  }

  /// 当前搜索结果可批量选择的视频。
  List<BiliUserVideoItem> get _currentSelectableItems {
    return _state.items
        .where((BiliUserVideoItem item) => item.canQueueDirectly)
        .toList(growable: false);
  }

  /// 开启或关闭搜索结果选择模式。
  void _toggleSelectionMode() {
    if (_batchQueuing) return;
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedVideoKeys.clear();
    });
  }

  /// 切换搜索结果单个视频选择状态。
  void _toggleVideoSelection(BiliUserVideoItem item) {
    if (_batchQueuing || !item.canQueueDirectly) return;
    final key = _videoIdentity(item);
    setState(() {
      // 已选中则取消，否则加入搜索页批量集合。
      if (!_selectedVideoKeys.remove(key)) _selectedVideoKeys.add(key);
    });
  }

  /// 全选或清空搜索结果当前可解析视频。
  void _toggleAllSelection() {
    if (_batchQueuing) return;
    final keys = _currentSelectableItems.map(_videoIdentity).toSet();
    if (keys.isEmpty) return;
    final allSelected = keys.every(_selectedVideoKeys.contains);
    setState(() {
      // 已经全选时点击清空，否则补齐所有可解析条目。
      _selectedVideoKeys
        ..clear()
        ..addAll(allSelected ? const <String>{} : keys);
    });
  }

  /// 批量解析搜索结果已选视频并加入待下载。
  Future<void> _queueSelectedVideos(BuildContext context) async {
    final selectedItems = _currentSelectableItems
        .where(
          (BiliUserVideoItem item) =>
              _selectedVideoKeys.contains(_videoIdentity(item)),
        )
        .toList(growable: false);
    if (selectedItems.isEmpty) return;
    setState(() {
      _batchQueuing = true;
      _batchProgressCurrent = 1;
      _batchProgressTotal = selectedItems.length;
    });
    var result = const UserVideoBatchQueueResult(
      added: 0,
      skipped: 0,
      failed: 0,
    );
    try {
      // 收藏搜索结果入队复用用户中心批量规则，保证任务去重和提示一致。
      result = await ref
          .read(userCenterPageControllerProvider.notifier)
          .queueVideoItems(
            items: selectedItems,
            onProgress: (int current, int total) {
              if (!mounted) return;
              setState(() {
                _batchProgressCurrent = current;
                _batchProgressTotal = total;
              });
            },
          );
    } finally {
      if (mounted) {
        setState(() {
          _batchQueuing = false;
          _batchProgressCurrent = 0;
          _batchProgressTotal = 0;
          _selectionMode = false;
          _selectedVideoKeys.clear();
        });
      }
    }
    if (!context.mounted) return;
    final pageController = ref.read(userCenterPageControllerProvider.notifier);
    pageController.showBatchQueueResult(context, result);
    if (result.added > 0) pageController.openPendingTasks(context);
  }

  /// 加载收藏搜索结果。
  Future<void> _loadSearch({required bool refresh}) async {
    final keyword = _submittedKeyword.trim();
    if (keyword.isEmpty) return;
    final current = refresh ? const VideoPagingState() : _state;
    if (current.loading ||
        current.loadingMore ||
        (!current.hasMore && !refresh)) {
      return;
    }
    setState(() {
      if (refresh) {
        // 刷新搜索会换掉完整结果集，避免不同关键词结果混选。
        _selectionMode = false;
        _selectedVideoKeys.clear();
      }
      _state = current.copyWith(
        loading: current.items.isEmpty,
        loadingMore: current.items.isNotEmpty,
        loadingLabel: current.items.isEmpty ? '正在搜索收藏…' : null,
        clearError: true,
        clearLoadingLabel: current.items.isNotEmpty,
      );
    });
    try {
      final page = await ref
          .read(biliUserContentServiceProvider)
          .fetchFavoriteVideos(
            keyword: keyword,
            page: refresh ? 1 : current.nextPage,
            pageSize: 40,
            onResolveProgress: _updateSearchResolveProgress,
          );
      if (!mounted || keyword != _submittedKeyword.trim()) return;
      final nextItems = refresh
          ? page.items
          : <BiliUserVideoItem>[...current.items, ...page.items];
      setState(() {
        _state = VideoPagingState(
          items: nextItems,
          hasMore: page.nextPage != null,
          nextPage: page.nextPage ?? current.nextPage,
          total: page.total ?? current.total,
        );
      });
      _scheduleScrollTopStateSync();
      AppDebugLog.user(
        'Favorite search loaded keyword=$keyword refresh=$refresh count=${page.items.length}',
      );
    } catch (error) {
      AppDebugLog.user('Favorite search failed keyword=$keyword error=$error');
      if (!mounted) return;
      setState(() {
        _state = current.copyWith(
          loading: false,
          loadingMore: false,
          clearLoadingLabel: true,
          errorMessage: biliUserMessage(error, fallback: '收藏搜索失败，请稍后重试。'),
        );
      });
    }
  }

  /// 更新搜索结果的分 P 预取进度。
  void _updateSearchResolveProgress(int current, int total) {
    if (!mounted || total <= 0) return;
    setState(() {
      _state = _state.copyWith(loadingLabel: '正在解析中 $current/$total …');
    });
  }

  /// 收藏搜索结果选择使用 BV 或 AV 构造稳定键。
  String _videoIdentity(BiliUserVideoItem item) {
    final bvid = item.bvid?.trim();
    if (bvid != null && bvid.isNotEmpty) return 'bv:$bvid';
    final aid = item.aid;
    if (aid != null && aid > 0) return 'av:$aid';
    return 'title:${item.title}|${item.duration.inSeconds}';
  }

  /// 响应 Shell 底栏的回顶部请求。
  void _scrollToTop() {
    if (!_scrollController.hasClients) {
      _syncScrollTopState();
      return;
    }
    unawaited(
      _scrollController
          .animateTo(
            0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          )
          .then((_) {
            if (!mounted) return;
            _syncScrollTopState();
          }),
    );
  }
}

/// 收藏搜索页顶部标题栏。
final class _FavoriteSearchHeader extends StatelessWidget {
  /// 创建返回按钮、标题和结果数量。
  const _FavoriteSearchHeader({required this.count, required this.onBack});

  /// 当前搜索结果数量或服务端总数。
  final int count;

  /// 返回收藏列表回调。
  final VoidCallback onBack;

  /// 构建固定高度标题栏。
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: <Widget>[
          AppCircleIconButton(
            onPressed: onBack,
            tooltip: '返回收藏',
            dimension: 36,
            iconSize: 21,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '收藏搜索',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text(
            '$count 项',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 收藏搜索页顶部输入条。
final class _FavoriteSearchInputBar extends StatelessWidget {
  /// 创建紧凑搜索输入和提交按钮。
  const _FavoriteSearchInputBar({
    required this.controller,
    required this.enabled,
    required this.loading,
    required this.onSubmitted,
  });

  /// 输入关键词控制器。
  final TextEditingController controller;

  /// 是否允许输入和提交。
  final bool enabled;

  /// 是否正在请求搜索结果。
  final bool loading;

  /// 提交搜索回调。
  final VoidCallback onSubmitted;

  /// 构建与用户中心搜索页一致的紧凑行高。
  @override
  Widget build(BuildContext context) {
    const inputControlHeight = AppControlSizes.compactHeight;
    final inputTextStyle = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(height: 1.15);
    return Row(
      children: <Widget>[
        Expanded(
          child: SizedBox(
            height: inputControlHeight,
            child: TextField(
              controller: controller,
              enabled: enabled,
              autofocus: true,
              maxLines: 1,
              textAlignVertical: TextAlignVertical.center,
              textInputAction: TextInputAction.search,
              style: inputTextStyle,
              strutStyle: const StrutStyle(
                fontSize: AppFontSizes.bodyLarge,
                height: 1.15,
                forceStrutHeight: true,
              ),
              decoration: const InputDecoration(
                constraints: BoxConstraints.tightFor(
                  height: inputControlHeight,
                ),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 0),
                hintText: '搜索收藏标题',
                prefixIcon: Icon(Icons.search_rounded),
                prefixIconConstraints: BoxConstraints.tightFor(
                  width: inputControlHeight,
                  height: inputControlHeight,
                ),
              ),
              onSubmitted: (_) => onSubmitted(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        AppActionButton(
          variant: AppActionButtonVariant.filled,
          onPressed: enabled ? onSubmitted : null,
          loading: loading,
          icon: Icons.search_rounded,
          label: '搜索',
          minWidth: 88,
        ),
      ],
    );
  }
}
