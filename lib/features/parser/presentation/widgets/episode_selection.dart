import 'package:flutter/material.dart';

import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../services/bilibili/models/bili_media_info.dart';

/// 响应式分集选择网格。
final class EpisodeGrid extends StatelessWidget {
  /// 创建分集选择网格。
  const EpisodeGrid({
    required this.episodes,
    required this.singleEpisodeTitle,
    required this.selectedIndexes,
    required this.interactionLocked,
    required this.onToggle,
    super.key,
  });

  /// 当前媒体全部分集。
  final List<BiliEpisodeInfo> episodes;

  /// 单条内容使用的视频总标题，多分集时为空。
  final String? singleEpisodeTitle;

  /// 已选中的分集 index。
  final Set<int> selectedIndexes;

  /// 入队处理中是否锁定分集点击。
  final bool interactionLocked;

  /// 点击分集回调。
  final ValueChanged<int> onToggle;

  /// 构建由外层 CustomScrollView 懒加载的桌面双列或手机单列 Sliver。
  @override
  Widget build(BuildContext context) {
    // 分集列数跟随应用外壳导航形态，避免桌面侧边栏状态退化成手机单列。
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.navigationRail;
    // 手机保持触控卡片，桌面双列使用更紧凑的单行高度。
    final columns = mobile ? 1 : 2;
    // SliverGrid 只构建视口附近卡片，超大合集不会一次创建全部 RenderObject。
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: mobile ? 52 : 64,
        crossAxisSpacing: 14,
        mainAxisSpacing: mobile ? 7 : 10,
      ),
      delegate: SliverChildBuilderDelegate((
        BuildContext context,
        int position,
      ) {
        // 读取当前位置分集和选择状态。
        final episode = episodes[position];
        // 根据分集索引读取选择状态。
        final selected = selectedIndexes.contains(episode.index);
        // ValueKey 只维持可见卡片身份，不持有离屏 BuildContext。
        return EpisodeTile(
          key: ValueKey<int>(episode.index),
          episode: episode,
          displayTitle: singleEpisodeTitle ?? episode.title,
          selected: selected,
          compact: mobile,
          enabled: !interactionLocked,
          onTap: () => onToggle(episode.index),
        );
      }, childCount: episodes.length),
    );
  }
}

/// 单条分集选择卡片。
final class EpisodeTile extends StatelessWidget {
  /// 创建分集卡片。
  const EpisodeTile({
    super.key,
    required this.episode,
    required this.displayTitle,
    required this.selected,
    required this.compact,
    required this.enabled,
    required this.onTap,
  });

  /// 当前分集信息。
  final BiliEpisodeInfo episode;

  /// 当前卡片实际展示的标题。
  final String displayTitle;

  /// 是否已选中。
  final bool selected;

  /// 是否使用手机端紧凑卡片规格。
  final bool compact;

  /// 当前卡片是否允许切换选择。
  final bool enabled;

  /// 点击切换回调。
  final VoidCallback onTap;

  /// 构建同时使用颜色、边框和复选框表达状态的卡片。
  @override
  Widget build(BuildContext context) {
    // 选中项使用低透明主色背景。
    final background = selected
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.10)
        : Theme.of(context).colorScheme.surface;
    // 选中项边框使用主色，未选中使用分隔色。
    final borderColor = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).dividerColor;
    // Material 和 InkWell 提供键鼠焦点和触摸反馈。
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 14,
            vertical: compact ? 4 : 6,
          ),
          child: Row(
            children: <Widget>[
              // 序号圆角标识帮助快速定位分集。
              Container(
                width: compact ? 28 : 34,
                height: compact ? 28 : 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : context.biliDownColors.secondarySurface,
                  borderRadius: BorderRadius.circular(compact ? 8 : 10),
                ),
                child: Text(
                  episode.index.toString(),
                  style: TextStyle(
                    color: selected
                        ? Theme.of(context).colorScheme.onPrimary
                        : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: compact ? 8 : 14),
              Expanded(
                child: Text(
                  displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: compact ? Theme.of(context).textTheme.bodySmall : null,
                ),
              ),
              // 复选框保留无障碍选择语义。
              Checkbox(
                value: selected,
                visualDensity: compact ? VisualDensity.compact : null,
                materialTapTargetSize: compact
                    ? MaterialTapTargetSize.shrinkWrap
                    : null,
                mouseCursor: enabled
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.forbidden,
                onChanged: enabled ? (_) => onTap() : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 分集选择固定操作栏。
final class SelectionActionBar extends StatelessWidget {
  /// 创建选择数量和入队操作栏。
  const SelectionActionBar({
    required this.selectedCount,
    required this.totalCount,
    required this.isQueuing,
    required this.queueProgressCurrent,
    required this.queueProgressTotal,
    required this.onToggleAll,
    required this.onQueue,
    super.key,
  });

  /// 已选择数量。
  final int selectedCount;

  /// 总分集数量。
  final int totalCount;

  /// 是否正在写入任务。
  final bool isQueuing;

  /// 入队当前处理的一基序号。
  final int queueProgressCurrent;

  /// 入队本轮需要处理的分集总数。
  final int queueProgressTotal;

  /// 全选或取消全选回调。
  final VoidCallback onToggleAll;

  /// 加入任务回调，未选择时为空。
  final VoidCallback? onQueue;

  /// 构建响应式底部操作区。
  @override
  Widget build(BuildContext context) {
    // 手机端严格使用设计稿的“数量 + 主按钮”单行操作栏。
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.navigationRail;
    // 入队期间主按钮显示当前分集进度，单集也明确反馈正在处理哪一项。
    final queueLabel = isQueuing && queueProgressTotal > 0
        ? '处理中 ${queueProgressCurrent.clamp(1, queueProgressTotal)}/$queueProgressTotal'
        : '解析选中项目';
    // 操作栏使用表面色、顶部分隔线和安全区域。
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? 12 : 24,
            vertical: mobile ? 8 : 14,
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              // 手机底部栏不显示额外全选按钮，避免偏离设计稿和挤压主操作。
              if (mobile) {
                // 空选、部分选择和全部选择分别映射为空框、横杠和勾选状态。
                final selectAllValue = _selectAllValue();
                return Row(
                  children: <Widget>[
                    Checkbox(
                      tristate: true,
                      value: selectAllValue,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      mouseCursor: isQueuing
                          ? SystemMouseCursors.forbidden
                          : SystemMouseCursors.click,
                      onChanged: isQueuing
                          ? null
                          : (_) {
                              // 控制器会在全部选中时取消全选，其余状态统一执行全选。
                              onToggleAll();
                            },
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text('已选择 $selectedCount 项')),
                    const SizedBox(width: 12),
                    AppActionButton(
                      variant: AppActionButtonVariant.filled,
                      onPressed: onQueue,
                      loading: isQueuing,
                      loadingLabel: queueLabel,
                      label: '解析选中项目',
                    ),
                  ],
                );
              }
              // 560 像素以下缩短按钮宽度但保持同一行。
              final compact =
                  constraints.maxWidth < AppBreakpoints.parserActionBarCompact;
              // 380 像素以下改为两行，避免两个按钮争抢有限宽度。
              final stacked =
                  constraints.maxWidth < AppBreakpoints.parserActionBarStack;
              // 选择统计文本。
              final countLabel = Text('已选择 $selectedCount / $totalCount');
              // 主操作显示入队进度。
              final queueButton = AppActionButton(
                variant: AppActionButtonVariant.filled,
                onPressed: onQueue,
                loading: isQueuing,
                loadingLabel: queueLabel,
                icon: Icons.playlist_add_rounded,
                label: '解析选中项目',
              );
              // 极窄窗口把选择信息和主操作拆行，所有子项都获得有限宽度。
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        AppActionButton(
                          variant: AppActionButtonVariant.outlined,
                          onPressed: isQueuing ? null : onToggleAll,
                          label: selectedCount == totalCount ? '取消' : '全选',
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: countLabel),
                      ],
                    ),
                    const SizedBox(height: 10),
                    queueButton,
                  ],
                );
              }
              // 手机使用紧凑全选按钮和扩展主按钮。
              if (compact) {
                return Row(
                  children: <Widget>[
                    AppActionButton(
                      variant: AppActionButtonVariant.outlined,
                      onPressed: isQueuing ? null : onToggleAll,
                      label: selectedCount == totalCount ? '取消' : '全选',
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: queueButton),
                  ],
                );
              }
              // 桌面同时展示全选、数量和右侧宽主按钮。
              return Row(
                children: <Widget>[
                  AppActionButton(
                    variant: AppActionButtonVariant.outlined,
                    onPressed: isQueuing ? null : onToggleAll,
                    label: selectedCount == totalCount ? '取消全选' : '全选',
                  ),
                  const SizedBox(width: 20),
                  countLabel,
                  const Spacer(),
                  queueButton,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 返回移动端全选复选框的三态值。
  bool? _selectAllValue() {
    // 空选时展示未勾选。
    if (selectedCount == 0) return false;
    // 全部选中时展示勾选。
    if (selectedCount == totalCount) return true;
    // 部分选中时展示半选。
    return null;
  }
}
