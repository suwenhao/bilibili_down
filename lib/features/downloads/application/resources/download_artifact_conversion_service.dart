import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/logging/app_debug_log.dart';
import '../../../../core/platform/platform_providers.dart';
import '../../../../core/platform/runtime_platform.dart';
import '../../../../services/media_merge/media_merge_files.dart';
import '../../../../services/media_merge/media_processing_guard.dart';
import 'download_resource_converter.dart';

/// 本地下载产物支持的转换大类。
enum DownloadArtifactConversionCategory {
  /// 含音频的视频成品。
  voicedVideo,

  /// 仅视频画面的分流文件。
  silentVideo,

  /// 独立音频或音频分流。
  audio,

  /// 字幕文本。
  subtitle,

  /// 弹幕文本。
  danmaku,
}

/// 用户在转换弹窗中选择的目标参数。
final class DownloadArtifactConversionOptions {
  /// 创建一次本地资源转换参数。
  const DownloadArtifactConversionOptions({
    required this.extension,
    this.videoCodec,
    this.audioCodec,
  });

  /// 输出文件后缀，不包含点号。
  final String extension;

  /// 目标视频编码；纯音频或文本转换时为空。
  final String? videoCodec;

  /// 目标音频编码；静音视频或文本转换时为空。
  final String? audioCodec;
}

/// 当前 FFmpeg 后端可用于本地资源转换的业务编码集合。
final class DownloadArtifactConversionCapabilities {
  /// 创建一次编码能力快照。
  const DownloadArtifactConversionCapabilities({
    required this.videoCodecs,
    required this.audioCodecs,
  });

  /// 可用于视频重编码的业务编码值，例如 h264、h265 或 av1。
  final Set<String> videoCodecs;

  /// 可用于音频重编码的业务编码值，例如 aac、mp3 或 flac。
  final Set<String> audioCodecs;

  /// 测试注入执行器时使用的完整候选能力，避免单元测试依赖本机 FFmpeg。
  static const DownloadArtifactConversionCapabilities optimistic =
      DownloadArtifactConversionCapabilities(
        videoCodecs: <String>{'h264', 'h265', 'av1'},
        audioCodecs: <String>{
          'aac',
          'mp3',
          'alac',
          'flac',
          'ac3',
          'opus',
          'pcm',
        },
      );
}

/// 本地资源转换完成后的文件信息。
final class DownloadArtifactConversionResult {
  /// 创建转换结果。
  const DownloadArtifactConversionResult({
    required this.path,
    required this.sizeBytes,
  });

  /// 转换生成的文件路径。
  final String path;

  /// 转换生成文件的字节数。
  final int sizeBytes;
}

/// 测试环境可注入的 FFmpeg 执行器。
typedef DownloadArtifactFfmpegRunner =
    Future<void> Function(List<String> arguments);

/// 测试环境可注入的 FFmpeg 能力查询器。
typedef DownloadArtifactFfmpegProbe =
    Future<String> Function(List<String> arguments);

/// 创建下载产物转换服务，并根据平台绑定对应 FFmpeg 后端。
final downloadArtifactConversionServiceProvider =
    FutureProvider<DownloadArtifactConversionService>((Ref ref) async {
      // 原生工具路径决定桌面 ARM64 是否需要使用随包 FFmpeg。
      final paths = await ref.watch(nativeToolPathsProvider.future);
      // Android 转换需要前台服务守卫，其余平台使用空实现。
      final guard =
          paths.platform.operatingSystem == HostOperatingSystem.android
          ? AndroidMediaProcessingGuard()
          : const NoopMediaProcessingGuard();
      return DownloadArtifactConversionService(
        backend: paths.mediaMergeBackend,
        ffmpegExecutable: paths.ffmpegExecutable,
        guard: guard,
      );
    });

/// 使用 FFmpeg 或内置文本转换器处理已下载的本地资源。
final class DownloadArtifactConversionService {
  /// 创建可复用的转换服务。
  DownloadArtifactConversionService({
    required this.backend,
    required this.ffmpegExecutable,
    required this.guard,
    this.ffmpegRunner,
    this.ffmpegProbe,
  });

  /// 当前平台选中的 FFmpeg 后端。
  final MediaMergeBackendKind backend;

  /// CLI 后端使用的 FFmpeg 可执行文件路径。
  final String? ffmpegExecutable;

  /// 转换期间维持平台后台执行能力的守卫。
  final MediaProcessingGuard guard;

  /// 测试专用执行器，生产环境为空并走真实 FFmpeg 后端。
  final DownloadArtifactFfmpegRunner? ffmpegRunner;

  /// 测试专用能力查询器，生产环境为空并读取真实 FFmpeg 能力。
  final DownloadArtifactFfmpegProbe? ffmpegProbe;

  /// 同一服务实例内串行执行转换，避免多个 FFmpeg 同时争抢资源。
  Future<void> _conversionQueue = Future<void>.value();

  /// 当前服务实例已读取的 FFmpeg 编码器集合。
  Future<Set<String>>? _registeredEncoderNamesCache;

  /// 当前服务实例已换算出的业务编码能力。
  Future<DownloadArtifactConversionCapabilities>? _conversionCapabilitiesCache;

  /// 查询当前 FFmpeg 后端实际支持的转换编码能力。
  Future<DownloadArtifactConversionCapabilities> conversionCapabilities() {
    // 能力列表在进程生命周期内基本稳定，缓存后避免每次打开弹窗都查询原生库。
    return _conversionCapabilitiesCache ??= _loadConversionCapabilities();
  }

  /// 将本地资源转换为用户选择的目标格式。
  Future<DownloadArtifactConversionResult> convert({
    required String sourcePath,
    required DownloadArtifactConversionCategory category,
    required DownloadArtifactConversionOptions options,
  }) {
    // 追加到串行队列，保持 UI 多次点击时的执行顺序。
    final completer = Completer<DownloadArtifactConversionResult>();
    _conversionQueue = _conversionQueue.then((_) async {
      try {
        final result = await _convertNow(
          sourcePath: sourcePath,
          category: category,
          options: options,
        );
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  /// 执行一次真实转换并返回输出文件。
  Future<DownloadArtifactConversionResult> _convertNow({
    required String sourcePath,
    required DownloadArtifactConversionCategory category,
    required DownloadArtifactConversionOptions options,
  }) async {
    // 输入文件必须存在，避免 FFmpeg 报出不友好的路径错误。
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw MediaMergeException('源文件不存在：${p.basename(sourcePath)}');
    }
    // 输出文件放在源文件同目录，并自动避让已有同名文件。
    final outputPath = await _nextAvailableOutputPath(
      sourcePath: sourcePath,
      category: category,
      options: options,
    );
    // 文本类 B 站专用格式优先走内置转换器，避免 FFmpeg 误判 XML 或 JSON。
    if (await _tryConvertTextResource(
      sourcePath: sourcePath,
      outputPath: outputPath,
      category: category,
      options: options,
    )) {
      final sizeBytes = await File(outputPath).length();
      return DownloadArtifactConversionResult(
        path: outputPath,
        sizeBytes: sizeBytes,
      );
    }

    // FFmpeg 输出使用真实后缀的临时文件，确保 muxer 能按扩展名推断格式。
    final temporaryPath = _temporaryOutputPath(outputPath);
    var guardStarted = false;
    var completed = false;
    try {
      await guard.start();
      guardStarted = true;
      final arguments = await _ffmpegArguments(
        sourcePath: sourcePath,
        outputPath: temporaryPath,
        category: category,
        options: options,
      );
      AppDebugLog.ffmpeg(
        'Artifact conversion started input=${p.basename(sourcePath)} '
        'output=${p.basename(outputPath)} category=${category.name}',
      );
      await _runFfmpeg(arguments);
      await _promoteTemporaryOutput(temporaryPath, outputPath);
      completed = true;
      final sizeBytes = await File(outputPath).length();
      AppDebugLog.ffmpeg(
        'Artifact conversion succeeded output=${p.basename(outputPath)}',
      );
      return DownloadArtifactConversionResult(
        path: outputPath,
        sizeBytes: sizeBytes,
      );
    } finally {
      // 失败或取消时删除临时文件，避免用户看到半成品。
      if (!completed) await MediaMergeFiles.cleanup(temporaryPath);
      // 只有成功启动过守卫才释放平台资源。
      if (guardStarted) await guard.stop();
    }
  }

  /// 尝试使用项目内置转换器处理 B 站弹幕和字幕原始文本。
  Future<bool> _tryConvertTextResource({
    required String sourcePath,
    required String outputPath,
    required DownloadArtifactConversionCategory category,
    required DownloadArtifactConversionOptions options,
  }) async {
    // 文件后缀用于识别 B 站原始文本格式。
    final sourceExtension = p.extension(sourcePath).toLowerCase();
    // 目标后缀统一成小写，避免大小写影响转换分支。
    final targetExtension = options.extension.toLowerCase();
    if (category == DownloadArtifactConversionCategory.danmaku &&
        sourceExtension == '.xml' &&
        targetExtension == 'ass') {
      await convertBiliDanmakuXmlFileToAss(
        inputPath: sourcePath,
        outputPath: outputPath,
      );
      return true;
    }
    if (category == DownloadArtifactConversionCategory.subtitle &&
        sourceExtension == '.json' &&
        targetExtension == 'srt') {
      await convertBiliSubtitleJsonFileToSrt(
        inputPath: sourcePath,
        outputPath: outputPath,
      );
      return true;
    }
    return false;
  }

  /// 运行当前平台对应的 FFmpeg 后端。
  Future<void> _runFfmpeg(List<String> arguments) async {
    // 测试注入执行器用于验证参数和输出发布，不依赖真实 FFmpeg 二进制。
    final injectedRunner = ffmpegRunner;
    if (injectedRunner != null) {
      await injectedRunner(arguments);
      return;
    }
    // 平台规则选择 FFmpegKit 时不需要外部可执行文件路径。
    if (backend == MediaMergeBackendKind.ffmpegKit) {
      await _runFfmpegKit(arguments);
      return;
    }
    // CLI 后端没有路径说明安装包资源不完整。
    final executable = ffmpegExecutable;
    if (executable == null || executable.isEmpty) {
      throw const MediaMergeException('当前平台缺少 FFmpeg 可执行文件。');
    }
    await _runCliFfmpeg(executable, arguments);
  }

  /// 使用 FFmpegKit 执行转换。
  Future<void> _runFfmpegKit(List<String> arguments) async {
    // FFmpegKit 原生库必须先初始化。
    await FFmpegKitExtended.initialize();
    final session = FFmpegKit.createSessionFromArguments(arguments);
    await session.executeAsync();
    final returnCode = session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = session.getLogsAsString() ?? session.getFailStackTrace();
      AppDebugLog.ffmpeg('Artifact conversion FFmpegKit failed logs=$logs');
      throw MediaMergeException('FFmpeg 转换失败。', logs);
    }
  }

  /// 使用随包 FFmpeg 子进程执行转换。
  Future<void> _runCliFfmpeg(String executable, List<String> arguments) async {
    // 参数列表直接传给 Process，避免 shell 转义路径。
    final process = await Process.start(
      executable,
      arguments,
      mode: ProcessStartMode.normal,
    );
    // 只保留最近错误日志，用于失败提示和诊断。
    final stderrLines = ListQueue<String>(80);
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((String line) {
          if (stderrLines.length == 80) stderrLines.removeFirst();
          stderrLines.addLast(line);
          AppDebugLog.ffmpeg('Artifact conversion stderr: $line');
        });
    final stdoutDone = process.stdout.drain<void>();
    final exitCode = await process.exitCode;
    await Future.wait(<Future<void>>[stderrDone, stdoutDone]);
    if (exitCode != 0) {
      throw MediaMergeException(
        'FFmpeg 转换失败，退出码 $exitCode。',
        stderrLines.join('\n'),
      );
    }
  }

  /// 根据资源类型构造 FFmpeg 参数。
  Future<List<String>> _ffmpegArguments({
    required String sourcePath,
    required String outputPath,
    required DownloadArtifactConversionCategory category,
    required DownloadArtifactConversionOptions options,
  }) async {
    // 基础参数隐藏横幅并禁用标准输入，避免后台任务被交互阻塞。
    final arguments = <String>[
      '-hide_banner',
      '-nostdin',
      '-y',
      '-i',
      sourcePath,
    ];
    switch (category) {
      case DownloadArtifactConversionCategory.voicedVideo:
        // 有声视频需要同时验证封装、视频编码和音频编码的组合。
        final videoArguments = await _videoCodecArguments(
          codec: options.videoCodec,
          extension: options.extension,
        );
        final audioArguments = await _audioCodecArguments(
          codec: options.audioCodec,
          extension: options.extension,
        );
        arguments.addAll(<String>['-map', '0:v:0', '-map', '0:a?']);
        arguments.addAll(videoArguments);
        arguments.addAll(audioArguments);
      case DownloadArtifactConversionCategory.silentVideo:
        // 静音视频只处理视频流，输出封装仍需要校验视频编码兼容性。
        final videoArguments = await _videoCodecArguments(
          codec: options.videoCodec,
          extension: options.extension,
        );
        arguments.addAll(<String>['-map', '0:v:0', '-an']);
        arguments.addAll(videoArguments);
      case DownloadArtifactConversionCategory.audio:
        // 独立音频根据目标后缀选择音频编码，避免输出扩展名和编码不匹配。
        final audioArguments = await _audioCodecArguments(
          codec: options.audioCodec,
          extension: options.extension,
        );
        arguments.addAll(<String>['-vn']);
        arguments.addAll(audioArguments);
      case DownloadArtifactConversionCategory.subtitle:
      case DownloadArtifactConversionCategory.danmaku:
        // 文本字幕转换由 FFmpeg 根据输入和输出扩展名选择对应解复用器。
        break;
    }
    if (_usesFastStart(options.extension)) {
      arguments.addAll(<String>['-movflags', '+faststart']);
    }
    arguments.add(outputPath);
    return arguments;
  }

  /// 将 UI 视频编码值映射为 FFmpeg 参数。
  Future<List<String>> _videoCodecArguments({
    required String? codec,
    required String extension,
  }) async {
    // 旧调用未指定视频编码时保持快速封装，不强制重编码。
    if (codec == null || codec.isEmpty) return const <String>['-c:v', 'copy'];
    _ensureVideoCodecAllowed(codec: codec, extension: extension);
    final encoder = await _resolveVideoEncoder(codec);
    final arguments = <String>['-c:v', encoder.name];
    // 不同编码器使用对应的低风险默认质量参数。
    arguments.addAll(encoder.extraArguments);
    return arguments;
  }

  /// 将 UI 音频编码值映射为 FFmpeg 参数。
  Future<List<String>> _audioCodecArguments({
    required String? codec,
    required String extension,
  }) async {
    // 旧调用未指定音频编码时保持快速封装，不强制重编码。
    if (codec == null || codec.isEmpty) return const <String>['-c:a', 'copy'];
    _ensureAudioCodecAllowed(codec: codec, extension: extension);
    final encoder = await _resolveAudioEncoder(codec);
    final arguments = <String>['-c:a', encoder.name];
    // 有损音频默认给到通用码率，避免 FFmpeg 使用过低默认值。
    arguments.addAll(encoder.extraArguments);
    return arguments;
  }

  /// 验证视频封装与编码组合。
  void _ensureVideoCodecAllowed({
    required String codec,
    required String extension,
  }) {
    // 输出后缀来自 UI 或外部调用，统一转小写后按封装能力判断。
    final normalizedExtension = extension.toLowerCase();
    final allowedCodecs = switch (normalizedExtension) {
      'mp4' || 'mov' || 'mkv' => const <String>{'h264', 'h265', 'av1'},
      'avi' || 'flv' => const <String>{'h264'},
      'webm' => const <String>{'av1'},
      _ => const <String>{},
    };
    if (!allowedCodecs.contains(codec)) {
      throw MediaMergeException(
        '${normalizedExtension.toUpperCase()} 不支持 ${codec.toUpperCase()} 视频编码。',
      );
    }
  }

  /// 验证音频封装与编码组合。
  void _ensureAudioCodecAllowed({
    required String codec,
    required String extension,
  }) {
    // 不同封装对音频编码限制较多，提前拦截可以给出更清晰的错误。
    final normalizedExtension = extension.toLowerCase();
    final allowedCodecs = switch (normalizedExtension) {
      'mp4' || 'mov' || 'm4a' => const <String>{'aac', 'alac', 'ac3'},
      'mkv' => const <String>{'aac', 'mp3', 'flac', 'ac3'},
      'avi' || 'flv' => const <String>{'aac', 'mp3'},
      'webm' || 'opus' => const <String>{'opus'},
      'aac' => const <String>{'aac'},
      'mp3' => const <String>{'mp3'},
      'flac' => const <String>{'flac'},
      'ogg' => const <String>{'opus', 'flac'},
      'ac3' => const <String>{'ac3'},
      'wav' => const <String>{'pcm'},
      _ => const <String>{},
    };
    if (!allowedCodecs.contains(codec)) {
      throw MediaMergeException(
        '${normalizedExtension.toUpperCase()} 不支持 ${codec.toUpperCase()} 音频编码。',
      );
    }
  }

  /// 解析当前 FFmpeg 可用的视频编码器。
  Future<_ResolvedFfmpegEncoder> _resolveVideoEncoder(String codec) async {
    // 业务编码映射到多个 FFmpeg 编码器候选，按当前包型和平台取第一个可用项。
    final candidates =
        _videoEncoderCandidatesByCodec[codec] ??
        const <_FfmpegEncoderCandidate>[];
    return _resolveEncoder(codec: codec.toUpperCase(), candidates: candidates);
  }

  /// 解析当前 FFmpeg 可用的音频编码器。
  Future<_ResolvedFfmpegEncoder> _resolveAudioEncoder(String codec) async {
    // 音频编码同样通过共享候选表解析，保证 UI 能力和执行参数不漂移。
    final candidates =
        _audioEncoderCandidatesByCodec[codec] ??
        const <_FfmpegEncoderCandidate>[];
    return _resolveEncoder(codec: codec.toUpperCase(), candidates: candidates);
  }

  /// 把 FFmpeg 编码器列表换算成 UI 可展示的业务编码能力。
  Future<DownloadArtifactConversionCapabilities>
  _loadConversionCapabilities() async {
    // 测试注入执行器但未注入探针时，沿用旧测试语义认为所有候选编码均可用。
    if (ffmpegRunner != null && ffmpegProbe == null) {
      return DownloadArtifactConversionCapabilities.optimistic;
    }
    // 原生 FFmpeg 能力输出是编码器名，需要映射回业务编码值。
    final encoders = await _registeredEncoderNames();
    return DownloadArtifactConversionCapabilities(
      videoCodecs: _supportedCodecKeys(
        _videoEncoderCandidatesByCodec,
        encoders,
      ),
      audioCodecs: _supportedCodecKeys(
        _audioEncoderCandidatesByCodec,
        encoders,
      ),
    );
  }

  /// 从候选编码器中选择当前 FFmpeg 支持的第一个。
  Future<_ResolvedFfmpegEncoder> _resolveEncoder({
    required String codec,
    required List<_FfmpegEncoderCandidate> candidates,
  }) async {
    // 测试注入执行器时不查询本机 FFmpeg，直接使用首个候选生成参数。
    if (ffmpegRunner != null && ffmpegProbe == null) {
      if (candidates.isEmpty) throw MediaMergeException('当前没有可用的 $codec 编码器。');
      final first = candidates.first;
      return _ResolvedFfmpegEncoder(first.name, first.extraArguments);
    }
    final encoders = await _registeredEncoderNames();
    for (final candidate in candidates) {
      if (encoders.contains(candidate.name)) {
        return _ResolvedFfmpegEncoder(candidate.name, candidate.extraArguments);
      }
    }
    throw MediaMergeException('当前 FFmpeg 包不支持 $codec 编码转换，请检查 FFmpegKit 包配置。');
  }

  /// 读取当前 FFmpeg 后端注册的编码器名称。
  Future<Set<String>> _registeredEncoderNames() async {
    // 编码器列表在进程内稳定，缓存后避免连续转换反复查询原生库或子进程。
    return _registeredEncoderNamesCache ??= _loadRegisteredEncoderNames();
  }

  /// 从真实后端或测试探针加载 FFmpeg 编码器名称。
  Future<Set<String>> _loadRegisteredEncoderNames() async {
    // 注入能力查询器供测试覆盖，不触发真实原生库或子进程。
    final probe = ffmpegProbe;
    if (probe != null) {
      return _parseFfmpegNameSet(await probe(const <String>['-encoders']));
    }
    if (backend == MediaMergeBackendKind.ffmpegKit) {
      await FFmpegKitExtended.initialize();
      return _parseFfmpegNameSet(FFmpegKitExtended.getRegisteredEncoders());
    }
    final executable = ffmpegExecutable;
    if (executable == null || executable.isEmpty) {
      throw const MediaMergeException('当前平台缺少 FFmpeg 可执行文件。');
    }
    final result = await Process.run(executable, const <String>['-encoders']);
    return _parseFfmpegNameSet('${result.stdout}\n${result.stderr}');
  }

  /// MP4 和 MOV 输出需要 faststart，方便移动端和播放器快速读取。
  bool _usesFastStart(String extension) {
    // 后缀来自弹窗固定候选，仍统一转小写防御调用方差异。
    final value = extension.toLowerCase();
    return value == 'mp4' || value == 'mov' || value == 'm4a';
  }

  /// 生成同目录且不覆盖已有文件的目标路径。
  Future<String> _nextAvailableOutputPath({
    required String sourcePath,
    required DownloadArtifactConversionCategory category,
    required DownloadArtifactConversionOptions options,
  }) async {
    // 输出目录沿用源文件目录，避免跨平台选择保存路径。
    final directory = p.dirname(sourcePath);
    // 基础名去掉原后缀后追加转换标记。
    final baseName = p.basenameWithoutExtension(sourcePath);
    // 后缀统一剥离点号，调用方传入 `.mp4` 也能容错。
    final safeExtension = options.extension.replaceFirst('.', '').toLowerCase();
    // 文件名标记必须体现目标封装和编码，用户才能区分多次转换结果。
    final marker = _conversionOutputMarker(
      category: category,
      options: options,
    );
    var index = 0;
    while (true) {
      // 首个输出直接使用目标标记，后续冲突用递增序号避免覆盖已有文件。
      final suffix = index == 0 ? marker : '${marker}_$index';
      final candidate = p.join(directory, '$baseName [$suffix].$safeExtension');
      if (!await File(candidate).exists()) return candidate;
      index += 1;
    }
  }

  /// 返回带真实扩展名的临时输出路径。
  String _temporaryOutputPath(String outputPath) {
    // 临时名保留真实扩展名，FFmpeg 才能识别输出封装格式。
    final extension = p.extension(outputPath);
    final withoutExtension = p.withoutExtension(outputPath);
    return '$withoutExtension.part$extension';
  }

  /// 将临时文件提升为最终输出文件。
  Future<void> _promoteTemporaryOutput(
    String temporaryPath,
    String outputPath,
  ) async {
    // 转换成功但没有生成文件属于 FFmpeg 异常。
    final temporary = File(temporaryPath);
    if (!await temporary.exists()) {
      throw MediaMergeException('转换输出未生成：${p.basename(outputPath)}');
    }
    await temporary.rename(outputPath);
  }
}

/// 生成转换文件名中的目标能力标记。
String _conversionOutputMarker({
  required DownloadArtifactConversionCategory category,
  required DownloadArtifactConversionOptions options,
}) {
  // 输出封装永远放在第一位，后续编码按资源类型追加，便于肉眼扫描。
  final parts = <String>[_conversionTag(options.extension)];
  switch (category) {
    case DownloadArtifactConversionCategory.voicedVideo:
      // 有声视频同时描述视频编码和音频编码。
      parts.add(_conversionTag(options.videoCodec ?? 'copy'));
      parts.add(_conversionTag(options.audioCodec ?? 'copy'));
    case DownloadArtifactConversionCategory.silentVideo:
      // 无声视频只描述视频编码。
      parts.add(_conversionTag(options.videoCodec ?? 'copy'));
    case DownloadArtifactConversionCategory.audio:
      // 独立音频只描述音频编码。
      parts.add(_conversionTag(options.audioCodec ?? 'copy'));
    case DownloadArtifactConversionCategory.subtitle:
    case DownloadArtifactConversionCategory.danmaku:
      // 文本资源目标格式已经足够表达转换结果。
      break;
  }
  return parts.where((String part) => part.isNotEmpty).join('_');
}

/// 清理文件名标记中的特殊字符。
String _conversionTag(String value) {
  // 编码和封装来自固定候选，但仍清理外部调用传入的异常字符。
  final normalized = value.replaceFirst('.', '').trim();
  if (normalized.isEmpty) return 'FILE';
  final cleaned = normalized.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '');
  return cleaned.isEmpty ? 'FILE' : cleaned.toUpperCase();
}

/// 从候选表筛出当前 FFmpeg 实际注册的业务编码键。
Set<String> _supportedCodecKeys(
  Map<String, List<_FfmpegEncoderCandidate>> candidatesByCodec,
  Set<String> encoderNames,
) {
  // 候选表的 key 是 UI 业务值，value 是可替代的底层编码器名称。
  return <String>{
    for (final entry in candidatesByCodec.entries)
      if (entry.value.any((candidate) => encoderNames.contains(candidate.name)))
        entry.key,
  };
}

/// 视频业务编码到 FFmpeg 编码器的候选映射。
const Map<String, List<_FfmpegEncoderCandidate>>
_videoEncoderCandidatesByCodec = <String, List<_FfmpegEncoderCandidate>>{
  'h264': <_FfmpegEncoderCandidate>[
    _FfmpegEncoderCandidate('libopenh264', <String>['-b:v', '5000k']),
    _FfmpegEncoderCandidate('libx264', <String>[
      '-preset',
      'veryfast',
      '-crf',
      '23',
    ]),
    _FfmpegEncoderCandidate('h264_videotoolbox', <String>[]),
    _FfmpegEncoderCandidate('h264_nvenc', <String>[]),
    _FfmpegEncoderCandidate('h264_qsv', <String>[]),
    _FfmpegEncoderCandidate('h264_amf', <String>[]),
    _FfmpegEncoderCandidate('h264_mediacodec', <String>[]),
  ],
  'h265': <_FfmpegEncoderCandidate>[
    _FfmpegEncoderCandidate('libx265', <String>[
      '-preset',
      'medium',
      '-crf',
      '28',
    ]),
    _FfmpegEncoderCandidate('hevc_videotoolbox', <String>[]),
    _FfmpegEncoderCandidate('hevc_nvenc', <String>[]),
    _FfmpegEncoderCandidate('hevc_qsv', <String>[]),
    _FfmpegEncoderCandidate('hevc_amf', <String>[]),
    _FfmpegEncoderCandidate('hevc_mediacodec', <String>[]),
  ],
  'av1': <_FfmpegEncoderCandidate>[
    _FfmpegEncoderCandidate('libsvtav1', <String>[
      '-preset',
      '8',
      '-crf',
      '35',
    ]),
    _FfmpegEncoderCandidate('libaom-av1', <String>[
      '-cpu-used',
      '6',
      '-crf',
      '35',
      '-b:v',
      '0',
    ]),
    _FfmpegEncoderCandidate('av1_nvenc', <String>[]),
    _FfmpegEncoderCandidate('av1_qsv', <String>[]),
    _FfmpegEncoderCandidate('av1_amf', <String>[]),
  ],
};

/// 音频业务编码到 FFmpeg 编码器的候选映射。
const Map<String, List<_FfmpegEncoderCandidate>>
_audioEncoderCandidatesByCodec = <String, List<_FfmpegEncoderCandidate>>{
  'aac': <_FfmpegEncoderCandidate>[
    _FfmpegEncoderCandidate('aac', <String>['-b:a', '192k']),
  ],
  'mp3': <_FfmpegEncoderCandidate>[
    _FfmpegEncoderCandidate('libmp3lame', <String>['-b:a', '192k']),
    _FfmpegEncoderCandidate('mp3', <String>['-b:a', '192k']),
  ],
  'alac': <_FfmpegEncoderCandidate>[
    _FfmpegEncoderCandidate('alac', <String>[]),
  ],
  'flac': <_FfmpegEncoderCandidate>[
    _FfmpegEncoderCandidate('flac', <String>[]),
  ],
  'ac3': <_FfmpegEncoderCandidate>[
    _FfmpegEncoderCandidate('ac3', <String>['-b:a', '192k']),
  ],
  'opus': <_FfmpegEncoderCandidate>[
    _FfmpegEncoderCandidate('libopus', <String>['-b:a', '160k']),
    _FfmpegEncoderCandidate('opus', <String>['-b:a', '160k']),
  ],
  'pcm': <_FfmpegEncoderCandidate>[
    _FfmpegEncoderCandidate('pcm_s16le', <String>[]),
  ],
};

/// FFmpeg 编码器候选项。
final class _FfmpegEncoderCandidate {
  /// 创建一个具体 FFmpeg 编码器候选。
  const _FfmpegEncoderCandidate(this.name, this.extraArguments);

  /// FFmpeg 命令行使用的编码器名称。
  final String name;

  /// 该编码器需要追加的默认质量或码率参数。
  final List<String> extraArguments;
}

/// 已解析出的 FFmpeg 编码器。
final class _ResolvedFfmpegEncoder {
  /// 创建已经确认可用的编码器。
  const _ResolvedFfmpegEncoder(this.name, this.extraArguments);

  /// FFmpeg 命令行使用的编码器名称。
  final String name;

  /// 该编码器需要追加的默认质量或码率参数。
  final List<String> extraArguments;
}

/// 从 FFmpegKit 或 CLI 输出中提取编码器名称集合。
Set<String> _parseFfmpegNameSet(String output) {
  // FFmpegKit 返回逗号分隔，CLI 返回表格；统一用常见编码器名称字符切分。
  return output
      .split(RegExp(r'[^A-Za-z0-9_.-]+'))
      .where((String value) => value.isNotEmpty)
      .map((String value) => value.toLowerCase())
      .toSet();
}
