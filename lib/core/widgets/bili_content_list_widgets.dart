import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/bilibili/bili_user_content_service.dart';
import '../../services/image_cache/cover_cache_manager.dart';
import 'app_icon_buttons.dart';

/// B 站视频列表。
final class BiliVideoList extends StatelessWidget {
  /// 创建响应式视频列表。
  const BiliVideoList({
    super.key,
    required this.items,
    required this.mobile,
    required this.onParse,
    required this.selecting,
    required this.selectedKeys,
    required this.selectionLocked,
    required this.itemKeyOf,
    required this.onToggleSelection,
    this.canSelectItem,
    this.allowDirectParse = true,
    this.detailNavigationOnly = false,
  });

  /// 视频条目集合。
  final List<BiliUserVideoItem> items;

  /// 是否使用移动端单列。
  final bool mobile;

  /// 点击解析回调。
  final ValueChanged<BiliUserVideoItem> onParse;

  /// 当前是否处于选择模式。
  final bool selecting;

  /// 当前选中视频稳定键。
  final Set<String> selectedKeys;

  /// 是否锁定选择控件。
  final bool selectionLocked;

  /// 生成视频稳定键。
  final String Function(BiliUserVideoItem item) itemKeyOf;

  /// 切换选择状态回调。
  final ValueChanged<BiliUserVideoItem> onToggleSelection;

  /// 判断条目在选择模式下是否可勾选；为空时沿用可直接入队规则。
  final bool Function(BiliUserVideoItem item)? canSelectItem;

  /// 是否允许非选择模式下单击或按钮直接解析。
  final bool allowDirectParse;

  /// 是否只给需要展开详情的条目显示入口。
  final bool detailNavigationOnly;

  /// 构建单列或桌面双列列表。
  @override
  Widget build(BuildContext context) {
    // 视频卡片需要先占满内容区，再按可用宽度决定一列或两列。
    const spacing = 12.0;
    if (mobile) {
      return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          // 移动端按需构建可见视频卡片，末项不额外增加间距。
          final item = items[index];
          final selectable = canSelectItem?.call(item) ?? item.canQueueDirectly;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == items.length - 1 ? 0 : 10,
            ),
            child: BiliVideoRowCard(
              item: item,
              onParse: onParse,
              selecting: selecting,
              selected: selectedKeys.contains(itemKeyOf(item)),
              selectable: selectable,
              selectionLocked: selectionLocked,
              onToggleSelection: onToggleSelection,
              allowDirectParse: allowDirectParse,
              detailNavigationOnly: detailNavigationOnly,
            ),
          );
        }, childCount: items.length),
      );
    }
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        // 宽屏可读性以两列为上限，中等桌面窗口不足两列时单列拉满避免右侧空洞。
        const minDesktopCardWidth = 520.0;
        final useTwoColumns =
            constraints.crossAxisExtent >= minDesktopCardWidth * 2 + spacing;
        final columns = useTwoColumns ? 2 : 1;
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 98,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            // 桌面端虚拟网格按需构建视频卡片，避免长合集一次性创建全部 RenderObject。
            final item = items[index];
            final selectable =
                canSelectItem?.call(item) ?? item.canQueueDirectly;
            return BiliVideoRowCard(
              item: item,
              onParse: onParse,
              selecting: selecting,
              selected: selectedKeys.contains(itemKeyOf(item)),
              selectable: selectable,
              selectionLocked: selectionLocked,
              onToggleSelection: onToggleSelection,
              allowDirectParse: allowDirectParse,
              detailNavigationOnly: detailNavigationOnly,
            );
          }, childCount: items.length),
        );
      },
    );
  }
}

/// B 站视频长条卡片。
final class BiliVideoRowCard extends StatelessWidget {
  /// 创建一条视频卡片。
  const BiliVideoRowCard({
    super.key,
    required this.item,
    required this.onParse,
    required this.selecting,
    required this.selected,
    required this.selectable,
    required this.selectionLocked,
    required this.onToggleSelection,
    this.allowDirectParse = true,
    this.detailNavigationOnly = false,
  });

  /// 视频数据。
  final BiliUserVideoItem item;

  /// 点击解析回调。
  final ValueChanged<BiliUserVideoItem> onParse;

  /// 当前是否处于选择模式。
  final bool selecting;

  /// 当前条目是否已选中。
  final bool selected;

  /// 当前条目是否允许在选择模式下勾选。
  final bool selectable;

  /// 是否锁定选择控件。
  final bool selectionLocked;

  /// 切换选择状态回调。
  final ValueChanged<BiliUserVideoItem> onToggleSelection;

  /// 是否允许非选择模式下单击或按钮直接解析。
  final bool allowDirectParse;

  /// 是否只允许需要展开详情的条目在普通模式下响应点击。
  final bool detailNavigationOnly;

  /// 构建封面、标题、UP 和解析按钮。
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 文案区和封面保持同高，标题贴上、补充信息贴下，避免中间挤出多余行。
    const coverWidth = 132.0;
    const coverHeight = 78.0;
    // 有 UP 名称优先显示 UP；番剧/影视等没有 UP 时才用简介补位。
    final metaText = _bottomMeta(item);
    final dateText = _dateText(item);
    final needsDetail = item.requiresDetailNavigation;
    // UP 根列表只给分 P 或合集类条目展示详情入口，避免单视频又回到解析页。
    final showParseAction =
        allowDirectParse && (!detailNavigationOnly || needsDetail);
    // 选择模式只给能直接入队的单视频显示复选框，多 P 条目保留详情箭头。
    final showSelectionCheckbox = selecting && selectable;
    final showActionButton = showParseAction && (!selecting || needsDetail);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // 选择模式下整卡用于勾选，允许直解时普通模式才进入解析。
        onTap: _cardEnabled
            ? () {
                if (selecting) {
                  onToggleSelection(item);
                } else if (showParseAction) {
                  onParse(item);
                }
              }
            : null,
        mouseCursor: _cardEnabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              Stack(
                children: <Widget>[
                  BiliCoverImage(
                    url: item.coverUrl,
                    width: coverWidth,
                    height: coverHeight,
                  ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: BiliDurationPill(duration: item.duration),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: coverHeight,
                  child: BiliVideoRowSummary(
                    title: item.title,
                    metaText: metaText,
                    dateText: dateText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (showSelectionCheckbox)
                Checkbox(
                  value: selected,
                  mouseCursor: selectionLocked
                      ? SystemMouseCursors.forbidden
                      : SystemMouseCursors.click,
                  onChanged: selectionLocked
                      ? null
                      : (_) => onToggleSelection(item),
                )
              else if (showActionButton)
                AppCircleIconButton(
                  onPressed: item.canParse ? () => onParse(item) : null,
                  tooltip: item.canParse
                      ? needsDetail
                            ? '查看分P'
                            : '解析视频'
                      : '视频已失效',
                  variant: needsDetail
                      ? AppCircleIconButtonVariant.primaryPlain
                      : AppCircleIconButtonVariant.filled,
                  icon: Icon(
                    needsDetail
                        ? Icons.chevron_right_rounded
                        : Icons.download_rounded,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 当前卡片是否允许响应点击。
  bool get _cardEnabled {
    if (selectionLocked) return false;
    if (selecting) return selectable;
    if (!allowDirectParse || !item.canParse) return false;
    // 仅详情入口模式下，普通单视频保持不可点击，分 P 条目用箭头进入详情。
    if (detailNavigationOnly) return item.requiresDetailNavigation;
    return true;
  }

  /// 生成底部第一行信息：有 UP 显示 UP，没有 UP 才显示简介。
  String? _bottomMeta(BiliUserVideoItem item) {
    final authorName = item.authorName?.trim();
    if (authorName != null && authorName.isNotEmpty) return authorName;
    final description = item.description?.trim();
    if (description != null && description.isNotEmpty) return description;
    // 最后兜底来源标签，避免番剧等特殊条目完全空白。
    if (item.source != BiliUserVideoSource.history) {
      return _sourceLabel(item.source);
    }
    return null;
  }

  /// 根据来源展示简短标签。
  String _sourceLabel(BiliUserVideoSource source) {
    return switch (source) {
      BiliUserVideoSource.history => '历史',
      BiliUserVideoSource.upload => '稿件',
      BiliUserVideoSource.favorite => '收藏',
      BiliUserVideoSource.collection => '合集',
      BiliUserVideoSource.episode => '分P',
      BiliUserVideoSource.liked => '最近点赞',
    };
  }

  /// 生成短日期文本。
  String _dateLabel(DateTime value) {
    String two(int input) => input.toString().padLeft(2, '0');
    return '${value.year}/${two(value.month)}/${two(value.day)}';
  }

  /// 生成底部日期文本。
  String? _dateText(BiliUserVideoItem item) {
    final value = item.publishedAt;
    if (value == null) return null;
    return _dateLabel(value);
  }
}

/// B 站视频行的标题和底部元信息。
final class BiliVideoRowSummary extends StatelessWidget {
  /// 创建视频行文案摘要。
  const BiliVideoRowSummary({
    super.key,
    required this.title,
    required this.metaText,
    required this.dateText,
  });

  /// 视频标题。
  final String title;

  /// UP 名称或简介兜底。
  final String? metaText;

  /// 视频发布时间。
  final String? dateText;

  /// 构建标题和最多两行补充信息。
  @override
  Widget build(BuildContext context) {
    final metaStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (metaText != null)
              Text(
                metaText!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: metaStyle,
              ),
            if (dateText != null)
              Text(
                dateText!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: metaStyle,
              ),
          ],
        ),
      ],
    );
  }
}

/// B 站封面图片。
final class BiliCoverImage extends StatelessWidget {
  /// 创建统一圆角封面。
  const BiliCoverImage({
    super.key,
    required this.url,
    required this.width,
    required this.height,
  });

  /// 封面 URL。
  final String? url;

  /// 封面宽度。
  final double width;

  /// 封面高度。
  final double height;

  /// 构建网络封面或占位图。
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedUrl = url;
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      return BiliCoverPlaceholder(width: width, height: height);
    }
    // 按实际卡片宽度限制内存解码尺寸，绘制阶段交给 BoxFit.cover 保持原图比例裁切。
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
            BiliCoverPlaceholder(width: width, height: height),
        errorWidget: (context, url, error) => ColoredBox(
          color: colorScheme.surfaceContainerHighest,
          child: SizedBox(
            width: width,
            height: height,
            child: Icon(
              Icons.broken_image_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// B 站封面占位。
final class BiliCoverPlaceholder extends StatelessWidget {
  /// 创建固定尺寸占位。
  const BiliCoverPlaceholder({
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

/// B 站视频时长角标。
final class BiliDurationPill extends StatelessWidget {
  /// 创建视频时长角标。
  const BiliDurationPill({super.key, required this.duration});

  /// 视频时长。
  final Duration duration;

  /// 构建半透明黑底时长。
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Text(
          _durationLabel(duration),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  /// 格式化时长。
  String _durationLabel(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    String two(int input) => input.toString().padLeft(2, '0');
    if (hours > 0) return '$hours:${two(minutes)}:${two(seconds)}';
    return '${two(minutes)}:${two(seconds)}';
  }
}

/// B 站收藏夹卡片。
final class BiliFavoriteFolderCard extends StatelessWidget {
  /// 创建可点击进入详情的收藏夹卡片。
  const BiliFavoriteFolderCard({
    super.key,
    required this.folder,
    required this.onOpen,
  });

  /// 收藏夹数据。
  final BiliFavoriteFolder folder;

  /// 点击打开详情回调。
  final ValueChanged<BiliFavoriteFolder> onOpen;

  /// 构建收藏夹卡片。
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpen(folder),
        mouseCursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              BiliCoverImage(url: folder.coverUrl, width: 88, height: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      folder.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${folder.mediaCount} 个内容',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// B 站 UP 合集卡片。
final class BiliUserCollectionCard extends StatelessWidget {
  /// 创建可点击进入详情的合集卡片。
  const BiliUserCollectionCard({
    super.key,
    required this.collection,
    required this.onOpen,
  });

  /// 合集数据。
  final BiliUserCollection collection;

  /// 点击打开详情回调。
  final ValueChanged<BiliUserCollection> onOpen;

  /// 构建合集卡片。
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final description = collection.description?.trim();
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpen(collection),
        mouseCursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              BiliCoverImage(url: collection.coverUrl, width: 112, height: 70),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      collection.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${collection.mediaCount} 个视频',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
