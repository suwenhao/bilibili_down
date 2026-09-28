part of '../parse_history_page.dart';

/// 解析历史长条卡片。
final class ParseHistoryCard extends StatelessWidget {
  /// 创建单条解析历史。
  const ParseHistoryCard({
    super.key,
    required this.entry,
    required this.onSelected,
    required this.onDelete,
  });

  /// 当前历史条目。
  final ParseHistoryEntry entry;

  /// 点击后恢复解析页快照。
  final ValueChanged<ParseHistoryEntry> onSelected;

  /// 删除当前历史快照。
  final ValueChanged<ParseHistoryEntry> onDelete;

  /// 构建封面、标题和历史摘要。
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 封面尺寸与用户中心视频长条保持一致。
    const coverWidth = 132.0;
    const coverHeight = 88.0;
    // 标题允许两行时需要固定行高，避免不同字体度量把底部摘要挤出卡片。
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(height: 1.18);
    // 摘要文本与标题共用同一列高度预算，行高略收紧但仍保留可读空隙。
    final metaStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      height: 1.15,
    );
    // 底部摘要展示来源、分集数量和最近解析时间。
    final metaText = _metaText(entry);
    final dateText = _dateText(entry.record.updatedAt);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onSelected(entry),
        mouseCursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              HistoryCoverImage(
                url: entry.record.coverUrl,
                width: coverWidth,
                height: coverHeight,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: coverHeight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.record.mediaTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            metaText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: metaStyle,
                          ),
                          Text(
                            dateText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: metaStyle,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  AppCircleIconButton(
                    tooltip: '删除解析历史',
                    variant: AppCircleIconButtonVariant.destructivePlain,
                    size: AppCircleIconButtonSize.small,
                    onPressed: () => onDelete(entry),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.keyboard_return_rounded,
                    color: colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 生成历史条目摘要。
  String _metaText(ParseHistoryEntry entry) {
    final publisher = entry.record.publisherName?.trim();
    final prefix = publisher == null || publisher.isEmpty
        ? entry.record.canonicalId
        : publisher;
    final episodeCount = entry.record.episodeCount;
    if (episodeCount <= 1) return '$prefix · 单集';
    return '$prefix · $episodeCount 项';
  }

  /// 生成最近解析时间文本。
  String _dateText(DateTime value) {
    String two(int input) => input.toString().padLeft(2, '0');
    return '最近解析 ${value.year}/${two(value.month)}/${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
  }
}

/// 历史封面图片。
final class HistoryCoverImage extends StatelessWidget {
  /// 创建固定尺寸封面。
  const HistoryCoverImage({
    super.key,
    required this.url,
    required this.width,
    required this.height,
  });

  /// 封面远程地址。
  final String? url;

  /// 封面宽度。
  final double width;

  /// 封面高度。
  final double height;

  /// 构建网络封面或占位图。
  @override
  Widget build(BuildContext context) {
    final resolvedUrl = url;
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      return HistoryCoverPlaceholder(width: width, height: height);
    }
    // 历史列表只按缩略图宽度限制解码，避免固定框高度参与重采样后拉伸封面。
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final decodeWidth = (width * devicePixelRatio).ceil();
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: CachedNetworkImage(
        imageUrl: resolvedUrl,
        cacheManager: CoverCacheManager.instance,
        width: width,
        height: height,
        fit: BoxFit.cover,
        memCacheWidth: decodeWidth,
        placeholder: (context, url) =>
            HistoryCoverPlaceholder(width: width, height: height),
        errorWidget: (context, url, error) =>
            HistoryCoverPlaceholder(width: width, height: height),
      ),
    );
  }
}

/// 历史封面占位。
final class HistoryCoverPlaceholder extends StatelessWidget {
  /// 创建占位封面。
  const HistoryCoverPlaceholder({
    super.key,
    required this.width,
    required this.height,
  });

  /// 占位宽度。
  final double width;

  /// 占位高度。
  final double height;

  /// 构建占位底色和图标。
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(9),
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Icon(
          Icons.movie_creation_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
