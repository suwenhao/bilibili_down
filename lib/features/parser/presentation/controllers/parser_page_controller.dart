import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../services/bilibili/bili_api_exception.dart';
import '../../../downloads/application/queue/download_queue_service.dart';
import '../../../downloads/application/ui_state/download_task_tab_controller.dart';
import '../../application/parser_controller.dart';

/// 解析页页面级动作入口。
final parserPageControllerProvider =
    NotifierProvider<ParserPageController, void>(ParserPageController.new);

/// 承接解析页的临时提示、入队反馈和跳转动作。
final class ParserPageController extends Notifier<void> {
  /// 页面动作无需持久状态，仅复用 Notifier 的 ref 读取业务服务。
  @override
  void build() {}

  /// 使用应用级顶部提示显示输入校验或解析错误。
  void showParserError(BuildContext context, ParserState state) {
    // 页面已销毁或错误已经被新状态清除时不再展示过期提示。
    if (!context.mounted || state.errorMessage == null) return;
    // 空输入只需说明原因，有有效输入时提供原地重试入口。
    final canRetry = state.input.trim().isNotEmpty;
    // 根 Overlay 可覆盖页面和弹窗，顶部居中避免占用结果区域。
    AppSnackBar.show(
      context,
      message: state.errorMessage!,
      type: AppSnackBarType.error,
      position: AppSnackBarPosition.top,
      layout: AppSnackBarLayout.centered,
      actionLabel: canRetry ? '重试' : null,
      onAction: canRetry
          ? () {
              // 重试读取控制器当前输入，避免闭包继续使用旧文本。
              unawaited(ref.read(parserControllerProvider.notifier).parse());
            }
          : null,
    );
  }

  /// 把当前选择加入任务列表并显示统计反馈。
  Future<void> queueSelected(BuildContext context) async {
    try {
      // 调用解析控制器生成独立任务并写入 Drift，同一视频允许多次加入。
      final result = await ref
          .read(parserControllerProvider.notifier)
          .queueSelected();
      // 页面可能在异步写入期间销毁，销毁后不能访问根 Overlay。
      if (!context.mounted) return;
      // 使用应用级提示展示入队统计，跳转后仍可覆盖新页面。
      AppSnackBar.show(
        context,
        message: _queueMessage(result),
        type: result.added > 0 ? AppSnackBarType.success : AppSnackBarType.info,
        position: AppSnackBarPosition.top,
      );
      // StatefulShell 会保留任务页旧 tab，先发一次明确请求再进入待下载配置页。
      ref
          .read(downloadTaskTabControllerProvider.notifier)
          .select(DownloadTaskTab.pending);
      context.go('/tasks');
    } catch (error) {
      // 页面销毁后不再显示错误提示。
      if (!context.mounted) return;
      // 数据库或路径解析失败时保留选择并提示用户重试。
      AppSnackBar.show(
        context,
        message: '加入任务失败：${biliUserMessage(error, fallback: '请稍后重试。')}',
        type: AppSnackBarType.error,
        position: AppSnackBarPosition.top,
      );
    }
  }

  /// 生成批量入队结果文案。
  String _queueMessage(QueueEpisodesResult result) {
    // 跳过数量与成功数量同时反馈，避免用户误以为所有分集都已入队。
    final skippedSuffix = result.skipped == 0
        ? ''
        : '，跳过 ${result.skipped} 个重名视频';
    // 没有自动附加内容时保持原有简洁反馈。
    if (result.extraAdded == 0) {
      return '已加入 ${result.added} 项待下载任务$skippedSuffix。';
    }
    // 分别反馈视频和自动附加资源数量，避免总数突然增加造成误解。
    return '已加入 ${result.added} 个视频，并保存 ${result.extraAdded} 项附加资源选择$skippedSuffix。';
  }
}
