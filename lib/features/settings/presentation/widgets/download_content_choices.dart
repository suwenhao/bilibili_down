import 'package:flutter/material.dart';

import '../../../../core/widgets/app_selection_controls.dart';
import '../../domain/app_settings.dart';
import '../models/settings_labels.dart';

/// 下载内容在手机使用三列网格，PC 保留现有流式标签。
final class DownloadContentChoices extends StatelessWidget {
  /// 创建下载附加内容多选组。
  const DownloadContentChoices({
    required this.compact,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// 是否使用手机三列布局。
  final bool compact;

  /// 当前已经启用的下载内容集合。
  final Set<DownloadContentOption> selected;

  /// 用户切换单项后的回调。
  final void Function(DownloadContentOption option, bool selected) onSelected;

  /// 构建等宽手机网格或 PC 流式选项。
  @override
  Widget build(BuildContext context) {
    // 剪切板监听属于运行时工具，不再混在实际下载文件内容里。
    const visibleOptions = DownloadContentOption.values;
    final contentOptions = visibleOptions
        .where((option) => option != DownloadContentOption.monitorClipboard)
        .toList(growable: false);
    // 复用同一标签构造，保证两种布局的选择行为一致。
    Widget buildChip(DownloadContentOption option) {
      return AppSelectionChip(
        visualDensity: compact ? VisualDensity.compact : null,
        label: downloadContentLabel(option),
        selected: selected.contains(option),
        onSelected: (bool value) => onSelected(option, value),
      );
    }

    // PC 不改变用户已经确认的现有 Wrap 规格。
    if (!compact) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: contentOptions.map(buildChip).toList(growable: false),
      );
    }
    // 手机按设计稿使用三列等宽选项，数量变化时自动换行。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 两段 6dp 间距从可用宽度中扣除，避免最后一列溢出。
        final itemWidth = (constraints.maxWidth - 12) / 3;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: contentOptions
              .map(
                (DownloadContentOption option) => SizedBox(
                  width: itemWidth,
                  child: AppMobileSelectionCell(
                    label: downloadContentLabel(option),
                    selected: selected.contains(option),
                    leading: Icon(
                      selected.contains(option)
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 18,
                    ),
                    onTap: () => onSelected(option, !selected.contains(option)),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

/// 工具类设置项，当前承载剪切板监听等不直接生成下载文件的开关。
final class ToolChoices extends StatelessWidget {
  /// 创建工具开关组。
  const ToolChoices({
    required this.compact,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// 是否使用手机紧凑布局。
  final bool compact;

  /// 剪切板监听当前是否启用。
  final bool selected;

  /// 用户切换剪切板监听后的保存回调。
  final ValueChanged<bool> onSelected;

  /// 构建工具行；PC 使用标签按钮，手机沿用设置网格单元格样式。
  @override
  Widget build(BuildContext context) {
    // 工具行目前只有一个开关，后续新增工具时可以继续放入同一 Wrap。
    const option = DownloadContentOption.monitorClipboard;
    if (!compact) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: <Widget>[
          AppSelectionChip(
            label: downloadContentLabel(option),
            selected: selected,
            onSelected: onSelected,
          ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 手机端和下载内容保持三列宽度，单个工具项不会撑满整行。
        final itemWidth = (constraints.maxWidth - 12) / 3;
        return SizedBox(
          width: itemWidth,
          child: AppMobileSelectionCell(
            label: downloadContentLabel(option),
            selected: selected,
            leading: Icon(
              selected
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 18,
            ),
            onTap: () => onSelected(!selected),
          ),
        );
      },
    );
  }
}
