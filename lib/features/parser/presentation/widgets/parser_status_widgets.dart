import 'package:flutter/material.dart';

import '../../../../core/widgets/app_floating_progress.dart';

/// 多分集逐项解析时显示在页面顶部的非阻断进度提示。
final class BatchParsingProgress extends StatelessWidget {
  /// 创建包含当前项和总数的解析提示。
  const BatchParsingProgress({
    required this.current,
    required this.total,
    super.key,
  });

  /// 当前正在解析的一基序号。
  final int current;

  /// 本轮需要解析的视频总数。
  final int total;

  /// 构建与应用提示体系一致的居中浮层。
  @override
  Widget build(BuildContext context) {
    // 解析页复用应用级浮动提示，避免不同入口的进度样式分裂。
    return AppFloatingProgress(
      message: '正在解析多个视频',
      current: current,
      total: total,
    );
  }
}

/// 尚未解析内容时展示的轻量操作引导。
final class ParserEmptyState extends StatelessWidget {
  /// 创建适配手机和桌面密度的解析空状态。
  const ParserEmptyState({required this.mobile, super.key});

  /// 是否使用手机紧凑尺寸。
  final bool mobile;

  /// 构建居中的链接图标、标题和支持格式说明。
  @override
  Widget build(BuildContext context) {
    // 空状态只提供说明，不重复放置顶部已经存在的解析按钮。
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: mobile ? 24 : 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.add_link_rounded,
                size: mobile ? 48 : 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              SizedBox(height: mobile ? 10 : 14),
              Text(
                '粘贴 B 站链接开始解析',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '支持 BV / AV / EP / SS、b23.tv 短链和 B 站 App 分享链接',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
