import 'package:flutter/material.dart';

import '../../../../services/bilibili/models/bili_media_info.dart';
import '../../application/parser_controller.dart';
import 'episode_selection.dart';
import 'media_information_card.dart';
import 'parser_status_widgets.dart';

/// 解析页输入区下方的空态或媒体结果区。
final class ParserResultSection extends StatelessWidget {
  /// 创建解析结果区。
  const ParserResultSection({
    required this.state,
    required this.media,
    required this.mobile,
    required this.showEmptyState,
    required this.horizontalPadding,
    required this.sectionSpacing,
    required this.scrollController,
    required this.episodeGridAnchorKey,
    required this.onToggleEpisode,
    super.key,
  });

  /// 当前解析状态。
  final ParserState state;

  /// 当前解析出的媒体信息。
  final BiliMediaInfo? media;

  /// 是否使用手机布局。
  final bool mobile;

  /// 是否展示未解析空态。
  final bool showEmptyState;

  /// 页面水平留白。
  final double horizontalPadding;

  /// 区块垂直间距。
  final double sectionSpacing;

  /// 结果列表滚动控制器。
  final ScrollController scrollController;

  /// 分集网格起点锚点。
  final GlobalKey episodeGridAnchorKey;

  /// 切换分集选择回调。
  final ValueChanged<int> onToggleEpisode;

  /// 构建输入区下方的空状态或解析结果滚动区。
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: showEmptyState
          ? ParserEmptyState(mobile: mobile)
          : LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final contentPadding = _resultContentPadding(
                  constraints: constraints,
                  horizontalPadding: horizontalPadding,
                );
                return CustomScrollView(
                  controller: scrollController,
                  slivers: _buildMediaSlivers(
                    context: context,
                    state: state,
                    media: media,
                    mobile: mobile,
                    contentPadding: contentPadding,
                    sectionSpacing: sectionSpacing,
                  ),
                );
              },
            ),
    );
  }

  /// 计算解析结果最大宽度居中所需的左右补偿。
  double _resultContentPadding({
    required BoxConstraints constraints,
    required double horizontalPadding,
  }) {
    final paddedContentWidth = constraints.maxWidth - horizontalPadding * 2;
    if (paddedContentWidth <= 1180) return horizontalPadding;
    return horizontalPadding + (paddedContentWidth - 1180) / 2;
  }

  /// 构建媒体信息卡、合集标题和分集网格 Sliver。
  List<Widget> _buildMediaSlivers({
    required BuildContext context,
    required ParserState state,
    required BiliMediaInfo? media,
    required bool mobile,
    required double contentPadding,
    required double sectionSpacing,
  }) {
    if (media == null) return const <Widget>[];
    return <Widget>[
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: contentPadding),
        sliver: SliverList.list(
          children: <Widget>[
            MediaInformationCard(media: media),
            SizedBox(height: sectionSpacing),
            if (media.episodes.length > 1) ...<Widget>[
              Text(
                media.title,
                style: mobile
                    ? Theme.of(context).textTheme.titleMedium
                    : Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: mobile ? 8 : 12),
            ],
            // 零高度锚点只提供网格起始滚动坐标，不为每个分集保留上下文。
            SizedBox(key: episodeGridAnchorKey, height: 0),
          ],
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: contentPadding),
        sliver: EpisodeGrid(
          episodes: media.episodes,
          singleEpisodeTitle: media.episodes.length == 1 ? media.title : null,
          selectedIndexes: state.selectedIndexes,
          interactionLocked: state.isQueuing,
          onToggle: onToggleEpisode,
        ),
      ),
      SliverToBoxAdapter(child: SizedBox(height: sectionSpacing)),
    ];
  }
}
