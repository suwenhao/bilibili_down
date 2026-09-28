import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/logging/app_debug_log.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_action_button.dart';
import '../../../core/widgets/app_icon_buttons.dart';
import '../../../core/widgets/app_list_footer.dart';
import '../../../core/widgets/app_selection_controls.dart';
import '../../../core/widgets/bili_content_list_widgets.dart';
import '../../../services/bilibili/bili_api_exception.dart';
import '../../../services/bilibili/bili_user_content_service.dart';
import '../../../services/bilibili/bilibili_providers.dart';
import '../../../services/bilibili/models/bili_auth_models.dart';
import '../../../services/image_cache/cover_cache_manager.dart';
import '../application/account_controller.dart';
import '../application/user_center_scroll_controller.dart';
import 'controllers/user_center_page_controller.dart';

part 'favorite_folder_detail_page.dart';
part 'favorite_search_page.dart';
part 'history_search_page.dart';
part 'models/user_content_state.dart';
part 'models/user_content_tab.dart';
part 'widgets/user_profile_header.dart';
part 'widgets/user_center_toolbars.dart';
part 'widgets/user_content_sections.dart';
part 'widgets/user_state_views.dart';

/// 登录后展示历史、稿件、收藏和最近点赞的用户中心。
final class UserCenterPage extends ConsumerStatefulWidget {
  /// 创建用户中心页面。
  const UserCenterPage({super.key, this.embedded = false});

  /// 是否嵌入桌面主内容区；嵌入时由外层侧栏提供返回和导航。
  final bool embedded;

  /// 创建本地页签、分页和收藏详情状态。
  @override
  ConsumerState<UserCenterPage> createState() => UserCenterPageViewState();
}

/// 管理用户中心页签、分页加载和收藏详情钻取状态。
final class UserCenterPageViewState extends ConsumerState<UserCenterPage> {
  /// 四个一级页签各自持有滚动控制器，切换页签时互不覆盖滚动位置。
  late final Map<UserContentTab, ScrollController> _tabScrollControllers;

  /// 当前选中的用户内容页签。
  UserContentTab _selectedTab = UserContentTab.history;

  /// 收藏夹详情路由是否覆盖在主列表上，用于屏蔽下层页面的回顶部监听。
  bool _favoriteRouteOpen = false;

  /// 历史记录分页状态。
  VideoPagingState _historyState = const VideoPagingState();

  /// 稿件分页状态。
  VideoPagingState _uploadsState = const VideoPagingState();

  /// 最近点赞分页状态；接口通常只有最近列表，不强行构造更多页。
  VideoPagingState _likesState = const VideoPagingState();

  /// 收藏夹列表状态。
  FavoriteFolderState _folderState = const FavoriteFolderState();

  /// 最近一次初始化的用户 UID，账号切换时重置页面缓存。
  int? _loadedMid;

  /// 当前是否进入视频列表选择模式。
  bool _selectionMode = false;

  /// 正在批量解析并写入待下载任务。
  bool _batchQueuing = false;

  /// 批量解析当前处理的一基序号。
  int _batchProgressCurrent = 0;

  /// 批量解析本轮需要处理的视频条目总数。
  int _batchProgressTotal = 0;

  /// 当前视频列表中被选中的稳定键。
  final Set<String> _selectedVideoKeys = <String>{};

  /// 初始化滚动监听。
  @override
  void initState() {
    super.initState();
    // 每个页签保持独立控制器和监听器，避免切换后沿用其他页签的偏移量。
    _tabScrollControllers = <UserContentTab, ScrollController>{
      for (final tab in UserContentTab.values) tab: ScrollController(),
    };
    for (final entry in _tabScrollControllers.entries) {
      // 监听器携带所属页签，只允许当前可见页签更新回顶状态和触发分页。
      entry.value.addListener(() => _handleTabScroll(entry.key));
    }
  }

  /// 释放滚动控制器。
  @override
  void dispose() {
    // 每个 ScrollController 都持有监听器和滚动位置，页面销毁时统一释放。
    for (final controller in _tabScrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// 返回当前可见页签的滚动控制器，供回顶和 Shell 状态同步使用。
  ScrollController get _activeScrollController =>
      _tabScrollControllers[_selectedTab]!;

  /// 构建响应式用户中心页面。
  @override
  Widget build(BuildContext context) {
    // 账号资料来自全局账号控制器，退出或过期后页面立即降级到登录提示。
    final account = ref.watch(accountControllerProvider);
    final profile = account.profile;
    // 手机端使用紧凑顶部结构，桌面端增加卡片宽度和双列列表。
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.navigationRail;
    // 首次进入或账号切换时启动当前用户数据加载。
    _ensureProfileLoaded(profile);
    // Shell 的“顶部”按钮发出递增信号后，用户中心滚动当前列表到顶部。
    ref.listen<int>(userCenterScrollTopRequestProvider, (
      int? previous,
      int next,
    ) {
      if (previous == next) return;
      // 详情路由打开时由详情页消费请求，不能同时改动下层主列表的保留位置。
      if (_favoriteRouteOpen) return;
      _scrollCurrentContentToTop();
    });
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: profile?.isLoggedIn == true
            ? _buildLoggedIn(
                context,
                profile!,
                mobile,
                embedded: widget.embedded,
              )
            : LoginRequiredView(
                checking: account.phase == AccountPhase.checking,
                embedded: widget.embedded,
                onBack: _leaveUserPage,
                onLogin: _openLoginDialog,
              ),
      ),
    );
  }

  /// 根据登录资料初始化当前账号的数据。
  void _ensureProfileLoaded(BiliLoginProfile? profile) {
    final mid = profile?.userId;
    if (profile?.isLoggedIn != true || mid == null) return;
    if (_loadedMid == mid) return;
    // 账号发生变化时清空旧用户的列表和收藏详情，避免串号显示。
    _loadedMid = mid;
    _historyState = const VideoPagingState();
    _uploadsState = const VideoPagingState();
    _likesState = const VideoPagingState();
    _folderState = const FavoriteFolderState();
    _selectionMode = false;
    _batchQueuing = false;
    _batchProgressCurrent = 0;
    _batchProgressTotal = 0;
    _selectedVideoKeys.clear();
    // 等待当前 build 完成后启动网络请求，避免构建期间 setState。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadCurrentTab(refresh: true);
    });
  }

  /// 构建已登录用户的个人资料和列表内容。
  Widget _buildLoggedIn(
    BuildContext context,
    BiliLoginProfile profile,
    bool mobile, {
    required bool embedded,
  }) {
    // 用户页内容保持最大宽度，避免桌面端列表跨屏过宽。
    final horizontalPadding = mobile ? 16.0 : 24.0;
    // 固定头部和滚动列表之间保留不可滚走的间距，避免列表滑到 tab 下方贴边。
    const fixedHeaderListGap = 14.0;
    // 页面控制器承接退出登录等跨组件动作，列表滚动状态仍由本 State 管理。
    final pageState = ref.watch(userCenterPageControllerProvider);
    return Column(
      children: <Widget>[
        if (!embedded) UserTopBar(mobile: mobile, onBack: _leaveUserPage),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      mobile ? 12 : 20,
                      horizontalPadding,
                      0,
                    ),
                    child: ProfileHero(
                      profile: profile,
                      mobile: mobile,
                      busy: _batchQueuing || pageState.loggingOut,
                      onLogout: _confirmLogout,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      14,
                      horizontalPadding,
                      0,
                    ),
                    child: UserToolbar(
                      selected: _selectedTab,
                      selecting: _selectionMode,
                      batchQueuing: _batchQueuing,
                      batchProgressCurrent: _batchProgressCurrent,
                      batchProgressTotal: _batchProgressTotal,
                      selectedCount: _selectedVideoKeys.length,
                      selectableCount: _currentSelectableItems.length,
                      mobile: mobile,
                      searchEnabled:
                          _selectedTab == UserContentTab.history ||
                          _selectedTab == UserContentTab.favorites,
                      onSearch: _openCurrentSearchPage,
                      onRefresh: mobile || _isTabBusy(_selectedTab)
                          ? null
                          : () => unawaited(_refreshTab(_selectedTab)),
                      onSelected: (value) {
                        if (_batchQueuing) return;
                        // 页签切换时清空选择，避免把上一页签的视频误用于当前批量操作。
                        setState(() {
                          _selectedTab = value;
                          _selectionMode = false;
                          _selectedVideoKeys.clear();
                        });
                        _loadTab(value, refresh: false);
                        _scheduleScrollFlagSync();
                      },
                      onToggleSelecting: _toggleSelectionMode,
                      onToggleAllSelection: _toggleAllSelection,
                      onBatchQueue: _selectedVideoKeys.isEmpty || _batchQueuing
                          ? null
                          : () => _queueSelectedVideos(context),
                    ),
                  ),
                  const SizedBox(height: fixedHeaderListGap),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedTab.index,
                      children: <Widget>[
                        for (final tab in UserContentTab.values)
                          _buildTabScrollView(
                            profile: profile,
                            mobile: mobile,
                            tab: tab,
                            horizontalPadding: horizontalPadding,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建单个页签的滚动容器，移动端额外支持系统下拉刷新手势。
  Widget _buildTabScrollView({
    required BiliLoginProfile profile,
    required bool mobile,
    required UserContentTab tab,
    required double horizontalPadding,
  }) {
    final scrollView = CustomScrollView(
      controller: _tabScrollControllers[tab],
      physics: mobile ? const AlwaysScrollableScrollPhysics() : null,
      slivers: <Widget>[
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          sliver: _buildTabContent(profile, mobile, tab),
        ),
        SliverToBoxAdapter(child: SizedBox(height: mobile ? 24 : 32)),
      ],
    );
    if (!mobile) return scrollView;
    return RefreshIndicator(
      onRefresh: () => _refreshTab(tab),
      child: scrollView,
    );
  }

  /// 按指定页签构建列表内容，供 IndexedStack 保持各页签自身状态。
  Widget _buildTabContent(
    BiliLoginProfile profile,
    bool mobile,
    UserContentTab tab,
  ) {
    final mid = profile.userId;
    if (mid == null) {
      return const UserEmptyState(
        icon: Icons.account_circle_outlined,
        title: '账号资料不完整',
        description: 'B 站没有返回 UID，请重新登录后再试。',
      );
    }
    return switch (tab) {
      UserContentTab.history => VideoSection(
        state: _historyState,
        mobile: mobile,
        emptyTitle: '暂无历史记录',
        emptyDescription: '这里只显示当前账号可读取的稿件视频历史。',
        onParse: _parseVideo,
        selecting: _selectionMode,
        selectedKeys: _selectedVideoKeys,
        selectionLocked: _batchQueuing,
        itemKeyOf: _videoIdentity,
        onToggleSelection: _toggleVideoSelection,
        onRetry: () => _loadHistory(mid: mid, refresh: true),
        onLoadMore: () => _loadHistory(mid: mid, refresh: false),
      ),
      UserContentTab.uploads => VideoSection(
        state: _uploadsState,
        mobile: mobile,
        emptyTitle: '暂无公开稿件',
        emptyDescription: '如果稿件被隐藏或账号没有公开投稿，这里会为空。',
        onParse: _parseVideo,
        selecting: _selectionMode,
        selectedKeys: _selectedVideoKeys,
        selectionLocked: _batchQueuing,
        itemKeyOf: _videoIdentity,
        onToggleSelection: _toggleVideoSelection,
        onRetry: () => _loadUploads(mid: mid, refresh: true),
        onLoadMore: () => _loadUploads(mid: mid, refresh: false),
      ),
      UserContentTab.favorites => _buildFavorites(mid, mobile),
      UserContentTab.likes => VideoSection(
        state: _likesState,
        mobile: mobile,
        emptyTitle: '暂无可见点赞',
        emptyDescription: 'B 站点赞列表受隐私和接口限制影响，这里只展示可读取的最近点赞。',
        onParse: _parseVideo,
        selecting: _selectionMode,
        selectedKeys: _selectedVideoKeys,
        selectionLocked: _batchQueuing,
        itemKeyOf: _videoIdentity,
        onToggleSelection: _toggleVideoSelection,
        onRetry: () => _loadLikes(mid: mid, refresh: true),
        onLoadMore: () => _loadLikes(mid: mid, refresh: false),
      ),
    };
  }

  /// 构建收藏夹列表。
  Widget _buildFavorites(int mid, bool mobile) {
    return FavoriteFolderSection(
      state: _folderState,
      mobile: mobile,
      emptyTitle: '暂无收藏夹',
      emptyDescription: '没有读取到公开收藏夹，或当前账号没有创建收藏夹。',
      onRetry: () => _loadFavoriteFolders(mid: mid, refresh: true),
      onOpen: _openFavoriteFolder,
    );
  }

  /// 处理指定页签滚动，仅当前可见页签可以更新 Shell 和触发分页。
  void _handleTabScroll(UserContentTab tab) {
    // IndexedStack 会让非当前页签保持挂载，必须阻止其滚动事件污染当前状态。
    if (tab != _selectedTab || _favoriteRouteOpen) return;
    final controller = _tabScrollControllers[tab]!;
    _syncScrollFlag(controller);
    _loadMoreNearBottom(tab, controller);
  }

  /// 指定页签滚动接近底部时加载下一页。
  void _loadMoreNearBottom(UserContentTab tab, ScrollController controller) {
    if (_batchQueuing) return;
    if (!controller.hasClients) return;
    final position = controller.position;
    // 距底部 360dp 提前加载，避免用户看到明显空档。
    if (position.extentAfter > 360) return;
    _loadTab(tab, refresh: false);
  }

  /// 同步当前滚动位置给外层 Shell，用于切换“个人/顶部”入口。
  void _syncScrollFlag(ScrollController controller) {
    if (!controller.hasClients) return;
    // 超过 300dp 才显示回顶部，避免轻微滚动时底栏文案频繁变化。
    final beyondTop = controller.offset > 300;
    final notifier = ref.read(userCenterScrolledBeyondTopProvider.notifier);
    notifier.setBeyondTop(beyondTop);
  }

  /// 等待层级切换完成后，把当前可见列表位置同步给 Shell。
  void _scheduleScrollFlagSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncScrollFlag(_activeScrollController);
    });
  }

  /// 响应底栏“顶部”入口，滚动当前用户中心列表到顶部。
  void _scrollCurrentContentToTop() {
    final controller = _activeScrollController;
    if (!controller.hasClients) return;
    unawaited(
      controller
          .animateTo(
            0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          )
          .then((_) {
            if (!mounted) return;
            _syncScrollFlag(controller);
          }),
    );
  }

  /// 加载当前页签对应的数据。
  void _loadCurrentTab({required bool refresh}) {
    _loadTab(_selectedTab, refresh: refresh);
  }

  /// 刷新指定页签，供桌面按钮和移动端下拉刷新共用。
  Future<void> _refreshTab(UserContentTab tab) async {
    final mid = _loadedMid;
    if (mid == null || _batchQueuing) return;
    switch (tab) {
      case UserContentTab.history:
        await _loadHistory(mid: mid, refresh: true);
      case UserContentTab.uploads:
        await _loadUploads(mid: mid, refresh: true);
      case UserContentTab.favorites:
        await _loadFavoriteFolders(mid: mid, refresh: true);
      case UserContentTab.likes:
        await _loadLikes(mid: mid, refresh: true);
    }
  }

  /// 加载指定页签的数据，避免异步回调依赖可能已经切换的当前页签。
  void _loadTab(UserContentTab tab, {required bool refresh}) {
    final mid = _loadedMid;
    if (mid == null) return;
    switch (tab) {
      case UserContentTab.history:
        unawaited(_loadHistory(mid: mid, refresh: refresh));
      case UserContentTab.uploads:
        unawaited(_loadUploads(mid: mid, refresh: refresh));
      case UserContentTab.favorites:
        unawaited(_loadFavoriteFolders(mid: mid, refresh: refresh));
      case UserContentTab.likes:
        unawaited(_loadLikes(mid: mid, refresh: refresh));
    }
  }

  /// 当前页签是否正在请求数据，刷新按钮据此进入禁用态。
  bool _isTabBusy(UserContentTab tab) {
    if (_batchQueuing) return true;
    return switch (tab) {
      UserContentTab.history =>
        _historyState.loading || _historyState.loadingMore,
      UserContentTab.uploads =>
        _uploadsState.loading || _uploadsState.loadingMore,
      UserContentTab.favorites => _folderState.loading,
      UserContentTab.likes => _likesState.loading || _likesState.loadingMore,
    };
  }

  /// 加载历史记录一页。
  Future<void> _loadHistory({required int mid, required bool refresh}) async {
    final current = refresh ? const VideoPagingState() : _historyState;
    if (current.loading ||
        current.loadingMore ||
        (!current.hasMore && !refresh)) {
      return;
    }
    setState(() {
      _historyState = current.copyWith(
        loading: current.items.isEmpty,
        loadingMore: current.items.isNotEmpty,
        clearError: true,
      );
    });
    try {
      // 历史接口使用 max/view_at 游标翻页，首次加载传默认零值。
      final cursor = current.historyCursor;
      final page = await ref
          .read(biliUserContentServiceProvider)
          .fetchHistory(
            max: refresh ? 0 : cursor?.max ?? 0,
            viewAt: refresh ? 0 : cursor?.viewAt ?? 0,
          );
      if (!mounted || _loadedMid != mid) return;
      final nextItems = refresh
          ? page.items
          : <BiliUserVideoItem>[...current.items, ...page.items];
      setState(() {
        _historyState = VideoPagingState(
          items: nextItems,
          hasMore:
              page.items.isNotEmpty &&
              page.historyCursor != null &&
              (page.historyCursor!.max != cursor?.max ||
                  page.historyCursor!.viewAt != cursor?.viewAt),
          historyCursor: page.historyCursor,
        );
      });
      AppDebugLog.user(
        'History loaded refresh=$refresh count=${page.items.length} total=${nextItems.length}',
      );
    } catch (error) {
      AppDebugLog.user('History load failed refresh=$refresh error=$error');
      if (!mounted) return;
      setState(() {
        _historyState = current.copyWith(
          loading: false,
          loadingMore: false,
          errorMessage: biliUserMessage(error, fallback: '历史记录加载失败，请稍后重试。'),
        );
      });
    }
  }

  /// 加载稿件列表一页。
  Future<void> _loadUploads({required int mid, required bool refresh}) async {
    final current = refresh ? const VideoPagingState() : _uploadsState;
    if (current.loading ||
        current.loadingMore ||
        (!current.hasMore && !refresh)) {
      return;
    }
    setState(() {
      _uploadsState = current.copyWith(
        loading: current.items.isEmpty,
        loadingMore: current.items.isNotEmpty,
        clearError: true,
      );
    });
    try {
      // 稿件接口使用 pn/ps 页码，下一页由本地状态维护。
      final page = await ref
          .read(biliUserContentServiceProvider)
          .fetchUploads(mid: mid, page: refresh ? 1 : current.nextPage);
      if (!mounted || _loadedMid != mid) return;
      final nextItems = refresh
          ? page.items
          : <BiliUserVideoItem>[...current.items, ...page.items];
      setState(() {
        _uploadsState = VideoPagingState(
          items: nextItems,
          hasMore: page.nextPage != null && page.items.isNotEmpty,
          nextPage: page.nextPage ?? current.nextPage,
        );
      });
      AppDebugLog.user(
        'Uploads loaded refresh=$refresh count=${page.items.length} total=${nextItems.length}',
      );
    } catch (error) {
      AppDebugLog.user('Uploads load failed refresh=$refresh error=$error');
      if (!mounted) return;
      setState(() {
        _uploadsState = current.copyWith(
          loading: false,
          loadingMore: false,
          errorMessage: biliUserMessage(error, fallback: '稿件加载失败，请稍后重试。'),
        );
      });
    }
  }

  /// 加载收藏夹列表。
  Future<void> _loadFavoriteFolders({
    required int mid,
    required bool refresh,
  }) async {
    if (_folderState.loading || (_folderState.items.isNotEmpty && !refresh)) {
      return;
    }
    setState(() {
      _folderState = _folderState.copyWith(loading: true, clearError: true);
    });
    try {
      // 收藏夹列表接口一次返回所有创建收藏夹。
      final folders = await ref
          .read(biliUserContentServiceProvider)
          .fetchFavoriteFolders(mid: mid);
      if (!mounted || _loadedMid != mid) return;
      setState(() {
        _folderState = FavoriteFolderState(items: folders);
      });
      AppDebugLog.user('Favorite folders loaded count=${folders.length}');
    } catch (error) {
      AppDebugLog.user('Favorite folders load failed error=$error');
      if (!mounted) return;
      setState(() {
        _folderState = _folderState.copyWith(
          loading: false,
          errorMessage: biliUserMessage(error, fallback: '收藏夹加载失败，请稍后重试。'),
        );
      });
    }
  }

  /// 加载最近点赞视频。
  Future<void> _loadLikes({required int mid, required bool refresh}) async {
    final current = refresh ? const VideoPagingState() : _likesState;
    if (current.loading ||
        current.loadingMore ||
        (!current.hasMore && !refresh)) {
      return;
    }
    setState(() {
      _likesState = current.copyWith(
        loading: current.items.isEmpty,
        loadingMore: current.items.isNotEmpty,
        clearError: true,
      );
    });
    try {
      // 最近点赞接口公开资料只保证最近列表，仍尝试 pn/ps；若服务端忽略页码，后续用去重结果收尾。
      final page = await ref
          .read(biliUserContentServiceProvider)
          .fetchLikedVideos(mid: mid, page: refresh ? 1 : current.nextPage);
      if (!mounted || _loadedMid != mid) return;
      final existingKeys = current.items.map(_videoIdentity).toSet();
      final loadedItems = refresh
          ? page.items
          : page.items
                .where((item) => existingKeys.add(_videoIdentity(item)))
                .toList(growable: false);
      final nextItems = refresh
          ? loadedItems
          : <BiliUserVideoItem>[...current.items, ...loadedItems];
      setState(() {
        _likesState = VideoPagingState(
          items: nextItems,
          hasMore: page.nextPage != null && loadedItems.isNotEmpty,
          nextPage: page.nextPage ?? current.nextPage,
        );
      });
      AppDebugLog.user(
        'Likes loaded refresh=$refresh count=${loadedItems.length} total=${nextItems.length}',
      );
    } catch (error) {
      AppDebugLog.user('Likes load failed refresh=$refresh error=$error');
      if (!mounted) return;
      setState(() {
        _likesState = current.copyWith(
          loading: false,
          loadingMore: false,
          hasMore: false,
          errorMessage: biliUserMessage(error, fallback: '点赞列表加载失败，请稍后重试。'),
        );
      });
    }
  }

  /// 生成跨页去重键，避免点赞接口忽略页码时重复追加同一批视频。
  String _videoIdentity(BiliUserVideoItem item) {
    final bvid = item.bvid?.trim();
    if (bvid != null && bvid.isNotEmpty) return 'bv:$bvid';
    final aid = item.aid;
    if (aid != null && aid > 0) return 'av:$aid';
    return 'title:${item.title}|${item.duration.inSeconds}';
  }

  /// 当前页签已经加载并可解析的视频条目。
  List<BiliUserVideoItem> get _currentSelectableItems {
    final items = switch (_selectedTab) {
      UserContentTab.history => _historyState.items,
      UserContentTab.uploads => _uploadsState.items,
      UserContentTab.favorites => const <BiliUserVideoItem>[],
      UserContentTab.likes => _likesState.items,
    };
    return items
        .where((BiliUserVideoItem item) => item.canQueueDirectly)
        .toList(growable: false);
  }

  /// 开启或关闭当前视频列表选择模式。
  void _toggleSelectionMode() {
    if (_batchQueuing) return;
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedVideoKeys.clear();
    });
  }

  /// 切换一个视频条目的选择状态。
  void _toggleVideoSelection(BiliUserVideoItem item) {
    if (_batchQueuing || !item.canQueueDirectly) return;
    final key = _videoIdentity(item);
    setState(() {
      // 已经选中则取消，否则加入当前页签的批量集合。
      if (!_selectedVideoKeys.remove(key)) _selectedVideoKeys.add(key);
    });
  }

  /// 在当前页签中全选或清空所有可解析视频。
  void _toggleAllSelection() {
    if (_batchQueuing) return;
    final keys = _currentSelectableItems.map(_videoIdentity).toSet();
    if (keys.isEmpty) return;
    final allSelected = keys.every(_selectedVideoKeys.contains);
    setState(() {
      // 全选状态下点击清空；未选或部分选择时点击补齐为全选。
      _selectedVideoKeys
        ..clear()
        ..addAll(allSelected ? const <String>{} : keys);
    });
  }

  /// 打开登录弹窗。
  void _openLoginDialog() {
    // 登录弹窗入口由用户模块控制器统一维护。
    ref
        .read(userCenterPageControllerProvider.notifier)
        .openLoginDialog(context);
  }

  /// 显示退出登录确认并执行账号清理。
  Future<void> _confirmLogout() async {
    // 控制器负责确认弹窗、账号清理和结果提示。
    await ref
        .read(userCenterPageControllerProvider.notifier)
        .confirmLogout(context);
  }

  /// 批量解析当前勾选的视频并直接写入待下载。
  Future<void> _queueSelectedVideos(BuildContext context) async {
    // 根据当前已加载列表提取稳定快照，防止异步期间滚动加载改变集合。
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
      // 控制器会先把解析结果留在内存，全部解析后再统一写库。
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
      // 成功入队后直接进入待下载页，方便用户继续确认清晰度或开始下载。
      pageController.openPendingTasks(context);
    }
  }

  /// 将收藏夹详情压入当前个人中心分支的 Navigator。
  Future<void> _openFavoriteFolder(BiliFavoriteFolder folder) async {
    // 详情页从顶部开始，因此先恢复底栏“个人”入口；后续滚动由详情页自行同步。
    ref.read(userCenterScrolledBeyondTopProvider.notifier).setBeyondTop(false);
    _favoriteRouteOpen = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext routeContext) {
            // 新路由覆盖在个人中心主列表之上，主列表实例和滚动位置会一直保留。
            return FavoriteFolderDetailPage(
              folder: folder,
              onParse: _parseVideo,
            );
          },
        ),
      );
    } finally {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          // 收藏详情路由完全退出后再恢复主列表监听，避免路由激活阶段同步触发布局更新。
          _favoriteRouteOpen = false;
          _scheduleScrollFlagSync();
        });
      }
    }
  }

  /// 根据当前页签打开对应的搜索子页。
  void _openCurrentSearchPage() {
    if (_batchQueuing) return;
    switch (_selectedTab) {
      case UserContentTab.history:
        unawaited(_openHistorySearchPage());
        return;
      case UserContentTab.favorites:
        unawaited(_openFavoriteSearchPage());
        return;
      case UserContentTab.uploads:
      case UserContentTab.likes:
        return;
    }
  }

  /// 将历史搜索页压入当前个人中心分支的 Navigator。
  Future<void> _openHistorySearchPage() async {
    if (_batchQueuing || _selectedTab != UserContentTab.history) return;
    ref.read(userCenterScrolledBeyondTopProvider.notifier).setBeyondTop(false);
    _favoriteRouteOpen = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext routeContext) {
            // 历史搜索是“我的”页面子页，复用本页解析入口和底栏状态。
            return HistorySearchPage(onParse: _parseVideo);
          },
        ),
      );
    } finally {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _favoriteRouteOpen = false;
          _scheduleScrollFlagSync();
        });
      }
    }
  }

  /// 将收藏搜索页压入当前个人中心分支的 Navigator。
  Future<void> _openFavoriteSearchPage() async {
    if (_batchQueuing || _selectedTab != UserContentTab.favorites) return;
    ref.read(userCenterScrolledBeyondTopProvider.notifier).setBeyondTop(false);
    _favoriteRouteOpen = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext routeContext) {
            // 收藏搜索是“我的”页面子页，搜索全部收藏资源而不是某个收藏夹。
            return FavoriteSearchPage(onParse: _parseVideo);
          },
        ),
      );
    } finally {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _favoriteRouteOpen = false;
          _scheduleScrollFlagSync();
        });
      }
    }
  }

  /// 离开用户中心。
  void _leaveUserPage() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/parse');
    }
  }

  /// 将用户列表视频送入解析页。
  void _parseVideo(BiliUserVideoItem item) {
    // 控制器负责不可解析提示、解析输入写入和路由跳转。
    ref
        .read(userCenterPageControllerProvider.notifier)
        .parseVideo(context, item);
  }
}
