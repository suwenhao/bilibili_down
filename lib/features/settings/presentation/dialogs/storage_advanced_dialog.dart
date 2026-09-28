import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_snack_bar.dart';
import '../../domain/file_naming_template.dart';
import '../widgets/naming_variable_section.dart';
import 'template_editor_dialog_parts.dart';

/// 展示存储高级设置弹窗。
Future<void> showStorageAdvancedDialog({
  required BuildContext context,
  required String baseDirectory,
  required String initialTemplate,
  required Future<void> Function(String template) onSave,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => StorageAdvancedDialog(
      baseDirectory: baseDirectory,
      initialTemplate: initialTemplate,
      onSave: onSave,
    ),
  );
}

/// 配置下载根目录下动态子文件夹规则的高级弹窗。
final class StorageAdvancedDialog extends StatefulWidget {
  /// 创建存储高级设置弹窗。
  const StorageAdvancedDialog({
    required this.baseDirectory,
    required this.initialTemplate,
    required this.onSave,
    this.pageMode = false,
    super.key,
  });

  /// “更改”按钮选择的实际下载根目录。
  final String baseDirectory;

  /// 当前保存的动态子文件夹模板。
  final String initialTemplate;

  /// 保存动态子文件夹模板回调。
  final Future<void> Function(String template) onSave;

  /// 是否作为移动端独立页面展示。
  final bool pageMode;

  /// 创建弹窗状态。
  @override
  State<StorageAdvancedDialog> createState() => _StorageAdvancedDialogState();
}

/// 管理文件夹变量、实时路径预览和保存状态。
final class _StorageAdvancedDialogState extends State<StorageAdvancedDialog> {
  /// 文件夹模板输入控制器。
  late final TextEditingController _controller;

  /// 防止重复保存的忙碌状态。
  bool _saving = false;

  /// 随机选择推荐文件夹模板。
  final Random _random = Random();

  /// 推荐模板只使用当前渲染器支持的稳定变量。
  static const List<String> _randomTemplates = <String>[
    '%upnn%',
    '%upnn%/%vtype%',
    '%upnn-uid%/%vtype%',
    '%dd:YYYY%/%upnn%',
    '%vtype%/%upnn%/%pd:YYYY%',
  ];

  /// 初始化文件夹模板和预览监听。
  @override
  void initState() {
    super.initState();
    // 使用当前高级规则填充输入框。
    _controller = TextEditingController(text: widget.initialTemplate);
    // 输入变化时实时刷新三种路径预览。
    _controller.addListener(_handleTemplateChanged);
  }

  /// 释放文本控制器。
  @override
  void dispose() {
    // 先移除输入监听。
    _controller.removeListener(_handleTemplateChanged);
    // 再释放控制器。
    _controller.dispose();
    super.dispose();
  }

  /// 构建与当前 BiliDown 主题一致的响应式高级弹窗。
  @override
  Widget build(BuildContext context) {
    // 视频变量覆盖发布者、内容类型和实际音画质。
    const videoVariables = <NamingVariable>[
      NamingVariable('UP主昵称', '%upnn%'),
      NamingVariable('UP主UID', '%uid%'),
      NamingVariable('UP主昵称-UID', '%upnn-uid%'),
      NamingVariable('UP主UID-昵称', '%uid-upnn%'),
      NamingVariable('视频类型', '%vtype%'),
      NamingVariable('音质', '%aqn%'),
      NamingVariable('画质', '%vqn%'),
      NamingVariable('视频标题', '%title%'),
      NamingVariable('合集标题', '%collection%'),
    ];
    // 日期变量与文件命名弹窗保持同一语法。
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
    // 复用模板编辑弹窗外壳，当前文件只保留动态目录的业务主体。
    return SettingsTemplateDialogScaffold(
      title: '存储高级设置',
      description:
          '此设置用于在下载根目录下动态创建子文件夹。点击变量会插入到当前光标位置，也可以使用 / 或 \\ 组合多层目录；留空则直接保存到根目录。',
      saving: _saving,
      clearLabel: '清空规则',
      onClear: _clearTemplate,
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
          const SizedBox(height: 22),
          SettingsTemplateInputRow(
            controller: _controller,
            enabled: !_saving,
            labelText: '文件夹变量配置',
            hintText: '例如：%upnn%/%vtype%',
            onGenerate: _generateTemplate,
          ),
          const SizedBox(height: 16),
          const SettingsTemplateTip(text: '简单规则优先；层级过深会增加路径长度，并影响跨平台移动文件。'),
          const SizedBox(height: 18),
          _StoragePreviewRow(
            label: '普通视频预览',
            baseDirectory: widget.baseDirectory,
            relativeFolder: _previewRelativeFolder(
              _previewValues(
                videoType: '普通视频',
                title: '测试视频标题',
                collectionTitle: '测试视频标题',
                index: 1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _StoragePreviewRow(
            label: '合集分集预览',
            baseDirectory: widget.baseDirectory,
            relativeFolder: _previewRelativeFolder(
              _previewValues(
                videoType: '合集分集',
                title: '合集第01集',
                collectionTitle: '测试合集标题',
                index: 1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _StoragePreviewRow(
            label: '番剧分集预览',
            baseDirectory: widget.baseDirectory,
            relativeFolder: _previewRelativeFolder(
              _previewValues(
                videoType: '番剧分集',
                title: '第一话',
                collectionTitle: '测试番剧标题',
                index: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 输入变化时刷新所有路径预览。
  void _handleTemplateChanged() {
    // 控制器释放后不再刷新。
    if (!mounted) return;
    // 三种预览都依赖当前文本。
    setState(() {});
  }

  /// 把变量插入当前光标或替换选中内容。
  void _insertVariable(String variable) {
    // 读取当前文本和选择范围。
    final value = _controller.value;
    // 未获得焦点时插入到末尾。
    final start = value.selection.isValid
        ? value.selection.start
        : value.text.length;
    // 有选中内容时用变量替换它。
    final end = value.selection.isValid
        ? value.selection.end
        : value.text.length;
    // 生成插入后的完整模板。
    final nextText = value.text.replaceRange(start, end, variable);
    // 同步文本和光标位置。
    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: start + variable.length),
    );
  }

  /// 随机选择一条安全推荐模板。
  void _generateTemplate() {
    // 随机下标限制在推荐模板集合范围内。
    final index = _random.nextInt(_randomTemplates.length);
    // 保存本次选中的模板。
    final template = _randomTemplates[index];
    // 更新文本并把光标放到末尾。
    _controller.value = TextEditingValue(
      text: template,
      selection: TextSelection.collapsed(offset: template.length),
    );
  }

  /// 清空动态目录规则并立即刷新预览。
  void _clearTemplate() {
    // 空模板表示直接使用下载根目录。
    _controller.clear();
  }

  /// 创建一种内容类型的示例变量值。
  FileNamingValues _previewValues({
    required String videoType,
    required String title,
    required String collectionTitle,
    required int index,
  }) {
    // 返回供共用渲染器使用的完整示例数据。
    return FileNamingValues(
      title: title,
      collectionTitle: collectionTitle,
      publisherName: '示例UP主',
      publisherId: 123456,
      audioQuality: '192K mp4a',
      videoQuality: '1080P 高清 AVC',
      videoType: videoType,
      bvid: 'BV1Example',
      cid: 987654,
      downloadDate: DateTime.now(),
      publishDate: DateTime(2026, 4, 6),
      index: index,
    );
  }

  /// 渲染并清理用于界面展示的相对子目录。
  String _previewRelativeFolder(FileNamingValues values) {
    // 空模板不创建额外目录。
    if (_controller.text.trim().isEmpty) return '';
    // 使用下载服务共用渲染器替换变量。
    final rendered = renderFileNamingTemplate(_controller.text, values);
    // 同时识别两种分隔符并阻止父目录跳转。
    final safeSegments = rendered
        .split(RegExp(r'[\\/]+'))
        .map((String segment) => segment.trim())
        .where(
          (String segment) =>
              segment.isNotEmpty && segment != '.' && segment != '..',
        )
        .map(
          (String segment) =>
              segment.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_'),
        )
        .where((String segment) => segment.isNotEmpty)
        .toList(growable: false);
    // 没有有效目录段时保持根目录。
    if (safeSegments.isEmpty) return '';
    // 使用当前系统分隔符拼接预览路径。
    return safeSegments.join(Platform.pathSeparator);
  }

  /// 保存文件夹模板并关闭弹窗。
  Future<void> _save() async {
    // 进入忙碌状态阻止重复提交。
    setState(() => _saving = true);
    try {
      // 空模板同样是有效设置，表示取消动态目录。
      await widget.onSave(_controller.text.trim());
      // 弹窗卸载后不再访问导航器。
      if (!mounted) return;
      // 关闭保存完成的弹窗。
      Navigator.of(context).pop();
    } catch (error) {
      // 弹窗卸载后不再更新状态。
      if (!mounted) return;
      // 恢复按钮允许用户重试。
      setState(() => _saving = false);
      // 根 Overlay 让保存错误显示在当前高级设置弹窗之上。
      AppSnackBar.show(
        context,
        message: '保存存储规则失败：$error',
        type: AppSnackBarType.error,
        position: AppSnackBarPosition.top,
      );
    }
  }
}

/// 展示高级存储规则对一种内容类型生成的实际目录。
final class _StoragePreviewRow extends StatelessWidget {
  /// 创建一条目录预览。
  const _StoragePreviewRow({
    required this.label,
    required this.baseDirectory,
    required this.relativeFolder,
  });

  /// 预览类型名称。
  final String label;

  /// 当前实际下载根目录。
  final String baseDirectory;

  /// 模板渲染后的相对子目录。
  final String relativeFolder;

  /// 构建可自动换行的路径预览。
  @override
  Widget build(BuildContext context) {
    // 获取主题颜色突出动态子目录。
    final colorScheme = Theme.of(context).colorScheme;
    // 目录预览属于辅助信息，统一使用比正文小一级的字号降低视觉权重。
    final previewTextStyle = Theme.of(context).textTheme.bodySmall;
    // 非空子目录前补当前系统路径分隔符。
    final dynamicPath = relativeFolder.isEmpty
        ? '（不创建子目录）'
        : '${Platform.pathSeparator}$relativeFolder';
    // 返回标签、根目录和动态部分。
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$label：  ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: baseDirectory),
          TextSpan(
            text: dynamicPath,
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      style: previewTextStyle,
    );
  }
}
