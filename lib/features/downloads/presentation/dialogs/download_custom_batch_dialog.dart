import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/app_anchored_dropdown.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../settings/domain/app_settings.dart';
import '../../domain/download_extra_resource.dart';
import '../models/download_custom_batch_result.dart';

/// 自定义批量弹窗中模式按钮和质量下拉的统一高度。
const double _batchDialogControlHeight = AppControlSizes.buttonMediumHeight;

/// 展示自定义批量弹窗，并返回用户确认的批量动作。
Future<DownloadCustomBatchResult?> showDownloadCustomBatchDialog({
  required BuildContext context,
  required int taskCount,
  required Set<DownloadExtraResource> availableResources,
  required DefaultAudioQuality initialAudioQuality,
  required DefaultVideoQuality initialVideoQuality,
}) {
  // 批量直下只开放不依赖主下载流的小资源。
  final directResourceOptions = availableResources
      .where(
        (DownloadExtraResource resource) =>
            resource != DownloadExtraResource.audio,
      )
      .toList(growable: false);
  var activeTab = 0;
  var selectedAudioQuality = initialAudioQuality;
  var selectedVideoQuality = initialVideoQuality;
  var selectedMode = DownloadBatchMediaMode.audioVideo;
  final selectedSettingResources = <DownloadExtraResource>{
    ...availableResources,
  };
  final selectedDirectResources = <DownloadExtraResource>{
    ...directResourceOptions,
  };
  return showDialog<DownloadCustomBatchResult>(
    context: context,
    builder: (BuildContext dialogContext) => AppAlertDialog(
      width: 620,
      title: const Text('自定义批量'),
      content: DownloadCustomBatchForm(
        taskCount: taskCount,
        availableResources: availableResources,
        directResourceOptions: directResourceOptions,
        activeTab: activeTab,
        selectedAudioQuality: selectedAudioQuality,
        selectedVideoQuality: selectedVideoQuality,
        selectedMode: selectedMode,
        selectedSettingResources: selectedSettingResources,
        selectedDirectResources: selectedDirectResources,
        compactActions: false,
      ),
      actions: const <Widget>[],
    ),
  );
}

/// 自定义批量表单，供桌面弹窗和手机二级页面复用。
final class DownloadCustomBatchForm extends StatefulWidget {
  /// 创建带内部临时选择状态的批量表单。
  const DownloadCustomBatchForm({
    required this.taskCount,
    required this.availableResources,
    required this.directResourceOptions,
    required this.activeTab,
    required this.selectedAudioQuality,
    required this.selectedVideoQuality,
    required this.selectedMode,
    required this.selectedSettingResources,
    required this.selectedDirectResources,
    required this.compactActions,
    super.key,
  });

  /// 本次批量涉及的待下载主任务数量。
  final int taskCount;

  /// 设置中心允许展示的附加资源。
  final Set<DownloadExtraResource> availableResources;

  /// 可以直接下载的附加资源候选。
  final List<DownloadExtraResource> directResourceOptions;

  /// 初始页签。
  final int activeTab;

  /// 初始音质选择。
  final DefaultAudioQuality selectedAudioQuality;

  /// 初始画质选择。
  final DefaultVideoQuality selectedVideoQuality;

  /// 初始音视频模式。
  final DownloadBatchMediaMode selectedMode;

  /// 初始批量设置附加资源集合。
  final Set<DownloadExtraResource> selectedSettingResources;

  /// 初始批量直下资源集合。
  final Set<DownloadExtraResource> selectedDirectResources;

  /// 是否使用手机端纵向按钮布局。
  final bool compactActions;

  /// 创建表单状态。
  @override
  State<DownloadCustomBatchForm> createState() =>
      _DownloadCustomBatchFormState();
}

/// 持有自定义批量页面和弹窗共享的临时选择状态。
final class _DownloadCustomBatchFormState
    extends State<DownloadCustomBatchForm> {
  /// 当前显示的页签，0 为批量设置，1 为批量下载。
  late int _activeTab = widget.activeTab;

  /// 当前选择的批量音质。
  late DefaultAudioQuality _selectedAudioQuality = widget.selectedAudioQuality;

  /// 当前选择的批量画质。
  late DefaultVideoQuality _selectedVideoQuality = widget.selectedVideoQuality;

  /// 当前音视频快捷模式。
  late DownloadBatchMediaMode _selectedMode = widget.selectedMode;

  /// 当前批量设置页签选择的附加资源。
  late final Set<DownloadExtraResource> _selectedSettingResources =
      <DownloadExtraResource>{...widget.selectedSettingResources};

  /// 当前批量直下页签选择的资源。
  late final Set<DownloadExtraResource> _selectedDirectResources =
      <DownloadExtraResource>{...widget.selectedDirectResources};

  /// 构建批量表单和确认按钮。
  @override
  Widget build(BuildContext context) {
    // 页签和候选选择只存在于当前页面或弹窗生命周期内，确认后才返回页面处理。
    final theme = Theme.of(context);
    final directTabEmpty = widget.directResourceOptions.isEmpty;
    final confirmDisabled = _activeTab == 1 && _selectedDirectResources.isEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SegmentedButton<int>(
          segments: const <ButtonSegment<int>>[
            ButtonSegment<int>(value: 0, label: Text('批量设置')),
            ButtonSegment<int>(value: 1, label: Text('批量下载')),
          ],
          selected: <int>{_activeTab},
          onSelectionChanged: (Set<int> selected) {
            // 页签切换只影响临时表单内容，不立即写入任务。
            setState(() => _activeTab = selected.single);
          },
        ),
        const SizedBox(height: 16),
        if (_activeTab == 0)
          BatchSettingsPane(
            taskCount: widget.taskCount,
            availableResources: widget.availableResources,
            selectedResources: _selectedSettingResources,
            selectedAudioQuality: _selectedAudioQuality,
            selectedVideoQuality: _selectedVideoQuality,
            selectedMode: _selectedMode,
            onAudioChanged: (DefaultAudioQuality value) {
              // 批量音质是确认后写入全部待下载任务的目标档位。
              setState(() => _selectedAudioQuality = value);
            },
            onVideoChanged: (DefaultVideoQuality value) {
              // 批量画质是确认后写入全部待下载任务的目标档位。
              setState(() => _selectedVideoQuality = value);
            },
            onModeChanged: (DownloadBatchMediaMode value) {
              // 快捷模式决定确认时是否清空音频或视频选择。
              setState(() => _selectedMode = value);
            },
            onResourceChanged: (DownloadExtraResource resource, bool selected) {
              // 附加资源集合确认后会覆盖每条待下载主任务。
              setState(() {
                if (selected) {
                  _selectedSettingResources.add(resource);
                } else {
                  _selectedSettingResources.remove(resource);
                }
              });
            },
          )
        else
          BatchDirectExportPane(
            taskCount: widget.taskCount,
            directResourceOptions: widget.directResourceOptions,
            selectedResources: _selectedDirectResources,
            onResourceChanged: (DownloadExtraResource resource, bool selected) {
              // 直下资源只用于本次操作，不写入任务列表。
              setState(() {
                if (selected) {
                  _selectedDirectResources.add(resource);
                } else {
                  _selectedDirectResources.remove(resource);
                }
              });
            },
          ),
        if (_activeTab == 1 && directTabEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            '当前设置中心没有启用可直接下载的封面、弹幕或字幕。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        SizedBox(height: widget.compactActions ? 24 : 18),
        _BatchFormActions(
          compact: widget.compactActions,
          confirmDisabled: confirmDisabled,
          confirmLabel: _activeTab == 0 ? '应用设置' : '开始下载',
          onCancel: () {
            // 取消时关闭当前页面或弹窗，不执行任何批量动作。
            Navigator.of(context).pop();
          },
          onConfirm: confirmDisabled ? null : _confirm,
        ),
      ],
    );
  }

  /// 根据当前页签返回不同动作，调用方统一处理。
  void _confirm() {
    if (_activeTab == 0) {
      Navigator.of(context).pop(
        DownloadBatchSettingsResult(
          resources: Set<DownloadExtraResource>.unmodifiable(
            _selectedSettingResources,
          ),
          audioQuality: _selectedAudioQuality,
          videoQuality: _selectedVideoQuality,
          mediaMode: _selectedMode,
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      DownloadBatchDirectExportResult(
        resources: Set<DownloadExtraResource>.unmodifiable(
          _selectedDirectResources,
        ),
      ),
    );
  }
}

/// 自定义批量表单的取消和确认按钮。
final class _BatchFormActions extends StatelessWidget {
  /// 创建响应式操作区。
  const _BatchFormActions({
    required this.compact,
    required this.confirmDisabled,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  /// 手机端是否使用纵向按钮布局。
  final bool compact;

  /// 确认按钮是否禁用。
  final bool confirmDisabled;

  /// 确认按钮文案。
  final String confirmLabel;

  /// 取消回调。
  final VoidCallback onCancel;

  /// 确认回调。
  final VoidCallback? onConfirm;

  /// 构建操作区按钮。
  @override
  Widget build(BuildContext context) {
    final cancelButton = AppActionButton(
      variant: AppActionButtonVariant.text,
      onPressed: onCancel,
      label: '取消',
    );
    final confirmButton = AppActionButton(
      variant: AppActionButtonVariant.filled,
      onPressed: confirmDisabled ? null : onConfirm,
      label: confirmLabel,
    );
    if (!compact) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          cancelButton,
          const SizedBox(width: 8),
          confirmButton,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        confirmButton,
        const SizedBox(height: 10),
        cancelButton,
      ],
    );
  }
}

/// 自定义批量弹窗里的统一质量下拉字段。
final class BatchQualityMenu<T> extends StatelessWidget {
  /// 创建一组使用公共弹出菜单样式的质量候选。
  const BatchQualityMenu({
    required this.label,
    required this.value,
    required this.enabled,
    required this.options,
    required this.labelBuilder,
    required this.selectedBuilder,
    required this.onSelected,
    super.key,
  });

  /// 字段名称，例如音质或画质。
  final String label;

  /// 当前选中的展示文案。
  final String value;

  /// 当前快捷模式是否允许修改该字段。
  final bool enabled;

  /// 设置中心支持的目标档位列表。
  final List<T> options;

  /// 把业务档位转换为菜单文案。
  final String Function(T option) labelBuilder;

  /// 判断业务档位是否为当前弹窗选择。
  final bool Function(T option) selectedBuilder;

  /// 用户选择某个档位后的回调。
  final ValueChanged<T> onSelected;

  /// 构建和任务卡片一致的锚定下拉。
  @override
  Widget build(BuildContext context) {
    // 统一菜单组件负责表面色、边框和选中行样式。
    final colorScheme = Theme.of(context).colorScheme;
    final canOpenMenu = enabled && options.isNotEmpty;
    final triggerRadius = BorderRadius.circular(10);
    return AppAnchoredSelectionMenu<T>(
      height: _batchDialogControlHeight,
      enabled: canOpenMenu,
      options: options,
      labelBuilder: labelBuilder,
      selectedBuilder: selectedBuilder,
      onSelected: onSelected,
      constraints: const BoxConstraints(minWidth: 176, maxWidth: 220),
      borderRadius: triggerRadius,
      splashRadius: 18,
      fieldLabel: label,
      fieldValue: value,
      fieldHeight: _batchDialogControlHeight,
      fieldHorizontalPadding: 12,
      fieldBorderRadius: triggerRadius,
      fieldIconSize: 18,
      fieldFillColor: colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.32,
      ),
      fieldLabelStyle: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
      fieldValueStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      fieldValueTextAlign: TextAlign.right,
    );
  }
}

/// 批量设置页签内容。
final class BatchSettingsPane extends StatelessWidget {
  /// 创建批量设置表单。
  const BatchSettingsPane({
    required this.taskCount,
    required this.availableResources,
    required this.selectedResources,
    required this.selectedAudioQuality,
    required this.selectedVideoQuality,
    required this.selectedMode,
    required this.onAudioChanged,
    required this.onVideoChanged,
    required this.onModeChanged,
    required this.onResourceChanged,
    super.key,
  });

  /// 本次批量设置涉及的主任务数量。
  final int taskCount;

  /// 设置中心允许展示的附加资源。
  final Set<DownloadExtraResource> availableResources;

  /// 当前已经选中的附加资源。
  final Set<DownloadExtraResource> selectedResources;

  /// 当前目标音质。
  final DefaultAudioQuality selectedAudioQuality;

  /// 当前目标画质。
  final DefaultVideoQuality selectedVideoQuality;

  /// 当前音视频快捷模式。
  final DownloadBatchMediaMode selectedMode;

  /// 音质变化回调。
  final ValueChanged<DefaultAudioQuality> onAudioChanged;

  /// 画质变化回调。
  final ValueChanged<DefaultVideoQuality> onVideoChanged;

  /// 音视频模式变化回调。
  final ValueChanged<DownloadBatchMediaMode> onModeChanged;

  /// 附加资源变化回调。
  final void Function(DownloadExtraResource resource, bool selected)
  onResourceChanged;

  /// 构建批量设置页签。
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('为当前 $taskCount 个待下载视频统一修改本地选择。'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DownloadBatchMediaMode.values
              .map(
                (DownloadBatchMediaMode mode) => AppActionButton(
                  height: _batchDialogControlHeight,
                  variant: selectedMode == mode
                      ? AppActionButtonVariant.filled
                      : AppActionButtonVariant.outlined,
                  icon: selectedMode == mode
                      ? Icons.check_rounded
                      : _iconForBatchMediaMode(mode),
                  label: _labelForBatchMediaMode(mode),
                  onPressed: () {
                    // 快捷模式是单选，点击后始终保留一个有效策略。
                    onModeChanged(mode);
                  },
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: BatchQualityMenu<DefaultAudioQuality>(
                label: '音质',
                value: selectedAudioQuality.label,
                enabled: selectedMode != DownloadBatchMediaMode.videoOnly,
                options: DefaultAudioQuality.values,
                labelBuilder: (DefaultAudioQuality quality) => quality.label,
                selectedBuilder: (DefaultAudioQuality quality) =>
                    quality == selectedAudioQuality,
                onSelected: onAudioChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BatchQualityMenu<DefaultVideoQuality>(
                label: '画质',
                value: selectedVideoQuality.label,
                enabled: selectedMode != DownloadBatchMediaMode.audioOnly,
                options: DefaultVideoQuality.values,
                labelBuilder: (DefaultVideoQuality quality) => quality.label,
                selectedBuilder: (DefaultVideoQuality quality) =>
                    quality == selectedVideoQuality,
                onSelected: onVideoChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('附加资源', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableResources
              .map(
                (DownloadExtraResource resource) => BatchResourceButton(
                  resource: resource,
                  selected: selectedResources.contains(resource),
                  onSelected: (bool selected) {
                    // 选择结果确认后会覆盖写入每条待下载任务。
                    onResourceChanged(resource, selected);
                  },
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 10),
        Text(
          '确认后会覆盖这些待下载任务的附加资源选择；音画质不存在精确档位时自动使用本地可用的最合适档位。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 批量直接下载页签内容。
final class BatchDirectExportPane extends StatelessWidget {
  /// 创建批量附加资源下载表单。
  const BatchDirectExportPane({
    required this.taskCount,
    required this.directResourceOptions,
    required this.selectedResources,
    required this.onResourceChanged,
    super.key,
  });

  /// 本次批量下载涉及的主任务数量。
  final int taskCount;

  /// 可以直接下载的附加资源候选。
  final List<DownloadExtraResource> directResourceOptions;

  /// 当前已经选中的直接下载资源。
  final Set<DownloadExtraResource> selectedResources;

  /// 附加资源变化回调。
  final void Function(DownloadExtraResource resource, bool selected)
  onResourceChanged;

  /// 构建批量下载页签。
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('直接下载当前 $taskCount 个待下载视频的附加资源。'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: directResourceOptions
              .map(
                (DownloadExtraResource resource) => BatchResourceButton(
                  resource: resource,
                  selected: selectedResources.contains(resource),
                  onSelected: (bool selected) {
                    // 批量下载页签只更新本次直下选择，不写回任务记录。
                    onResourceChanged(resource, selected);
                  },
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 10),
        Text(
          '不会添加到任务列表；文件会保存到下载目录下的时间戳文件夹。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 批量弹窗里的附加资源按钮。
final class BatchResourceButton extends StatelessWidget {
  /// 创建严格使用弹窗 medium 高度的多选按钮。
  const BatchResourceButton({
    required this.resource,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// 当前按钮代表的附加资源。
  final DownloadExtraResource resource;

  /// 当前资源是否已选中。
  final bool selected;

  /// 选择状态变化回调。
  final ValueChanged<bool> onSelected;

  /// 构建统一高度和选中颜色的资源按钮。
  @override
  Widget build(BuildContext context) {
    return AppActionButton(
      height: _batchDialogControlHeight,
      variant: selected
          ? AppActionButtonVariant.filled
          : AppActionButtonVariant.outlined,
      icon: selected ? Icons.check_rounded : _iconForExtraResource(resource),
      label: downloadExtraResourceLabel(resource),
      onPressed: () {
        // 附加资源允许独立多选，点击后返回反转状态。
        onSelected(!selected);
      },
    );
  }
}

/// 返回批量音视频快捷模式的展示文案。
String _labelForBatchMediaMode(DownloadBatchMediaMode mode) {
  return switch (mode) {
    DownloadBatchMediaMode.audioVideo => '有声视频',
    DownloadBatchMediaMode.videoOnly => '无声视频',
    DownloadBatchMediaMode.audioOnly => '音频(无视频)',
  };
}

/// 返回批量音视频快捷模式的语义图标。
IconData _iconForBatchMediaMode(DownloadBatchMediaMode mode) {
  return switch (mode) {
    DownloadBatchMediaMode.audioVideo => Icons.movie_filter_outlined,
    DownloadBatchMediaMode.videoOnly => Icons.videocam_outlined,
    DownloadBatchMediaMode.audioOnly => Icons.graphic_eq_rounded,
  };
}

/// 返回附加资源在批量弹窗中的语义图标。
IconData _iconForExtraResource(DownloadExtraResource resource) {
  return switch (resource) {
    DownloadExtraResource.cover => Icons.image_outlined,
    DownloadExtraResource.audio => Icons.audio_file_outlined,
    DownloadExtraResource.danmakuXml => Icons.code_rounded,
    DownloadExtraResource.danmakuAss => Icons.subtitles_outlined,
    DownloadExtraResource.subtitles => Icons.closed_caption_outlined,
    DownloadExtraResource.aiSubtitles => Icons.auto_awesome_outlined,
  };
}
