part of 'user_center_page.dart';

/// 收藏夹详情独立路由，避免替换个人中心主列表后丢失滚动位置。
final class FavoriteFolderDetailPage extends ConsumerStatefulWidget {
  /// 创建指定收藏夹的详情页。
  const FavoriteFolderDetailPage({
    super.key,
    required this.folder,
    required this.onParse,
  });

  /// 当前需要展示的收藏夹。
  final BiliFavoriteFolder folder;

  /// 点击视频下载按钮后交给个人中心执行解析的回调。
  final ValueChanged<BiliUserVideoItem> onParse;

  /// 创建独立分页和滚动状态。
  @override
  ConsumerState<FavoriteFolderDetailPage> createState() =>
      FavoriteFolderDetailPageState();
}

/// 管理收藏夹详情的分页、滚动和回顶部状态。
final class FavoriteFolderDetailPageState
    extends ConsumerState<FavoriteFolderDetailPage> {
  /// 详情列表滚动控制器，只在当前详情路由生命周期内存在。
  final ScrollController _scrollController = ScrollController();

  /// 当前收藏夹已加载的视频和分页信息。
  VideoPagingState _state = const VideoPagingState(loading: true);

  /// 收藏夹详情是否处于批量选择模式。
  bool _selectionMode = false;

  /// 收藏夹详情当前是否正在批量解析并写入队列。
  bool _batchQueuing = false;

  /// 收藏夹详情批量解析当前处理的一基序号。
  int _batchProgressCurrent = 0;

  /// 收藏夹详情批量解析本轮需要处理的视频条目总数。
  int _batchProgressTotal = 0;

  /// 收藏夹详情中已勾选的视频稳定键集合。
  final Set<String> _selectedVideoKeys = <String>{};

  /// 初始化详情滚动监听并请求第一页。
  @override
  void initState() {
    super.initState();
    // 滚动监听同时负责分页触底和底栏回顶部状态。
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 新详情页从顶部展示，不能继承主收藏列表的回顶部状态。
      ref
          .read(userCenterScrolledBeyondTopProvider.notifier)
          .setBeyondTop(false);
      unawaited(_loadVideos(refresh: true));
    });
  }

  /// 释放详情路由独占的滚动控制器。
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 构建固定详情标题和可独立滚动的视频列表。
  @override
  Widget build(BuildContext context) {
    // 手机端使用紧凑边距，桌面端保持个人中心内容最大宽度。
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.navigationRail;
    final horizontalPadding = mobile ? 16.0 : 24.0;
    // Shell 的“回顶部”入口只操作当前详情路由的列表。
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
                  child: FavoriteDetailHeader(
                    folder: widget.folder,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    mobile ? 8 : 8,
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
                const SizedBox(height: 12),
                Expanded(
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: <Widget>[
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        sliver: VideoSection(
                          state: _state,
                          mobile: mobile,
                          emptyTitle: '收藏夹暂无可解析视频',
                          emptyDescription: '音频、合集等无法定位的内容不会作为普通视频展示。',
                          onParse: widget.onParse,
                          selecting: _selectionMode,
                          selectedKeys: _selectedVideoKeys,
                          selectionLocked: _batchQueuing,
                          itemKeyOf: _videoIdentity,
                          onToggleSelection: _toggleVideoSelection,
                          onRetry: () => _loadVideos(refresh: true),
                          onLoadMore: () => _loadVideos(refresh: false),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(height: mobile ? 24 : 32),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 收藏夹详情中当前已经加载并可批量解析的视频条目。
  List<BiliUserVideoItem> get _currentSelectableItems {
    return _state.items
        .where((BiliUserVideoItem item) => item.canQueueDirectly)
        .toList(growable: false);
  }

  /// 开启或关闭收藏夹详情的选择模式。
  void _toggleSelectionMode() {
    if (_batchQueuing) return;
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedVideoKeys.clear();
    });
  }

  /// 切换收藏夹详情中单个视频的勾选状态。
  void _toggleVideoSelection(BiliUserVideoItem item) {
    if (_batchQueuing || !item.canQueueDirectly) return;
    final key = _videoIdentity(item);
    setState(() {
      // 已存在的键代表取消选择，否则加入本详情页批量集合。
      if (!_selectedVideoKeys.remove(key)) _selectedVideoKeys.add(key);
    });
  }

  /// 在收藏夹详情中全选或清空所有可解析视频。
  void _toggleAllSelection() {
    if (_batchQueuing) return;
    final keys = _currentSelectableItems.map(_videoIdentity).toSet();
    if (keys.isEmpty) return;
    final allSelected = keys.every(_selectedVideoKeys.contains);
    setState(() {
      // 复选框半选或未选时补齐全选，已全选时清空本详情页选择。
      _selectedVideoKeys
        ..clear()
        ..addAll(allSelected ? const <String>{} : keys);
    });
  }

  /// 批量解析收藏夹详情已勾选的视频并加入待下载。
  Future<void> _queueSelectedVideos(BuildContext context) async {
    // 从当前已加载收藏视频生成快照，异步解析期间继续加载更多不会影响本批。
    final selectedItems = _currentSelectableItems
        .where(
          (BiliUserVideoItem item) =>
              _selectedVideoKeys.contains(_videoIdentity(item)),
        )
        .toList(growable: false);
    if (selectedItems.isEmpty) return;
    setState(() {
      _batchQueuing = true;
      _batchProgressCurrent = selectedItems.isEmpty ? 0 : 1;
      _batchProgressTotal = selectedItems.length;
    });
    var result = const UserVideoBatchQueueResult(
      added: 0,
      skipped: 0,
      failed: 0,
    );
    try {
      // 与用户页批量入口共用控制器里的先解析、后统一写库流程。
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
    if (result.added > 0) {
      // 成功入队后直接进入待下载页，和个人中心其他视频列表保持一致。
      pageController.openPendingTasks(context);
    }
  }

  /// 监听列表滚动，接近底部时加载下一页并同步回顶部入口。
  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // 超过 300dp 后底栏切换为“回顶部”。
    ref
        .read(userCenterScrolledBeyondTopProvider.notifier)
        .setBeyondTop(position.pixels > 300);
    // 提前 360dp 请求下一页，避免用户滚到列表末尾后等待。
    if (!_batchQueuing && position.extentAfter <= 360) {
      unawaited(_loadVideos(refresh: false));
    }
  }

  /// 加载收藏夹视频第一页或下一页。
  Future<void> _loadVideos({required bool refresh}) async {
    final current = refresh ? const VideoPagingState() : _state;
    if (current.loading ||
        current.loadingMore ||
        (!current.hasMore && !refresh)) {
      return;
    }
    setState(() {
      if (refresh) {
        // 刷新收藏夹详情时清空旧选择，避免新列表复用旧稳定键。
        _selectionMode = false;
        _selectedVideoKeys.clear();
      }
      _state = current.copyWith(
        loading: current.items.isEmpty,
        loadingMore: current.items.isNotEmpty,
        loadingLabel: current.items.isEmpty ? '正在读取视频列表…' : null,
        clearError: true,
        clearLoadingLabel: current.items.isNotEmpty,
      );
    });
    try {
      // B 站收藏夹详情接口使用 media_id 和页码分页。
      final page = await ref
          .read(biliUserContentServiceProvider)
          .fetchFavoriteVideos(
            mediaId: widget.folder.id,
            page: refresh ? 1 : current.nextPage,
            onResolveProgress: _updateFavoriteResolveProgress,
          );
      if (!mounted) return;
      final nextItems = refresh
          ? page.items
          : <BiliUserVideoItem>[...current.items, ...page.items];
      setState(() {
        _state = VideoPagingState(
          items: nextItems,
          // 收藏夹可能包含被过滤的失效内容，仍以服务端下一页标记决定是否继续。
          hasMore: page.nextPage != null,
          nextPage: page.nextPage ?? current.nextPage,
        );
      });
      AppDebugLog.user(
        'Favorite videos loaded refresh=$refresh count=${page.items.length} total=${nextItems.length}',
      );
    } catch (error) {
      AppDebugLog.user(
        'Favorite videos load failed refresh=$refresh error=$error',
      );
      if (!mounted) return;
      setState(() {
        _state = current.copyWith(
          loading: false,
          loadingMore: false,
          errorMessage: biliUserMessage(error, fallback: '收藏详情加载失败，请稍后重试。'),
          clearLoadingLabel: true,
        );
      });
    }
  }

  /// 更新收藏夹详情预取分 P 数据时的解析进度。
  void _updateFavoriteResolveProgress(int current, int total) {
    if (!mounted || total <= 0) return;
    setState(() {
      _state = _state.copyWith(loadingLabel: '正在解析中 $current/$total …');
    });
  }

  /// 收藏夹详情列表只用于单项解析，稳定键仅满足复用视频区块的选择参数。
  String _videoIdentity(BiliUserVideoItem item) {
    final bvid = item.bvid?.trim();
    if (bvid != null && bvid.isNotEmpty) return 'bv:$bvid';
    final aid = item.aid;
    if (aid != null && aid > 0) return 'av:$aid';
    return 'title:${item.title}|${item.duration.inSeconds}';
  }

  /// 响应 Shell 底栏的回顶部请求。
  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    unawaited(
      _scrollController
          .animateTo(
            0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          )
          .then((_) {
            if (!mounted) return;
            ref
                .read(userCenterScrolledBeyondTopProvider.notifier)
                .setBeyondTop(false);
          }),
    );
  }
}
