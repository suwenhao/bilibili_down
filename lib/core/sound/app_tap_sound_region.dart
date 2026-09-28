import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_sound_service.dart';

/// 在应用根部为真正可点击控件补充统一 tap.wav 反馈。
final class AppTapSoundRegion extends ConsumerStatefulWidget {
  /// 创建不改变子树布局和命中行为的点击音区域。
  const AppTapSoundRegion({required this.child, super.key});

  /// MaterialApp 当前构建的路由或启动页面。
  final Widget child;

  @override
  ConsumerState<AppTapSoundRegion> createState() => _AppTapSoundRegionState();
}

/// 记录指针位移并过滤滚动、拖动和空白区域点击。
final class _AppTapSoundRegionState extends ConsumerState<AppTapSoundRegion> {
  /// 各指针按下位置与当时按钮命中结果，用于排除滚动并兼容点击后立即导航。
  final Map<int, ({Offset position, bool hitsTapAction})> _pointerDownStates =
      <int, ({Offset position, bool hitsTapAction})>{};

  /// 超过此物理逻辑像素距离视为拖动，不播放按钮音。
  static const double _maximumTapDistance = 12;

  @override
  Widget build(BuildContext context) {
    // Listener 只观察原始事件，不抢占按钮自身手势竞技场。
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (PointerDownEvent event) {
        // 按下时保存按钮命中结果，避免 onTap 导航后原控件已从渲染树移除。
        _pointerDownStates[event.pointer] = (
          position: event.position,
          hitsTapAction: _hitsTapAction(event),
        );
      },
      onPointerCancel: (PointerCancelEvent event) {
        // 系统取消手势时移除状态且不播放声音。
        _pointerDownStates.remove(event.pointer);
      },
      onPointerUp: _handlePointerUp,
      child: widget.child,
    );
  }

  /// 在短距离点击且命中具有 tap 语义的控件时播放按钮音。
  void _handlePointerUp(PointerUpEvent event) {
    // 取出并清理按下位置，未知指针不参与判断。
    final downState = _pointerDownStates.remove(event.pointer);
    if (downState == null) return;
    // 滚动或拖动结束不能被误判为按钮点击。
    if ((event.position - downState.position).distance > _maximumTapDistance) {
      return;
    }
    // 空白区域和只支持滚动的 RenderObject 不播放 tap 音。
    if (!downState.hitsTapAction) return;
    // 音效服务内部再次检查设置开关并异步播放。
    ref.read(appSoundServiceProvider).play(AppSoundEffect.tap);
  }

  /// 重新命中当前位置并检查渲染链上是否存在可点击控件。
  bool _hitsTapAction(PointerEvent event) {
    // 使用当前 FlutterView ID 支持桌面多窗口与移动端统一命中。
    final result = HitTestResult();
    RendererBinding.instance.hitTestInView(
      result,
      event.position,
      event.viewId,
    );
    // 输入框也可能声明 tap 语义，必须先完整扫描命中链再决定是否播放。
    var hitsTextInput = false;
    // 保存按钮、Chip、选择控件或自定义 InkWell 的明确点击能力。
    var hitsTapAction = false;
    for (final entry in result.path) {
      // 检查命中链上的实际渲染节点，避免把滚动容器或空白区域当成按钮。
      final target = entry.target;
      // RenderEditable 是 TextField/EditableText 的输入核心，点击仅用于聚焦和选区。
      if (target is RenderEditable) hitsTextInput = true;
      if (target is RenderSemanticsGestureHandler && target.onTap != null) {
        hitsTapAction = true;
      }
      // Button、Chip、Switch、Radio 等控件会在 Semantics 上声明可用的 tap 动作。
      if (target is SemanticsAnnotationsMixin) {
        // 禁用控件虽然仍有语义节点，但不能产生点击反馈音。
        final properties = target.properties;
        if (properties.textField == true) hitsTextInput = true;
        if (properties.enabled != false && properties.onTap != null) {
          hitsTapAction = true;
        }
      }
      // InkWell 和导航项在桌面及移动端命中链中使用点击光标标识交互能力。
      if (target is RenderMouseRegion &&
          target.cursor == SystemMouseCursors.click) {
        hitsTapAction = true;
      }
    }
    // 输入框本体优先排除；其内部独立图标按钮不命中 RenderEditable，仍正常播放。
    return !hitsTextInput && hitsTapAction;
  }
}
