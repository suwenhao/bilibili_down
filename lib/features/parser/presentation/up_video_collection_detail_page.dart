part of 'up_user_page.dart';

/// UP 页视频详情加载函数。
typedef _DetailVideoLoader =
    Future<BiliUserVideoPage> Function(
      int page,
      BiliVideoResolveProgress? onResolveProgress,
    );

/// UP 收藏夹或合集下的视频详情页。
final class _UpVideoCollectionDetailPage extends ConsumerStatefulWidget {
  /// 创建视频详情页。
  const _UpVideoCollectionDetailPage({
    required this.title,
    required this.mediaCount,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.onParse,
    required this.loader,
  });

  /// 页面标题。
  final String title;

  /// 详情中资源总数。
  final int mediaCount;

  /// 空态标题。
  final String emptyTitle;

  /// 空态说明。
  final String emptyDescription;

  /// 点击解析回调。
  final ValueChanged<BiliUserVideoItem> onParse;

  /// 分页加载函数。
  final _DetailVideoLoader loader;

  /// 创建详情状态。
  @override
  ConsumerState<_UpVideoCollectionDetailPage> createState() =>
      _UpVideoCollectionDetailPageState();
}

/// 管理收藏夹或合集视频详情分页。
final class _UpVideoCollectionDetailPageState
    extends ConsumerState<_UpVideoCollectionDetailPage> {
  /// 详情页滚动控制器。
  final ScrollController _scrollController = ScrollController();

  /// 视频分页状态。
  _VideoPagingState _state = const _VideoPagingState(
    loading: true,
    loadingLabel: '正在读取视频列表…',
  );

  /// 详情页是否处于选择模式。
  bool _selectionMode = false;

  /// 详情页是否正在批量解析入队。
  bool _batchQueuing = false;

  /// 批量解析当前处理的一基序号。
  int _batchProgressCurrent = 0;

  /// 批量解析本轮需要处理的视频条目总数。
  int _batchProgressTotal = 0;

  /// 详情页已选中的视频稳定键。
  final Set<String> _selectedVideoKeys = <String>{};

  /// 初始化详情加载。
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(parserScrolledBeyondTopProvider.notifier).setBeyondTop(false);
      unawaited(_loadVideos(refresh: true));
    });
  }

  /// 释放滚动控制器。
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 构建详情页。
  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.navigationRail;
    final horizontalPadding = mobile ? 16.0 : 24.0;
    // Shell 的解析分支回顶部入口只操作当前打开的详情列表。
    ref.listen<int>(parserScrollTopRequestProvider, (int? previous, int next) {
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
                  child: _UpDetailHeader(
                    title: widget.title,
                    mediaCount: _state.total ?? widget.mediaCount,
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
                  child: _UpDetailBatchControls(
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
                        sliver: _VideoSliverSection(
                          state: _state,
                          mobile: mobile,
                          emptyTitle: widget.emptyTitle,
                          emptyDescription: widget.emptyDescription,
                          onParse: widget.onParse,
                          selecting: _selectionMode,
                          selectedKeys: _selectedVideoKeys,
                          selectionLocked: _batchQueuing,
                          onToggleSelection: _toggleVideoSelection,
                          allowDirectParse: true,
                          detailNavigationOnly: true,
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

  /// 详情滚动时同步回顶部入口并接近底部加载。
  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    ref
        .read(parserScrolledBeyondTopProvider.notifier)
        .setBeyondTop(position.pixels > 300);
    if (position.extentAfter > 360) return;
    unawaited(_loadVideos(refresh: false));
  }

  /// 响应 Shell 回顶部事件。
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
                .read(parserScrolledBeyondTopProvider.notifier)
                .setBeyondTop(false);
          }),
    );
  }

  /// 详情页当前可批量选择的视频。
  List<BiliUserVideoItem> get _currentSelectableItems {
    return _state.items
        .where((BiliUserVideoItem item) => item.canQueueDirectly)
        .toList(growable: false);
  }

  /// 开启或关闭详情页选择模式。
  void _toggleSelectionMode() {
    if (_batchQueuing) return;
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedVideoKeys.clear();
    });
  }

  /// 切换详情页单个视频的选择状态。
  void _toggleVideoSelection(BiliUserVideoItem item) {
    if (_batchQueuing || !item.canQueueDirectly) return;
    final key = _videoIdentity(item);
    setState(() {
      // 已选中则取消，否则加入详情页批量集合。
      if (!_selectedVideoKeys.remove(key)) _selectedVideoKeys.add(key);
    });
  }

  /// 全选或清空详情页当前可解析视频。
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

  /// 批量解析详情页已选视频并加入待下载。
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
      // 详情页同样复用用户中心批量入队规则，避免两套解析行为分叉。
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

  /// 加载视频详情页。
  Future<void> _loadVideos({required bool refresh}) async {
    final current = refresh ? const _VideoPagingState() : _state;
    if (current.loading ||
        current.loadingMore ||
        (!current.hasMore && !refresh)) {
      return;
    }
    setState(() {
      if (refresh) {
        // 刷新详情列表时清空旧选择，避免不同数据复用旧键。
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
      // 详情页由调用方决定具体接口，只统一处理分页状态。
      final page = await widget.loader(
        refresh ? 1 : current.nextPage,
        _updateDetailResolveProgress,
      );
      if (!mounted) return;
      final nextItems = refresh
          ? page.items
          : <BiliUserVideoItem>[...current.items, ...page.items];
      setState(() {
        _state = _VideoPagingState(
          items: nextItems,
          hasMore: page.nextPage != null,
          nextPage: page.nextPage ?? current.nextPage,
          total: page.total ?? current.total,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = current.copyWith(
          loading: false,
          loadingMore: false,
          clearLoadingLabel: true,
          errorMessage: biliUserMessage(error, fallback: '视频列表加载失败，请稍后重试。'),
        );
      });
    }
  }

  /// 更新详情列表的分 P 预取进度。
  void _updateDetailResolveProgress(int current, int total) {
    if (!mounted || total <= 0) return;
    setState(() {
      _state = _state.copyWith(loadingLabel: '正在解析中 $current/$total …');
    });
  }
}
