import 'package:flutter/material.dart';

import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/widgets/app_toolbar_actions.dart';
import '../../application/ui_state/download_task_query_providers.dart';

/// v2 下划线任务页签。
final class TaskFilterTabs extends StatelessWidget {
  /// 创建页签、数量和选择回调。
  const TaskFilterTabs({
    required this.compact,
    required this.selected,
    required this.counts,
    required this.onSelected,
    super.key,
  });

  /// 是否在窄屏使用等分页签。
  final bool compact;

  /// 当前页签。
  final TaskFilter selected;

  /// 每个页签任务数量。
  final Map<TaskFilter, int> counts;

  /// 页签切换回调。
  final ValueChanged<TaskFilter> onSelected;

  /// 构建横向页签和底部分隔线。
  @override
  Widget build(BuildContext context) {
    // 数量为零时隐藏括号，避免空页签展示无意义的“(0)”。
    String labelWithCount(String label, TaskFilter filter) {
      // 从当前任务统计中读取页签数量。
      final count = counts[filter] ?? 0;
      // 仅有任务时追加数量。
      return count > 0 ? '$label ($count)' : label;
    }

    // 先创建三个页签，桌面宽度由文字和按钮内边距共同决定。
    final tabs = <Widget>[
      DownloadTaskTabButton(
        label: labelWithCount('待下载', TaskFilter.pending),
        selected: selected == TaskFilter.pending,
        horizontalPadding: compact ? 10 : 32,
        onPressed: () => onSelected(TaskFilter.pending),
      ),
      DownloadTaskTabButton(
        label: labelWithCount('下载中', TaskFilter.active),
        selected: selected == TaskFilter.active,
        horizontalPadding: compact ? 10 : 32,
        onPressed: () => onSelected(TaskFilter.active),
      ),
      DownloadTaskTabButton(
        label: labelWithCount('已下载', TaskFilter.completed),
        selected: selected == TaskFilter.completed,
        horizontalPadding: compact ? 10 : 32,
        onPressed: () => onSelected(TaskFilter.completed),
      ),
    ];
    // 页签容器提供统一底部分隔线。
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: tabs
            .map((Widget tab) => compact ? Expanded(child: tab) : tab)
            .toList(growable: false),
      ),
    );
  }
}

/// 单个下划线页签按钮。
final class DownloadTaskTabButton extends StatelessWidget {
  /// 创建页签按钮。
  const DownloadTaskTabButton({
    required this.label,
    required this.selected,
    required this.horizontalPadding,
    required this.onPressed,
    super.key,
  });

  /// 页签文本。
  final String label;

  /// 是否当前选中。
  final bool selected;

  /// 页签内容左右留白，桌面用于撑开自适应宽度。
  final double horizontalPadding;

  /// 点击回调。
  final VoidCallback onPressed;

  /// 构建选中态绿色下划线。
  @override
  Widget build(BuildContext context) {
    // 选中页签使用品牌色，未选中沿用正文颜色。
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    // InkWell 提供桌面悬停和移动端水波反馈，点击区域仍占满页签。
    return InkWell(
      onTap: onPressed,
      mouseCursor: SystemMouseCursors.click,
      child: Padding(
        // 左右留白负责撑开页签，标题含数量时可以随内容自然变宽。
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          10,
          horizontalPadding,
          0,
        ),
        child: Center(
          // 下划线只跟随页签文字宽度，不再铺满整个桌面或手机页签。
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: selected ? color : Colors.transparent,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 已下载页用于批量清理记录和可选成品文件的工具栏。
final class CompletedToolbar extends StatelessWidget {
  /// 创建已下载清空操作区。
  const CompletedToolbar({
    required this.mobile,
    required this.clearing,
    required this.processed,
    required this.total,
    required this.onClear,
    super.key,
  });

  /// 是否使用手机按钮规格。
  final bool mobile;

  /// 是否正在批量删除记录或文件。
  final bool clearing;

  /// 当前已经完成文件和记录处理的任务数量。
  final int processed;

  /// 当前确认快照包含的任务总数。
  final int total;

  /// 清空回调，没有已下载记录时为空。
  final VoidCallback? onClear;

  /// 构建靠左显示的危险操作按钮。
  @override
  Widget build(BuildContext context) {
    // 已获得任务快照时显示真实进度，平台批次准备阶段继续使用简短加载文案。
    final clearingLabel = total > 0 ? '清空中 $processed/$total' : '清空中…';
    // 公共按钮组件负责高度、危险色、加载圈和禁用状态。
    final clearButton = AppToolbarActionButton(
      compact: mobile,
      variant: AppToolbarActionVariant.destructiveOutlined,
      icon: Icons.delete_sweep_outlined,
      label: '清空',
      loading: clearing,
      loadingLabel: clearingLabel,
      onPressed: onClear,
    );
    if (mobile) {
      // 手机端只有一个清空按钮时也占满整行，避免左侧孤立小按钮破坏节奏。
      return SizedBox(width: double.infinity, child: clearButton);
    }
    return Align(alignment: Alignment.centerLeft, child: clearButton);
  }
}

/// 下载中页的批量清空和暂停工具栏。
final class ActiveToolbar extends StatelessWidget {
  /// 创建下载中任务批量操作工具栏。
  const ActiveToolbar({
    required this.mobile,
    required this.allPaused,
    required this.showToggle,
    required this.toggling,
    required this.clearing,
    required this.automaticShutdownLabel,
    required this.automaticShutdownArmed,
    required this.showAutomaticShutdown,
    required this.onToggle,
    required this.onClear,
    required this.onAutomaticShutdown,
    super.key,
  });

  /// 是否使用手机按钮规格。
  final bool mobile;

  /// 当前可见任务是否全部暂停，用于切换按钮语义。
  final bool allPaused;

  /// 当前列表是否仍包含可暂停或继续的下载阶段任务。
  final bool showToggle;

  /// 是否正在批量暂停或恢复。
  final bool toggling;

  /// 是否正在批量清空。
  final bool clearing;

  /// 自动关机按钮文案，启用后包含用户选择的延迟。
  final String automaticShutdownLabel;

  /// 当前下载批次是否已经绑定一次性自动关机计划。
  final bool automaticShutdownArmed;

  /// 当前平台是否允许展示系统自动关机入口。
  final bool showAutomaticShutdown;

  /// 批量暂停或恢复回调，没有任务时为空。
  final VoidCallback? onToggle;

  /// 批量清空回调，没有任务时为空。
  final VoidCallback? onClear;

  /// 创建或解除当前批次自动关机计划的回调。
  final VoidCallback? onAutomaticShutdown;

  /// 构建靠左横排的两个紧凑操作按钮。
  @override
  Widget build(BuildContext context) {
    // 任一批量操作运行时禁用两个按钮，防止状态交叉修改。
    final busy = toggling || clearing;
    // 清空按钮使用公共危险描边类型，加载态由组件内部统一处理。
    final clearButton = AppToolbarActionButton(
      compact: mobile,
      variant: AppToolbarActionVariant.destructiveOutlined,
      icon: Icons.delete_sweep_outlined,
      label: '清空',
      loading: clearing,
      onPressed: busy ? null : onClear,
    );
    // 全部暂停时按钮切换为继续，避免再次点击“暂停”没有反馈。
    final toggleButton = AppToolbarActionButton(
      compact: mobile,
      variant: AppToolbarActionVariant.filled,
      icon: allPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
      label: allPaused ? '继续' : '暂停',
      loading: toggling,
      onPressed: busy ? null : onToggle,
    );
    // 自动关机只绑定当前下载中列表，启用态使用主色提示已有一次性计划。
    final automaticShutdownButton = AppToolbarActionButton(
      compact: mobile,
      variant: AppToolbarActionVariant.outlined,
      icon: automaticShutdownArmed
          ? Icons.power_settings_new_rounded
          : Icons.schedule_rounded,
      label: automaticShutdownLabel,
      highlighted: automaticShutdownArmed,
      onPressed: busy ? null : onAutomaticShutdown,
    );
    if (mobile) {
      // 手机端三个批量操作等分撑满整行，和任务列表宽度建立对齐关系。
      return Row(
        children: <Widget>[
          Expanded(child: clearButton),
          if (showToggle) ...<Widget>[
            const SizedBox(width: 8),
            Expanded(child: toggleButton),
          ],
          if (showAutomaticShutdown) ...<Widget>[
            const SizedBox(width: 8),
            Expanded(child: automaticShutdownButton),
          ],
        ],
      );
    }
    // 桌面端继续使用自然宽度，避免批量工具栏过度拉伸。
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        clearButton,
        if (showToggle) toggleButton,
        if (showAutomaticShutdown) automaticShutdownButton,
      ],
    );
  }
}

/// 待下载页的存储和批量操作工具栏。
final class PendingToolbar extends StatelessWidget {
  /// 创建响应式工具栏。
  const PendingToolbar({
    required this.mobile,
    required this.storagePath,
    required this.starting,
    required this.onChangeStorage,
    required this.onCustomBatch,
    required this.onStart,
    required this.onClear,
    super.key,
  });

  /// 是否手机布局。
  final bool mobile;

  /// 当前存储目录。
  final String storagePath;

  /// 是否正在批量启动。
  final bool starting;

  /// 修改存储目录回调。
  final VoidCallback? onChangeStorage;

  /// 自定义批量回调。
  final VoidCallback? onCustomBatch;

  /// 启动当前待下载列表回调，列表为空时为空。
  final VoidCallback? onStart;

  /// 清空待下载回调，没有可清空项时为空。
  final VoidCallback? onClear;

  /// 构建设计稿中的桌面横排或手机两行工具栏。
  @override
  Widget build(BuildContext context) {
    // 存储栏可点击状态同时受启动中和平台目录选择能力限制。
    final canChangeStorage = !starting && onChangeStorage != null;
    // 存储目录收纳右侧“更改”小按钮，保持整块像一个输入框。
    final storagePathView = AppToolbarInfoField(
      compact: mobile,
      icon: Icons.folder_outlined,
      prefix: '存储： ',
      value: storagePath,
      onTap: canChangeStorage ? onChangeStorage : null,
      actionLabel: '更改',
    );
    // 自定义批量按钮对应设计稿次级操作。
    final custom = AppToolbarActionButton(
      compact: mobile,
      variant: AppToolbarActionVariant.outlined,
      icon: Icons.tune_rounded,
      label: '自定义批量',
      onPressed: starting ? null : onCustomBatch,
    );
    // 下载按钮启动当前待下载列表中的全部任务，不再展示选择数量。
    final download = AppToolbarActionButton(
      compact: mobile,
      variant: AppToolbarActionVariant.filled,
      icon: Icons.download_rounded,
      label: '下载视频',
      loading: starting,
      onPressed: starting ? null : onStart,
    );
    // 清空使用错误色边框表达破坏性。
    final clear = AppToolbarActionButton(
      compact: mobile,
      variant: AppToolbarActionVariant.destructiveOutlined,
      icon: Icons.delete_outline_rounded,
      label: '清空',
      onPressed: starting ? null : onClear,
    );
    // 手机端目录单独占一行，三个批量操作始终保持同一行。
    if (mobile) {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // 最窄手机保留文字语义并隐藏图标，避免用户只能依靠图形猜测操作。
          final textOnly = constraints.maxWidth < AppBreakpoints.smallMobile;
          // 紧凑模式的自定义批量按钮只显示文字。
          final compactCustom = AppToolbarActionButton(
            compact: mobile,
            variant: AppToolbarActionVariant.outlined,
            label: '自定义批量',
            onPressed: starting ? null : onCustomBatch,
            textOnly: true,
          );
          // 紧凑模式根据启动状态展示进度或下载文字。
          final compactDownload = AppToolbarActionButton(
            compact: mobile,
            variant: AppToolbarActionVariant.filled,
            label: '下载视频',
            loading: starting,
            onPressed: starting ? null : onStart,
            textOnly: true,
          );
          // 紧凑模式的清空按钮保留危险色文字和边框。
          final compactClear = AppToolbarActionButton(
            compact: mobile,
            variant: AppToolbarActionVariant.destructiveOutlined,
            label: '清空',
            onPressed: starting ? null : onClear,
            textOnly: true,
          );
          // 根据宽度在完整按钮和纯文字按钮之间切换，不改变三列结构。
          final customAction = textOnly ? compactCustom : custom;
          // 下载操作与自定义操作使用同一显示策略。
          final downloadAction = textOnly ? compactDownload : download;
          // 清空操作与另外两个按钮保持同一行和统一高度。
          final clearAction = textOnly ? compactClear : clear;
          // 根据当前实际宽度构建两行紧凑工具栏。
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              storagePathView,
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    // 自定义批量与下载按钮保持等宽，避免小屏下前者先被压缩换行。
                    flex: 5,
                    child: customAction,
                  ),
                  const SizedBox(width: 6),
                  Expanded(flex: 5, child: downloadAction),
                  const SizedBox(width: 6),
                  Expanded(flex: 3, child: clearAction),
                ],
              ),
            ],
          );
        },
      );
    }
    // PC 工具栏固定为单行，目录占用操作按钮之外的全部剩余宽度。
    return Row(
      children: <Widget>[
        Expanded(child: storagePathView),
        const SizedBox(width: 10),
        custom,
        const SizedBox(width: 10),
        download,
        const SizedBox(width: 10),
        clear,
      ],
    );
  }
}
