import 'package:flutter/material.dart';

/// 手机下载中卡片的标题、状态和操作摘要。
final class MobileProgressMediaSummary extends StatelessWidget {
  /// 创建手机下载中卡片右侧摘要区。
  const MobileProgressMediaSummary({
    required this.title,
    required this.workLabel,
    required this.workLabelColor,
    required this.actions,
    super.key,
  });

  /// 当前下载任务标题。
  final String title;

  /// 当前下载对象、阶段和速度组合后的短文本。
  final String workLabel;

  /// 状态短文本颜色，暂停时弱化，其余跟随主色。
  final Color workLabelColor;

  /// 暂停、继续或打开目录等紧凑操作入口。
  final Widget actions;

  /// 构建两行标题和底部操作摘要。
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Text(
                workLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: workLabelColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            actions,
          ],
        ),
      ],
    );
  }
}

/// 手机已完成卡片的标题、发布者和元信息摘要。
final class MobileCompletedMediaSummary extends StatelessWidget {
  /// 创建手机已完成卡片右侧摘要区。
  const MobileCompletedMediaSummary({
    required this.title,
    required this.publisherLabel,
    required this.metaLabel,
    required this.actions,
    super.key,
  });

  /// 当前任务标题。
  final String title;

  /// 发布者和发布时间等第一行辅助信息。
  final String publisherLabel;

  /// 文件大小、时长等第二行辅助信息。
  final String metaLabel;

  /// 更多操作入口。
  final Widget actions;

  /// 构建标题和两行辅助信息。
  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    publisherLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    metaLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            actions,
          ],
        ),
      ],
    );
  }
}

/// 手机排队卡片的标题、来源身份和紧凑操作摘要。
final class MobileQueuedMediaSummary extends StatelessWidget {
  /// 创建手机排队卡片右侧摘要区。
  const MobileQueuedMediaSummary({
    required this.title,
    required this.identityLabel,
    required this.actions,
    super.key,
  });

  /// 当前任务标题。
  final String title;

  /// 发布者、发布时间或兜底来源文案。
  final String identityLabel;

  /// 选择附加资源和开始下载等操作入口。
  final Widget actions;

  /// 构建排队卡片的三行摘要。
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          identityLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions,
      ],
    );
  }
}
