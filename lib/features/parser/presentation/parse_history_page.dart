import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/widgets/app_action_button.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_icon_buttons.dart';
import '../../../core/widgets/app_list_footer.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../services/image_cache/cover_cache_manager.dart';
import '../application/parser_controller.dart';
import '../data/parse_history_repository.dart';

part 'widgets/parse_history_card.dart';
part 'widgets/parse_history_header.dart';
part 'widgets/parse_history_list.dart';
part 'widgets/parse_history_state_views.dart';

/// 解析历史页面，展示本地 SQLite 中保存的解析快照。
final class ParseHistoryPage extends ConsumerWidget {
  /// 创建解析历史页面。
  const ParseHistoryPage({super.key});

  /// 构建历史列表、空态和错误态。
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 历史列表来自本地 Drift 查询流，数据库变化会自动刷新页面。
    final history = ref.watch(parseHistoryEntriesProvider);
    // 手机端沿用解析页和用户中心的导航断点。
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.navigationRail;
    // 页面内容与解析页保持同一最大宽度，避免桌面端列表过宽。
    final horizontalPadding = mobile ? 16.0 : 24.0;
    return Scaffold(
      body: SafeArea(
        bottom: false,
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
                    12,
                  ),
                  child: ParseHistoryTopBar(
                    onBack: () => Navigator.of(context).pop(),
                    onClear: history.asData?.value.isNotEmpty == true
                        ? () => unawaited(_clearAllHistory(context, ref))
                        : null,
                  ),
                ),
                Expanded(
                  child: history.when(
                    loading: () => const ParseHistoryLoadingState(),
                    error: (Object error, StackTrace stackTrace) =>
                        ParseHistoryErrorState(
                          onRetry: () =>
                              ref.invalidate(parseHistoryEntriesProvider),
                        ),
                    data: (List<ParseHistoryEntry> entries) {
                      if (entries.isEmpty) {
                        return const ParseHistoryEmptyState();
                      }
                      return ParseHistoryList(
                        entries: entries,
                        mobile: mobile,
                        horizontalPadding: horizontalPadding,
                        onSelected: (ParseHistoryEntry entry) =>
                            _restoreHistoryEntry(context, ref, entry),
                        onDelete: (ParseHistoryEntry entry) =>
                            unawaited(_deleteHistoryEntry(context, ref, entry)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 恢复一条解析历史并返回解析页。
  void _restoreHistoryEntry(
    BuildContext context,
    WidgetRef ref,
    ParseHistoryEntry entry,
  ) {
    // 先取出控制器和快照数据，后续历史页退出后不能再依赖当前 BuildContext。
    final controller = ref.read(parserControllerProvider.notifier);
    final input = entry.record.sourceInput;
    final media = entry.media;
    final selectedIndexes = Set<int>.of(entry.selectedIndexes);
    // 先退出 push 出来的历史页，避免 Sliver 列表和 tooltip 覆盖层激活期间同步触发解析页重布局。
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 历史页完全退出当前帧后再恢复解析结果，规避 OverlayPortal 在布局阶段被重新挂载。
      controller.restoreFromHistory(
        input: input,
        media: media,
        selectedIndexes: selectedIndexes,
      );
    });
  }

  /// 确认并删除一条解析历史。
  Future<void> _deleteHistoryEntry(
    BuildContext context,
    WidgetRef ref,
    ParseHistoryEntry entry,
  ) async {
    // 删除历史会永久移除本地 SQLite 快照，必须先让用户确认目标标题。
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: const Text('删除解析历史？'),
      content: Text('将删除「${entry.record.mediaTitle}」的解析快照。'),
      confirmLabel: '删除',
    );
    if (!confirmed || !context.mounted) return;
    try {
      // 使用历史主键删除当前条目，列表会通过 Drift 查询流自动刷新。
      await ref
          .read(parseHistoryRepositoryProvider)
          .deleteByHistoryKey(entry.record.historyKey);
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        message: '已删除解析历史。',
        type: AppSnackBarType.success,
      );
    } catch (error) {
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        message: '删除解析历史失败：$error',
        type: AppSnackBarType.error,
      );
    }
  }

  /// 确认并清空全部解析历史。
  Future<void> _clearAllHistory(BuildContext context, WidgetRef ref) async {
    // 清空历史属于批量破坏性操作，必须明确确认。
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: const Text('清空解析历史？'),
      content: const Text('所有解析历史快照都会从本地数据库删除，此操作无法撤销。'),
      confirmLabel: '清空',
    );
    if (!confirmed || !context.mounted) return;
    try {
      // 清空只影响解析历史表，数据库流会自动把页面切换为空状态。
      final deleted = await ref.read(parseHistoryRepositoryProvider).clearAll();
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        message: '已清空 $deleted 条解析历史。',
        type: AppSnackBarType.success,
      );
    } catch (error) {
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        message: '清空解析历史失败：$error',
        type: AppSnackBarType.error,
      );
    }
  }
}
