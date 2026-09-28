import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_debug_log.dart';
import '../../../services/bilibili/bili_api_exception.dart';
import '../../../services/bilibili/bilibili_parser_service.dart';
import '../../../services/bilibili/bili_input_normalizer.dart';
import '../../../services/bilibili/bilibili_providers.dart';
import '../../../services/bilibili/models/bili_media_info.dart';
import '../../downloads/application/queue/download_queue_service.dart';
import '../data/parse_history_repository.dart';

/// 提供视频输入、解析结果和分集选择状态。
final parserControllerProvider =
    NotifierProvider<ParserController, ParserState>(ParserController.new);

/// 视频解析页当前阶段。
enum ParserPhase {
  /// 尚未提交解析。
  idle,

  /// 正在请求 B 站接口。
  loading,

  /// 已经获得视频和分集信息。
  loaded,

  /// 输入、网络或接口解析失败。
  failed,
}

/// 视频解析页不可变状态。
final class ParserState {
  /// 创建解析页状态快照。
  ParserState({
    required this.input,
    required this.phase,
    required Set<int> selectedIndexes,
    this.media,
    this.errorMessage,
    this.errorRevision = 0,
    this.isQueuing = false,
    this.queueProgressCurrent = 0,
    this.queueProgressTotal = 0,
  }) : selectedIndexes = Set<int>.unmodifiable(selectedIndexes);

  /// 用户当前输入，切换页面后仍保留。
  final String input;

  /// 当前解析阶段。
  final ParserPhase phase;

  /// 已解析媒体信息。
  final BiliMediaInfo? media;

  /// 选中分集的一基 index 集合。
  final Set<int> selectedIndexes;

  /// 失败时展示的稳定错误说明。
  final String? errorMessage;

  /// 每次解析失败递增的反馈序号，用于允许相同错误再次提示。
  final int errorRevision;

  /// 是否正在批量写入待下载任务。
  final bool isQueuing;

  /// 批量解析当前正在处理的一基序号。
  final int queueProgressCurrent;

  /// 本轮批量解析需要处理的分集总数。
  final int queueProgressTotal;

  /// 创建初始空状态。
  factory ParserState.initial() {
    // 默认输入为空且未选择分集。
    return ParserState(
      input: '',
      phase: ParserPhase.idle,
      selectedIndexes: const <int>{},
    );
  }
}

/// 管理真实 B 站解析调用和分集选择。
final class ParserController extends Notifier<ParserState> {
  /// 当前解析失败反馈序号；每次用户提交失败都递增一次。
  int _errorRevision = 0;

  /// 从依赖容器读取解析服务。
  BilibiliParserService get _parser => ref.read(bilibiliParserServiceProvider);

  /// 从依赖容器读取待下载入队服务。
  DownloadQueueService get _queueService =>
      ref.read(downloadQueueServiceProvider);

  /// 从依赖容器读取解析历史仓库。
  ParseHistoryRepository get _historyRepository =>
      ref.read(parseHistoryRepositoryProvider);

  /// 创建解析页初始状态。
  @override
  ParserState build() => ParserState.initial();

  /// 保存输入框文本，页面切换后仍可恢复。
  void updateInput(String value) {
    // 判断文本是否真的变化，避免同值同步无意义地清除结果。
    final inputChanged = value != state.input;
    // 新输入不能继续绑定旧媒体，否则会用错误的来源地址创建任务。
    state = ParserState(
      input: value,
      phase: inputChanged ? ParserPhase.idle : state.phase,
      media: inputChanged ? null : state.media,
      selectedIndexes: inputChanged ? const <int>{} : state.selectedIndexes,
      errorMessage: inputChanged ? null : state.errorMessage,
      errorRevision: state.errorRevision,
      isQueuing: state.isQueuing,
    );
  }

  /// 清空输入、解析结果和分集选择。
  void clearInput() {
    // 请求或入队执行期间不允许改变输入，避免界面文本与正在处理的参数不一致。
    if (state.phase == ParserPhase.loading || state.isQueuing) return;
    // 输入与媒体结果必须同步清除，避免空来源继续显示旧入队操作。
    state = ParserState(
      input: '',
      phase: ParserPhase.idle,
      selectedIndexes: const <int>{},
    );
  }

  /// 解析当前输入并优先选中链接实际指向的分集。
  Future<void> parse({int? preferredCid}) async {
    // 已经有解析请求在路上时忽略重复提交，避免按钮外的调用路径并发打 B 站接口。
    if (state.phase == ParserPhase.loading) return;
    // 正在写入任务时不替换媒体状态，避免异步完成顺序覆盖新结果。
    if (state.isQueuing) return;
    // 去除首尾空白，保持 URL 中间内容不变。
    final input = state.input.trim();
    // 空输入在本地直接反馈，不发网络请求。
    if (input.isEmpty) {
      AppDebugLog.parser('Parse rejected reason=empty-input');
      // 空输入不能保留旧媒体和选择，否则底部按钮会尝试用空来源入队。
      state = ParserState(
        input: state.input,
        phase: ParserPhase.failed,
        selectedIndexes: const <int>{},
        errorMessage: '请输入视频链接或 BV / AV / EP / SS 号。',
        // 即使文案与上次相同，本次点击也必须产生新的界面反馈事件。
        errorRevision: ++_errorRevision,
      );
      return;
    }
    // 进入加载状态并清除旧错误，保留旧结果避免页面高度闪烁。
    state = ParserState(
      input: state.input,
      phase: ParserPhase.loading,
      media: state.media,
      selectedIndexes: state.selectedIndexes,
    );
    try {
      AppDebugLog.parser('Parse started inputLength=${input.length}');
      // 调用统一解析服务展开短链接并解析视频或剧集信息。
      final parsedInput = await _parser.parseInput(input);
      // 解析结果包含标准目标，合集展开后仍可找到原链接对应的分集。
      final media = parsedInput.media;
      // BV 和 EP 精确匹配目标分集；AV/SS 等集合目标找不到单集时才回退首项。
      final initialSelection = _initialSelectionFor(
        target: parsedInput.target,
        media: media,
        preferredCid: preferredCid,
      );
      // 成功解析后写入本地 SQLite 历史，历史失败不能影响本次解析结果展示。
      unawaited(
        _historyRepository
            .saveParsedInput(
              sourceInput: input,
              parsedInput: parsedInput,
              selectedIndexes: initialSelection,
            )
            .catchError((Object error, StackTrace stackTrace) {
              // 历史记录属于辅助能力，写入失败不应打断用户已经获得的解析结果。
              AppDebugLog.parser('Parse history save failed error=$error');
            }),
      );
      AppDebugLog.parser(
        'Parse succeeded target=${parsedInput.target.kind.name} '
        'episodes=${media.episodes.length} selected=${initialSelection.length}',
      );
      // 用新媒体结果完整替换旧解析状态。
      state = ParserState(
        input: state.input,
        phase: ParserPhase.loaded,
        media: media,
        selectedIndexes: initialSelection,
      );
    } catch (error) {
      AppDebugLog.parser('Parse failed error=$error');
      // 保留输入并显示适合用户阅读的错误，内部异常结构只进入日志。
      state = ParserState(
        input: state.input,
        phase: ParserPhase.failed,
        media: state.media,
        selectedIndexes: state.selectedIndexes,
        errorMessage: biliUserMessage(error, fallback: '解析失败，请检查链接后重试。'),
        // 重复网络或接口错误仍对应一次新的用户提交，需要再次显示提示。
        errorRevision: ++_errorRevision,
      );
    }
  }

  /// 从解析历史快照恢复输入、媒体和分集选择。
  void restoreFromHistory({
    required String input,
    required BiliMediaInfo media,
    required Set<int> selectedIndexes,
  }) {
    // 历史恢复来自本地 SQLite 快照，不再发起网络解析。
    AppDebugLog.parser(
      'Parse restored from history episodes=${media.episodes.length} '
      'selected=${selectedIndexes.length}',
    );
    state = ParserState(
      input: input,
      phase: ParserPhase.loaded,
      media: media,
      selectedIndexes: selectedIndexes,
    );
  }

  /// 根据标准输入目标计算解析完成后的默认分集选择。
  Set<int> _initialSelectionFor({
    required BiliInputTarget target,
    required BiliMediaInfo media,
    int? preferredCid,
  }) {
    // 空结果不产生选择，防止访问不存在的首项。
    if (media.episodes.isEmpty) return const <int>{};
    if (preferredCid != null) {
      for (final episode in media.episodes) {
        // 分 P 详情页传入 CID 时优先选中用户点击的具体 P。
        if (episode.cid == preferredCid) return <int>{episode.index};
      }
    }
    // 遍历完整合集，优先找到输入 BV 或 EP 真正对应的条目。
    BiliEpisodeInfo? firstBvidMatch;
    for (final episode in media.episodes) {
      // BV 主体区分大小写，比较时统一小写以兼容用户链接格式。
      final matchesBvid =
          target.kind == BiliInputKind.bvid &&
          episode.bvid.toLowerCase() == target.bvid!.toLowerCase();
      if (matchesBvid) {
        // URL 带 p 参数时要定位到同一 BV 下的具体分 P，而不是只选第一条 BV 命中项。
        if (target.pageNumber != null &&
            episode.pageNumber == target.pageNumber) {
          return <int>{episode.index};
        }
        firstBvidMatch ??= episode;
      }
      // EP 使用接口返回的稳定 episodeId 定位季度中的具体分集。
      final matchesEpisode =
          target.kind == BiliInputKind.episode &&
          episode.episodeId == target.numericId;
      // 命中标准目标后只选中这一条，不再错误选择集合首项。
      if (matchesEpisode) return <int>{episode.index};
    }
    if (firstBvidMatch != null) return <int>{firstBvidMatch.index};
    // SS 代表整个季度，或异常响应缺少目标条目时沿用首项兜底。
    return <int>{media.episodes.first.index};
  }

  /// 切换单个分集选择状态。
  void toggleEpisode(int index) {
    if (state.isQueuing) return;
    // 复制不可变集合后执行本次切换。
    final selection = Set<int>.of(state.selectedIndexes);
    // 已选中时取消，否则加入选择。
    if (!selection.remove(index)) selection.add(index);
    // 保存新选择并保留其余解析状态。
    state = ParserState(
      input: state.input,
      phase: state.phase,
      media: state.media,
      selectedIndexes: selection,
      errorMessage: state.errorMessage,
      isQueuing: state.isQueuing,
    );
  }

  /// 全选或取消全选当前媒体分集。
  void toggleAll() {
    if (state.isQueuing) return;
    // 没有媒体结果时无需修改状态。
    final media = state.media;
    if (media == null) return;
    // 已经全部选中时清空，否则选择所有分集 index。
    final selection = state.selectedIndexes.length == media.episodes.length
        ? const <int>{}
        : media.episodes
              .map((BiliEpisodeInfo episode) => episode.index)
              .toSet();
    // 保存批量选择结果。
    state = ParserState(
      input: state.input,
      phase: state.phase,
      media: media,
      selectedIndexes: selection,
      errorMessage: state.errorMessage,
      isQueuing: state.isQueuing,
    );
  }

  /// 把选中分集写入 Drift 待下载列表并返回统计结果。
  Future<QueueEpisodesResult> queueSelected() async {
    // 已有入队操作运行时忽略重复提交。
    if (state.isQueuing) {
      return const QueueEpisodesResult(added: 0);
    }
    // 没有媒体或没有选择时返回零结果。
    final media = state.media;
    if (media == null || state.selectedIndexes.isEmpty) {
      AppDebugLog.parser('Queue selected skipped reason=empty-selection');
      return const QueueEpisodesResult(added: 0);
    }
    // 按媒体原顺序筛选当前选中的分集，进度总数以这份稳定快照为准。
    final selectedEpisodes = media.episodes
        .where(
          (BiliEpisodeInfo episode) =>
              state.selectedIndexes.contains(episode.index),
        )
        .toList(growable: false);
    // 标记入队中并预告首项，阻止用户重复点击创建相同任务。
    state = ParserState(
      input: state.input,
      phase: state.phase,
      media: media,
      selectedIndexes: state.selectedIndexes,
      isQueuing: true,
      queueProgressCurrent: 1,
      queueProgressTotal: selectedEpisodes.length,
    );
    try {
      AppDebugLog.parser(
        'Queue selected started count=${selectedEpisodes.length}',
      );
      // 调用应用服务完成独立路径生成和数据库写入，同一分集允许重复加入。
      final result = await _queueService.queueEpisodes(
        sourceInput: state.input.trim(),
        media: media,
        episodes: selectedEpisodes,
        onProgress: (int current, int total) {
          // 服务上报每个 DASH 请求开始位置，页面据此刷新顶部批量提示。
          state = ParserState(
            input: state.input,
            phase: state.phase,
            media: media,
            selectedIndexes: state.selectedIndexes,
            errorMessage: state.errorMessage,
            isQueuing: true,
            queueProgressCurrent: current,
            queueProgressTotal: total,
          );
        },
      );
      AppDebugLog.parser(
        'Queue selected completed added=${result.added} '
        'skipped=${result.skipped} extra=${result.extraAdded}',
      );
      return result;
    } catch (error) {
      AppDebugLog.parser('Queue selected failed error=$error');
      rethrow;
    } finally {
      // 无论成功或失败都恢复按钮可用状态。
      state = ParserState(
        input: state.input,
        phase: state.phase,
        media: media,
        selectedIndexes: state.selectedIndexes,
        errorMessage: state.errorMessage,
      );
    }
  }
}
