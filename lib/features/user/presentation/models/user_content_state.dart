part of '../user_center_page.dart';

/// 视频列表分页加载状态。
final class VideoPagingState {
  /// 创建一组视频分页状态。
  const VideoPagingState({
    this.items = const <BiliUserVideoItem>[],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.nextPage = 1,
    this.total,
    this.historyCursor,
    this.errorMessage,
    this.loadingLabel,
  });

  /// 已经加载到页面中的视频条目。
  final List<BiliUserVideoItem> items;

  /// 是否正在加载第一页。
  final bool loading;

  /// 是否正在追加下一页。
  final bool loadingMore;

  /// 服务端是否还有更多数据。
  final bool hasMore;

  /// 页码式接口下一页页码。
  final int nextPage;

  /// 服务端返回的结果总数，接口不提供时为空。
  final int? total;

  /// 历史接口下一页游标。
  final BiliHistoryCursor? historyCursor;

  /// 失败时展示给用户的文案。
  final String? errorMessage;

  /// 加载阶段展示给用户的细分进度文案。
  final String? loadingLabel;

  /// 根据本次变更创建新的不可变状态。
  VideoPagingState copyWith({
    List<BiliUserVideoItem>? items,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    int? nextPage,
    int? total,
    BiliHistoryCursor? historyCursor,
    String? errorMessage,
    String? loadingLabel,
    bool clearError = false,
    bool clearLoadingLabel = false,
  }) {
    // 只复制页面真正需要变化的字段，避免异步加载覆盖旧数据。
    return VideoPagingState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextPage: nextPage ?? this.nextPage,
      total: total ?? this.total,
      historyCursor: historyCursor ?? this.historyCursor,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      loadingLabel: clearLoadingLabel
          ? null
          : loadingLabel ?? this.loadingLabel,
    );
  }
}

/// 收藏夹列表加载状态。
final class FavoriteFolderState {
  /// 创建收藏夹列表状态。
  const FavoriteFolderState({
    this.items = const <BiliFavoriteFolder>[],
    this.loading = false,
    this.errorMessage,
  });

  /// 已加载收藏夹。
  final List<BiliFavoriteFolder> items;

  /// 是否正在请求收藏夹列表。
  final bool loading;

  /// 失败时展示给用户的文案。
  final String? errorMessage;

  /// 根据本次变更创建新状态。
  FavoriteFolderState copyWith({
    List<BiliFavoriteFolder>? items,
    bool? loading,
    String? errorMessage,
    bool clearError = false,
  }) {
    // 收藏夹接口没有页码，只维护首屏状态即可。
    return FavoriteFolderState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
