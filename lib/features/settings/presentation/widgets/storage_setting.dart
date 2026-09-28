import 'package:flutter/material.dart';

import '../../../../core/widgets/app_action_button.dart';

/// 存储目录展示和三个操作入口。
final class StorageSetting extends StatelessWidget {
  /// 创建存储目录设置。
  const StorageSetting({
    required this.compact,
    required this.directory,
    required this.onChange,
    required this.showChange,
    required this.onAdvanced,
    required this.onOpen,
    required this.onReset,
    super.key,
  });

  /// 是否使用手机纵向布局。
  final bool compact;

  /// 当前实际下载目录。
  final String directory;

  /// 系统目录选择器回调。
  final VoidCallback? onChange;

  /// 是否展示目录更改入口，不支持持久自定义目录的平台会隐藏。
  final bool showChange;

  /// 高级目录弹窗回调。
  final VoidCallback onAdvanced;

  /// 打开目录回调，目录未解析时为空。
  final VoidCallback? onOpen;

  /// 恢复默认目录回调，仅存在自定义目录时启用。
  final VoidCallback? onReset;

  /// 构建路径框和操作按钮。
  @override
  Widget build(BuildContext context) {
    // 路径框在桌面限制宽度，手机占满整行。
    final pathField = Container(
      constraints: BoxConstraints(maxWidth: compact ? double.infinity : 420),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(directory, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
    // 三个文本操作与参考设计保持轻量。
    final actions = Wrap(
      spacing: 2,
      runSpacing: 4,
      children: <Widget>[
        if (showChange)
          AppActionButton(
            variant: AppActionButtonVariant.text,
            onPressed: onChange,
            label: '更改',
          ),
        AppActionButton(
          variant: AppActionButtonVariant.text,
          onPressed: onAdvanced,
          label: '高级',
        ),
        AppActionButton(
          variant: AppActionButtonVariant.text,
          onPressed: onOpen,
          label: '打开目录',
        ),
        if (onReset != null)
          AppActionButton(
            variant: AppActionButtonVariant.text,
            onPressed: onReset,
            label: '恢复默认',
          ),
      ],
    );
    // 手机路径使用无边框入口和右箭头，操作文本放在下一行。
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: onChange,
            mouseCursor: onChange == null
                ? SystemMouseCursors.forbidden
                : SystemMouseCursors.click,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      directory,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (onChange != null) ...<Widget>[
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 20),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          actions,
        ],
      );
    }
    // 桌面路径框和文本操作横向排列。
    return Row(
      children: <Widget>[
        Flexible(fit: FlexFit.loose, child: pathField),
        const SizedBox(width: 8),
        actions,
      ],
    );
  }
}
