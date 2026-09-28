part of 'up_user_page.dart';

/// UP 主站内视频搜索子页。
final class _UpUserSearchPage extends ConsumerStatefulWidget {
  /// 创建指定 UP 主的视频搜索页。
  const _UpUserSearchPage({
    required this.mid,
    required this.fallbackName,
    required this.onParse,
  });

  /// 当前 UP 主 UID。
  final int mid;

  /// UP 名称兜底，用于日志和页面标题。
  final String? fallbackName;

  /// 点击分 P 详情入口时复用 UP 根页解析逻辑。
  final ValueChanged<BiliUserVideoItem> onParse;

  /// 创建搜索页状态。
  @override
  ConsumerState<_UpUserSearchPage> createState() => _UpUserSearchPageState();
}

/// 管理 UP 主视频搜索、分页和批量解析。
final class _UpUserSearchPageState extends ConsumerState<_UpUserSearchPage> {
  /// 搜索输入框控制器。
  final TextEditingController _keywordController = TextEditingController();

  /// 搜索结果滚动控制器。
  final ScrollController _scrollController = ScrollController();

  /// 当前已经提交给接口的关键词。
  String _submittedKeyword = '';

  /// 搜索接口下一页 offset 游标。
  String? _nextOffset;

  /// 搜索结果分页状态。
  _VideoPagingState _state = const _VideoPagingState(hasMore: false);

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
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(parserScrolledBeyondTopProvider.notifier).setBeyondTop(false);
    });
  }

  /// 释放输入和滚动控制器。
  @override
  void dispose() {
    _keywordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 构建搜索输入和结果列表。
  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.navigationRail;
    final horizontalPadding = mobile ? 16.0 : 24.0;
    // Shell 的解析分支回顶部入口只操作当前搜索列表。
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
                    title:
                        '搜索 ${widget.fallbackName?.trim().isNotEmpty == true ? widget.fallbackName!.trim() : 'UP'} 视频',
                    mediaCount: _state.total ?? _state.items.length,
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
                  child: _UpSearchInputBar(
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
        child: _UpEmptyState(
          icon: Icons.search_rounded,
          title: '搜索当前 UP 的视频',
          description: '输入标题、BV 或 AV 关键词后开始搜索。',
        ),
      );
    }
    return _VideoSliverSection(
      state: _state,
      mobile: mobile,
      emptyTitle: '没有搜到视频',
      emptyDescription: '换个关键词再试试，或确认这个 UP 是否公开了相关投稿。',
      onParse: widget.onParse,
      selecting: _selectionMode,
      selectedKeys: _selectedVideoKeys,
      selectionLocked: _batchQueuing,
      onToggleSelection: _toggleVideoSelection,
      allowDirectParse: true,
      detailNavigationOnly: true,
      onRetry: () => _loadSearch(refresh: true),
      onLoadMore: () => _loadSearch(refresh: false),
    );
  }

  /// 提交搜索关键词并从第一页重新加载。
  void _submitSearch() {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty || _batchQueuing) return;
    setState(() {
      // 新关键词会替换整组结果，分页游标和旧选择都必须重置。
      _submittedKeyword = keyword;
      _nextOffset = null;
      _selectionMode = false;
      _selectedVideoKeys.clear();
    });
    unawaited(_loadSearch(refresh: true));
  }

  /// 搜索列表滚动时同步回顶部入口并接近底部加载。
  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    ref
        .read(parserScrolledBeyondTopProvider.notifier)
        .setBeyondTop(position.pixels > 300);
    if (position.extentAfter > 360) return;
    unawaited(_loadSearch(refresh: false));
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
      // 搜索结果入队仍复用用户中心批量规则，保证任务去重和提示一致。
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

  /// 加载 UP 视频搜索结果。
  Future<void> _loadSearch({required bool refresh}) async {
    final keyword = _submittedKeyword.trim();
    if (keyword.isEmpty) return;
    final current = refresh ? const _VideoPagingState() : _state;
    if (current.loading ||
        current.loadingMore ||
        (!current.hasMore && !refresh)) {
      return;
    }
    setState(() {
      if (refresh) {
        // 刷新搜索会换掉分页游标和旧选择，避免不同结果集混选。
        _nextOffset = null;
        _selectionMode = false;
        _selectedVideoKeys.clear();
      }
      _state = current.copyWith(
        loading: current.items.isEmpty,
        loadingMore: current.items.isNotEmpty,
        loadingLabel: current.items.isEmpty ? '正在搜索视频…' : null,
        clearError: true,
        clearLoadingLabel: current.items.isNotEmpty,
      );
    });
    try {
      // 动态搜索使用 page + offset 双游标，offset 为空时表示第一页。
      final page = await ref
          .read(biliUserContentServiceProvider)
          .searchUpVideos(
            mid: widget.mid,
            keyword: keyword,
            page: refresh ? 1 : current.nextPage,
            offset: refresh ? null : _nextOffset,
            onResolveProgress: _updateSearchResolveProgress,
          );
      if (!mounted || keyword != _submittedKeyword.trim()) return;
      final nextItems = refresh
          ? page.items
          : <BiliUserVideoItem>[...current.items, ...page.items];
      setState(() {
        _nextOffset = page.nextOffset;
        _state = _VideoPagingState(
          items: nextItems,
          hasMore: page.nextPage != null,
          nextPage: page.nextPage ?? current.nextPage,
          total: page.total ?? current.total,
        );
      });
      AppDebugLog.user(
        'UP search loaded mid=${widget.mid} keyword=$keyword refresh=$refresh count=${page.items.length}',
      );
    } catch (error) {
      AppDebugLog.user(
        'UP search load failed mid=${widget.mid} keyword=$keyword error=$error',
      );
      if (!mounted) return;
      setState(() {
        _state = current.copyWith(
          loading: false,
          loadingMore: false,
          clearLoadingLabel: true,
          errorMessage: biliUserMessage(error, fallback: 'UP 视频搜索失败，请稍后重试。'),
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
}

/// UP 搜索页顶部输入条。
final class _UpSearchInputBar extends StatelessWidget {
  /// 创建紧凑搜索输入和提交按钮。
  const _UpSearchInputBar({
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

  /// 构建与解析页输入框接近的紧凑行高。
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
                hintText: '搜索标题、BV / AV',
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
          minWidth: 96,
        ),
      ],
    );
  }
}
