import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 解析结果列表是否已经超过“回到顶部”显示阈值。
final parserScrolledBeyondTopProvider =
    NotifierProvider<ParserScrolledBeyondTopController, bool>(
      ParserScrolledBeyondTopController.new,
    );

/// Shell 请求解析结果列表回到顶部的递增信号。
final parserScrollTopRequestProvider =
    NotifierProvider<ParserScrollTopRequestController, int>(
      ParserScrollTopRequestController.new,
    );

/// 保存解析结果列表是否需要显示回顶部入口。
final class ParserScrolledBeyondTopController extends Notifier<bool> {
  /// 初始位于结果顶部，不显示回顶部入口。
  @override
  bool build() => false;

  /// 更新结果列表是否超过阈值。
  void setBeyondTop(bool value) {
    // 相同状态不重复通知，避免导航外壳和解析页无意义重建。
    if (state == value) return;
    state = value;
  }
}

/// 用递增序号承载解析页回顶部事件。
final class ParserScrollTopRequestController extends Notifier<int> {
  /// 初始没有回顶部请求。
  @override
  int build() => 0;

  /// 发出一次新的回顶部请求。
  void request() {
    // 序号能保证每次点击都形成新事件，不受上一次状态影响。
    state++;
  }
}
