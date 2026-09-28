import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 用户中心当前可见滚动区是否已经超过“回到顶部”阈值。
final userCenterScrolledBeyondTopProvider =
    NotifierProvider<UserCenterScrolledBeyondTopController, bool>(
      UserCenterScrolledBeyondTopController.new,
    );

/// Shell 请求用户中心回到顶部的递增信号。
final userCenterScrollTopRequestProvider =
    NotifierProvider<UserCenterScrollTopRequestController, int>(
      UserCenterScrollTopRequestController.new,
    );

/// 保存用户中心是否已经滚动到需要显示“顶部”入口的位置。
final class UserCenterScrolledBeyondTopController extends Notifier<bool> {
  /// 初始未滚动，底栏仍显示“个人”。
  @override
  bool build() => false;

  /// 更新当前可见滚动区是否超过阈值。
  void setBeyondTop(bool value) {
    // 相同状态不重复通知，避免底栏不必要重建。
    if (state == value) return;
    state = value;
  }
}

/// 用递增序号承载“回到顶部”事件。
final class UserCenterScrollTopRequestController extends Notifier<int> {
  /// 初始没有任何回顶请求。
  @override
  int build() => 0;

  /// 发出一次新的回顶请求。
  void request() {
    // 使用序号而不是 bool，保证连续点击也能被用户中心识别为新事件。
    state++;
  }
}
