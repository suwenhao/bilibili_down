import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/app_icon_buttons.dart';
import '../../application/parser_controller.dart';

/// 解析页顶部输入框、解析按钮和历史入口。
final class ParserInputArea extends StatelessWidget {
  /// 创建受外部文本控制器和解析状态驱动的输入区。
  const ParserInputArea({
    required this.controller,
    required this.state,
    required this.onChanged,
    required this.onClear,
    required this.onParse,
    super.key,
  });

  /// 保存输入框文本和光标状态的控制器。
  final TextEditingController controller;

  /// 当前解析状态，用于锁定输入和展示 loading。
  final ParserState state;

  /// 输入文本变化后同步到解析控制器。
  final ValueChanged<String> onChanged;

  /// 清空输入和解析结果的回调。
  final VoidCallback onClear;

  /// 提交当前输入执行解析的回调。
  final VoidCallback onParse;

  /// 构建响应式输入框和解析按钮。
  @override
  Widget build(BuildContext context) {
    // LayoutBuilder 依据内容宽度在横排和竖排之间切换。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 600 像素以下让主按钮占满宽度，避免输入框过窄。
        final compact = constraints.maxWidth < AppBreakpoints.parserInputStack;
        // 手机和桌面的输入框、主按钮统一使用全局标准控件高度。
        const inputControlHeight = AppControlSizes.standardHeight;
        // 解析或入队期间锁定输入与清空操作，防止请求参数在处理中改变。
        final inputLocked =
            state.phase == ParserPhase.loading || state.isQueuing;
        // Android 输入控件的字体度量较高，固定行高可避免单行文本被上下裁切。
        final inputTextStyle = Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(height: 1.15);
        // 输入框负责保存文本并支持回车提交。
        final input = TextField(
          controller: controller,
          enabled: !inputLocked,
          maxLines: 1,
          textAlignVertical: TextAlignVertical.center,
          textInputAction: TextInputAction.search,
          style: inputTextStyle,
          strutStyle: const StrutStyle(
            fontSize: AppFontSizes.bodyLarge,
            height: 1.15,
            forceStrutHeight: true,
          ),
          decoration: InputDecoration(
            constraints: BoxConstraints.tightFor(height: inputControlHeight),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 0),
            hintText: '请输入视频链接或 BV / AV / EP / SS 号',
            prefixIcon: const Icon(Icons.link_rounded),
            prefixIconConstraints: const BoxConstraints.tightFor(
              width: inputControlHeight,
              height: inputControlHeight,
            ),
            suffixIcon: state.input.isEmpty
                ? null
                : AppCircleIconButton(
                    tooltip: '清空输入',
                    dimension: inputControlHeight,
                    iconSize: 20,
                    onPressed: inputLocked ? null : onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
            suffixIconConstraints: const BoxConstraints.tightFor(
              width: inputControlHeight,
              height: inputControlHeight,
            ),
          ),
          onChanged: onChanged,
          onSubmitted: (_) {
            // 加载期间忽略重复回车提交。
            if (inputLocked) return;
            onParse();
          },
        );
        // 解析按钮在加载时显示进度并禁用。
        final button = AppActionButton(
          variant: AppActionButtonVariant.filled,
          size: AppActionButtonSize.large,
          height: inputControlHeight,
          onPressed: inputLocked
              ? null
              : () {
                  // 点击按钮执行解析，不阻塞 Flutter 事件回调。
                  onParse();
                },
          loading: state.phase == ParserPhase.loading,
          icon: Icons.search_rounded,
          label: state.phase == ParserPhase.loading ? '解析中…' : '解析视频',
        );
        // 历史入口使用 push 打开当前解析分支内的新页面，返回时保留解析页状态。
        final historyButton = AppCircleIconButton(
          tooltip: '解析历史',
          dimension: inputControlHeight,
          iconSize: 22,
          onPressed: () => context.push('/parse/history'),
          variant: AppCircleIconButtonVariant.outlined,
          icon: const Icon(Icons.history_rounded),
        );
        // 手机使用纵向排列并让按钮铺满。
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(height: inputControlHeight, child: input),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: SizedBox(height: inputControlHeight, child: button),
                  ),
                  const SizedBox(width: 8),
                  historyButton,
                ],
              ),
            ],
          );
        }
        // 桌面横排位于滚动容器中，必须提供有限高度才能使用 stretch 对齐。
        return SizedBox(
          height: inputControlHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: input),
              const SizedBox(width: 16),
              SizedBox(height: inputControlHeight, width: 150, child: button),
              const SizedBox(width: 10),
              historyButton,
            ],
          ),
        );
      },
    );
  }
}
