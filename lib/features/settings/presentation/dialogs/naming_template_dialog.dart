import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_snack_bar.dart';
import '../../domain/file_naming_template.dart';
import '../widgets/naming_variable_section.dart';
import 'template_editor_dialog_parts.dart';

/// 展示输出文件命名模板编辑弹窗。
Future<void> showNamingTemplateDialog({
  required BuildContext context,
  required String initialTemplate,
  required Future<void> Function(String value) onSave,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) =>
        NamingTemplateDialog(initialTemplate: initialTemplate, onSave: onSave),
  );
}

/// 编辑输出文件命名模板的弹窗。
final class NamingTemplateDialog extends StatefulWidget {
  /// 创建命名模板弹窗。
  const NamingTemplateDialog({
    required this.initialTemplate,
    required this.onSave,
    this.pageMode = false,
    super.key,
  });

  /// 当前模板。
  final String initialTemplate;

  /// 保存模板回调。
  final Future<void> Function(String value) onSave;

  /// 是否作为移动端独立页面展示。
  final bool pageMode;

  /// 创建弹窗状态。
  @override
  State<NamingTemplateDialog> createState() => _NamingTemplateDialogState();
}

/// 管理模板输入和变量快捷插入。
final class _NamingTemplateDialogState extends State<NamingTemplateDialog> {
  /// 模板输入控制器。
  late final TextEditingController _controller;

  /// 防止重复保存。
  bool _saving = false;

  /// 空模板校验是否需要展示。
  bool _showEmptyError = false;

  /// 随机选择推荐模板的随机数生成器。
  final Random _random = Random();

  /// 随机生成只使用当前渲染器支持的稳定变量。
  static const List<String> _randomTemplates = <String>[
    '%index%-%title%',
    '%index:01%-%title%-%upnn%',
    '%title%-%aqn%-%vqn%',
    '%dd:YYYYMMDD%-%title%-%bv%',
    '%index%-%title%-%upnn%-%aqn%-%vqn%',
  ];

  /// 初始化模板输入。
  @override
  void initState() {
    super.initState();
    // 使用当前设置模板填充输入框。
    _controller = TextEditingController(text: widget.initialTemplate);
    // 输入变化时实时刷新预览。
    _controller.addListener(_handleTemplateChanged);
  }

  /// 释放模板控制器。
  @override
  void dispose() {
    // 先移除监听，避免释放期间触发状态更新。
    _controller.removeListener(_handleTemplateChanged);
    // 释放本地文本控制器。
    _controller.dispose();
    super.dispose();
  }

  /// 构建模板编辑弹窗。
  @override
  Widget build(BuildContext context) {
    // 视频变量与任务入队阶段真实可用字段保持一致。
    const videoVariables = <NamingVariable>[
      NamingVariable('视频标题', '%title%'),
      NamingVariable('UP主昵称', '%upnn%'),
      NamingVariable('UP主UID', '%uid%'),
      NamingVariable('音质', '%aqn%'),
      NamingVariable('画质', '%vqn%'),
      NamingVariable('BV号', '%bv%'),
      NamingVariable('CID号', '%cid%'),
    ];
    // 日期变量支持整体日期以及年月日独立格式。
    const dateVariables = <NamingVariable>[
      NamingVariable('下载日期', '%dd%'),
      NamingVariable('下载年', '%dd:YYYY%'),
      NamingVariable('下载月', '%dd:MM%'),
      NamingVariable('下载日', '%dd:DD%'),
      NamingVariable('下载年月日', '%dd:YYYYMMDD%'),
      NamingVariable('发布日期', '%pd%'),
      NamingVariable('发布年', '%pd:YYYY%'),
      NamingVariable('发布月', '%pd:MM%'),
      NamingVariable('发布日', '%pd:DD%'),
      NamingVariable('发布年月日', '%pd:YYYYMMDD%'),
    ];
    // 排序变量覆盖一开始、零开始和两种补零形式。
    const orderVariables = <NamingVariable>[
      NamingVariable('序号（建议前置）', '%index%'),
      NamingVariable('从0开始', '%index:0%'),
      NamingVariable('从0开始并补零', '%index:00%'),
      NamingVariable('从1开始并补零', '%index:01%'),
    ];
    // 预览卡片仍需要主题色强调最终生成的文件名。
    final colorScheme = Theme.of(context).colorScheme;
    // 复用模板编辑弹窗外壳，当前文件保留命名模板的校验和预览语义。
    return SettingsTemplateDialogScaffold(
      title: '自定义文件命名设置',
      description: '点击变量会插入到当前光标位置，也可以直接输入普通文字和分隔符；保存后将用于新加入的下载任务。',
      saving: _saving,
      clearLabel: '清空模板',
      onClear: _resetTemplate,
      onSave: _save,
      pageMode: widget.pageMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          NamingVariableSection(
            title: '视频相关',
            variables: videoVariables,
            enabled: !_saving,
            onInsert: _insertVariable,
          ),
          const SizedBox(height: 18),
          NamingVariableSection(
            title: '日期相关',
            variables: dateVariables,
            enabled: !_saving,
            onInsert: _insertVariable,
          ),
          const SizedBox(height: 18),
          NamingVariableSection(
            title: '排序相关',
            variables: orderVariables,
            enabled: !_saving,
            onInsert: _insertVariable,
          ),
          const SizedBox(height: 22),
          SettingsTemplateInputRow(
            controller: _controller,
            enabled: !_saving,
            labelText: '文件名模板',
            hintText: '%index%-%title%',
            errorText: _showEmptyError ? '命名模板不能为空' : null,
            onGenerate: _generateTemplate,
          ),
          const SizedBox(height: 16),
          const SettingsTemplateTip(text: '优先把序号放在开头，合集文件在资源管理器中会更容易排序。'),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.34),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  const TextSpan(
                    text: '预览：  ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: _previewForTemplate(_controller.text),
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 文本变化时刷新预览并清除已经修正的空值错误。
  void _handleTemplateChanged() {
    // 控制器释放后不再刷新界面。
    if (!mounted) return;
    // 输入恢复非空时同步清除错误。
    final shouldClearError =
        _showEmptyError && _controller.text.trim().isNotEmpty;
    // 预览依赖文本，因此每次输入都需要刷新。
    setState(() {
      if (shouldClearError) _showEmptyError = false;
    });
  }

  /// 把变量插入当前选择范围并把光标移动到变量末尾。
  void _insertVariable(String variable) {
    // 读取输入框当前文本和选择范围。
    final value = _controller.value;
    // 输入框未获得焦点时默认插入到文本末尾。
    final start = value.selection.isValid
        ? value.selection.start
        : value.text.length;
    // 有选中文本时使用变量替换选中范围。
    final end = value.selection.isValid
        ? value.selection.end
        : value.text.length;
    // 构造插入变量后的新文本。
    final nextText = value.text.replaceRange(start, end, variable);
    // 一次性更新文本与光标，避免光标跳回开头。
    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: start + variable.length),
    );
  }

  /// 从安全模板集合中随机选择一条并更新实时预览。
  void _generateTemplate() {
    // 随机下标始终限制在推荐模板集合中。
    final index = _random.nextInt(_randomTemplates.length);
    // 替换当前文本并把光标移动到末尾。
    _controller.value = TextEditingValue(
      text: _randomTemplates[index],
      selection: TextSelection.collapsed(
        offset: _randomTemplates[index].length,
      ),
    );
  }

  /// 清空自定义模板并恢复为默认标题命名。
  void _resetTemplate() {
    // 默认模板与设置中心“%title%”规则保持一致。
    const defaultTemplate = '%title%';
    // 恢复默认值后把光标放到末尾，方便继续编辑。
    _controller.value = const TextEditingValue(
      text: defaultTemplate,
      selection: TextSelection.collapsed(offset: defaultTemplate.length),
    );
  }

  /// 使用与真实命名渲染器一致的示例数据生成即时预览。
  String _previewForTemplate(String template) {
    // 空模板展示明确占位，不生成空白预览框。
    if (template.trim().isEmpty) return '请输入命名模板';
    // 按真实下载服务共用的渲染器替换示例值。
    final preview = renderFileNamingTemplate(
      template,
      FileNamingValues(
        title: '测试视频标题',
        collectionTitle: '测试合集',
        publisherName: '示例UP主',
        publisherId: 123456,
        audioQuality: '192K mp4a',
        videoQuality: '1080P 高清 AVC',
        videoType: '普通视频',
        bvid: 'BV1Example',
        cid: 987654,
        downloadDate: DateTime.now(),
        publishDate: DateTime(2026, 4, 6),
        index: 1,
      ),
    );
    // 用真实文件名清理规则替换跨平台非法字符。
    return preview.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
  }

  /// 保存非空模板并关闭弹窗。
  Future<void> _save() async {
    // 空模板时展示就地错误并保持弹窗打开。
    if (_controller.text.trim().isEmpty) {
      setState(() => _showEmptyError = true);
      return;
    }
    // 进入忙碌状态。
    setState(() => _saving = true);
    try {
      // 等待设置持久化完成。
      await widget.onSave(_controller.text.trim());
      // 弹窗已卸载时不再访问导航器。
      if (!mounted) return;
      // 关闭已经保存的弹窗。
      Navigator.of(context).pop();
    } catch (error) {
      // 弹窗已卸载时不再更新状态或显示提示。
      if (!mounted) return;
      // 恢复按钮以允许用户重试。
      setState(() => _saving = false);
      // 根 Overlay 让保存错误显示在当前命名设置弹窗之上。
      AppSnackBar.show(
        context,
        message: '保存命名模板失败：$error',
        type: AppSnackBarType.error,
        position: AppSnackBarPosition.top,
      );
    }
  }
}
