import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前任务页签是否已经超过“回到顶部”显示阈值。
final downloadTasksScrolledBeyondTopProvider =
    NotifierProvider<DownloadTasksScrolledBeyondTopController, bool>(
      DownloadTasksScrolledBeyondTopController.new,
    );

/// Shell 请求当前任务页签回到顶部的递增信号。
final downloadTasksScrollTopRequestProvider =
    NotifierProvider<DownloadTasksScrollTopRequestController, int>(
      DownloadTasksScrollTopRequestController.new,
    );

/// 保存当前任务页签是否需要显示回顶部入口。
final class DownloadTasksScrolledBeyondTopController extends Notifier<bool> {
  /// 初始位于任务列表顶部，不显示回顶部入口。
  @override
  bool build() => false;

  /// 更新当前任务页签是否超过阈值。
  void setBeyondTop(bool value) {
    // 相同状态不重复通知，避免导航外壳无意义重建。
    if (state == value) return;
    state = value;
  }
}

/// 用递增序号承载任务页回顶部事件。
final class DownloadTasksScrollTopRequestController extends Notifier<int> {
  /// 初始没有回顶部请求。
  @override
  int build() => 0;

  /// 发出一次新的回顶部请求。
  void request() {
    // 序号保证连续点击也会形成独立事件。
    state++;
  }
}
