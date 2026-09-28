import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/logging/app_debug_log.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../services/bilibili/bili_input_normalizer.dart';
import '../../../../services/bilibili/bili_user_content_service.dart';
import '../../../../services/bilibili/bilibili_parser_service.dart';
import '../../../../services/bilibili/bilibili_providers.dart';
import '../../../../services/bilibili/models/bili_media_info.dart';
import '../../../downloads/application/queue/download_queue_service.dart';
import '../../../downloads/application/ui_state/download_task_tab_controller.dart';
import '../../../parser/application/parser_controller.dart';
import '../../application/account_controller.dart';
import '../dialogs/account_dialog.dart';

/// 用户中心页面级动作入口。
final userCenterPageControllerProvider =
    NotifierProvider<UserCenterPageController, UserCenterPageState>(
      UserCenterPageController.new,
    );

/// 用户中心页面动作状态。
final class UserCenterPageState {
  /// 创建用户中心动作状态。
  const UserCenterPageState({required this.loggingOut});

  /// 初始状态没有退出登录动作。
  factory UserCenterPageState.initial() {
    return const UserCenterPageState(loggingOut: false);
  }

  /// 是否正在清除当前登录会话。
  final bool loggingOut;

  /// 返回替换部分字段后的新状态。
  UserCenterPageState copyWith({bool? loggingOut}) {
    return UserCenterPageState(loggingOut: loggingOut ?? this.loggingOut);
  }
}

/// 用户中心批量入队的汇总结果。
final class UserVideoBatchQueueResult {
  /// 创建一次批量解析入队的数量统计。
  const UserVideoBatchQueueResult({
    required this.added,
    required this.skipped,
    required this.failed,
  });

  /// 成功新增到待下载的任务数。
  final int added;

  /// 下载队列按重名等规则跳过的任务数。
  final int skipped;

  /// 基础解析、目标分集匹配或统一入队失败的条目数。
  final int failed;
}

/// 用户中心批量解析时上报当前条目序号和总数。
typedef UserVideoBatchProgressCallback = void Function(int current, int total);

/// 生成批量解析按钮的加载态文案。
String userBatchLoadingLabel(int current, int total) {
  if (total <= 0) return '解析中…';
  final safeCurrent = current.clamp(1, total);
  return '解析中 $safeCurrent/$total';
}

/// 承接用户中心中的账号、解析和批量入队动作。
final class UserCenterPageController extends Notifier<UserCenterPageState> {
  /// 创建初始页面动作状态。
  @override
  UserCenterPageState build() => UserCenterPageState.initial();

  /// 打开登录入口。
  void openLoginDialog(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.navigationRail;
    if (mobile) {
      // 手机端账号登录作为个人分支子页展示，保留底部导航和当前 Shell 上下文。
      AppDebugLog.user('Login account subpage opened from user center');
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext routeContext) => const AccountCenterPage(),
          ),
        ),
      );
      return;
    }
    // 桌面端仍使用居中账号弹窗，避免为短登录流程占满内容区。
    AppDebugLog.user('Login dialog opened from user center');
    unawaited(showAccountDialog(context));
  }

  /// 显示退出登录确认并执行账号清理。
  Future<void> confirmLogout(BuildContext context) async {
    if (state.loggingOut) return;
    // 退出登录是破坏当前会话的操作，必须先获得用户确认。
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: const Text('退出登录？'),
      content: const Text('将清除本机保存的 B 站登录凭据，不会删除下载任务和已有文件。'),
      confirmLabel: '退出登录',
    );
    if (!confirmed || !context.mounted) return;
    AppDebugLog.user('Logout confirmed from user center');
    state = state.copyWith(loggingOut: true);
    try {
      // 账号控制器只清理本机凭据并同步未登录状态，不影响 B 站账号其他设备。
      await ref.read(accountControllerProvider.notifier).logout();
      if (!context.mounted) return;
      AppDebugLog.user('Local logout feedback shown');
      AppSnackBar.show(
        context,
        message: '已清除本机登录凭据。',
        type: AppSnackBarType.success,
        position: AppSnackBarPosition.top,
      );
    } catch (error) {
      AppDebugLog.user('Logout failed error=$error');
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        message: '退出登录处理失败：$error',
        type: AppSnackBarType.error,
        position: AppSnackBarPosition.top,
      );
    } finally {
      state = state.copyWith(loggingOut: false);
    }
  }

  /// 将用户列表视频送入解析页。
  void parseVideo(BuildContext context, BiliUserVideoItem item) {
    final input = item.parseInput;
    if (!item.canParse || input == null) {
      AppDebugLog.user(
        'User video parse rejected unavailable=${item.isUnavailable}',
      );
      AppSnackBar.show(
        context,
        message: item.isUnavailable ? '这个视频已失效，不能解析。' : '这个条目缺少可解析的视频 ID。',
        type: AppSnackBarType.warning,
        position: AppSnackBarPosition.top,
      );
      return;
    }
    // 先写入解析输入，再跳转到解析页并立即执行解析。
    AppDebugLog.user('User video parse opened source=${item.source.name}');
    final parser = ref.read(parserControllerProvider.notifier);
    parser.updateInput(input);
    unawaited(parser.parse());
    context.go('/parse');
  }

  /// 批量解析用户视频条目并在全部基础解析完成后统一写入下载库。
  Future<UserVideoBatchQueueResult> queueVideoItems({
    required List<BiliUserVideoItem> items,
    UserVideoBatchProgressCallback? onProgress,
  }) async {
    var added = 0;
    var skipped = 0;
    var failed = 0;
    AppDebugLog.user('Batch queue started count=${items.length}');
    // 解析器只负责把 BV/AV 入口展开为媒体信息，数据库写入延后到队列服务一次完成。
    final parser = ref.read(bilibiliParserServiceProvider);
    final requests = <QueueEpisodeRequest>[];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      // 按选中视频条目上报基础解析进度，按钮可显示“解析中 1/12”。
      onProgress?.call(index + 1, items.length);
      final input = item.parseInput;
      if (!item.canQueueDirectly || input == null) {
        AppDebugLog.user(
          'Batch queue item skipped reason=unparseable source=${item.source.name}',
        );
        failed++;
        continue;
      }
      try {
        // 用户中心入口指向单个视频，遇到合集解析结果时只取命中的那一集。
        final parsedInput = await parser.parseInput(input);
        final targetEpisode = _episodeForUserItem(parsedInput, item);
        if (targetEpisode == null) {
          AppDebugLog.user('Batch queue item failed reason=no-target-episode');
          failed++;
          continue;
        }
        // 先放入内存请求列表，避免每解析一条就触发一次数据库写入。
        requests.add(
          QueueEpisodeRequest(
            sourceInput: input,
            media: parsedInput.media,
            episodes: <BiliEpisodeInfo>[targetEpisode],
          ),
        );
      } catch (error) {
        // 单条解析失败不影响剩余条目，最终用汇总结果提示用户。
        AppDebugLog.user('Batch queue item parse failed error=$error');
        failed++;
      }
    }
    if (requests.isNotEmpty) {
      try {
        // 全部基础解析结束后，队列服务再集中解析 DASH 并批量写库。
        final result = await ref
            .read(downloadQueueServiceProvider)
            .queueEpisodeRequests(requests: requests);
        added = result.added;
        skipped = result.skipped;
      } catch (error) {
        // 集中入队失败时，本批请求都没有可靠完成，统一计入失败。
        AppDebugLog.user('Batch queue write failed error=$error');
        failed += requests.length;
      }
    }
    AppDebugLog.user(
      'Batch queue completed added=$added skipped=$skipped failed=$failed',
    );
    return UserVideoBatchQueueResult(
      added: added,
      skipped: skipped,
      failed: failed,
    );
  }

  /// 展示批量解析入队完成后的统一反馈。
  void showBatchQueueResult(
    BuildContext context,
    UserVideoBatchQueueResult result,
  ) {
    final skippedText = result.skipped == 0
        ? ''
        : '，跳过 ${result.skipped} 个重名视频';
    final failedText = result.failed == 0 ? '' : '，${result.failed} 个解析失败';
    AppSnackBar.show(
      context,
      message: '已加入 ${result.added} 个待下载任务$skippedText$failedText。',
      type: result.added > 0
          ? AppSnackBarType.success
          : AppSnackBarType.warning,
      position: AppSnackBarPosition.top,
    );
  }

  /// 跳转到待下载页签，方便用户继续确认清晰度或开始下载。
  void openPendingTasks(BuildContext context) {
    ref
        .read(downloadTaskTabControllerProvider.notifier)
        .select(DownloadTaskTab.pending);
    context.go('/tasks');
  }

  /// 从解析结果中选择当前用户中心条目对应的单个分集。
  BiliEpisodeInfo? _episodeForUserItem(
    BiliParsedInput parsedInput,
    BiliUserVideoItem item,
  ) {
    final media = parsedInput.media;
    if (media.episodes.isEmpty) return null;
    final targetCid = item.targetCid;
    if (targetCid != null) {
      for (final episode in media.episodes) {
        // 分 P 详情页已经拿到 CID，按 CID 命中才能避免多 P 视频总是下载第一 P。
        if (episode.cid == targetCid) return episode;
      }
    }
    final target = parsedInput.target;
    for (final episode in media.episodes) {
      // 用户中心条目只提供 BV/AV 入口，BV 命中时不能把整个合集加入待下载。
      final matchesBvid =
          target.kind == BiliInputKind.bvid &&
          episode.bvid.toLowerCase() == target.bvid!.toLowerCase();
      // 旧 AV 输入无法定位合集中的其他 BV，只能使用解析器返回的首个目标结果。
      if (matchesBvid) return episode;
    }
    return media.episodes.first;
  }
}
