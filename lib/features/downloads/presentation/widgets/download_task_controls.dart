import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/app_anchored_dropdown.dart';
import '../../../../core/widgets/app_popup_menu_items.dart';
import '../../../../core/widgets/app_tooltip.dart';
import '../../domain/download_extra_resource.dart';

/// 桌面任务标题。
final class DesktopTaskTitle extends StatelessWidget {
  /// 创建单行任务标题。
  const DesktopTaskTitle({required this.task, super.key});

  /// 任务快照。
  final DownloadTaskRecord task;

  /// 构建图二左上角标题。
  @override
  Widget build(BuildContext context) {
    // 标题保持单行，避免把右上角操作区挤成竖列。
    return AppTooltip(
      message: task.title,
      child: Text(
        task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

/// 桌面音频或视频预计大小文本。
final class DesktopMetric extends StatelessWidget {
  /// 创建紧凑指标。
  const DesktopMetric({required this.label, required this.value, super.key});

  /// 指标名称。
  final String label;

  /// 指标值。
  final String value;

  /// 构建图二中的加粗名称和值。
  @override
  Widget build(BuildContext context) {
    // 使用同一行表达流类型和预计大小。
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$label  ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value),
        ],
      ),
      // 与“发布 / 简介”两行使用同级字号和紧凑行高。
      style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// 桌面下载中或已下载任务的只读质量字段。
final class DesktopReadOnlyOption extends StatelessWidget {
  /// 创建只读标签和值。
  const DesktopReadOnlyOption({
    required this.label,
    required this.value,
    super.key,
  });

  /// 字段名称。
  final String label;

  /// 当前任务实际使用的质量。
  final String value;

  /// 构建不带边框和下拉箭头的普通文字。
  @override
  Widget build(BuildContext context) {
    // 使用一行布局与相邻文件大小字段保持对齐。
    return Row(
      children: <Widget>[
        Text('$label：', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

/// 桌面音质或画质锚定下拉字段。
final class DesktopOptionField<T> extends StatelessWidget {
  /// 创建标签、当前值和同步候选。
  const DesktopOptionField({
    required this.label,
    required this.value,
    required this.options,
    required this.labelBuilder,
    required this.selectedBuilder,
    required this.onSelected,
    required this.onClear,
    required this.cleared,
    super.key,
  });

  /// 字段名称。
  final String label;

  /// 当前选择。
  final String value;

  /// 解析时随任务入库的候选项。
  final List<T> options;

  /// 候选项显示文案转换器。
  final String Function(T option) labelBuilder;

  /// 判断候选项是否为当前选择。
  final bool Function(T option) selectedBuilder;

  /// 用户点击候选项后的保存回调。
  final ValueChanged<T> onSelected;

  /// 用户选择“无”时取消当前媒体流。
  final VoidCallback onClear;

  /// 当前媒体流是否已经取消。
  final bool cleared;

  /// 构建与图二一致的标签加下拉框布局。
  @override
  Widget build(BuildContext context) {
    // 展示设置默认值经过本地清单降级后的实际任务选择。
    return Row(
      children: <Widget>[
        Text('$label：', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Flexible(
          child: ConstrainedBox(
            // 下拉框本体最多 180dp，父级不足时继续收缩并省略当前值。
            constraints: const BoxConstraints(maxWidth: 180),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // 菜单宽度严格跟随不超过 180dp 的实际字段宽度。
                final menuWidth = constraints.hasBoundedWidth
                    ? constraints.maxWidth
                    : 180.0;
                // 公共锚定下拉负责菜单外壳、展开状态和候选项样式。
                return AppAnchoredSelectionMenu<T>(
                  options: options,
                  constraints: BoxConstraints(
                    minWidth: menuWidth,
                    maxWidth: menuWidth,
                  ),
                  labelBuilder: labelBuilder,
                  selectedBuilder: selectedBuilder,
                  onSelected: onSelected,
                  onClear: onClear,
                  cleared: cleared,
                  borderRadius: BorderRadius.circular(7),
                  splashRadius: 16,
                  fieldValue: value,
                  fieldHeight: 30,
                  fieldBorderRadius: BorderRadius.circular(7),
                  fieldValueStyle: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// 桌面任务合并后的附加内容下拉菜单。
final class DesktopResourceMenu extends StatefulWidget {
  /// 创建用于编辑主任务附加资源 JSON 的复选菜单。
  const DesktopResourceMenu({
    required this.availableResources,
    required this.selectedResources,
    required this.onChanged,
    super.key,
  });

  /// 设置中心当前已启用并允许展示的资源。
  final Set<DownloadExtraResource> availableResources;

  /// 当前主任务已经勾选的资源。
  final Set<DownloadExtraResource> selectedResources;

  /// 用户切换后返回新的完整选择集合。
  final ValueChanged<Set<DownloadExtraResource>> onChanged;

  /// 创建菜单展开状态。
  @override
  State<DesktopResourceMenu> createState() => _DesktopResourceMenuState();
}

/// 管理桌面“更多”下拉箭头和菜单状态。
final class _DesktopResourceMenuState extends State<DesktopResourceMenu> {
  /// 构建封面和音频合并后的锚定下拉按钮。
  @override
  Widget build(BuildContext context) {
    // 获取主题主色，用于绘制桌面“更多”触发按钮。
    final primary = Theme.of(context).colorScheme.primary;
    // 胶囊触发器 hover 和按压反馈需要限制在按钮圆角内。
    final triggerRadius = BorderRadius.circular(18);
    // 设置中心未启用任何附加资源时完全隐藏入口，不能显示空菜单。
    if (widget.availableResources.isEmpty) return const SizedBox.shrink();
    // 下拉只编辑当前主任务选择，不创建或启动独立任务。
    return AppAnchoredDropdownMenu<DownloadExtraResource>(
      constraints: const BoxConstraints(minWidth: 168, maxWidth: 168),
      maxMenuHeight: 320,
      borderRadius: triggerRadius,
      splashRadius: 18,
      onSelected: (DownloadExtraResource resource) {
        // 选择后基于当前快照切换对应复选项。
        final nextResources = <DownloadExtraResource>{
          ...widget.selectedResources,
        };
        if (!nextResources.add(resource)) nextResources.remove(resource);
        widget.onChanged(
          Set<DownloadExtraResource>.unmodifiable(nextResources),
        );
      },
      itemBuilder: (BuildContext context) {
        // 菜单只渲染设置白名单中的资源，并用复选框表达是否随主任务下载。
        return widget.availableResources
            .map(
              (DownloadExtraResource resource) =>
                  PopupMenuItem<DownloadExtraResource>(
                    value: resource,
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AppCheckboxMenuItemRow(
                      selected: widget.selectedResources.contains(resource),
                      label: downloadExtraResourceLabel(resource),
                    ),
                  ),
            )
            .toList(growable: false);
      },
      childBuilder: (BuildContext context, bool open) => Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: primary.withValues(alpha: 0.55)),
          borderRadius: triggerRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '更多',
              style: TextStyle(color: primary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            Icon(
              open
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// 手机待下载卡片的紧凑附加资源菜单。
final class MobileResourceMenu extends StatelessWidget {
  /// 创建只占一个图标宽度的菜单入口。
  const MobileResourceMenu({
    required this.availableResources,
    required this.selectedResources,
    required this.onChanged,
    super.key,
  });

  /// 设置中心当前允许展示的资源。
  final Set<DownloadExtraResource> availableResources;

  /// 当前主任务已经勾选的资源。
  final Set<DownloadExtraResource> selectedResources;

  /// 用户切换后返回新的完整选择集合。
  final ValueChanged<Set<DownloadExtraResource>> onChanged;

  /// 构建与手机底部操作行尺寸一致的菜单按钮。
  @override
  Widget build(BuildContext context) {
    // 设置关闭全部附加资源时不保留无意义的手机图标占位。
    if (availableResources.isEmpty) return const SizedBox.shrink();
    return AppAnchoredDropdownMenu<DownloadExtraResource>(
      constraints: const BoxConstraints(minWidth: 168, maxWidth: 168),
      maxMenuHeight: 320,
      onSelected: (DownloadExtraResource resource) {
        // 手机端同样只切换主任务 JSON，不创建第二张任务卡片。
        final nextResources = <DownloadExtraResource>{...selectedResources};
        if (!nextResources.add(resource)) nextResources.remove(resource);
        onChanged(Set<DownloadExtraResource>.unmodifiable(nextResources));
      },
      itemBuilder: (BuildContext context) {
        // 手机端与桌面端使用同一设置白名单和复选状态。
        return availableResources
            .map(
              (DownloadExtraResource resource) =>
                  PopupMenuItem<DownloadExtraResource>(
                    value: resource,
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AppCheckboxMenuItemRow(
                      selected: selectedResources.contains(resource),
                      label: downloadExtraResourceLabel(resource),
                    ),
                  ),
            )
            .toList(growable: false);
      },
      childBuilder: (BuildContext context, bool open) => const SizedBox.square(
        dimension: 48,
        child: Icon(Icons.more_horiz_rounded),
      ),
    );
  }
}

/// 手机下载中或已下载任务的只读质量行。
final class MobileReadOnlyOption extends StatelessWidget {
  /// 创建只读标签和值。
  const MobileReadOnlyOption({
    required this.label,
    required this.value,
    super.key,
  });

  /// 字段名称。
  final String label;

  /// 当前任务实际使用的质量。
  final String value;

  /// 构建与手机下拉行等高的普通文字。
  @override
  Widget build(BuildContext context) {
    // 只读质量行与可编辑下拉行使用同一级手机端紧凑字号。
    final textStyle = Theme.of(context).textTheme.bodySmall;
    // 保留原有纵向内边距，切换阶段时卡片尺寸不会跳动。
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: <Widget>[
          Text(label, style: textStyle),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: textStyle,
            ),
          ),
        ],
      ),
    );
  }
}

/// 手机音质或画质锚定下拉行。
final class MobileOptionRow<T> extends StatelessWidget {
  /// 创建同步候选信息行。
  const MobileOptionRow({
    required this.label,
    required this.value,
    required this.options,
    required this.labelBuilder,
    required this.selectedBuilder,
    required this.onSelected,
    required this.onClear,
    required this.cleared,
    super.key,
  });

  /// 字段标签。
  final String label;

  /// 当前值。
  final String value;

  /// 解析时随任务入库的候选项。
  final List<T> options;

  /// 候选项显示文案转换器。
  final String Function(T option) labelBuilder;

  /// 判断候选项是否为当前选择。
  final bool Function(T option) selectedBuilder;

  /// 用户点击候选项后的保存回调。
  final ValueChanged<T> onSelected;

  /// 用户选择“无”时取消当前媒体流。
  final VoidCallback onClear;

  /// 当前媒体流是否已经取消。
  final bool cleared;

  /// 构建紧凑信息行。
  @override
  Widget build(BuildContext context) {
    // 触发行文字与弹出候选项统一使用 bodySmall，展开前后字号保持一致。
    final textStyle = Theme.of(context).textTheme.bodySmall;
    // 手机整行作为锚点，菜单在当前行下方展开。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 菜单最多占当前卡片宽度。
        final menuWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 280.0;
        // 复用公共锚定菜单行为，移动端只保留行内触发器布局差异。
        return AppAnchoredSelectionMenu<T>(
          options: options,
          constraints: BoxConstraints(minWidth: menuWidth, maxWidth: menuWidth),
          labelBuilder: labelBuilder,
          selectedBuilder: selectedBuilder,
          onSelected: onSelected,
          onClear: onClear,
          cleared: cleared,
          borderRadius: BorderRadius.circular(7),
          splashRadius: 16,
          fieldBuilder: (BuildContext context, bool open) =>
              AppAnchoredDropdownInlineRow(
                label: label,
                value: value,
                open: open,
                textStyle: textStyle,
              ),
        );
      },
    );
  }
}

/// 手机进度行使用的紧凑状态标签。
final class TaskStatusBadge extends StatelessWidget {
  /// 创建指定文字和语义颜色的标签。
  const TaskStatusBadge({required this.label, required this.color, super.key});

  /// 百分比或阶段文字。
  final String label;

  /// 标签前景及背景基准颜色。
  final Color color;

  /// 构建与 PC 进度百分比相同的圆角标签。
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
