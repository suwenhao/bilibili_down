import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/network/bili_network_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/image_cache/cover_cache_manager.dart';
import '../utils/download_task_formatters.dart';

/// 视频封面与时长角标。
final class TaskCover extends StatelessWidget {
  /// 创建指定尺寸的封面。
  const TaskCover({
    required this.task,
    required this.width,
    required this.height,
    this.showDuration = true,
    super.key,
  });

  /// 任务快照。
  final DownloadTaskRecord task;

  /// 封面宽度。
  final double width;

  /// 封面高度。
  final double height;

  /// 是否显示右下角视频时长，紧凑列表可关闭以减少信息噪音。
  final bool showDuration;

  /// 构建网络图片、加载失败回退和时长角标。
  @override
  Widget build(BuildContext context) {
    // 封面地址可能为空，统一使用产品次级表面回退。
    final coverUrl = task.coverUrl;
    // 只有有限尺寸才主动约束封面；手机端的无限占位值交给外层 AspectRatio 决定。
    final constrainedWidth = width.isFinite ? width : null;
    // 高度使用相同规则，确保桌面 Row 中的 Stack 始终获得明确尺寸。
    final constrainedHeight = height.isFinite ? height : null;
    // SizedBox 约束外层 ClipRRect，而不是只给内部 Image 设置尺寸。
    return SizedBox(
      width: constrainedWidth,
      height: constrainedHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (coverUrl == null || coverUrl.isEmpty)
              ColoredBox(
                color: context.biliDownColors.secondarySurface,
                child: const Icon(Icons.image_outlined),
              )
            else
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  // 使用实际布局宽度和设备像素比限制 Flutter 解码尺寸；
                  // 磁盘仍保存原始封面，解析页复用同一文件时不会损失清晰度。
                  final devicePixelRatio = MediaQuery.devicePixelRatioOf(
                    context,
                  );
                  final decodeWidth = constraints.maxWidth.isFinite
                      ? (constraints.maxWidth * devicePixelRatio).ceil()
                      : null;
                  // 只限制解码宽度，绘制阶段交给 BoxFit.cover 按原图比例裁切。
                  // 同时传宽高可能让部分封面被重采样成卡片比例，看起来像被拉伸。
                  return CachedNetworkImage(
                    imageUrl: coverUrl,
                    cacheManager: CoverCacheManager.instance,
                    fit: BoxFit.cover,
                    memCacheWidth: decodeWidth,
                    httpHeaders: const <String, String>{
                      'User-Agent': BiliNetworkClient.userAgent,
                      'Referer': BiliNetworkClient.defaultReferer,
                    },
                    placeholder: (BuildContext context, String url) {
                      // 首次下载封面时保持卡片尺寸，避免列表内容跳动。
                      return ColoredBox(
                        color: context.biliDownColors.secondarySurface,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorWidget:
                        (BuildContext context, String url, Object error) {
                          // 网络或缓存文件失败时保留卡片尺寸和可识别图标。
                          return ColoredBox(
                            color: context.biliDownColors.secondarySurface,
                            child: const Icon(Icons.broken_image_outlined),
                          );
                        },
                  );
                },
              ),
            if (showDuration)
              Positioned(
                right: 5,
                bottom: 5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    child: Text(
                      durationLabel(task.durationMilliseconds),
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 任务的视频元数据摘要。
final class VideoSummary extends StatelessWidget {
  /// 创建标题和基础信息摘要。
  const VideoSummary({
    required this.task,
    this.showDescription = true,
    super.key,
  });

  /// 任务快照。
  final DownloadTaskRecord task;

  /// 是否在摘要中直接展示简介。
  final bool showDescription;

  /// 构建不依赖尚未落库字段的稳定信息。
  @override
  Widget build(BuildContext context) {
    // 使用入队时保存的解析元数据构建设计稿信息行。
    final identity = <String>[
      if (task.publisherName != null && task.publisherName!.isNotEmpty)
        task.publisherName!,
      if (task.resolutionLabel != null && task.resolutionLabel!.isNotEmpty)
        task.resolutionLabel!,
      if (task.partIndex > 0) '第 ${task.partIndex} 集',
      if (task.qualityLabel != null) task.qualityLabel!,
    ].join(' · ');
    // 标题最多两行，避免桌面表格高度失控。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          task.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 7),
        Text(
          identity.isEmpty ? 'Bilibili 视频' : identity,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (showDescription &&
            task.description != null &&
            task.description!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            task.description!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        // 摘要仅承载视频身份信息；失败原因由待下载失败区统一展示一次，
        // 避免任务退回待下载页签后同时出现两份错误文案和旧下载进度。
      ],
    );
  }
}
