import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/widgets/app_scroll_to_top_button.dart';
import '../../../services/bilibili/models/bili_media_info.dart';
import '../application/clipboard_monitor_controller.dart';
import '../application/parser_controller.dart';
import '../application/parser_scroll_controller.dart';
import 'controllers/parser_page_controller.dart';
import 'widgets/episode_selection.dart';
import 'widgets/parser_input_section.dart';
import 'widgets/parser_result_section.dart';
import 'widgets/parser_status_widgets.dart';

/// 支持桌面与手机布局的视频解析页面。
final class ParserPage extends ConsumerStatefulWidget {
  /// 创建视频解析页面。
  const ParserPage({super.key});

  /// 创建输入框和页面状态。
  @override
  ConsumerState<ParserPage> createState() => ParserPageViewState();
}

/// 管理输入框控制器并消费 Riverpod 解析状态。
final class ParserPageViewState extends ConsumerState<ParserPage> {
  /// 保存输入框文本和光标状态。
  late final TextEditingController _inputController;

  /// 控制媒体信息和分集列表的独立滚动位置。
  final ScrollController _resultsScrollController = ScrollController();

  /// 标记分集 Sliver 起点，自动定位使用固定网格行高计算目标偏移。
  final GlobalKey _episodeGridAnchorKey = GlobalKey();

  /// 从 Riverpod 中恢复输入文本。
  @override
  void initState() {
    // 先完成 StatefulWidget 默认初始化。
    super.initState();
    // 页面重新创建时恢复控制器文本，切换导航不会丢失输入。
    _inputController = TextEditingController(
      text: ref.read(parserControllerProvider).input,
    );
    // 结果列表滚动时同步手机底栏与桌面悬浮回顶部按钮的显示状态。
    _resultsScrollController.addListener(_handleResultsScroll);
    // 手机端进入解析页属于明确输入场景，允许按设置读取一次剪贴板候选。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(clipboardMonitorControllerProvider.notifier)
          .checkOnParserPageVisible();
    });
  }

  /// 释放输入框控制器。
  @override
  void dispose() {
    // TextEditingController 持有监听器，页面销毁时必须释放。
    _inputController.dispose();
    // 结果滚动控制器持有滚动位置监听器，页面销毁时同步释放。
    _resultsScrollController.dispose();
    // 完成父类生命周期清理。
    super.dispose();
  }

  /// 构建输入、视频信息、分集选择和底部操作栏。
  @override
  Widget build(BuildContext context) {
    // 监听解析状态和分集选择变化。
    final state = ref.watch(parserControllerProvider);
    // 仅在新解析结果出现时定位默认选中项，用户手动勾选不会触发跳转。
    ref.listen<ParserState>(parserControllerProvider, (
      ParserState? previous,
      ParserState next,
    ) {
      // 外部页面或解析历史回填输入时，同步 Stateful 输入框控制器。
      final receivedExternalInput =
          previous?.input != next.input && _inputController.text != next.input;
      if (receivedExternalInput) {
        _inputController.value = TextEditingValue(
          text: next.input,
          selection: TextSelection.collapsed(offset: next.input.length),
        );
      }
      // 新的输入校验或解析错误统一使用应用级临时提示反馈。
      final receivedNewError =
          next.phase == ParserPhase.failed &&
          next.errorMessage != null &&
          previous?.errorRevision != next.errorRevision;
      // 等待当前构建结束后再访问根 Overlay。
      if (receivedNewError) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showParserError(next);
        });
      }
      // 加载完成且媒体对象已经替换时，才需要执行一次自动定位。
      final resolvedNewMedia =
          next.phase == ParserPhase.loaded &&
          next.media != null &&
          next.selectedIndexes.isNotEmpty &&
          (previous?.phase != ParserPhase.loaded ||
              !identical(previous?.media, next.media));
      // 加载中、失败或仅切换选择时保持用户当前滚动位置。
      if (!resolvedNewMedia) return;
      // 初始选择始终只有目标分集，读取该 index 作为定位键。
      final selectedIndex = next.selectedIndexes.first;
      // 等待网格完成布局后再读取目标 RenderObject。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpSelectedEpisodeToCenter(selectedIndex);
      });
    });
    // 当前媒体为空时只显示输入和说明。
    final media = state.media;
    // 手机解析页按设计稿使用紧凑间距，桌面继续保留原有留白。
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.navigationRail;
    // 手机各区块紧密衔接，桌面继续使用较宽区块间隔。
    final sectionSpacing = mobile ? 12.0 : 24.0;
    // 固定输入区和滚动内容使用同一水平边距，保证左右边缘完全对齐。
    final horizontalPadding = mobile ? 12.0 : 24.0;
    // 未解析或解析失败时展示引导空状态，错误原因由 SnackBar 临时反馈。
    final showEmptyState = media == null && state.phase != ParserPhase.loading;
    // 当前滚动状态同时控制手机底栏入口和桌面右下角悬浮按钮。
    final scrolledBeyondTop = ref.watch(parserScrolledBeyondTopProvider);
    // Shell 发出请求后由解析页持有的 ScrollController 执行滚动。
    ref.listen<int>(parserScrollTopRequestProvider, (int? previous, int next) {
      if (previous == next) return;
      _scrollResultsToTop();
    });
    // 解析结果被清空时滚动视口会卸载，需要同步移除旧的回顶部状态。
    if (showEmptyState && scrolledBeyondTop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(parserScrolledBeyondTopProvider.notifier).setBeyondTop(false);
      });
    }
    // 只有同时处理多个分集时展示顶部进度，单 P 或单项选择保持原界面。
    final showBatchProgress = state.isQueuing && state.queueProgressTotal > 1;
    // 主内容保持原有 Column 尺寸，批量提示不能参与其布局计算。
    final mainContent = Column(
      children: <Widget>[
        ParserInputSection(
          controller: _inputController,
          state: state,
          horizontalPadding: horizontalPadding,
          sectionSpacing: sectionSpacing,
          onChanged: (String value) {
            // 每次编辑同步 Riverpod，页面切换后仍能恢复。
            ref.read(parserControllerProvider.notifier).updateInput(value);
          },
          onClear: () {
            // 先清理文本控制器，立即移除界面中的输入和光标选择。
            _inputController.clear();
            // 再同步 Riverpod 状态并清除与旧输入关联的错误提示。
            ref.read(parserControllerProvider.notifier).clearInput();
          },
          onParse: () {
            // 提交当前输入执行真实解析。
            unawaited(ref.read(parserControllerProvider.notifier).parse());
          },
        ),
        ParserResultSection(
          state: state,
          media: media,
          mobile: mobile,
          showEmptyState: showEmptyState,
          horizontalPadding: horizontalPadding,
          sectionSpacing: sectionSpacing,
          scrollController: _resultsScrollController,
          episodeGridAnchorKey: _episodeGridAnchorKey,
          onToggleEpisode: (int index) {
            // 把单集选择操作交给 Riverpod 控制器。
            ref.read(parserControllerProvider.notifier).toggleEpisode(index);
          },
        ),
        if (media != null) _buildSelectionActionBar(state, media),
      ],
    );
    // Stack 只负责叠加固定进度提示，主内容位置始终与未入队时一致。
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        mainContent,
        if (showBatchProgress) _buildBatchProgressOverlay(state),
        if (!mobile && scrolledBeyondTop) _buildScrollToTopButton(media),
      ],
    );
  }

  /// 构建解析结果底部固定操作栏。
  Widget _buildSelectionActionBar(ParserState state, BiliMediaInfo media) {
    return SelectionActionBar(
      selectedCount: state.selectedIndexes.length,
      totalCount: media.episodes.length,
      isQueuing: state.isQueuing,
      queueProgressCurrent: state.queueProgressCurrent,
      queueProgressTotal: state.queueProgressTotal,
      onToggleAll: () {
        // 全选状态由控制器根据当前集合自动判断。
        ref.read(parserControllerProvider.notifier).toggleAll();
      },
      onQueue: state.selectedIndexes.isEmpty || state.isQueuing
          ? null
          : () => ref
                .read(parserPageControllerProvider.notifier)
                .queueSelected(context),
    );
  }

  /// 构建批量解析期间覆盖在顶部的进度提示。
  Widget _buildBatchProgressOverlay(ParserState state) {
    return Positioned(
      top: 10,
      left: 0,
      right: 0,
      child: IgnorePointer(
        // 提示可能覆盖输入区域，但不能截获输入框或按钮的鼠标与触摸事件。
        child: Center(
          child: BatchParsingProgress(
            current: state.queueProgressCurrent,
            total: state.queueProgressTotal,
          ),
        ),
      ),
    );
  }

  /// 构建桌面端右下角回到顶部按钮。
  Widget _buildScrollToTopButton(BiliMediaInfo? media) {
    return Positioned(
      right: 24,
      // 有结果时避开固定选择操作栏；空结果理论上不会显示，但仍保留安全位置。
      bottom: media != null ? 84 : 24,
      child: AppScrollToTopButton(onPressed: _scrollResultsToTop),
    );
  }

  /// 同步解析结果滚动位置，并在超过 300dp 后显示回顶部入口。
  void _handleResultsScroll() {
    if (!_resultsScrollController.hasClients) return;
    final beyondTop = _resultsScrollController.offset > 300;
    ref.read(parserScrolledBeyondTopProvider.notifier).setBeyondTop(beyondTop);
  }

  /// 将解析结果列表平滑滚回顶部。
  void _scrollResultsToTop() {
    if (!_resultsScrollController.hasClients) return;
    unawaited(
      _resultsScrollController
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

  /// 使用应用级顶部提示显示输入校验或解析错误。
  void _showParserError(ParserState state) {
    // 页面级提示和重试动作由控制器集中处理。
    ref
        .read(parserPageControllerProvider.notifier)
        .showParserError(context, state);
  }

  /// 无动画地把指定分集卡片定位到结果视口中间。
  void _jumpSelectedEpisodeToCenter(int index) {
    // 页面关闭、媒体已替换或滚动视口尚未挂载时不执行定位。
    if (!mounted) return;
    final media = ref.read(parserControllerProvider).media;
    final anchorContext = _episodeGridAnchorKey.currentContext;
    if (media == null ||
        anchorContext == null ||
        !_resultsScrollController.hasClients) {
      return;
    }
    // 分集 index 可能不是从零连续递增，必须先查找它在接口列表中的真实位置。
    final position = media.episodes.indexWhere(
      (BiliEpisodeInfo episode) => episode.index == index,
    );
    if (position < 0) return;
    // 列数、卡片高度和间距必须与 EpisodeGrid 的响应式委托保持一致。
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.navigationRail;
    final columns = mobile ? 1 : 2;
    final tileExtent = mobile ? 52.0 : 64.0;
    final rowSpacing = mobile ? 7.0 : 10.0;
    final row = position ~/ columns;
    // 锚点已经位于 SliverGrid 正上方，其 reveal 偏移就是网格起点。
    final anchorRenderObject = anchorContext.findRenderObject();
    if (anchorRenderObject == null) return;
    final viewport = RenderAbstractViewport.of(anchorRenderObject);
    final gridStartOffset = viewport
        .getOffsetToReveal(anchorRenderObject, 0)
        .offset;
    final scrollPosition = _resultsScrollController.position;
    // 目标行居中显示，并限制在当前 Sliver 总滚动范围内。
    final targetOffset =
        gridStartOffset +
        row * (tileExtent + rowSpacing) -
        (scrollPosition.viewportDimension - tileExtent) / 2;
    _resultsScrollController.jumpTo(
      targetOffset.clamp(0.0, scrollPosition.maxScrollExtent),
    );
  }
}
