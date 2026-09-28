import 'dart:io';

import 'package:bilibili_down/core/platform/runtime_platform.dart';
import 'package:bilibili_down/features/downloads/application/resources/download_artifact_conversion_service.dart';
import 'package:bilibili_down/services/media_merge/media_merge_files.dart';
import 'package:bilibili_down/services/media_merge/media_processing_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 创建使用测试 FFmpeg 执行器的转换服务。
  DownloadArtifactConversionService serviceWithRunner(
    Future<void> Function(List<String> arguments)? runner,
  ) {
    // 测试固定使用随包 FFmpeg 分支，执行器注入后不会启动真实进程。
    return DownloadArtifactConversionService(
      backend: MediaMergeBackendKind.bundledFfmpeg,
      ffmpegExecutable: null,
      guard: const NoopMediaProcessingGuard(),
      ffmpegRunner: runner,
    );
  }

  /// 验证 B 站 XML 弹幕优先走内置转换器，不依赖 FFmpeg 二进制。
  test('XML 弹幕转换为 ASS 不需要 FFmpeg', () async {
    // 临时目录隔离转换输入和输出。
    final directory = await Directory.systemTemp.createTemp(
      'bilidown-artifact-danmaku-',
    );
    addTearDown(() => directory.delete(recursive: true));
    // 输入使用真实 B 站 d 节点，覆盖内置弹幕转换路径。
    final source = File('${directory.path}/demo.xml');
    await source.writeAsString('<i><d p="1,1,25,16777215">弹幕</d></i>');

    // 没有 ffmpegExecutable 时如果错误走 FFmpeg 分支会直接失败。
    final result = await serviceWithRunner(null).convert(
      sourcePath: source.path,
      category: DownloadArtifactConversionCategory.danmaku,
      options: const DownloadArtifactConversionOptions(extension: 'ass'),
    );

    // 输出应为同目录带目标格式标记的 ASS 文件。
    expect(result.path, endsWith('demo [ASS].ass'));
    expect(await File(result.path).readAsString(), contains('Dialogue:'));
    expect(result.sizeBytes, greaterThan(0));
  });

  /// 验证字幕转换会避让已存在的转换文件名。
  test('字幕转换输出自动避让重名文件', () async {
    // 临时目录里预先放置首个候选输出，触发序号递增分支。
    final directory = await Directory.systemTemp.createTemp(
      'bilidown-artifact-subtitle-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}/subtitle.json');
    await source.writeAsString('{"body":[{"from":0,"to":1,"content":"第一句"}]}');
    await File('${directory.path}/subtitle [SRT].srt').writeAsString('old');

    // BCC JSON 转 SRT 使用内置转换器，也不需要真实 FFmpeg。
    final result = await serviceWithRunner(null).convert(
      sourcePath: source.path,
      category: DownloadArtifactConversionCategory.subtitle,
      options: const DownloadArtifactConversionOptions(extension: 'srt'),
    );

    // 第二个候选名应被选中，避免覆盖用户已有文件。
    expect(result.path, endsWith('subtitle [SRT_1].srt'));
    expect(await File(result.path).readAsString(), contains('第一句'));
  });

  /// 验证有声视频按用户选择生成转码参数。
  test('有声视频转换使用选择的视频和音频编码', () async {
    // 临时源文件只用于通过存在性检查，真实内容由测试执行器忽略。
    final directory = await Directory.systemTemp.createTemp(
      'bilidown-artifact-video-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}/video.mp4');
    await source.writeAsBytes(<int>[1, 2, 3]);
    late List<String> capturedArguments;

    // 测试执行器记录参数并模拟 FFmpeg 生成临时输出文件。
    final service = serviceWithRunner((List<String> arguments) async {
      capturedArguments = arguments;
      await File(arguments.last).writeAsString('converted');
    });
    final result = await service.convert(
      sourcePath: source.path,
      category: DownloadArtifactConversionCategory.voicedVideo,
      options: const DownloadArtifactConversionOptions(
        extension: 'mkv',
        videoCodec: 'h264',
        audioCodec: 'flac',
      ),
    );

    // 文件名必须体现目标封装和编码，方便用户区分多次转换结果。
    expect(result.path, endsWith('video [MKV_H264_FLAC].mkv'));
    // 选择 H264 和 FLAC 后应真实传递对应编码器，而不是继续流复制。
    expect(
      capturedArguments,
      containsAllInOrder(<String>['-c:v', 'libopenh264']),
    );
    expect(capturedArguments, containsAllInOrder(<String>['-c:a', 'flac']));
    expect(
      capturedArguments,
      isNot(containsAllInOrder(<String>['-c:v', 'copy'])),
    );
    expect(
      capturedArguments,
      isNot(containsAllInOrder(<String>['-c:a', 'copy'])),
    );
  });

  /// 验证纯音频导出按目标封装选择基础内置编码器。
  test('音频转 WAV 使用 PCM 编码', () async {
    // 临时源文件只用于模拟已下载音频资源。
    final directory = await Directory.systemTemp.createTemp(
      'bilidown-artifact-audio-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}/audio.m4a');
    await source.writeAsBytes(<int>[1, 2, 3]);
    late List<String> capturedArguments;

    // 记录 FFmpeg 参数并写出临时文件，覆盖音频编码映射。
    final service = serviceWithRunner((List<String> arguments) async {
      capturedArguments = arguments;
      await File(arguments.last).writeAsString('converted');
    });
    final result = await service.convert(
      sourcePath: source.path,
      category: DownloadArtifactConversionCategory.audio,
      options: const DownloadArtifactConversionOptions(
        extension: 'wav',
        audioCodec: 'pcm',
      ),
    );

    // 音频转换文件名同样要写入目标封装和音频编码。
    expect(result.path, endsWith('audio [WAV_PCM].wav'));
    // WAV 输出应使用 FFmpeg 内置 PCM，而不是外部音频编码库。
    expect(
      capturedArguments,
      containsAllInOrder(<String>['-c:a', 'pcm_s16le']),
    );
    expect(capturedArguments, isNot(contains('libmp3lame')));
    expect(capturedArguments, isNot(contains('libopus')));
  });

  /// 验证不兼容的封装和编码组合会提前失败。
  test('WebM 有声视频不允许 AAC 音频编码', () async {
    // 临时源文件只用于通过存在性检查。
    final directory = await Directory.systemTemp.createTemp(
      'bilidown-artifact-invalid-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}/video.mp4');
    await source.writeAsBytes(<int>[1, 2, 3]);

    // WebM 在当前 UI 中只允许 OPUS，AAC 应被服务层拦截。
    await expectLater(
      serviceWithRunner((List<String> arguments) async {
        await File(arguments.last).writeAsString('converted');
      }).convert(
        sourcePath: source.path,
        category: DownloadArtifactConversionCategory.voicedVideo,
        options: const DownloadArtifactConversionOptions(
          extension: 'webm',
          videoCodec: 'av1',
          audioCodec: 'aac',
        ),
      ),
      throwsA(isA<MediaMergeException>()),
    );
  });

  /// 验证能力探测不会把当前包缺失的 H265 暴露给 UI。
  test('转换能力按 FFmpeg 实际编码器过滤 H265', () async {
    // 探针只返回 LGPL 常见编码器，不包含 libx265 或 HEVC 硬件编码器。
    final service = DownloadArtifactConversionService(
      backend: MediaMergeBackendKind.bundledFfmpeg,
      ffmpegExecutable: null,
      guard: const NoopMediaProcessingGuard(),
      ffmpegProbe: (_) async => '''
Encoders:
 V..... libopenh264 OpenH264 H.264 encoder
 A..... aac AAC encoder
 A..... flac FLAC encoder
''',
    );

    final capabilities = await service.conversionCapabilities();

    // H264 可展示，H265 没有底层 encoder 时不能展示给用户。
    expect(capabilities.videoCodecs, contains('h264'));
    expect(capabilities.videoCodecs, isNot(contains('h265')));
    expect(capabilities.audioCodecs, containsAll(<String>['aac', 'flac']));
  });
}
