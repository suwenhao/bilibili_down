import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 发布 B 站 Cookie 已失效事件，不承载下载任务或页面阻断状态。
final biliSessionInvalidationControllerProvider =
    NotifierProvider<BiliSessionInvalidationController, int>(
      BiliSessionInvalidationController.new,
    );

/// 使用递增修订号通知账号控制器回落游客权限。
final class BiliSessionInvalidationController extends Notifier<int> {
  /// 初始修订号表示本进程尚未收到会话失效事件。
  @override
  int build() => 0;

  /// 在网络层清除失效 Cookie 后发布一次权限降级事件。
  void notifyExpired() {
    // 事件只影响账号权限状态，不关联、暂停或删除任何下载任务。
    state++;
  }
}
