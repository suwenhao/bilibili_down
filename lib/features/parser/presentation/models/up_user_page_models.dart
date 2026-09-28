part of '../up_user_page.dart';

/// UP 页面内容页签。
enum _UpContentTab {
  /// UP 投稿视频。
  uploads,

  /// UP 公开收藏夹。
  favorites,

  /// UP 公开合集。
  collections,
}

/// UP 主资料加载状态。
final class _UpProfileState {
  /// 创建资料加载状态。
  const _UpProfileState({
    this.profile,
    this.loading = false,
    this.errorMessage,
  });

  /// 已加载的资料。
  final BiliUpProfile? profile;

  /// 是否正在请求资料。
  final bool loading;

  /// 请求失败时的错误文案。
  final String? errorMessage;

  /// 创建局部更新后的新状态。
  _UpProfileState copyWith({
    BiliUpProfile? profile,
    bool? loading,
    String? errorMessage,
    bool clearError = false,
  }) {
    // 资料接口失败时保留旧资料，避免刷新或重试期间头部闪烁。
    return _UpProfileState(
      profile: profile ?? this.profile,
      loading: loading ?? this.loading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

/// 视频列表分页状态。
final class _VideoPagingState {
  /// 创建视频分页状态。
  const _VideoPagingState({
    this.items = const <BiliUserVideoItem>[],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.nextPage = 1,
    this.total,
    this.errorMessage,
    this.loadingLabel,
  });

  /// 已加载的视频条目。
  final List<BiliUserVideoItem> items;

  /// 是否正在加载首屏。
  final bool loading;

  /// 是否正在追加下一页。
  final bool loadingMore;

  /// 是否还有下一页。
  final bool hasMore;

  /// 下一页页码。
  final int nextPage;

  /// 服务端或解析结果返回的总条目数。
  final int? total;

  /// 错误文案。
  final String? errorMessage;

  /// 首屏加载时展示的进度文案。
  final String? loadingLabel;

  /// 创建局部变更后的新状态。
  _VideoPagingState copyWith({
    List<BiliUserVideoItem>? items,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    int? nextPage,
    int? total,
    String? errorMessage,
    String? loadingLabel,
    bool clearError = false,
    bool clearLoadingLabel = false,
  }) {
    // 只替换本次变化的字段，避免异步加载覆盖旧列表。
    return _VideoPagingState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextPage: nextPage ?? this.nextPage,
      total: total ?? this.total,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      loadingLabel: clearLoadingLabel
          ? null
          : loadingLabel ?? this.loadingLabel,
    );
  }
}

/// 收藏夹列表状态。
final class _FolderState {
  /// 创建收藏夹列表状态。
  const _FolderState({
    this.items = const <BiliFavoriteFolder>[],
    this.loading = false,
    this.requested = false,
    this.errorMessage,
  });

  /// 已加载收藏夹。
  final List<BiliFavoriteFolder> items;

  /// 是否正在加载。
  final bool loading;

  /// 是否已经发起过收藏夹请求，用于区分首次未加载和真实空列表。
  final bool requested;

  /// 错误文案。
  final String? errorMessage;

  /// 创建局部变更后的新状态。
  _FolderState copyWith({
    List<BiliFavoriteFolder>? items,
    bool? loading,
    bool? requested,
    String? errorMessage,
    bool clearError = false,
  }) {
    // 收藏夹列表无分页，只维护首屏状态。
    return _FolderState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      requested: requested ?? this.requested,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

/// 合集分页状态。
final class _CollectionPagingState {
  /// 创建合集分页状态。
  const _CollectionPagingState({
    this.items = const <BiliUserCollection>[],
    this.loading = false,
    this.loadingMore = false,
    this.requested = false,
    this.hasMore = true,
    this.nextPage = 1,
    this.errorMessage,
  });

  /// 已加载合集。
  final List<BiliUserCollection> items;

  /// 是否正在加载首屏。
  final bool loading;

  /// 是否正在追加下一页。
  final bool loadingMore;

  /// 是否已经发起过合集请求，用于区分首次未加载和真实空列表。
  final bool requested;

  /// 是否还有下一页。
  final bool hasMore;

  /// 下一页页码。
  final int nextPage;

  /// 错误文案。
  final String? errorMessage;

  /// 创建局部变更后的新状态。
  _CollectionPagingState copyWith({
    List<BiliUserCollection>? items,
    bool? loading,
    bool? loadingMore,
    bool? requested,
    bool? hasMore,
    int? nextPage,
    String? errorMessage,
    bool clearError = false,
  }) {
    // 只替换本次变化的字段，避免分页回调覆盖旧数据。
    return _CollectionPagingState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      requested: requested ?? this.requested,
      hasMore: hasMore ?? this.hasMore,
      nextPage: nextPage ?? this.nextPage,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
