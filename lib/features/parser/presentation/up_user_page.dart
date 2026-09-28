import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/logging/app_debug_log.dart';
import '../../../core/network/bili_network_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon_buttons.dart';
import '../../../core/widgets/app_list_footer.dart';
import '../../../core/widgets/app_action_button.dart';
import '../../../core/widgets/app_selection_controls.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/bili_content_list_widgets.dart';
import '../../../services/image_cache/cover_cache_manager.dart';
import '../../../services/bilibili/bili_api_exception.dart';
import '../../../services/bilibili/bili_user_content_service.dart';
import '../../../services/bilibili/bilibili_providers.dart';
import '../../user/presentation/controllers/user_center_page_controller.dart';
import '../application/parser_controller.dart';
import '../application/parser_scroll_controller.dart';

part 'models/up_user_page_models.dart';
part 'widgets/up_user_page_widgets.dart';
part 'up_video_collection_detail_page.dart';
part 'up_user_search_page.dart';
part 'utils/up_user_page_utils.dart';

/// 解析结果进入 UP 主页时携带的参数。
final class UpUserPageArguments {
  /// 创建 UP 主页参数。
  const UpUserPageArguments({required this.mid, this.name});

  /// UP 主 UID。
  final int mid;

  /// UP 主昵称，路由直达时可能缺失。
  final String? name;
}

/// 解析分支内的 UP 内容页。
final class UpUserPage extends ConsumerStatefulWidget {
  /// 创建指定 UP 主的二级页。
  const UpUserPage({super.key, required this.mid, this.name});

  /// UP 主 UID。
  final int mid;

  /// UP 主昵称。
  final String? name;

  /// 创建本地页签和分页状态。
  @override
  ConsumerState<UpUserPage> createState() => _UpUserPageState();
}

/// 管理 UP 页三个内容页签的加载和解析动作。
final class _UpUserPageState extends ConsumerState<UpUserPage> {
  /// 投稿列表滚动控制器。
  final ScrollController _uploadsController = ScrollController();

  /// 公开收藏列表滚动控制器。
  final ScrollController _favoritesController = ScrollController();

  /// 合集列表滚动控制器。
  final ScrollController _collectionsController = ScrollController();

  /// 投稿分页状态。
  _VideoPagingState _uploadsState = const _VideoPagingState(
    loading: true,
    loadingLabel: '正在读取视频列表…',
  );

  /// 公开收藏夹加载状态。
  _FolderState _favoriteState = const _FolderState();

  /// 合集分页状态。
  _CollectionPagingState _collectionState = const _CollectionPagingState();

  /// UP 主资料状态。
  _UpProfileState _profileState = const _UpProfileState(loading: true);

  /// 当前选中的 UP 内容页签。
  _UpContentTab _selectedTab = _UpContentTab.uploads;

  /// 当前视频列表是否处于选择模式。
  bool _selectionMode = false;

  /// 当前是否正在批量解析并写入待下载任务。
  bool _batchQueuing = false;

  /// 收藏夹或合集详情是否覆盖在 UP 根页上方。
  bool _detailRouteActive = false;

  /// 批量解析当前处理的一基序号。
  int _batchProgressCurrent = 0;

  /// 批量解析本轮需要处理的视频条目总数。
  int _batchProgressTotal = 0;

  /// 当前页签已选中的视频稳定键。
  final Set<String> _selectedVideoKeys = <String>{};

  /// 初始化页签监听和首个页签加载。
  @override
  void initState() {
    super.initState();
    _uploadsController.addListener(_handleUploadsScroll);
    _favoritesController.addListener(_handleFavoritesScroll);
    _collectionsController.addListener(_handleCollectionsScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(parserScrolledBeyondTopProvider.notifier).setBeyondTop(false);
      unawaited(_loadInitialUpContent());
    });
  }

  /// 释放页面持有的控制器。
  @override
  void dispose() {
    _uploadsController.dispose();
    _favoritesController.dispose();
    _collectionsController.dispose();
    super.dispose();
  }

  /// 构建 UP 页顶栏、页签和内容。
  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.navigationRail;
    final horizontalPadding = mobile ? 16.0 : 24.0;
    // Shell 的解析分支回顶部入口会滚动当前 UP 页签。
    ref.listen<int>(parserScrollTopRequestProvider, (int? previous, int next) {
      if (previous == next) return;
      if (_detailRouteActive) return;
      _scrollCurrentTabToTop();
    });
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              children: <Widget>[
                _UpProfileHero(
                  profile: _profileState.profile,
                  fallbackName: widget.name,
                  mid: widget.mid,
                  loading: _profileState.loading,
                  mobile: mobile,
                  onBack: _leavePage,
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    10,
                    horizontalPadding,
                    0,
                  ),
                  child: _UpToolbar(
                    selected: _selectedTab,
                    selecting: _selectionMode,
                    batchQueuing: _batchQueuing,
                    batchProgressCurrent: _batchProgressCurrent,
                    batchProgressTotal: _batchProgressTotal,
                    selectedCount: _selectedVideoKeys.length,
                    selectableCount: _currentSelectableItems.length,
                    mobile: mobile,
                    onSelected: _selectTab,
                    onRefresh: _refreshCurrentTab,
                    onSearch: _openSearchPage,
                    onToggleSelecting: _toggleSelectionMode,
                    onToggleAllSelection: _toggleAllSelection,
                    onBatchQueue: _selectedVideoKeys.isEmpty || _batchQueuing
                        ? null
                        : () => _queueSelectedVideos(context),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: IndexedStack(
                    index: _selectedTab.index,
                    children: <Widget>[
                      _buildUploadsTab(horizontalPadding, mobile),
                      _buildFavoritesTab(horizontalPadding, mobile),
                      _buildCollectionsTab(horizontalPadding, mobile),
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

  /// 按需加载切换后的页签。
  void _selectTab(_UpContentTab tab) {
    if (_batchQueuing) return;
    setState(() {
      _selectedTab = tab;
      _selectionMode = false;
      _selectedVideoKeys.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncActiveScrollTopState();
    });
    switch (tab) {
      case _UpContentTab.uploads:
        if (_uploadsState.items.isEmpty && !_uploadsState.loading) {
          unawaited(_loadUploads(refresh: true));
        }
      case _UpContentTab.favorites:
        if (!_favoriteState.requested && !_favoriteState.loading) {
          unawaited(_loadFavoriteFolders(refresh: true));
        }
      case _UpContentTab.collections:
        if (!_collectionState.requested && !_collectionState.loading) {
          unawaited(_loadCollections(refresh: true));
        }
    }
  }

  /// 刷新当前页签，并把分页恢复到第一页。
  Future<void> _refreshCurrentTab() async {
    if (_batchQueuing) return;
    setState(() {
      // 刷新会替换当前页签数据，旧选择必须清空以免误批量解析。
      _selectionMode = false;
      _selectedVideoKeys.clear();
    });
    switch (_selectedTab) {
      case _UpContentTab.uploads:
        await _loadUploads(refresh: true);
      case _UpContentTab.favorites:
        await _loadFavoriteFolders(refresh: true);
      case _UpContentTab.collections:
        await _loadCollections(refresh: true);
    }
  }

  /// 打开当前 UP 主的视频搜索子页。
  void _openSearchPage() {
    if (_batchQueuing) return;
    _detailRouteActive = true;
    final profileName = _profileState.profile?.name ?? widget.name;
    unawaited(
      Navigator.of(context)
          .push<void>(
            MaterialPageRoute<void>(
              builder: (BuildContext routeContext) {
                return _UpUserSearchPage(
                  mid: widget.mid,
                  fallbackName: profileName,
                  onParse: _parseVideo,
                );
              },
            ),
          )
          .whenComplete(() {
            _detailRouteActive = false;
            if (mounted) _syncActiveScrollTopState();
          }),
    );
  }

  /// 构建投稿页签。
  Widget _buildUploadsTab(double horizontalPadding, bool mobile) {
    final scrollView = CustomScrollView(
      controller: _uploadsController,
      physics: mobile ? const AlwaysScrollableScrollPhysics() : null,
      slivers: <Widget>[
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          sliver: _VideoSliverSection(
            state: _uploadsState,
            mobile: mobile,
            emptyTitle: '暂无公开投稿',
            emptyDescription: '如果稿件被隐藏或账号没有公开投稿，这里会为空。',
            onParse: _parseVideo,
            selecting: _selectionMode,
            selectedKeys: _selectedVideoKeys,
            selectionLocked: _batchQueuing,
            onToggleSelection: _toggleVideoSelection,
            allowDirectParse: true,
            detailNavigationOnly: true,
            onRetry: () => _loadUploads(refresh: true),
            onLoadMore: () => _loadUploads(refresh: false),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: mobile ? 24 : 32)),
      ],
    );
    if (!mobile) return scrollView;
    return RefreshIndicator(
      onRefresh: () => _loadUploads(refresh: true),
      child: scrollView,
    );
  }

  /// 构建公开收藏页签。
  Widget _buildFavoritesTab(double horizontalPadding, bool mobile) {
    final scrollView = CustomScrollView(
      controller: _favoritesController,
      physics: mobile ? const AlwaysScrollableScrollPhysics() : null,
      slivers: <Widget>[
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          sliver: _FavoriteFolderSliverSection(
            state: _favoriteState,
            mobile: mobile,
            onRetry: () => _loadFavoriteFolders(refresh: true),
            onOpen: _openFavoriteFolder,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: mobile ? 24 : 32)),
      ],
    );
    if (!mobile) return scrollView;
    return RefreshIndicator(
      onRefresh: () => _loadFavoriteFolders(refresh: true),
      child: scrollView,
    );
  }

  /// 构建合集页签。
  Widget _buildCollectionsTab(double horizontalPadding, bool mobile) {
    final scrollView = CustomScrollView(
      controller: _collectionsController,
      physics: mobile ? const AlwaysScrollableScrollPhysics() : null,
      slivers: <Widget>[
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          sliver: _CollectionSliverSection(
            state: _collectionState,
            mobile: mobile,
            onRetry: () => _loadCollections(refresh: true),
            onLoadMore: () => _loadCollections(refresh: false),
            onOpen: _openCollection,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: mobile ? 24 : 32)),
      ],
    );
    if (!mobile) return scrollView;
    return RefreshIndicator(
      onRefresh: () => _loadCollections(refresh: true),
      child: scrollView,
    );
  }

  /// 投稿滚动时同步回顶部状态并接近底部加载。
  void _handleUploadsScroll() {
    if (!_uploadsController.hasClients) return;
    _syncScrollTopState(_uploadsController);
    if (_uploadsController.position.extentAfter > 360) return;
    unawaited(_loadUploads(refresh: false));
  }

  /// 公开收藏滚动时同步回顶部状态。
  void _handleFavoritesScroll() {
    if (!_favoritesController.hasClients) return;
    _syncScrollTopState(_favoritesController);
  }

  /// 合集滚动时同步回顶部状态并接近底部加载。
  void _handleCollectionsScroll() {
    if (!_collectionsController.hasClients) return;
    _syncScrollTopState(_collectionsController);
    if (_collectionsController.position.extentAfter > 360) return;
    unawaited(_loadCollections(refresh: false));
  }

  /// 当前页签滚动控制器。
  ScrollController get _activeScrollController {
    return switch (_selectedTab) {
      _UpContentTab.uploads => _uploadsController,
      _UpContentTab.favorites => _favoritesController,
      _UpContentTab.collections => _collectionsController,
    };
  }

  /// 同步当前页签是否超过回顶部阈值。
  void _syncActiveScrollTopState() {
    final controller = _activeScrollController;
    if (!controller.hasClients) {
      ref.read(parserScrolledBeyondTopProvider.notifier).setBeyondTop(false);
      return;
    }
    _syncScrollTopState(controller);
  }

  /// 根据指定滚动控制器同步解析分支回顶部入口。
  void _syncScrollTopState(ScrollController controller) {
    ref
        .read(parserScrolledBeyondTopProvider.notifier)
        .setBeyondTop(controller.position.pixels > 300);
  }

  /// 响应 Shell 回顶部事件，滚动当前 UP 页签。
  void _scrollCurrentTabToTop() {
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
            ref
                .read(parserScrolledBeyondTopProvider.notifier)
                .setBeyondTop(false);
          }),
    );
  }

  /// 当前根页可批量选择的视频。
  List<BiliUserVideoItem> get _currentSelectableItems {
    final items = switch (_selectedTab) {
      _UpContentTab.uploads => _uploadsState.items,
      _UpContentTab.favorites => const <BiliUserVideoItem>[],
      _UpContentTab.collections => const <BiliUserVideoItem>[],
    };
    return items
        .where((BiliUserVideoItem item) => item.canQueueDirectly)
        .toList(growable: false);
  }

  /// 开启或关闭根页选择模式。
  void _toggleSelectionMode() {
    if (_batchQueuing) return;
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedVideoKeys.clear();
    });
  }

  /// 切换根页单个视频的选择状态。
  void _toggleVideoSelection(BiliUserVideoItem item) {
    if (_batchQueuing || !item.canQueueDirectly) return;
    final key = _videoIdentity(item);
    setState(() {
      // 已选中则移除，否则加入本轮批量集合。
      if (!_selectedVideoKeys.remove(key)) _selectedVideoKeys.add(key);
    });
  }

  /// 全选或清空根页当前视频列表。
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

  /// 批量解析根页已选视频并加入待下载。
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
      // 批量入队复用用户中心控制器，保持解析、去重和入队规则一致。
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

  /// 错峰加载 UP 首屏资料和投稿列表。
  Future<void> _loadInitialUpContent() async {
    // UP 资料和投稿接口都走空间域名，首屏错开发起能降低 412 风控概率。
    unawaited(_loadProfile());
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await _loadUploads(refresh: true);
  }

  /// 加载 UP 主头像、昵称和简介。
  Future<void> _loadProfile() async {
    if (_profileState.loading && _profileState.profile != null) return;
    setState(() {
      _profileState = _profileState.copyWith(loading: true, clearError: true);
    });
    try {
      // UP 资料用于顶部展示，不参与解析流程；失败时使用路由携带的名称兜底。
      final profile = await ref
          .read(biliUserContentServiceProvider)
          .fetchUpProfile(mid: widget.mid);
      if (!mounted) return;
      setState(() {
        _profileState = _UpProfileState(profile: profile);
      });
    } catch (error) {
      AppDebugLog.user('UP profile load failed mid=${widget.mid} error=$error');
      if (!mounted) return;
      setState(() {
        _profileState = _profileState.copyWith(
          loading: false,
          errorMessage: biliUserMessage(error, fallback: 'UP 资料加载失败。'),
        );
      });
    }
  }

  /// 加载 UP 投稿。
  Future<void> _loadUploads({required bool refresh}) async {
    final current = refresh ? const _VideoPagingState() : _uploadsState;
    if (current.loading ||
        current.loadingMore ||
        (!current.hasMore && !refresh)) {
      return;
    }
    setState(() {
      _uploadsState = current.copyWith(
        loading: current.items.isEmpty,
        loadingMore: current.items.isNotEmpty,
        loadingLabel: current.items.isEmpty ? '正在读取视频列表…' : null,
        clearError: true,
        clearLoadingLabel: current.items.isNotEmpty,
      );
    });
    try {
      // 投稿接口使用 UID 和页码加载，UP 页只读取公开稿件。
      final page = await ref
          .read(biliUserContentServiceProvider)
          .fetchUploads(
            mid: widget.mid,
            page: refresh ? 1 : current.nextPage,
            onResolveProgress: _updateUploadsResolveProgress,
          );
      if (!mounted) return;
      final nextItems = refresh
          ? page.items
          : <BiliUserVideoItem>[...current.items, ...page.items];
      setState(() {
        _uploadsState = _VideoPagingState(
          items: nextItems,
          hasMore: page.nextPage != null && page.items.isNotEmpty,
          nextPage: page.nextPage ?? current.nextPage,
        );
      });
      AppDebugLog.user(
        'UP uploads loaded mid=${widget.mid} refresh=$refresh count=${page.items.length}',
      );
    } catch (error) {
      AppDebugLog.user('UP uploads load failed mid=${widget.mid} error=$error');
      if (!mounted) return;
      setState(() {
        _uploadsState = current.copyWith(
          loading: false,
          loadingMore: false,
          clearLoadingLabel: true,
          errorMessage: biliUserMessage(error, fallback: 'UP 投稿加载失败，请稍后重试。'),
        );
      });
    }
  }

  /// 更新 UP 投稿首屏或追加分页时的分 P 预取进度。
  void _updateUploadsResolveProgress(int current, int total) {
    if (!mounted || total <= 0) return;
    setState(() {
      _uploadsState = _uploadsState.copyWith(
        loadingLabel: '正在解析中 $current/$total …',
      );
    });
  }

  /// 加载 UP 公开收藏夹。
  Future<void> _loadFavoriteFolders({required bool refresh}) async {
    if (_favoriteState.loading ||
        (_favoriteState.items.isNotEmpty && !refresh)) {
      return;
    }
    setState(() {
      _favoriteState = _favoriteState.copyWith(
        loading: true,
        requested: true,
        clearError: true,
      );
    });
    try {
      // 公开收藏只在 UP 主允许展示时返回，未公开时显示空态或接口提示。
      final folders = await ref
          .read(biliUserContentServiceProvider)
          .fetchFavoriteFolders(mid: widget.mid);
      if (!mounted) return;
      setState(() {
        _favoriteState = _FolderState(items: folders, requested: true);
      });
      AppDebugLog.user(
        'UP favorite folders loaded mid=${widget.mid} count=${folders.length}',
      );
    } catch (error) {
      AppDebugLog.user(
        'UP favorite folders load failed mid=${widget.mid} error=$error',
      );
      if (!mounted) return;
      setState(() {
        _favoriteState = _favoriteState.copyWith(
          loading: false,
          requested: true,
          errorMessage: biliUserMessage(
            error,
            fallback: 'UP 未公开收藏夹，或当前接口无法读取。',
          ),
        );
      });
    }
  }

  /// 加载 UP 合集。
  Future<void> _loadCollections({required bool refresh}) async {
    final current = refresh ? const _CollectionPagingState() : _collectionState;
    if (current.loading ||
        current.loadingMore ||
        (!current.hasMore && !refresh)) {
      return;
    }
    setState(() {
      _collectionState = current.copyWith(
        loading: current.items.isEmpty,
        loadingMore: current.items.isNotEmpty,
        requested: true,
        clearError: true,
      );
    });
    try {
      // 合集接口按 UP 主 UID 读取公开 UGC season 列表。
      final page = await ref
          .read(biliUserContentServiceProvider)
          .fetchCollections(
            mid: widget.mid,
            page: refresh ? 1 : current.nextPage,
          );
      if (!mounted) return;
      final nextItems = refresh
          ? page.items
          : <BiliUserCollection>[...current.items, ...page.items];
      setState(() {
        _collectionState = _CollectionPagingState(
          items: nextItems,
          requested: true,
          hasMore: page.nextPage != null && page.items.isNotEmpty,
          nextPage: page.nextPage ?? current.nextPage,
        );
      });
      AppDebugLog.user(
        'UP collections loaded mid=${widget.mid} refresh=$refresh count=${page.items.length}',
      );
    } catch (error) {
      AppDebugLog.user(
        'UP collections load failed mid=${widget.mid} error=$error',
      );
      if (!mounted) return;
      setState(() {
        _collectionState = current.copyWith(
          loading: false,
          loadingMore: false,
          requested: true,
          errorMessage: biliUserMessage(error, fallback: 'UP 合集加载失败，请稍后重试。'),
        );
      });
    }
  }

  /// 打开公开收藏夹详情。
  Future<void> _openFavoriteFolder(BiliFavoriteFolder folder) async {
    _detailRouteActive = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext routeContext) {
            return _UpVideoCollectionDetailPage(
              title: folder.title,
              mediaCount: folder.mediaCount,
              emptyTitle: '收藏夹暂无可解析视频',
              emptyDescription: '音频、合集等无法定位的内容不会作为普通视频展示。',
              onParse: _parseVideo,
              loader: (int page, onResolveProgress) => ref
                  .read(biliUserContentServiceProvider)
                  .fetchFavoriteVideos(
                    mediaId: folder.id,
                    page: page,
                    onResolveProgress: onResolveProgress,
                  ),
            );
          },
        ),
      );
    } finally {
      _detailRouteActive = false;
      if (mounted) _syncActiveScrollTopState();
    }
  }

  /// 打开 UP 合集详情。
  Future<void> _openCollection(BiliUserCollection collection) async {
    _detailRouteActive = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext routeContext) {
            return _UpVideoCollectionDetailPage(
              title: collection.title,
              mediaCount: collection.mediaCount,
              emptyTitle: '合集暂无可解析视频',
              emptyDescription: '如果合集为空或接口隐藏了稿件，这里会为空。',
              onParse: _parseVideo,
              loader: (int page, onResolveProgress) {
                final profileName = _profileState.profile?.name ?? widget.name;
                // 合集详情接口不带 UP 名，沿用当前 UP 资料补齐列表副标题。
                return ref
                    .read(biliUserContentServiceProvider)
                    .fetchCollectionVideos(
                      collectionId: collection.id,
                      collectionType: collection.type,
                      mid: widget.mid,
                      authorName: profileName,
                      page: page,
                      onResolveProgress: onResolveProgress,
                    );
              },
            );
          },
        ),
      );
    } finally {
      _detailRouteActive = false;
      if (mounted) _syncActiveScrollTopState();
    }
  }

  /// 将 UP 页视频送入解析页。
  void _parseVideo(BiliUserVideoItem item) {
    final input = item.parseInput;
    if (!item.canParse || input == null) {
      AppSnackBar.show(
        context,
        message: item.isUnavailable ? '这个视频已失效，不能解析。' : '这个条目缺少可解析的视频 ID。',
        type: AppSnackBarType.warning,
        position: AppSnackBarPosition.top,
      );
      return;
    }
    if (item.requiresDetailNavigation) {
      _openVideoPartDetail(item);
      return;
    }
    // 复用解析页控制器写入输入；这里来自 UP 二级页，必须 push 保留合集/收藏详情返回栈。
    final parser = ref.read(parserControllerProvider.notifier);
    parser.updateInput(input);
    unawaited(parser.parse(preferredCid: item.targetCid));
    unawaited(context.push<void>('/parse'));
  }

  /// 继续用同一个详情页展开某个投稿自己的分 P。
  void _openVideoPartDetail(BiliUserVideoItem item) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext routeContext) {
            return _UpVideoCollectionDetailPage(
              title: item.title,
              mediaCount: item.pageCount ?? 0,
              emptyTitle: '这个视频暂无可解析分 P',
              emptyDescription: '如果视频已失效或接口没有返回 pages，这里会为空。',
              onParse: _parseVideo,
              loader: (int page, onResolveProgress) async {
                // 当前 BV 的分 P 列表一次性返回；后续分页请求直接给空页。
                if (page > 1) {
                  return const BiliUserVideoPage(items: <BiliUserVideoItem>[]);
                }
                return ref
                    .read(biliUserContentServiceProvider)
                    .fetchVideoPages(item: item);
              },
            );
          },
        ),
      ),
    );
  }

  /// 返回解析页或上一级页面。
  void _leavePage() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/parse');
    }
  }
}
