import 'package:flutter/material.dart';

import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../application/resources/download_artifact_conversion_service.dart';

/// 打开本地资源转换弹窗并返回用户选择。
Future<DownloadArtifactConversionOptions?>
showDownloadArtifactConversionDialog({
  required BuildContext context,
  required DownloadArtifactConversionCategory category,
  required String sourceExtension,
  required DownloadArtifactConversionCapabilities capabilities,
}) {
  // 弹窗状态只服务当前资源，关闭后由详情页触发真实转换。
  return showDialog<DownloadArtifactConversionOptions>(
    context: context,
    builder: (BuildContext dialogContext) => _DownloadArtifactConversionDialog(
      category: category,
      sourceExtension: sourceExtension,
      capabilities: capabilities,
    ),
  );
}

/// 本地资源转换参数选择弹窗。
final class _DownloadArtifactConversionDialog extends StatefulWidget {
  /// 创建转换弹窗。
  const _DownloadArtifactConversionDialog({
    required this.category,
    required this.sourceExtension,
    required this.capabilities,
  });

  /// 当前资源的转换大类。
  final DownloadArtifactConversionCategory category;

  /// 当前资源原始后缀。
  final String sourceExtension;

  /// 当前 FFmpeg 后端已经确认可用的编码能力。
  final DownloadArtifactConversionCapabilities capabilities;

  /// 创建弹窗状态。
  @override
  State<_DownloadArtifactConversionDialog> createState() =>
      _DownloadArtifactConversionDialogState();
}

/// 维护转换参数选择状态。
final class _DownloadArtifactConversionDialogState
    extends State<_DownloadArtifactConversionDialog> {
  /// 当前选中的输出后缀。
  late String _extension;

  /// 当前选中的视频编码；为空时表示沿用原视频流快速封装。
  late String? _videoCodec;

  /// 当前选中的音频编码；为空时表示沿用原音频流快速封装。
  late String? _audioCodec;

  /// 初始化来源后缀和默认编码选项。
  @override
  void initState() {
    super.initState();
    // 源文件后缀若本身就是可选输出格式，则默认保留该封装，减少无意义转换。
    _extension = _initialExtension();
    // full 包允许视频重编码，默认选择当前封装最稳妥的视频编码。
    _videoCodec = _firstChoiceValue(_videoCodecOptions);
    // 音频编码默认选择当前封装最稳妥的音频编码。
    _audioCodec = _firstChoiceValue(_audioCodecOptions);
  }

  /// 当前类型可选的输出格式。
  List<_ConversionChoice> get _extensionOptions {
    // 源后缀决定 B 站专用文本是否只能走内置转换器。
    final sourceExtension = _normalizedSourceExtension;
    // 资源类型决定输出格式，避免显示 FFmpeg 不适合处理的无效选项。
    return switch (widget.category) {
      DownloadArtifactConversionCategory.voicedVideo ||
      DownloadArtifactConversionCategory.silentVideo =>
        const <_ConversionChoice>[
          _ConversionChoice('mp4', 'MP4'),
          _ConversionChoice('mkv', 'MKV'),
          _ConversionChoice('mov', 'MOV'),
          _ConversionChoice('avi', 'AVI'),
          _ConversionChoice('flv', 'FLV'),
          _ConversionChoice('webm', 'WEBM'),
        ],
      DownloadArtifactConversionCategory.audio => const <_ConversionChoice>[
        _ConversionChoice('aac', 'AAC'),
        _ConversionChoice('m4a', 'M4A'),
        _ConversionChoice('mp3', 'MP3'),
        _ConversionChoice('flac', 'FLAC'),
        _ConversionChoice('ogg', 'OGG'),
        _ConversionChoice('opus', 'OPUS'),
        _ConversionChoice('ac3', 'AC3'),
        _ConversionChoice('wav', 'WAV'),
      ],
      DownloadArtifactConversionCategory.subtitle
          when sourceExtension == 'json' =>
        const <_ConversionChoice>[_ConversionChoice('srt', 'SRT')],
      DownloadArtifactConversionCategory.subtitle => const <_ConversionChoice>[
        _ConversionChoice('srt', 'SRT'),
        _ConversionChoice('ass', 'ASS'),
        _ConversionChoice('vtt', 'VTT'),
      ],
      DownloadArtifactConversionCategory.danmaku
          when sourceExtension == 'xml' =>
        const <_ConversionChoice>[_ConversionChoice('ass', 'ASS')],
      DownloadArtifactConversionCategory.danmaku => const <_ConversionChoice>[
        _ConversionChoice('ass', 'ASS'),
      ],
    };
  }

  /// 当前封装可选的视频编码。
  List<_ConversionChoice> get _videoCodecOptions {
    // 只有视频类资源需要展示视频编码；部分封装只暴露稳定组合。
    final choices = switch (widget.category) {
      DownloadArtifactConversionCategory.voicedVideo ||
      DownloadArtifactConversionCategory.silentVideo => switch (_extension) {
        'avi' ||
        'flv' => const <_ConversionChoice>[_ConversionChoice('h264', 'H264')],
        'webm' => const <_ConversionChoice>[_ConversionChoice('av1', 'AV1')],
        _ => const <_ConversionChoice>[
          _ConversionChoice('h264', 'H264'),
          _ConversionChoice('h265', 'H265'),
          _ConversionChoice('av1', 'AV1'),
        ],
      },
      _ => const <_ConversionChoice>[],
    };
    // 当前包型没有注册的编码器不展示，避免用户选择后才被 FFmpeg 拒绝。
    return _filterSupportedChoices(choices, widget.capabilities.videoCodecs);
  }

  /// 当前类型可选的音频编码。
  List<_ConversionChoice> get _audioCodecOptions {
    // 有声视频和音频资源才需要音频编码；封装决定合法编码集合。
    final choices = switch (widget.category) {
      DownloadArtifactConversionCategory.voicedVideo => switch (_extension) {
        'mp4' || 'mov' => const <_ConversionChoice>[
          _ConversionChoice('aac', 'AAC'),
          _ConversionChoice('alac', 'ALAC'),
          _ConversionChoice('ac3', 'AC3'),
        ],
        'mkv' => const <_ConversionChoice>[
          _ConversionChoice('aac', 'AAC'),
          _ConversionChoice('mp3', 'MP3'),
          _ConversionChoice('flac', 'FLAC'),
          _ConversionChoice('ac3', 'AC3'),
        ],
        'webm' => const <_ConversionChoice>[_ConversionChoice('opus', 'OPUS')],
        _ => const <_ConversionChoice>[
          _ConversionChoice('aac', 'AAC'),
          _ConversionChoice('mp3', 'MP3'),
        ],
      },
      DownloadArtifactConversionCategory.audio => switch (_extension) {
        'm4a' => const <_ConversionChoice>[
          _ConversionChoice('aac', 'AAC'),
          _ConversionChoice('alac', 'ALAC'),
        ],
        'aac' => const <_ConversionChoice>[_ConversionChoice('aac', 'AAC')],
        'mp3' => const <_ConversionChoice>[_ConversionChoice('mp3', 'MP3')],
        'flac' => const <_ConversionChoice>[_ConversionChoice('flac', 'FLAC')],
        'ogg' => const <_ConversionChoice>[
          _ConversionChoice('opus', 'OPUS'),
          _ConversionChoice('flac', 'FLAC'),
        ],
        'opus' => const <_ConversionChoice>[_ConversionChoice('opus', 'OPUS')],
        'ac3' => const <_ConversionChoice>[_ConversionChoice('ac3', 'AC3')],
        'wav' => const <_ConversionChoice>[_ConversionChoice('pcm', 'WAV PCM')],
        _ => const <_ConversionChoice>[_ConversionChoice('aac', 'AAC')],
      },
      _ => const <_ConversionChoice>[],
    };
    // 音频编码同样按真实 FFmpeg 能力过滤，兼容 video/base/full 等包型差异。
    return _filterSupportedChoices(choices, widget.capabilities.audioCodecs);
  }

  /// 切换输出封装并同步当前编码选择。
  void _selectExtension(String value) {
    // 封装改变后，原来的编码可能不再合法，需要落到新集合的默认项。
    setState(() {
      _extension = value;
      _videoCodec = _selectedOrFirst(_videoCodec, _videoCodecOptions);
      _audioCodec = _selectedOrFirst(_audioCodec, _audioCodecOptions);
    });
  }

  /// 根据源文件后缀推导弹窗初始输出格式。
  String _initialExtension() {
    // 来源后缀可能来自 UI 展示值，统一清理点号和大小写。
    final sourceExtension = _normalizedSourceExtension;
    // 固定候选内存在相同封装时优先选中，避免用户打开弹窗后格式突然变化。
    for (final choice in _extensionOptions) {
      if (choice.value == sourceExtension) return choice.value;
    }
    return _extensionOptions.first.value;
  }

  /// 清理后的源文件后缀。
  String get _normalizedSourceExtension {
    // 来源可能是详情页展示用的大写后缀，也可能带点号。
    return widget.sourceExtension.replaceFirst('.', '').toLowerCase();
  }

  /// 构建转换选项和操作按钮。
  @override
  Widget build(BuildContext context) {
    return AppAlertDialog(
      width: 520,
      title: Text(
        _dialogTitle(widget.category),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ChoiceSection(
              title: '输出格式',
              choices: _extensionOptions,
              selectedValue: _extension,
              onChanged: _selectExtension,
            ),
            if (_videoCodecOptions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              _ChoiceSection(
                title: '视频编码',
                choices: _videoCodecOptions,
                selectedValue: _videoCodec,
                onChanged: (String value) {
                  // 视频编码只影响有视频流的资源转换。
                  setState(() => _videoCodec = value);
                },
              ),
            ],
            if (_audioCodecOptions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              _ChoiceSection(
                title: '音频编码',
                choices: _audioCodecOptions,
                selectedValue: _audioCodec,
                onChanged: (String value) {
                  // 音频编码只影响有声视频和音频转换。
                  setState(() => _audioCodec = value);
                },
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        AppActionButton(
          label: '取消',
          variant: AppActionButtonVariant.text,
          onPressed: () {
            // 取消不生成转换任务。
            Navigator.of(context).pop();
          },
        ),
        AppActionButton(
          label: '转换',
          icon: Icons.sync_alt_rounded,
          variant: AppActionButtonVariant.filled,
          onPressed: () {
            // 将当前选择交给调用页执行，避免弹窗持有异步业务状态。
            Navigator.of(context).pop(
              DownloadArtifactConversionOptions(
                extension: _extension,
                videoCodec: _videoCodec,
                audioCodec: _audioCodec,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 一组选项按钮。
final class _ChoiceSection extends StatelessWidget {
  /// 创建选项区域。
  const _ChoiceSection({
    required this.title,
    required this.choices,
    required this.selectedValue,
    required this.onChanged,
  });

  /// 区域标题。
  final String title;

  /// 可选项集合。
  final List<_ConversionChoice> choices;

  /// 当前选中的值。
  final String? selectedValue;

  /// 选项改变回调。
  final ValueChanged<String> onChanged;

  /// 构建标题和换行选项按钮。
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            for (final choice in choices)
              AppActionButton(
                label: choice.label,
                size: AppActionButtonSize.small,
                variant: selectedValue == choice.value
                    ? AppActionButtonVariant.filled
                    : AppActionButtonVariant.outlined,
                minWidth: 86,
                onPressed: () {
                  // 选项按钮直接写入当前分组值。
                  onChanged(choice.value);
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// 弹窗内单个候选项。
final class _ConversionChoice {
  /// 创建候选项。
  const _ConversionChoice(this.value, this.label);

  /// 业务值。
  final String value;

  /// 显示文案。
  final String label;
}

/// 返回转换弹窗标题。
String _dialogTitle(DownloadArtifactConversionCategory category) {
  // 标题说明当前资源大类，避免用户误把字幕当视频处理。
  return switch (category) {
    DownloadArtifactConversionCategory.voicedVideo => '转换有声视频',
    DownloadArtifactConversionCategory.silentVideo => '转换无声视频',
    DownloadArtifactConversionCategory.audio => '转换音频',
    DownloadArtifactConversionCategory.subtitle => '转换字幕',
    DownloadArtifactConversionCategory.danmaku => '转换弹幕',
  };
}

/// 返回候选列表首项业务值，空列表代表当前资源不需要这组选项。
String? _firstChoiceValue(List<_ConversionChoice> choices) {
  // 视频、音频编码不是所有资源都有，空列表要保留为空。
  if (choices.isEmpty) return null;
  return choices.first.value;
}

/// 当前值仍在候选内时保留，否则回退到首项。
String? _selectedOrFirst(String? selected, List<_ConversionChoice> choices) {
  // 切换封装时保留兼容编码，减少用户重复选择。
  if (choices.any((choice) => choice.value == selected)) return selected;
  return _firstChoiceValue(choices);
}

/// 根据 FFmpeg 实际能力过滤一组选项。
List<_ConversionChoice> _filterSupportedChoices(
  List<_ConversionChoice> choices,
  Set<String> supportedValues,
) {
  // 没有注册底层编码器的业务选项不能展示，否则点击转换会稳定失败。
  return choices
      .where((choice) => supportedValues.contains(choice.value))
      .toList(growable: false);
}
