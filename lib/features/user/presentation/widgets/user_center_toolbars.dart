part of '../user_center_page.dart';

/// 用户中心页签和批量操作工具栏。
final class UserToolbar extends StatelessWidget {
  /// 创建页签、批量解析和选择入口。
  const UserToolbar({
    super.key,
    required this.selected,
    required this.selecting,
    required this.batchQueuing,
    required this.batchProgressCurrent,
    required this.batchProgressTotal,
    required this.selectedCount,
    required this.selectableCount,
    required this.mobile,
    required this.searchEnabled,
    required this.onSearch,
    required this.onRefresh,
    required this.onSelected,
    required this.onToggleSelecting,
    required this.onToggleAllSelection,
    required this.onBatchQueue,
  });

  /// 当前选中页签。
  final UserContentTab selected;

  /// 当前是否处于选择模式。
  final bool selecting;

  /// 是否正在批量解析入队。
  final bool batchQueuing;

  /// 批量解析当前处理的一基序号。
  final int batchProgressCurrent;

  /// 批量解析本轮需要处理的视频条目总数。
  final int batchProgressTotal;

  /// 当前选中数量。
  final int selectedCount;

  /// 当前页签可选择视频数量。
  final int selectableCount;

  /// 是否使用移动端纵向工具栏。
  final bool mobile;

  /// 当前页签是否允许展示搜索入口。
  final bool searchEnabled;

  /// 打开当前页签的搜索子页面。
  final VoidCallback onSearch;

  /// 桌面端刷新当前页签；移动端为空并使用下拉刷新。
  final VoidCallback? onRefresh;

  /// 点击页签后的回调。
  final ValueChanged<UserContentTab> onSelected;

  /// 开启或退出选择模式。
  final VoidCallback onToggleSelecting;

  /// 全选或清空当前页签可解析视频。
  final VoidCallback onToggleAllSelection;

  /// 批量解析入队回调。
  final VoidCallback? onBatchQueue;

  /// 构建可横向滚动的页签按钮。
  @override
  Widget build(BuildContext context) {
    final tabs = <UserContentTab, String>{
      UserContentTab.history: '历史',
      UserContentTab.uploads: '稿件',
      UserContentTab.favorites: '收藏',
      UserContentTab.likes: '点赞',
    };
    final tabBar = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.entries
            .map((entry) {
              // 当前页签只改变单选状态，视觉统一交给公共选择按钮处理。
              final active = selected == entry.key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AppSelectionChip(
                  selected: active,
                  label: entry.value,
                  enabled: !batchQueuing,
                  onSelected: (_) => onSelected(entry.key),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
    // 收藏夹主列表不是视频列表，选择入口在没有可解析视频时禁用。
    final canSelect = selectableCount > 0 && !batchQueuing;
    final batchButton = AppActionButton(
      variant: AppActionButtonVariant.filled,
      onPressed: onBatchQueue,
      loading: batchQueuing,
      loadingLabel: userBatchLoadingLabel(
        batchProgressCurrent,
        batchProgressTotal,
      ),
      icon: Icons.playlist_add_check_rounded,
      label: '批量解析下载',
    );
    final selectButton = AppActionButton(
      variant: AppActionButtonVariant.outlined,
      highlighted: selecting,
      onPressed: canSelect ? onToggleSelecting : null,
      icon: selecting ? Icons.close_rounded : Icons.checklist_rounded,
      label: selecting ? '取消选择' : '选择',
    );
    final searchButton = searchEnabled
        ? AppCircleIconButton(
            tooltip: selected == UserContentTab.favorites ? '搜索收藏' : '搜索历史',
            variant: AppCircleIconButtonVariant.outlined,
            dimension: AppControlSizes.buttonMediumHeight,
            iconSize: 17,
            onPressed: batchQueuing ? null : onSearch,
            icon: const Icon(Icons.search_rounded),
          )
        : null;
    final refreshButton = AppCircleIconButton(
      tooltip: '刷新当前页',
      variant: AppCircleIconButtonVariant.outlined,
      dimension: AppControlSizes.buttonMediumHeight,
      iconSize: 17,
      onPressed: onRefresh,
      icon: const Icon(Icons.refresh_rounded),
    );
    final selectionSummary = selecting
        ? SelectionSummary(
            selectedCount: selectedCount,
            selectableCount: selectableCount,
            enabled: canSelect,
            onToggleAll: onToggleAllSelection,
          )
        : null;
    final desktopActions = <Widget>[
      ?selectionSummary,
      ?searchButton,
      refreshButton,
      batchButton,
      selectButton,
    ];
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          tabBar,
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              if (searchButton != null) ...<Widget>[
                searchButton,
                const SizedBox(width: 8),
              ],
              Expanded(child: batchButton),
              const SizedBox(width: 8),
              selectButton,
            ],
          ),
          if (selectionSummary != null) ...<Widget>[
            const SizedBox(height: 6),
            selectionSummary,
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // 选择模式会增加全选、计数和取消按钮，固定上下两行避免依赖不可预测的文字宽度。
        final shouldStackToolbar = selecting;
        if (shouldStackToolbar) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              tabBar,
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _spacedToolbarActions(desktopActions, gap: 8),
                ),
              ),
            ],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: tabBar),
            ),
            const SizedBox(width: 12),
            Flexible(
              fit: FlexFit.loose,
              child: Align(
                alignment: Alignment.centerRight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _spacedToolbarActions(desktopActions, gap: 8),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 给桌面操作按钮插入固定间距，避免窄宽度滚动时按钮粘连。
  List<Widget> _spacedToolbarActions(
    List<Widget> children, {
    required double gap,
  }) {
    final spaced = <Widget>[];
    for (var index = 0; index < children.length; index += 1) {
      // 非首个控件前插入间距，保持滚动内容宽度可预测。
      if (index > 0) spaced.add(SizedBox(width: gap));
      spaced.add(children[index]);
    }
    return spaced;
  }
}

/// 收藏夹详情批量操作工具栏。
final class FavoriteDetailToolbar extends StatelessWidget {
  /// 创建收藏夹详情的批量解析和选择入口。
  const FavoriteDetailToolbar({
    super.key,
    required this.selecting,
    required this.batchQueuing,
    required this.batchProgressCurrent,
    required this.batchProgressTotal,
    required this.selectedCount,
    required this.selectableCount,
    required this.mobile,
    required this.onToggleSelecting,
    required this.onToggleAllSelection,
    required this.onBatchQueue,
  });

  /// 当前详情页是否处于选择模式。
  final bool selecting;

  /// 当前是否正在批量解析入队。
  final bool batchQueuing;

  /// 批量解析当前处理的一基序号。
  final int batchProgressCurrent;

  /// 批量解析本轮需要处理的视频条目总数。
  final int batchProgressTotal;

  /// 已选择的视频数量。
  final int selectedCount;

  /// 当前已加载且可选择的视频数量。
  final int selectableCount;

  /// 是否使用移动端纵向按钮布局。
  final bool mobile;

  /// 开启或退出选择模式。
  final VoidCallback onToggleSelecting;

  /// 全选或清空当前详情页可解析视频。
  final VoidCallback onToggleAllSelection;

  /// 执行批量解析入队。
  final VoidCallback? onBatchQueue;

  /// 构建收藏详情中的批量按钮组。
  @override
  Widget build(BuildContext context) {
    final canSelect = selectableCount > 0 && !batchQueuing;
    final batchButton = AppActionButton(
      variant: AppActionButtonVariant.filled,
      onPressed: onBatchQueue,
      loading: batchQueuing,
      loadingLabel: userBatchLoadingLabel(
        batchProgressCurrent,
        batchProgressTotal,
      ),
      icon: Icons.playlist_add_check_rounded,
      label: '批量解析下载',
    );
    final selectButton = AppActionButton(
      variant: AppActionButtonVariant.outlined,
      highlighted: selecting,
      onPressed: canSelect ? onToggleSelecting : null,
      icon: selecting ? Icons.close_rounded : Icons.checklist_rounded,
      label: selecting ? '取消选择' : '选择',
    );
    final selectionSummary = selecting
        ? SelectionSummary(
            selectedCount: selectedCount,
            selectableCount: selectableCount,
            enabled: canSelect,
            onToggleAll: onToggleAllSelection,
          )
        : null;
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: batchButton),
              const SizedBox(width: 8),
              selectButton,
            ],
          ),
          if (selectionSummary != null) ...<Widget>[
            const SizedBox(height: 6),
            selectionSummary,
          ],
        ],
      );
    }
    return Row(
      children: <Widget>[
        batchButton,
        const SizedBox(width: 8),
        selectButton,
        if (selectionSummary != null) ...<Widget>[
          const SizedBox(width: 12),
          selectionSummary,
        ],
      ],
    );
  }
}

/// 选择模式下展示全选状态和已选数量。
final class SelectionSummary extends StatelessWidget {
  /// 创建三态全选复选框和数量文本。
  const SelectionSummary({
    super.key,
    required this.selectedCount,
    required this.selectableCount,
    required this.enabled,
    required this.onToggleAll,
  });

  /// 当前已选择的视频数量。
  final int selectedCount;

  /// 当前列表中可选择的视频数量。
  final int selectableCount;

  /// 当前批量操作是否允许切换全选。
  final bool enabled;

  /// 点击复选框后全选或清空当前列表。
  final VoidCallback onToggleAll;

  /// 构建三态复选框和计数文案。
  @override
  Widget build(BuildContext context) {
    final checkboxValue = _checkboxValue;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox.square(
          dimension: 32,
          child: Checkbox(
            value: checkboxValue,
            tristate: true,
            mouseCursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.forbidden,
            onChanged: enabled ? (_) => onToggleAll() : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '已选择 $selectedCount / $selectableCount',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// 根据已选数量返回未选、半选或全选状态。
  bool? get _checkboxValue {
    if (selectableCount <= 0 || selectedCount <= 0) return false;
    if (selectedCount >= selectableCount) return true;
    return null;
  }
}
