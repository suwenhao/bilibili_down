import 'package:flutter/material.dart';

/// 侧滑操作按钮的领域无关配置。
final class AppSwipeAction {
  /// 创建一个侧滑操作按钮。
  const AppSwipeAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
  });

  /// 操作图标。
  final IconData icon;

  /// 操作文案。
  final String label;

  /// 点击操作后的回调。
  final VoidCallback onPressed;

  /// 操作区域背景色；为空时使用主题错误色。
  final Color? backgroundColor;

  /// 操作图标和文字颜色；为空时使用背景色对应的前景色。
  final Color? foregroundColor;
}

/// 通用列表项侧滑架子，支持左右两侧和多个操作按钮。
final class AppSwipeRevealActions extends StatefulWidget {
  /// 创建一个可复用的侧滑操作包装。
  const AppSwipeRevealActions({
    required this.itemId,
    required this.child,
    this.startActions = const <AppSwipeAction>[],
    this.endActions = const <AppSwipeAction>[],
    this.actionWidth = 64,
    this.maxRevealExtent,
    this.borderRadius = BorderRadius.zero,
    this.onTap,
    super.key,
  });

  /// 当前列表项 ID，用于列表复用 Widget 时识别身份变化。
  final String itemId;

  /// 被滑动的列表项主体；高度完全由业务列表项自身决定。
  final Widget child;

  /// 从左侧露出的操作按钮，用户向右滑时展示。
  final List<AppSwipeAction> startActions;

  /// 从右侧露出的操作按钮，用户向左滑时展示。
  final List<AppSwipeAction> endActions;

  /// 单个侧滑按钮的宽度。
  final double actionWidth;

  /// 最大露出宽度；为空时等于对应侧按钮数量乘以按钮宽度。
  final double? maxRevealExtent;

  /// 侧滑操作背景的外侧圆角，由使用方按卡片圆角传入。
  final BorderRadius borderRadius;

  /// 主体未展开时的点击回调，适合进入详情页等非破坏性操作。
  final VoidCallback? onTap;

  /// 创建侧滑状态。
  @override
  State<AppSwipeRevealActions> createState() => _AppSwipeRevealActionsState();
}

/// 管理列表项的左右侧滑展开距离。
final class _AppSwipeRevealActionsState extends State<AppSwipeRevealActions> {
  /// 操作按钮向卡片下方延伸的宽度，用于让卡片圆角盖在按钮背景上。
  static const double _actionUnderlayExtent = 18;

  /// 当前已经展开的侧滑项，用于点其它卡片时自动收起旧项。
  static _AppSwipeRevealActionsState? _openedState;

  /// 当前卡片偏移量；负数表示向左露出右侧按钮，正数表示向右露出左侧按钮。
  double _dragOffset = 0;

  /// 左侧操作总露出宽度。
  double get _startRevealExtent =>
      _effectiveRevealExtent(widget.startActions.length);

  /// 右侧操作总露出宽度。
  double get _endRevealExtent =>
      _effectiveRevealExtent(widget.endActions.length);

  /// 计算指定侧操作可露出的最大宽度。
  double _effectiveRevealExtent(int actionCount) {
    // 没有按钮的一侧不能被拖出空白区域。
    if (actionCount <= 0) return 0;
    // 使用方可限制最大宽度；默认按按钮数量自然展开。
    final naturalExtent = widget.actionWidth * actionCount;
    final maxReveal = widget.maxRevealExtent;
    return maxReveal == null
        ? naturalExtent
        : naturalExtent.clamp(0, maxReveal);
  }

  /// Widget 绑定到新记录时关闭旧侧滑状态，避免删除后状态串到下一项。
  @override
  void didUpdateWidget(covariant AppSwipeRevealActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemId == widget.itemId) return;
    // 列表删除后 Flutter 可能复用 State 给下一条记录，必须清空展开状态。
    _close();
  }

  /// 收起当前已经展开的侧滑项。
  void _close() {
    // 已经关闭时不触发多余重建。
    if (_dragOffset == 0) return;
    setState(() => _dragOffset = 0);
    if (_openedState == this) _openedState = null;
  }

  /// 点到其它卡片时关闭旧的侧滑项。
  void _closeOtherOpenedItem() {
    // 同一张卡片打开时点击自身只负责收起。
    if (_openedState == null || _openedState == this) return;
    _openedState?._close();
  }

  /// 按拖动距离更新卡片位置，限制在左右可用操作区之间。
  void _updateDragOffset(double deltaDx) {
    // 开始拖动当前卡片时先关闭其它已展开卡片。
    _closeOtherOpenedItem();
    // 左右两侧分别按是否配置操作按钮决定可拖动范围。
    final nextOffset = (_dragOffset + deltaDx).clamp(
      -_endRevealExtent,
      _startRevealExtent,
    );
    if (nextOffset == _dragOffset) return;
    setState(() => _dragOffset = nextOffset);
  }

  /// 手势结束后按阈值吸附到打开或关闭状态。
  void _settleDragOffset() {
    // 根据当前拖动方向选择对应侧的阈值，小幅误触会自动回收。
    final nextOffset = switch (_dragOffset) {
      < 0 when _dragOffset.abs() > _endRevealExtent * 0.5 => -_endRevealExtent,
      > 0 when _dragOffset > _startRevealExtent * 0.5 => _startRevealExtent,
      _ => 0.0,
    };
    if (nextOffset != _dragOffset) {
      setState(() => _dragOffset = nextOffset);
    }
    // 记录当前展开项，下一次点击其它卡片时会自动关闭。
    _openedState = nextOffset == 0 ? null : this;
  }

  /// 移除组件时清理全局展开引用，避免列表回收后持有旧状态。
  @override
  void dispose() {
    // 列表项被回收时同步清空全局展开状态。
    if (_openedState == this) _openedState = null;
    super.dispose();
  }

  /// 构建左右两侧的操作背景和可滑动主体。
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (DragUpdateDetails details) {
        // 只响应横向拖动，纵向滚动仍交给外层列表。
        _updateDragOffset(details.delta.dx);
      },
      onHorizontalDragEnd: (DragEndDetails details) {
        // 松手后吸附，保持“滑开后再点击操作”的交互。
        _settleDragOffset();
      },
      child: Stack(
        children: <Widget>[
          if (widget.startActions.isNotEmpty)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _SwipeActionRail(
                  actions: widget.startActions,
                  actionWidth: widget.actionWidth,
                  side: _SwipeActionSide.start,
                  borderRadius: widget.borderRadius,
                  underlayExtent: _actionUnderlayExtent,
                  onActionPressed: _close,
                ),
              ),
            ),
          if (widget.endActions.isNotEmpty)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: _SwipeActionRail(
                  actions: widget.endActions,
                  actionWidth: widget.actionWidth,
                  side: _SwipeActionSide.end,
                  borderRadius: widget.borderRadius,
                  underlayExtent: _actionUnderlayExtent,
                  onActionPressed: _close,
                ),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_dragOffset, 0, 0),
            child: GestureDetector(
              onTap: () {
                // 已展开时点击卡片自身收起；点击其它卡片时收起旧项。
                if (_dragOffset != 0) {
                  _close();
                } else if (_openedState != null && _openedState != this) {
                  // 其它卡片处于展开状态时，本次点击只负责收起，不触发业务跳转。
                  _closeOtherOpenedItem();
                } else {
                  // 无展开状态时把点击交给业务列表项。
                  widget.onTap?.call();
                }
              },
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

/// 侧滑操作所在方向。
enum _SwipeActionSide {
  /// 左侧操作区。
  start,

  /// 右侧操作区。
  end,
}

/// 侧滑按钮轨道，宽度由按钮数量决定，高度跟随父级列表项。
final class _SwipeActionRail extends StatelessWidget {
  /// 创建一个侧滑按钮轨道。
  const _SwipeActionRail({
    required this.actions,
    required this.actionWidth,
    required this.side,
    required this.borderRadius,
    required this.underlayExtent,
    required this.onActionPressed,
  });

  /// 当前侧展示的操作列表。
  final List<AppSwipeAction> actions;

  /// 单个按钮宽度。
  final double actionWidth;

  /// 当前操作区方向。
  final _SwipeActionSide side;

  /// 操作区外侧圆角。
  final BorderRadius borderRadius;

  /// 操作按钮向卡片主体下方延伸的宽度。
  final double underlayExtent;

  /// 操作执行前的关闭回调。
  final VoidCallback onActionPressed;

  /// 构建侧滑操作按钮组。
  @override
  Widget build(BuildContext context) {
    // 轨道比真实露出宽度多一段，让按钮背景铺到卡片圆角下面。
    final railWidth = actionWidth * actions.length + underlayExtent;
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: railWidth,
        height: double.infinity,
        child: Row(
          mainAxisAlignment: side == _SwipeActionSide.start
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          children: <Widget>[
            for (var index = 0; index < actions.length; index++)
              SizedBox(
                width: _actionButtonWidth(index),
                height: double.infinity,
                child: _SwipeActionButton(
                  action: actions[index],
                  side: side,
                  underlayExtent: _isInnerAction(index) ? underlayExtent : 0,
                  onActionPressed: onActionPressed,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 计算按钮宽度；靠近卡片的一颗按钮额外延伸到卡片下方。
  double _actionButtonWidth(int index) {
    // 只有贴着卡片的按钮需要加宽，多个按钮时外侧按钮保持原本宽度。
    return actionWidth + (_isInnerAction(index) ? underlayExtent : 0);
  }

  /// 判断当前按钮是否是贴近卡片主体的那一颗。
  bool _isInnerAction(int index) {
    // 左侧轨道贴近卡片的是最右侧按钮，右侧轨道贴近卡片的是最左侧按钮。
    return side == _SwipeActionSide.start
        ? index == actions.length - 1
        : index == 0;
  }
}

/// 单个侧滑操作按钮。
final class _SwipeActionButton extends StatelessWidget {
  /// 创建侧滑按钮。
  const _SwipeActionButton({
    required this.action,
    required this.side,
    required this.underlayExtent,
    required this.onActionPressed,
  });

  /// 当前按钮配置。
  final AppSwipeAction action;

  /// 当前按钮所在侧，用于把内容避开被卡片盖住的区域。
  final _SwipeActionSide side;

  /// 被卡片覆盖的按钮背景宽度。
  final double underlayExtent;

  /// 业务回调前需要先收起侧滑。
  final VoidCallback onActionPressed;

  /// 构建图标和文字垂直居中的操作按钮。
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = action.backgroundColor ?? colorScheme.error;
    final foregroundColor = action.foregroundColor ?? colorScheme.onError;
    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: () {
          // 点击操作后先关闭侧滑，再执行外部业务，避免删除成功后展开状态串到下一项。
          onActionPressed();
          action.onPressed();
        },
        mouseCursor: SystemMouseCursors.click,
        child: Padding(
          padding: EdgeInsets.only(
            // 右侧按钮的左半段会压到卡片下方，内容需要移到真实露出区域。
            left: side == _SwipeActionSide.end ? underlayExtent : 0,
            // 左侧按钮的右半段会压到卡片下方，内容需要移到真实露出区域。
            right: side == _SwipeActionSide.start ? underlayExtent : 0,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(action.icon, color: foregroundColor, size: 22),
              const SizedBox(height: 4),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
