import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_action_button.dart';
import 'app_icon_buttons.dart';

/// 应用提示的语义类型。
enum AppSnackBarType {
  /// 不强调结果的普通提示。
  normal,

  /// 操作成功提示。
  success,

  /// 操作或请求失败提示。
  error,

  /// 需要用户留意但不阻断流程的警告。
  warning,

  /// 功能说明或状态信息。
  info,
}

/// 应用提示相对窗口的垂直位置。
enum AppSnackBarPosition {
  /// 显示在窗口安全区顶部。
  top,

  /// 显示在窗口安全区底部。
  bottom,
}

/// 应用提示的水平布局方式。
enum AppSnackBarLayout {
  /// 居中显示并限制最大宽度。
  centered,

  /// 在安全边距内横向撑满。
  fullWidth,
}

/// 跨页面、弹窗和 Scaffold 共用的应用提示入口。
abstract final class AppSnackBar {
  /// 当前显示的 Overlay 条目；新提示会替换旧提示。
  static OverlayEntry? _currentEntry;

  /// 当前提示状态键，用于外部主动关闭时播放退出动画。
  static GlobalKey<_AppSnackBarOverlayState>? _currentKey;

  /// 应用根部注册的最高层 Overlay，用于盖住路由、弹窗和应用级遮罩。
  static GlobalKey<OverlayState>? _topOverlayKey;

  /// 注册应用根部的最高提示层。
  static void registerTopOverlay(GlobalKey<OverlayState> key) {
    // 根组件重建时更新引用，后续提示统一进入最外层 Overlay。
    _topOverlayKey = key;
  }

  /// 注销指定的最高提示层，避免热重启或根组件销毁后保留失效引用。
  static void unregisterTopOverlay(GlobalKey<OverlayState> key) {
    // 只清理当前注册的同一个 key，防止迟到 dispose 清掉新的应用实例。
    if (!identical(_topOverlayKey, key)) return;
    _topOverlayKey = null;
  }

  /// 显示一条具有类型、位置和宽度策略的应用提示。
  static void show(
    BuildContext context, {
    required String message,
    AppSnackBarType type = AppSnackBarType.normal,
    AppSnackBarPosition position = AppSnackBarPosition.top,
    AppSnackBarLayout layout = AppSnackBarLayout.centered,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    // 优先使用应用根 Stack 最高层 Overlay，普通根 Overlay 仍可能位于应用级遮罩下面。
    final overlay =
        _topOverlayKey?.currentState ??
        Overlay.maybeOf(context, rootOverlay: true);
    // 启动、退出或错误恢复边界可能暂时没有 Overlay，提示不能反向制造崩溃。
    if (overlay == null) return;
    showInOverlay(
      overlay,
      message: message,
      type: type,
      position: position,
      layout: layout,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// 使用已经解析出的 Overlay 显示应用提示，适合根 Navigator 等无页面 context 的场景。
  static void showInOverlay(
    OverlayState overlay, {
    required String message,
    AppSnackBarType type = AppSnackBarType.normal,
    AppSnackBarPosition position = AppSnackBarPosition.top,
    AppSnackBarLayout layout = AppSnackBarLayout.centered,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    // 空文案没有可展示信息，避免创建无意义 Overlay。
    if (message.trim().isEmpty) return;
    // 显式传入的路由 Overlay 也要让位给应用最高层，确保提示不被自绘遮罩挡住。
    final targetOverlay = _topOverlayKey?.currentState ?? overlay;
    // 同一时间只保留最新提示，防止批量错误堆叠遮挡界面。
    _removeImmediately();
    // 状态键供 hide 方法调用当前提示的退出动画。
    final overlayKey = GlobalKey<_AppSnackBarOverlayState>();
    // 延迟声明用于在关闭回调中核对当前条目身份。
    late final OverlayEntry entry;
    // Overlay 构建提示位置、样式和生命周期组件。
    entry = OverlayEntry(
      builder: (BuildContext overlayContext) => _AppSnackBarOverlay(
        key: overlayKey,
        message: message,
        type: type,
        position: position,
        layout: layout,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismissed: () {
          // 旧提示的异步回调不能移除后来显示的新提示。
          if (!identical(_currentEntry, entry)) return;
          _removeImmediately();
        },
      ),
    );
    // 保存当前条目和状态键后插入最终提示 Overlay。
    _currentEntry = entry;
    _currentKey = overlayKey;
    targetOverlay.insert(entry);
  }

  /// 主动关闭当前提示并播放退出动画。
  static void hide() {
    // Overlay 首帧尚未完成时状态可能为空，此时直接移除条目。
    final state = _currentKey?.currentState;
    if (state == null) {
      _removeImmediately();
      return;
    }
    // 状态组件负责取消计时并执行反向动画。
    unawaited(state.dismiss());
  }

  /// 不播放动画地释放当前 Overlay 条目。
  static void _removeImmediately() {
    // 保存旧条目后立即清空静态引用，避免 dispose 回调重入。
    final entry = _currentEntry;
    _currentEntry = null;
    _currentKey = null;
    // 没有提示时无需操作 Overlay。
    if (entry == null) return;
    // 根导航销毁时条目可能已经卸载，仅对仍挂载条目执行 remove。
    if (entry.mounted) entry.remove();
    // remove 与 dispose 必须配对，防止 OverlayEntry 持有旧 Widget 树。
    entry.dispose();
  }
}

/// 管理提示的进入、停留和退出动画。
final class _AppSnackBarOverlay extends StatefulWidget {
  /// 创建一条应用级 Overlay 提示。
  const _AppSnackBarOverlay({
    required this.message,
    required this.type,
    required this.position,
    required this.layout,
    required this.duration,
    required this.onDismissed,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// 提示正文。
  final String message;

  /// 提示语义类型。
  final AppSnackBarType type;

  /// 顶部或底部位置。
  final AppSnackBarPosition position;

  /// 居中限宽或横向撑满布局。
  final AppSnackBarLayout layout;

  /// 自动关闭前的停留时间。
  final Duration duration;

  /// 可选操作按钮文案。
  final String? actionLabel;

  /// 可选操作回调。
  final VoidCallback? onAction;

  /// 退出动画完成后的条目释放回调。
  final VoidCallback onDismissed;

  /// 创建提示动画状态。
  @override
  State<_AppSnackBarOverlay> createState() => _AppSnackBarOverlayState();
}

/// 控制应用提示动画、自动关闭计时和操作响应。
final class _AppSnackBarOverlayState extends State<_AppSnackBarOverlay>
    with SingleTickerProviderStateMixin {
  /// 提示进入和退出动画控制器。
  late final AnimationController _controller;

  /// 透明度与位移动画共用的缓动进度。
  late final Animation<double> _animation;

  /// 自动关闭计时器。
  Timer? _dismissTimer;

  /// 防止操作按钮和计时器重复触发退出流程。
  bool _dismissing = false;

  /// 初始化动画并启动自动关闭计时。
  @override
  void initState() {
    super.initState();
    // 短动画保持提示反馈及时，同时避免突然闪现。
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 140),
    );
    // 标准缓出曲线用于进入，反向播放时自然收起。
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    // 外部 Overlay 插入完成后立即播放进入动画。
    unawaited(_controller.forward());
    // 非正时长表示由调用方手动关闭，不启动自动计时。
    if (widget.duration > Duration.zero) {
      _dismissTimer = Timer(widget.duration, () {
        unawaited(dismiss());
      });
    }
  }

  /// 取消计时并释放动画控制器。
  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// 播放退出动画并通知公共入口移除 Overlay。
  Future<void> dismiss() async {
    // 已在退出时忽略重复关闭请求。
    if (_dismissing) return;
    _dismissing = true;
    // 用户操作关闭后不允许自动计时再次触发。
    _dismissTimer?.cancel();
    // Widget 仍挂载时反向播放提示动画。
    if (mounted) await _controller.reverse();
    // Overlay 可能已被新提示替换，回调会再次核对条目身份。
    widget.onDismissed();
  }

  /// 执行可选操作并关闭当前提示。
  void _handleAction() {
    try {
      // 业务回调先执行，便于立即开始重试或跳转。
      widget.onAction?.call();
    } finally {
      // 即使业务回调同步抛错也要收起旧提示，避免界面残留。
      unawaited(dismiss());
    }
  }

  /// 构建顶部或底部的居中/撑满提示卡片。
  @override
  Widget build(BuildContext context) {
    // 当前设备安全区用于避开状态栏和系统手势区域。
    final mediaPadding = MediaQuery.paddingOf(context);
    // 顶部提示从安全区向下留出 12dp。
    final top = widget.position == AppSnackBarPosition.top
        ? mediaPadding.top + 12
        : null;
    // 底部提示从安全区向上留出 12dp。
    final bottom = widget.position == AppSnackBarPosition.bottom
        ? mediaPadding.bottom + 12
        : null;
    // 不同语义类型映射到主题染色表面、强调色和状态图标。
    final visuals = _snackBarVisuals(context, widget.type);
    // 居中模式按参考图限制为紧凑浮层，撑满模式使用全部安全宽度。
    final maxWidth = widget.layout == AppSnackBarLayout.centered
        ? 400.0
        : double.infinity;
    // 顶部从上方向内滑入，底部从下方向内滑入。
    final beginOffset = widget.position == AppSnackBarPosition.top
        ? const Offset(0, -0.25)
        : const Offset(0, 0.25);
    return Positioned(
      left: 12,
      right: 12,
      top: top,
      bottom: bottom,
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: _buildAnimatedSnackBar(
            context: context,
            visuals: visuals,
            beginOffset: beginOffset,
          ),
        ),
      ),
    );
  }

  /// 构建提示进入和离场动画外壳。
  Widget _buildAnimatedSnackBar({
    required BuildContext context,
    required _AppSnackBarVisuals visuals,
    required Offset beginOffset,
  }) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: beginOffset,
          end: Offset.zero,
        ).animate(_animation),
        child: IntrinsicWidth(child: _buildSnackBarSurface(context, visuals)),
      ),
    );
  }

  /// 构建提示卡片表面和语义区域。
  Widget _buildSnackBarSurface(
    BuildContext context,
    _AppSnackBarVisuals visuals,
  ) {
    return Semantics(
      liveRegion: true,
      child: Material(
        color: visuals.background,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: visuals.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 280, minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
            child: _buildSnackBarContent(context, visuals),
          ),
        ),
      ),
    );
  }

  /// 构建提示图标、正文、可选动作和关闭入口。
  Widget _buildSnackBarContent(
    BuildContext context,
    _AppSnackBarVisuals visuals,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        _SnackBarStatusIcon(visuals: visuals),
        const SizedBox(width: 12),
        Expanded(child: _buildMessageText(context, visuals)),
        if (widget.actionLabel != null && widget.onAction != null) ...<Widget>[
          const SizedBox(width: 8),
          AppActionButton(
            variant: AppActionButtonVariant.text,
            height: 32,
            onPressed: _handleAction,
            horizontalPadding: 10,
            foregroundColor: visuals.accent,
            backgroundColor: visuals.iconBackground,
            label: widget.actionLabel!,
          ),
        ],
        const SizedBox(width: 4),
        AppCircleIconButton(
          onPressed: () => unawaited(dismiss()),
          tooltip: '关闭提示',
          foregroundColor: visuals.closeForeground,
          dimension: 36,
          iconSize: 18,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }

  /// 构建提示正文文字。
  Widget _buildMessageText(BuildContext context, _AppSnackBarVisuals visuals) {
    return Text(
      widget.message,
      softWrap: true,
      overflow: TextOverflow.visible,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: visuals.foreground,
        fontSize: AppFontSizes.snackBar,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),
    );
  }
}

/// 提示条左侧的圆形状态图标。
final class _SnackBarStatusIcon extends StatelessWidget {
  /// 创建提示条状态图标。
  const _SnackBarStatusIcon({required this.visuals});

  /// 当前提示类型对应的视觉令牌。
  final _AppSnackBarVisuals visuals;

  /// 构建固定尺寸的圆形图标。
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: visuals.iconBackground,
        shape: BoxShape.circle,
      ),
      child: Icon(visuals.icon, size: 16, color: visuals.accent),
    );
  }
}

/// 一种提示类型对应的主题颜色和图标。
final class _AppSnackBarVisuals {
  /// 创建提示视觉令牌。
  const _AppSnackBarVisuals({
    required this.background,
    required this.foreground,
    required this.closeForeground,
    required this.accent,
    required this.iconBackground,
    required this.border,
    required this.icon,
  });

  /// 提示背景色。
  final Color background;

  /// 提示正文和图标色。
  final Color foreground;

  /// 关闭按钮使用的弱化前景色。
  final Color closeForeground;

  /// 当前语义类型的强调色。
  final Color accent;

  /// 左侧圆形图标区域的轻量染色背景。
  final Color iconBackground;

  /// 提示卡片的低对比语义描边。
  final Color border;

  /// 提示类型图标。
  final IconData icon;
}

/// 从当前主题解析提示类型的颜色和图标。
_AppSnackBarVisuals _snackBarVisuals(
  BuildContext context,
  AppSnackBarType type,
) {
  // 卡片表面、正文与普通提示强调色来自当前主题，自动适配亮暗模式。
  final colors = Theme.of(context).colorScheme;
  // 当前亮暗模式用于选择具有稳定可读性的成功、警告和信息强调色。
  final brightness = Theme.of(context).brightness;
  // 每种类型先确定强调色和 Material 语义图标，卡片结构保持完全一致。
  final (accent, icon) = switch (type) {
    AppSnackBarType.normal => (
      colors.primary,
      Icons.notifications_none_rounded,
    ),
    AppSnackBarType.success => (
      brightness == Brightness.dark
          ? const Color(0xFF69D39C)
          : const Color(0xFF208A5B),
      Icons.check_rounded,
    ),
    AppSnackBarType.error => (colors.error, Icons.priority_high_rounded),
    AppSnackBarType.warning => (
      brightness == Brightness.dark
          ? const Color(0xFFF6C453)
          : const Color(0xFFA86400),
      Icons.warning_amber_rounded,
    ),
    AppSnackBarType.info => (
      brightness == Brightness.dark
          ? const Color(0xFF79B2FF)
          : const Color(0xFF2B6FCB),
      Icons.info_outline_rounded,
    ),
  };
  // 普通提示使用主题色，成功、警告、错误和信息使用各自语义强调色。
  final surfaceAccent = accent;
  // 暗色表面使用略强染色，亮色表面降低透明度避免出现大面积高饱和色块。
  final surfaceTintAlpha = brightness == Brightness.dark ? 0.10 : 0.06;
  // 在主题高层表面上叠加语义色，获得参考图的克制染色而非纯色警报块。
  final background = Color.alphaBlend(
    surfaceAccent.withValues(alpha: surfaceTintAlpha),
    colors.surfaceContainerHigh,
  );
  // 所有类型共享主题正文色，长错误信息不会因语义色过亮而降低可读性。
  final foreground = colors.onSurface.withValues(alpha: 0.92);
  // 返回统一表面、圆形图标区和轻量描边所需的完整视觉令牌。
  return _AppSnackBarVisuals(
    background: background,
    foreground: foreground,
    closeForeground: colors.onSurfaceVariant,
    accent: accent,
    iconBackground: accent.withValues(
      alpha: brightness == Brightness.dark ? 0.18 : 0.10,
    ),
    border: surfaceAccent.withValues(
      alpha: brightness == Brightness.dark ? 0.22 : 0.18,
    ),
    icon: icon,
  );
}
