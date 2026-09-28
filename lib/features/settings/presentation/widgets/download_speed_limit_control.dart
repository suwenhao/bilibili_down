import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 设置页中的 aria2 全局下载限速控件。
final class DownloadSpeedLimitControl extends StatefulWidget {
  /// 创建由滑块和手动输入共同控制的限速设置。
  const DownloadSpeedLimitControl({
    required this.compact,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// 是否使用手机紧凑布局。
  final bool compact;

  /// 当前已保存的下载速度上限，单位为 MB/s。
  final int value;

  /// 用户提交新速度上限时的回调。
  final ValueChanged<int> onChanged;

  /// 创建维护输入框草稿值的控件状态。
  @override
  State<DownloadSpeedLimitControl> createState() =>
      _DownloadSpeedLimitControlState();
}

/// 管理限速滑块草稿、输入框文本和失焦提交。
final class _DownloadSpeedLimitControlState
    extends State<DownloadSpeedLimitControl> {
  /// 手动输入框控制器，用于在外部设置变化时同步显示文本。
  late final TextEditingController _textController;

  /// 输入框焦点节点，用于失焦时提交用户手动输入。
  late final FocusNode _focusNode;

  /// 当前尚未提交的滑块或输入框草稿值。
  late int _draftValue;

  /// 初始化本地草稿和输入框监听。
  @override
  void initState() {
    super.initState();
    // 初始草稿来自持久化设置，保证首帧显示真实限速。
    _draftValue = _normalizedLimit(widget.value);
    // 输入框文本始终展示纯数字，单位由右侧后缀提供。
    _textController = TextEditingController(text: '$_draftValue');
    // 失焦时自动提交输入，适配鼠标点击页面其他位置的编辑习惯。
    _focusNode = FocusNode()..addListener(_handleFocusChanged);
  }

  /// 响应外部设置更新并修正本地草稿。
  @override
  void didUpdateWidget(DownloadSpeedLimitControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 设置控制器持久化完成后会刷新 widget.value，需要同步输入框。
    if (oldWidget.value == widget.value) return;
    // 外部值经过同一规则规范化，防止测试或旧设置传入越界值。
    final nextValue = _normalizedLimit(widget.value);
    _draftValue = nextValue;
    // 正在输入时不抢光标；失焦提交会再把最终值写回。
    if (_focusNode.hasFocus) return;
    _textController.text = '$nextValue';
  }

  /// 释放输入框控制器和焦点节点。
  @override
  void dispose() {
    // 先移除监听，避免 dispose 期间触发提交逻辑。
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  /// 构建滑块、数值输入和单位标签。
  @override
  Widget build(BuildContext context) {
    // 紧凑布局下输入框换到下一行，避免滑块和文本互相挤压。
    if (widget.compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildSlider(),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: _buildInput(context)),
        ],
      );
    }
    // 桌面布局保持单行，便于快速拖动后直接键盘微调。
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Row(
        children: <Widget>[
          Expanded(child: _buildSlider()),
          const SizedBox(width: 14),
          _buildInput(context),
        ],
      ),
    );
  }

  /// 构建一到一百 MB/s 的离散滑块。
  Widget _buildSlider() {
    return Slider(
      value: _draftValue.toDouble(),
      min: 1,
      max: 100,
      divisions: 99,
      label: '$_draftValue MB/s',
      mouseCursor: SystemMouseCursors.click,
      onChanged: (double value) {
        // 拖动期间只更新本地草稿，避免高频写入 SharedPreferences。
        _setDraftValue(value.round(), updateText: true);
      },
      onChangeEnd: (double value) {
        // 用户释放滑块时提交一次最终值，并同步 aria2 全局选项。
        unawaited(_commitValue(value.round()));
      },
    );
  }

  /// 构建手动输入框和单位文本。
  Widget _buildInput(BuildContext context) {
    // 当前主题用于限制输入框尺寸和文字颜色保持设置页一致。
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 72,
          child: TextField(
            controller: _textController,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            mouseCursor: SystemMouseCursors.text,
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.done,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => unawaited(_commitTextInput()),
          ),
        ),
        const SizedBox(width: 8),
        Text('MB/s', style: textTheme.bodyMedium),
      ],
    );
  }

  /// 焦点变化时提交输入框里的手动数值。
  void _handleFocusChanged() {
    // 只有失去焦点才提交，获得焦点时保留用户当前文本。
    if (_focusNode.hasFocus) return;
    unawaited(_commitTextInput());
  }

  /// 更新本地草稿值并按需同步输入框文本。
  void _setDraftValue(int value, {required bool updateText}) {
    // 所有入口统一限制范围，保证滑块、输入框和设置层一致。
    final normalizedValue = _normalizedLimit(value);
    setState(() {
      // 草稿值驱动滑块位置和悬浮标签。
      _draftValue = normalizedValue;
      // 滑块拖动时同步输入框；用户正在输入时避免打断光标。
      if (updateText) _textController.text = '$normalizedValue';
    });
  }

  /// 解析输入框文本并提交规范化后的值。
  Future<void> _commitTextInput() async {
    // 空输入按当前草稿回填，不让设置进入无意义的空状态。
    final parsedValue = int.tryParse(_textController.text);
    // 手动输入可能超出范围，提交前统一 clamp。
    final nextValue = _normalizedLimit(parsedValue ?? _draftValue);
    _setDraftValue(nextValue, updateText: true);
    await _commitValue(nextValue);
  }

  /// 提交新限速到上层设置控制器。
  Future<void> _commitValue(int value) async {
    // 所有提交入口再次规范化，避免动画或测试传入越界值。
    final normalizedValue = _normalizedLimit(value);
    // 同值提交不需要重复写入，也避免显示多余保存反馈。
    if (normalizedValue == widget.value) return;
    widget.onChanged(normalizedValue);
  }

  /// 将任意整数限制到产品允许的一到一百 MB/s。
  int _normalizedLimit(int value) => value.clamp(1, 100);
}
