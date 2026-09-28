part of 'user_center_page.dart';

/// 当前账号观看历史搜索子页。
final class HistorySearchPage extends ConsumerStatefulWidget {
  /// 创建我的历史搜索页。
  const HistorySearchPage({super.key, required this.onParse});

  /// 点击视频时复用用户中心解析逻辑。
  final ValueChanged<BiliUserVideoItem> onParse;

  /// 创建搜索页状态。
  @override
  ConsumerState<HistorySearchPage> createState() => _HistorySearchPageState();
}

/// 管理观看历史搜索、筛选、选择和批量下载状态。
final class _HistorySearchPageState extends ConsumerState<HistorySearchPage> {
  /// 搜索输入框控制器。
  final TextEditingController _keywordController = TextEditingController();

  /// 搜索结果列表滚动控制器。
  late final ScrollController _scrollController;

  /// 当前已经提交给接口的关键词。
  String _submittedKeyword = '';

  /// 当前时间筛选条件。
  BiliHistorySearchTimeRange _timeRange = BiliHistorySearchTimeRange.all;

  /// 当前时长筛选条件。
  BiliHistorySearchDurationRange _durationRange =
      BiliHistorySearchDurationRange.all;

  /// 当前设备筛选条件。
  BiliHistorySearchDevice _device = BiliHistorySearchDevice.all;

  /// 筛选面板展开状态；为空时按当前布局使用默认值。
  bool? _filtersExpandedOverride;

  /// 搜索结果分页状态。
  VideoPagingState _state = const VideoPagingState();

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

  /// 请求序号用于丢弃筛选切换后的旧响应。
  int _requestRevision = 0;

  /// 初始化滚动和首次搜索。
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      onAttach: (ScrollPosition position) {
        // 搜索页恢复滚动位置或首次挂载后，需要同步手机底栏和桌面悬浮回顶按钮。
        _scheduleScrollTopStateSync();
      },
    );
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(userCenterScrolledBeyondTopProvider.notifier)
          .setBeyondTop(false);
      unawaited(_loadSearch(refresh: true));
    });
  }

  /// 释放输入和滚动控制器。
  @override
  void dispose() {
    _keywordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 构建搜索栏、筛选条件和结果列表。
  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.navigationRail;
    final horizontalPadding = mobile ? 16.0 : 24.0;
    final hasQueueableSelection = _selectedItems().any(
      (BiliUserVideoItem item) => item.canQueueDirectly,
    );
    final filtersExpanded = _filtersExpandedFor(mobile);
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
                    mobile ? 8 : 12,
                    horizontalPadding,
                    0,
                  ),
                  child: _HistorySearchHeader(
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
                  child: _HistorySearchInputBar(
                    controller: _keywordController,
                    enabled: !_busy,
                    loading: _state.loading,
                    onSubmitted: _submitSearch,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    10,
                    horizontalPadding,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _HistorySearchFilterHeader(
                        expanded: filtersExpanded,
                        enabled: !_busy,
                        summary: _filterSummary,
                        onToggle: () => _toggleFiltersExpanded(mobile),
                      ),
                      if (filtersExpanded) ...<Widget>[
                        SizedBox(height: mobile ? 8 : 10),
                        _HistorySearchFilterPanel(
                          mobile: mobile,
                          enabled: !_busy,
                          timeRange: _timeRange,
                          durationRange: _durationRange,
                          device: _device,
                          onTimeChanged: _changeTimeRange,
                          onDurationChanged: _changeDurationRange,
                          onDeviceChanged: _changeDevice,
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    10,
                    horizontalPadding,
                    0,
                  ),
                  child: _HistorySearchActions(
                    selecting: _selectionMode,
                    busy: _busy,
                    batchQueuing: _batchQueuing,
                    batchProgressCurrent: _batchProgressCurrent,
                    batchProgressTotal: _batchProgressTotal,
                    selectedCount: _selectedVideoKeys.length,
                    selectableCount: _currentSelectableItems.length,
                    mobile: mobile,
                    onToggleSelecting: _toggleSelectionMode,
                    onToggleAllSelection: _toggleAllSelection,
                    onBatchQueue: !hasQueueableSelection || _batchQueuing
                        ? null
                        : () => _queueSelectedVideos(context),
                  ),
                ),
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

  /// 当前是否有会改变列表或选择结果的动作在运行。
  bool get _busy => _batchQueuing;

  /// 当前布局下筛选面板是否展开，手机默认收起，桌面默认展开。
  bool _filtersExpandedFor(bool mobile) {
    return _filtersExpandedOverride ?? !mobile;
  }

  /// 用户手动展开或收起筛选面板。
  void _toggleFiltersExpanded(bool mobile) {
    if (_busy) return;
    setState(() {
      _filtersExpandedOverride = !_filtersExpandedFor(mobile);
    });
  }

  /// 手机端滚动结果时自动收起筛选，减少列表可视区域占用。
  void _collapseMobileFiltersOnScroll() {
    if (!mounted) return;
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.navigationRail;
    if (!mobile || !_filtersExpandedFor(mobile)) return;
    setState(() {
      _filtersExpandedOverride = false;
    });
  }

  /// 生成折叠状态下展示的筛选摘要。
  String get _filterSummary {
    return '${_durationRangeLabel(_durationRange)} · '
        '${_timeRangeLabel(_timeRange)} · '
        '${_deviceLabel(_device)}';
  }

  /// 构建搜索结果滚动容器，移动端支持下拉重新搜索。
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
          sliver: VideoSection(
            state: _state,
            mobile: mobile,
            emptyTitle: '没有匹配的历史记录',
            emptyDescription: '换个关键词或筛选条件再试。',
            onParse: widget.onParse,
            selecting: _selectionMode,
            selectedKeys: _selectedVideoKeys,
            selectionLocked: _busy,
            itemKeyOf: _videoIdentity,
            onToggleSelection: _toggleVideoSelection,
            canSelectItem: (BiliUserVideoItem item) => item.canQueueDirectly,
            onRetry: () => _loadSearch(refresh: true),
            onLoadMore: () => _loadSearch(refresh: false),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: mobile ? 24 : 32)),
      ],
    );
    if (!mobile) return scrollView;
    return RefreshIndicator(
      onRefresh: () => _loadSearch(refresh: true),
      child: scrollView,
    );
  }

  /// 提交输入框关键词并重新搜索。
  void _submitSearch() {
    if (_busy) return;
    setState(() {
      // 新关键词代表新的结果集，必须清空旧选择和页码。
      _submittedKeyword = _keywordController.text.trim();
      _selectionMode = false;
      _selectedVideoKeys.clear();
    });
    unawaited(_loadSearch(refresh: true));
  }

  /// 切换时间筛选后重新搜索。
  void _changeTimeRange(BiliHistorySearchTimeRange value) {
    if (_busy || value == _timeRange) return;
    setState(() {
      _timeRange = value;
      _selectionMode = false;
      _selectedVideoKeys.clear();
    });
    unawaited(_loadSearch(refresh: true));
  }

  /// 切换时长筛选后重新搜索。
  void _changeDurationRange(BiliHistorySearchDurationRange value) {
    if (_busy || value == _durationRange) return;
    setState(() {
      _durationRange = value;
      _selectionMode = false;
      _selectedVideoKeys.clear();
    });
    unawaited(_loadSearch(refresh: true));
  }

  /// 切换设备筛选后重新搜索。
  void _changeDevice(BiliHistorySearchDevice value) {
    if (_busy || value == _device) return;
    setState(() {
      _device = value;
      _selectionMode = false;
      _selectedVideoKeys.clear();
    });
    unawaited(_loadSearch(refresh: true));
  }

  /// 搜索列表滚动时同步回顶部入口并接近底部加载。
  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _collapseMobileFiltersOnScroll();
    _syncScrollTopState();
    if (position.extentAfter > 360) return;
    unawaited(_loadSearch(refresh: false));
  }

  /// 同步当前搜索页是否需要显示回顶部入口。
  void _syncScrollTopState() {
    final beyondTop =
        _scrollController.hasClients && _scrollController.offset > 300;
    ref
        .read(userCenterScrolledBeyondTopProvider.notifier)
        .setBeyondTop(beyondTop);
  }

  /// 等待列表挂载或数据重建完成后同步回顶部状态。
  void _scheduleScrollTopStateSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncScrollTopState();
    });
  }

  /// 响应 Shell 回顶部事件。
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

  /// 当前搜索结果可批量选择的视频。
  List<BiliUserVideoItem> get _currentSelectableItems {
    return _state.items
        .where((BiliUserVideoItem item) => item.canQueueDirectly)
        .toList(growable: false);
  }

  /// 开启或关闭搜索结果选择模式。
  void _toggleSelectionMode() {
    if (_busy) return;
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedVideoKeys.clear();
    });
  }

  /// 切换搜索结果单个视频选择状态。
  void _toggleVideoSelection(BiliUserVideoItem item) {
    if (_busy || !item.canQueueDirectly) return;
    final key = _videoIdentity(item);
    setState(() {
      // 已经选中则取消，否则加入搜索页批量集合。
      if (!_selectedVideoKeys.remove(key)) _selectedVideoKeys.add(key);
    });
  }

  /// 全选或清空搜索结果当前可解析视频。
  void _toggleAllSelection() {
    if (_busy) return;
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
    final selectedItems = _selectedItems()
        .where((BiliUserVideoItem item) => item.canQueueDirectly)
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
      // 历史搜索页入队复用用户中心批量规则，保证解析和去重一致。
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

  /// 返回当前勾选的视频快照。
  List<BiliUserVideoItem> _selectedItems() {
    return _currentSelectableItems
        .where(
          (BiliUserVideoItem item) =>
              _selectedVideoKeys.contains(_videoIdentity(item)),
        )
        .toList(growable: false);
  }

  /// 时间筛选值对应的页面文案。
  String _timeRangeLabel(BiliHistorySearchTimeRange value) {
    return switch (value) {
      BiliHistorySearchTimeRange.all => '全部时间',
      BiliHistorySearchTimeRange.today => '今天',
      BiliHistorySearchTimeRange.yesterday => '昨天',
      BiliHistorySearchTimeRange.week => '近一周',
    };
  }

  /// 时长筛选值对应的页面文案。
  String _durationRangeLabel(BiliHistorySearchDurationRange value) {
    return switch (value) {
      BiliHistorySearchDurationRange.all => '全部时长',
      BiliHistorySearchDurationRange.underTenMinutes => '10分钟以下',
      BiliHistorySearchDurationRange.tenToThirtyMinutes => '10-30分钟',
      BiliHistorySearchDurationRange.thirtyToSixtyMinutes => '30-60分钟',
      BiliHistorySearchDurationRange.overSixtyMinutes => '60分钟以上',
    };
  }

  /// 设备筛选值对应的页面文案。
  String _deviceLabel(BiliHistorySearchDevice value) {
    return switch (value) {
      BiliHistorySearchDevice.all => '全部设备',
      BiliHistorySearchDevice.pc => 'PC',
      BiliHistorySearchDevice.phone => '手机',
      BiliHistorySearchDevice.tablet => '平板',
      BiliHistorySearchDevice.tv => 'TV',
    };
  }

  /// 加载历史搜索结果。
  Future<void> _loadSearch({required bool refresh}) async {
    final current = refresh ? const VideoPagingState() : _state;
    if (current.loading ||
        current.loadingMore ||
        (!current.hasMore && !refresh) ||
        _busy) {
      return;
    }
    final revision = ++_requestRevision;
    final keyword = _submittedKeyword;
    final timeRange = _timeRange;
    final durationRange = _durationRange;
    final device = _device;
    setState(() {
      if (refresh) {
        // 刷新会替换完整结果集，旧选择不能继续保留。
        _selectionMode = false;
        _selectedVideoKeys.clear();
      }
      _state = current.copyWith(
        loading: current.items.isEmpty,
        loadingMore: current.items.isNotEmpty,
        loadingLabel: current.items.isEmpty ? '正在搜索历史…' : null,
        clearError: true,
        clearLoadingLabel: current.items.isNotEmpty,
      );
    });
    try {
      final page = await ref
          .read(biliUserContentServiceProvider)
          .searchHistoryVideos(
            keyword: keyword,
            timeRange: timeRange,
            durationRange: durationRange,
            device: device,
            page: refresh ? 1 : current.nextPage,
          );
      if (!mounted || revision != _requestRevision) return;
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
        'History search loaded keyword=$keyword refresh=$refresh count=${page.items.length}',
      );
    } catch (error) {
      AppDebugLog.user('History search failed keyword=$keyword error=$error');
      if (!mounted || revision != _requestRevision) return;
      setState(() {
        _state = current.copyWith(
          loading: false,
          loadingMore: false,
          clearLoadingLabel: true,
          errorMessage: biliUserMessage(error, fallback: '历史搜索失败，请稍后重试。'),
        );
      });
    }
  }

  /// 生成跨页去重和选择用稳定键。
  String _videoIdentity(BiliUserVideoItem item) {
    final historyKey = item.historyKey?.trim();
    if (historyKey != null && historyKey.isNotEmpty) {
      return 'history:$historyKey';
    }
    final bvid = item.bvid?.trim();
    if (bvid != null && bvid.isNotEmpty) return 'bv:$bvid';
    final aid = item.aid;
    if (aid != null && aid > 0) return 'av:$aid';
    return 'title:${item.title}|${item.duration.inSeconds}';
  }
}

/// 历史搜索页顶部标题栏。
final class _HistorySearchHeader extends StatelessWidget {
  /// 创建返回按钮、标题和结果数量。
  const _HistorySearchHeader({required this.count, required this.onBack});

  /// 当前结果数量或服务端总数。
  final int count;

  /// 返回我的页面回调。
  final VoidCallback onBack;

  /// 构建固定高度顶部栏。
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: <Widget>[
          AppCircleIconButton(
            onPressed: onBack,
            tooltip: '返回我的页面',
            dimension: 36,
            iconSize: 21,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '历史搜索',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text(
            '$count 条',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 历史搜索输入栏。
final class _HistorySearchInputBar extends StatelessWidget {
  /// 创建搜索输入框和提交按钮。
  const _HistorySearchInputBar({
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

  /// 构建紧凑输入栏。
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
                hintText: '搜索历史标题、UP、BV / AV',
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

/// 历史搜索筛选折叠栏。
final class _HistorySearchFilterHeader extends StatelessWidget {
  /// 创建筛选摘要和展开收起按钮。
  const _HistorySearchFilterHeader({
    required this.expanded,
    required this.enabled,
    required this.summary,
    required this.onToggle,
  });

  /// 筛选面板当前是否展开。
  final bool expanded;

  /// 是否允许展开收起。
  final bool enabled;

  /// 当前筛选条件摘要。
  final String summary;

  /// 展开或收起筛选面板。
  final VoidCallback onToggle;

  /// 构建单行筛选摘要，避免手机端占用过多首屏空间。
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              Icon(
                Icons.tune_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        AppActionButton(
          variant: AppActionButtonVariant.outlined,
          onPressed: enabled ? onToggle : null,
          icon: expanded
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
          label: expanded ? '收起' : '筛选',
          minWidth: 82,
        ),
      ],
    );
  }
}

/// 历史搜索筛选面板。
final class _HistorySearchFilterPanel extends StatelessWidget {
  /// 创建时间、时长和设备筛选。
  const _HistorySearchFilterPanel({
    required this.mobile,
    required this.enabled,
    required this.timeRange,
    required this.durationRange,
    required this.device,
    required this.onTimeChanged,
    required this.onDurationChanged,
    required this.onDeviceChanged,
  });

  /// 是否使用移动端紧凑布局。
  final bool mobile;

  /// 筛选项是否可点击。
  final bool enabled;

  /// 当前时间范围。
  final BiliHistorySearchTimeRange timeRange;

  /// 当前时长范围。
  final BiliHistorySearchDurationRange durationRange;

  /// 当前设备来源。
  final BiliHistorySearchDevice device;

  /// 时间范围变更回调。
  final ValueChanged<BiliHistorySearchTimeRange> onTimeChanged;

  /// 时长范围变更回调。
  final ValueChanged<BiliHistorySearchDurationRange> onDurationChanged;

  /// 设备来源变更回调。
  final ValueChanged<BiliHistorySearchDevice> onDeviceChanged;

  /// 构建无卡片包裹的筛选行。
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _HistorySearchFilterRow<BiliHistorySearchDurationRange>(
          label: '时长',
          enabled: enabled,
          value: durationRange,
          options:
              const <
                _HistorySearchFilterOption<BiliHistorySearchDurationRange>
              >[
                _HistorySearchFilterOption(
                  value: BiliHistorySearchDurationRange.all,
                  label: '全部',
                ),
                _HistorySearchFilterOption(
                  value: BiliHistorySearchDurationRange.underTenMinutes,
                  label: '10分钟以下',
                ),
                _HistorySearchFilterOption(
                  value: BiliHistorySearchDurationRange.tenToThirtyMinutes,
                  label: '10-30分钟',
                ),
                _HistorySearchFilterOption(
                  value: BiliHistorySearchDurationRange.thirtyToSixtyMinutes,
                  label: '30-60分钟',
                ),
                _HistorySearchFilterOption(
                  value: BiliHistorySearchDurationRange.overSixtyMinutes,
                  label: '60分钟以上',
                ),
              ],
          onChanged: onDurationChanged,
        ),
        SizedBox(height: mobile ? 8 : 10),
        _HistorySearchFilterRow<BiliHistorySearchTimeRange>(
          label: '时间',
          enabled: enabled,
          value: timeRange,
          options:
              const <_HistorySearchFilterOption<BiliHistorySearchTimeRange>>[
                _HistorySearchFilterOption(
                  value: BiliHistorySearchTimeRange.all,
                  label: '全部',
                ),
                _HistorySearchFilterOption(
                  value: BiliHistorySearchTimeRange.today,
                  label: '今天',
                ),
                _HistorySearchFilterOption(
                  value: BiliHistorySearchTimeRange.yesterday,
                  label: '昨天',
                ),
                _HistorySearchFilterOption(
                  value: BiliHistorySearchTimeRange.week,
                  label: '近一周',
                ),
              ],
          onChanged: onTimeChanged,
        ),
        SizedBox(height: mobile ? 8 : 10),
        _HistorySearchFilterRow<BiliHistorySearchDevice>(
          label: '设备',
          enabled: enabled,
          value: device,
          options: const <_HistorySearchFilterOption<BiliHistorySearchDevice>>[
            _HistorySearchFilterOption(
              value: BiliHistorySearchDevice.all,
              label: '全部',
            ),
            _HistorySearchFilterOption(
              value: BiliHistorySearchDevice.pc,
              label: 'PC',
            ),
            _HistorySearchFilterOption(
              value: BiliHistorySearchDevice.phone,
              label: '手机',
            ),
            _HistorySearchFilterOption(
              value: BiliHistorySearchDevice.tablet,
              label: '平板',
            ),
            _HistorySearchFilterOption(
              value: BiliHistorySearchDevice.tv,
              label: 'TV',
            ),
          ],
          onChanged: onDeviceChanged,
        ),
      ],
    );
  }
}

/// 历史搜索筛选项配置。
final class _HistorySearchFilterOption<T> {
  /// 创建单个筛选项。
  const _HistorySearchFilterOption({required this.value, required this.label});

  /// 筛选值。
  final T value;

  /// 页面展示文案。
  final String label;
}

/// 历史搜索单行筛选。
final class _HistorySearchFilterRow<T> extends StatelessWidget {
  /// 创建带标题和一组 chip 的筛选行。
  const _HistorySearchFilterRow({
    required this.label,
    required this.enabled,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  /// 筛选行标题。
  final String label;

  /// 是否允许点击。
  final bool enabled;

  /// 当前选中的值。
  final T value;

  /// 可选择项集合。
  final List<_HistorySearchFilterOption<T>> options;

  /// 用户选择后的回调。
  final ValueChanged<T> onChanged;

  /// 构建可自动换行的筛选行。
  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 44,
          height: 36,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(label, style: labelStyle),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map((option) {
                  // 每个 chip 只表达当前筛选状态，实际请求由父级统一触发。
                  return AppSelectionChip(
                    selected: option.value == value,
                    label: option.label,
                    enabled: enabled,
                    onSelected: (_) => onChanged(option.value),
                  );
                })
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

/// 历史搜索操作按钮组。
final class _HistorySearchActions extends StatelessWidget {
  /// 创建批量解析、选择和全选操作。
  const _HistorySearchActions({
    required this.selecting,
    required this.busy,
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

  /// 当前是否处于选择模式。
  final bool selecting;

  /// 是否有动作正在运行。
  final bool busy;

  /// 是否正在批量入队。
  final bool batchQueuing;

  /// 批量解析当前处理的一基序号。
  final int batchProgressCurrent;

  /// 批量解析本轮需要处理的视频条目总数。
  final int batchProgressTotal;

  /// 当前选中数量。
  final int selectedCount;

  /// 当前可选择视频数量。
  final int selectableCount;

  /// 是否使用移动端布局。
  final bool mobile;

  /// 开启或退出选择模式。
  final VoidCallback onToggleSelecting;

  /// 全选或清空当前结果。
  final VoidCallback onToggleAllSelection;

  /// 批量解析入队回调。
  final VoidCallback? onBatchQueue;

  /// 构建操作按钮。
  @override
  Widget build(BuildContext context) {
    final canSelect = selectableCount > 0 && !busy;
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
    final selectionSummary = selecting
        ? SelectionSummary(
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
          if (selectionSummary != null) ...<Widget>[
            const SizedBox(height: 6),
            selectionSummary,
          ],
        ],
      );
    }
    return Row(
      children: <Widget>[
        batchButton,
        const SizedBox(width: 8),
        selectButton,
        if (selectionSummary != null) ...<Widget>[
          const SizedBox(width: 12),
          selectionSummary,
        ],
      ],
    );
  }
}
