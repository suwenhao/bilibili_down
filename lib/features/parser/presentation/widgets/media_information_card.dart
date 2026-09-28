import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/network/bili_network_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/app_tooltip.dart';
import '../../../../services/bilibili/models/bili_media_info.dart';
import '../../../../services/image_cache/cover_cache_manager.dart';
import '../up_user_page.dart';

/// 视频基础信息卡片。
final class MediaInformationCard extends StatelessWidget {
  /// 创建媒体信息卡片。
  const MediaInformationCard({required this.media, super.key});

  /// 当前已解析媒体信息。
  final BiliMediaInfo media;

  /// 构建桌面双栏或手机单栏信息区。
  @override
  Widget build(BuildContext context) {
    // 手机信息卡按设计稿压缩内边距和字段行，桌面保持宽松布局。
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.navigationRail;
    // 卡片内部根据可用宽度决定封面与字段排列。
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(mobile ? 8 : 18),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // 只要应用外壳显示桌面侧边栏，解析信息就保持桌面双栏结构。
            final wide =
                MediaQuery.sizeOf(context).width >=
                AppBreakpoints.navigationRail;
            // 桌面封面使用更接近横版壁纸预览的十四比九比例。
            const desktopCoverAspectRatio = 14 / 9;
            // 桌面封面固定宽度，避免窗口变宽时封面跟随弹性列持续放大。
            const desktopCoverWidth = 448.0;
            // 高度由十四比九比例推导，图片绘制阶段继续使用 BoxFit.cover 裁切。
            const desktopCoverHeight =
                desktopCoverWidth / desktopCoverAspectRatio;
            // 封面按布局分支选择比例并提供加载和错误回退。
            final cover = NetworkCover(
              url: media.coverUrl,
              aspectRatio: wide ? desktopCoverAspectRatio : 16 / 9,
            );
            // 信息字段只展示解析阶段实际拥有的数据。
            final information = MediaDetails(media: media, compact: !wide);
            // 手机纵向排列标题、封面和字段。
            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    media.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  cover,
                  const SizedBox(height: 6),
                  information,
                ],
              );
            }
            // 桌面先显示标题，再使用封面和字段双栏。
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  media.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: desktopCoverWidth,
                      height: desktopCoverHeight,
                      child: cover,
                    ),
                    const SizedBox(width: 24),
                    Expanded(child: information),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 远程封面图。
final class NetworkCover extends StatelessWidget {
  /// 创建带空值回退的封面。
  const NetworkCover({super.key, required this.url, required this.aspectRatio});

  /// B 站封面地址。
  final String? url;

  /// 当前布局要求的封面比例。
  final double aspectRatio;

  /// 构建固定比例封面。
  @override
  Widget build(BuildContext context) {
    // 使用裁剪和固定比例避免图片加载造成布局跳动。
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: url == null
            ? _placeholder(context)
            : LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  // 解析页桌面和手机封面尺寸不同，按当前约束计算解码宽度；
                  // 仅限制内存位图，不改变 CoverCacheManager 保存的原始缓存文件。
                  final decodeWidth = constraints.maxWidth.isFinite
                      ? (constraints.maxWidth *
                                MediaQuery.devicePixelRatioOf(context))
                            .ceil()
                      : null;
                  return CachedNetworkImage(
                    imageUrl: url!,
                    cacheManager: CoverCacheManager.instance,
                    fit: BoxFit.cover,
                    memCacheWidth: decodeWidth,
                    httpHeaders: const <String, String>{
                      'User-Agent': BiliNetworkClient.userAgent,
                      'Referer': BiliNetworkClient.defaultReferer,
                    },
                    placeholder: (BuildContext context, String imageUrl) {
                      // 首次下载期间使用居中进度，保持固定比例。
                      return ColoredBox(
                        color: context.biliDownColors.secondarySurface,
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorWidget:
                        (BuildContext context, String imageUrl, Object error) {
                          // CDN 图片失败时展示稳定占位，不影响文字信息。
                          return _placeholder(context);
                        },
                  );
                },
              ),
      ),
    );
  }

  /// 构建封面缺失占位。
  Widget _placeholder(BuildContext context) {
    // 次级表面与图片图标说明当前位置是封面区域。
    return ColoredBox(
      color: context.biliDownColors.secondarySurface,
      child: const Center(child: Icon(Icons.image_not_supported_outlined)),
    );
  }
}

/// 媒体基础字段列表。
final class MediaDetails extends StatelessWidget {
  /// 创建字段列表。
  const MediaDetails({super.key, required this.media, required this.compact});

  /// 当前媒体信息。
  final BiliMediaInfo media;

  /// 是否使用手机端紧凑字段规格。
  final bool compact;

  /// 构建发布者、时间、分辨率、时长、集数和描述。
  @override
  Widget build(BuildContext context) {
    // 第一条分集提供集合级分辨率和时长回退。
    final firstEpisode = media.episodes.isEmpty ? null : media.episodes.first;
    // 发布者名称来自解析结果，按钮和普通文本都使用这个清理后的展示值。
    final publisherName = media.publisherName?.trim();
    // 发布者 UID 来自解析结果，只有存在有效 UID 时才允许进入 UP 二级页。
    final publisherId = media.publisherId;
    // 除发布者外的字段按设计稿固定顺序排列。
    final entries = <(String, String)>[
      ('发布时间', _formatDateTime(media.publishedAt)),
      ('分辨率', firstEpisode?.resolutionLabel ?? '暂无'),
      ('时长', _formatDuration(firstEpisode?.duration)),
      ('集数', media.episodes.length.toString()),
      (
        '描述',
        media.description?.trim().isNotEmpty == true
            ? media.description!
            : '暂无描述',
      ),
    ];
    // 使用 Column 构建紧凑字段行。
    return Column(
      children: <Widget>[
        DetailRow(
          label: '发布者',
          value: publisherName?.isNotEmpty == true ? publisherName! : '暂无',
          compact: compact,
          valueChild:
              publisherName?.isNotEmpty == true &&
                  publisherId != null &&
                  publisherId > 0
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: AppActionButton(
                    label: publisherName!,
                    icon: Icons.person_outline_rounded,
                    size: AppActionButtonSize.small,
                    height: compact ? 26 : 30,
                    minWidth: 0,
                    horizontalPadding: compact ? 8 : 10,
                    variant: AppActionButtonVariant.plain,
                    onPressed: () {
                      // 发布者字段带 UID 时进入解析分支下的 UP 二级页。
                      context.push(
                        '/parse/up/$publisherId',
                        extra: UpUserPageArguments(
                          mid: publisherId,
                          name: publisherName,
                        ),
                      );
                    },
                  ),
                )
              : null,
        ),
        ...entries.map(
          ((String, String) entry) =>
              DetailRow(label: entry.$1, value: entry.$2, compact: compact),
        ),
      ],
    );
  }

  /// 格式化本地发布时间。
  static String _formatDateTime(DateTime? value) {
    // 时间缺失时保持字段占位。
    if (value == null) return '暂无';
    // 使用零填充生成稳定年月日时分文本。
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    // 返回适合中英文数字混排的短时间格式。
    return '${value.year}/${twoDigits(value.month)}/${twoDigits(value.day)} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }

  /// 格式化分集时长。
  static String _formatDuration(Duration? value) {
    // 零时长或缺失时显示暂无。
    if (value == null || value <= Duration.zero) return '暂无';
    // 总分钟包含超过一小时的部分。
    final minutes = value.inMinutes;
    // 秒数取一分钟内余数。
    final seconds = value.inSeconds.remainder(60);
    // 使用分秒显示保持设计稿紧凑风格。
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}

/// 单条媒体字段。
final class DetailRow extends StatelessWidget {
  /// 创建标签和值。
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    required this.compact,
    this.valueChild,
  });

  /// 字段名称。
  final String label;

  /// 字段显示值。
  final String value;

  /// 是否使用手机端紧凑高度、字号和标签宽度。
  final bool compact;

  /// 自定义值区域，用于发布者等可点击字段。
  final Widget? valueChild;

  /// 构建带分隔线的字段行。
  @override
  Widget build(BuildContext context) {
    // 只有描述可能承载长段落，其他短字段不额外展示 Tooltip。
    final valueText = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: compact ? Theme.of(context).textTheme.bodySmall : null,
    );
    // 固定单行高度并让所有字段值在空间不足时省略。
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 24 : 42),
      padding: EdgeInsets.symmetric(vertical: compact ? 3 : 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: compact ? 120 : 86,
            child: Text(
              label,
              style:
                  (compact
                          ? Theme.of(context).textTheme.bodySmall
                          : Theme.of(context).textTheme.bodyMedium)
                      ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          Expanded(
            child:
                valueChild ??
                (label == '描述'
                    ? AppTooltip(message: value, child: valueText)
                    : valueText),
          ),
        ],
      ),
    );
  }
}
