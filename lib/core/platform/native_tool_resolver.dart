import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'runtime_platform.dart';

/// 当前平台最终可用的原生工具路径及后端选择结果。
final class NativeToolPaths {
  /// 保存平台信息以及可为空的工具路径。
  const NativeToolPaths({
    required this.platform,
    required this.aria2Executable,
    required this.ffmpegExecutable,
  });

  /// 用于决定下载和合并后端的平台信息。
  final RuntimePlatform platform;

  /// aria2c 可执行文件路径；系统下载后端不需要该路径。
  final String? aria2Executable;

  /// 独立 FFmpeg 路径；使用 FFmpegKit 时保持为空。
  final String? ffmpegExecutable;

  /// 复用平台规则暴露当前下载后端。
  DownloadBackendKind get downloadBackend => platform.primaryDownloadBackend;

  /// 复用平台规则暴露当前媒体合并后端。
  MediaMergeBackendKind get mediaMergeBackend => platform.mediaMergeBackend;
}

/// 解析开发环境或安装包内与当前平台匹配的原生工具。
final class NativeToolResolver {
  /// 支持注入平台、通道和路径，便于测试不同系统的解析规则。
  NativeToolResolver({
    RuntimePlatform? platform,
    MethodChannel? androidChannel,
    Map<String, String>? environment,
    String? executablePath,
    String? workingDirectory,
  }) : _platform = platform ?? RuntimePlatform.current(),
       _androidChannel =
           androidChannel ?? const MethodChannel(_androidChannelName),
       _environment = environment ?? Platform.environment,
       _executablePath = executablePath ?? Platform.resolvedExecutable,
       _workingDirectory = workingDirectory ?? Directory.current.path;

  /// Android 原生层提供运行时工具路径的方法通道名称。
  static const String _androidChannelName = 'com.bilidown.app/native_runtime';

  /// 当前运行平台。
  final RuntimePlatform _platform;

  /// Android 原生运行时信息通道。
  final MethodChannel _androidChannel;

  /// 环境变量快照，可通过变量覆盖二进制目录。
  final Map<String, String> _environment;

  /// 当前应用可执行文件路径，用于定位安装包目录。
  final String _executablePath;

  /// 当前工作目录，用于定位开发阶段的 native_bins。
  final String _workingDirectory;

  /// 按操作系统选择对应解析流程并返回已校验的路径。
  Future<NativeToolPaths> resolve() async {
    // Android 二进制由原生层解压并设置执行权限，必须通过通道获取路径。
    if (_platform.operatingSystem == HostOperatingSystem.android) {
      return _resolveAndroid();
    }
    // iOS 使用系统下载能力和 FFmpegKit，不分发可执行文件。
    if (_platform.operatingSystem == HostOperatingSystem.ios) {
      return NativeToolPaths(
        platform: _platform,
        aria2Executable: null,
        ffmpegExecutable: null,
      );
    }
    // 未支持的非桌面平台不能套用桌面路径规则。
    if (!_platform.isDesktop) {
      throw UnsupportedError(
        'Unsupported platform: ${_platform.operatingSystem}',
      );
    }
    // Windows、macOS 和 Linux 从安装目录或开发目录解析工具。
    return _resolveDesktop();
  }

  /// 获取 Android 原生层已经准备好的 aria2c 路径。
  Future<NativeToolPaths> _resolveAndroid() async {
    // 没有对应 ABI 资源时回退系统下载后端，不尝试启动 aria2c。
    if (!_platform.supportsBundledAria2) {
      return NativeToolPaths(
        platform: _platform,
        aria2Executable: null,
        ffmpegExecutable: null,
      );
    }

    // 调用 Kotlin 方法通道，让原生层返回解压后的运行时信息。
    final runtimeInfo = await _androidChannel.invokeMapMethod<String, Object?>(
      'getNativeRuntimeInfo',
    );
    // 从通道结果读取 aria2c 的绝对路径。
    final aria2Path = runtimeInfo?['aria2Path'] as String?;
    // 原生层没有返回有效路径时立即终止，避免稍后启动进程时出现模糊错误。
    if (aria2Path == null || aria2Path.isEmpty) {
      throw const NativeToolException(
        'Android native runtime did not provide an aria2 path.',
      );
    }
    // 再次检查文件存在性，确保通道返回的缓存路径仍然有效。
    await _requireFile(aria2Path, 'aria2c');

    // Android 的 FFmpeg 由 FFmpegKit 提供，因此仅返回 aria2c 路径。
    return NativeToolPaths(
      platform: _platform,
      aria2Executable: aria2Path,
      ffmpegExecutable: null,
    );
  }

  /// 从桌面安装包或源码目录解析 aria2c 及可选 FFmpeg。
  Future<NativeToolPaths> _resolveDesktop() async {
    // 先确定与当前系统和架构匹配的原生资源目录。
    final nativeDirectory = await _findDesktopNativeDirectory();
    // Windows 可执行文件需要 .exe 后缀，类 Unix 系统则使用无后缀文件名。
    final aria2Name = _platform.operatingSystem == HostOperatingSystem.windows
        ? 'aria2c.exe'
        : 'aria2c';
    // 拼接并检查 aria2c 的最终路径。
    final aria2Path = p.join(nativeDirectory, aria2Name);
    await _requireFile(aria2Path, 'aria2c');

    // 默认由 FFmpegKit 合并，此变量仅在需要独立 FFmpeg 的平台赋值。
    String? ffmpegPath;
    // Windows ARM64 与 Linux ARM64 缺少 FFmpegKit 支持，需要查找随包工具。
    if (_platform.mediaMergeBackend == MediaMergeBackendKind.bundledFfmpeg) {
      // 根据系统选择 FFmpeg 文件名。
      final ffmpegName =
          _platform.operatingSystem == HostOperatingSystem.windows
          ? 'ffmpeg.exe'
          : 'ffmpeg';
      // 安装包目录优先，源码开发目录作为调试回退。
      final ffmpegCandidates = <String>[
        p.join(nativeDirectory, ffmpegName),
        _developmentFfmpegPath(ffmpegName),
      ];
      // 取第一个真实存在的候选文件。
      ffmpegPath = await _firstExistingFile(ffmpegCandidates);
      // 已选择 CLI 后端却找不到 FFmpeg 时必须给出完整检查列表。
      if (ffmpegPath == null) {
        throw NativeToolException(
          'ffmpeg is missing. Checked: ${ffmpegCandidates.join(', ')}',
        );
      }
    }

    // 返回已经完成存在性校验的工具集合。
    return NativeToolPaths(
      platform: _platform,
      aria2Executable: aria2Path,
      ffmpegExecutable: ffmpegPath,
    );
  }

  /// 按环境变量、安装包、源码目录的优先级查找桌面原生目录。
  Future<String> _findDesktopNativeDirectory() async {
    // 开发或部署环境可显式覆盖自动推导的目录。
    final override = _environment['BILIDOWN_NATIVE_BIN_DIR'];
    // 保持候选顺序，确保显式配置优先于自动路径。
    final candidates = <String>[
      if (override != null && override.isNotEmpty) override,
      _packagedDesktopDirectory(),
      _developmentDesktopDirectory(),
    ];

    // 逐一检查目录，首个存在的候选即为最终目录。
    for (final candidate in candidates) {
      if (await Directory(candidate).exists()) return p.normalize(candidate);
    }
    throw NativeToolException(
      'Native binary directory was not found. Checked: ${candidates.join(', ')}',
    );
  }

  /// 依据应用可执行文件位置推导安装后的原生资源目录。
  String _packagedDesktopDirectory() {
    // 所有平台都以应用可执行文件所在目录作为定位起点。
    final executableDirectory = File(_executablePath).parent.path;
    // macOS 二进制位于 .app/Contents/MacOS，资源需要回到 Contents/Resources。
    if (_platform.operatingSystem == HostOperatingSystem.macos) {
      return p.normalize(
        p.join(
          executableDirectory,
          '..',
          'Resources',
          'native_bins',
          _platform.architectureDirectoryName,
        ),
      );
    }
    // Windows 与 Linux 将 native_bins 复制到可执行文件同级目录。
    return p.join(executableDirectory, 'native_bins');
  }

  /// 根据平台和架构映射源码仓库中的 aria2 开发目录。
  String _developmentDesktopDirectory() {
    // native_bins 是所有开发环境原生资源的公共根目录。
    final root = p.join(_workingDirectory, 'native_bins');
    // 每个分支只返回与当前系统和架构匹配的目录，防止混装其他平台文件。
    return switch ((_platform.operatingSystem, _platform.architecture)) {
      (HostOperatingSystem.windows, CpuArchitecture.x64) => p.join(
        root,
        'aria2',
        'windows-x86_x64',
      ),
      (HostOperatingSystem.windows, CpuArchitecture.arm64) => p.join(
        root,
        'aria2',
        'windows-arm64',
      ),
      (HostOperatingSystem.macos, CpuArchitecture.x64) => p.join(
        root,
        'aria2',
        'macos-x86_64',
      ),
      (HostOperatingSystem.macos, CpuArchitecture.arm64) => p.join(
        root,
        'aria2',
        'macos-arm64',
      ),
      (HostOperatingSystem.linux, CpuArchitecture.x64) => p.join(
        root,
        'aria2',
        'linux-x86_x64',
      ),
      (HostOperatingSystem.linux, CpuArchitecture.arm64) => p.join(
        root,
        'aria2',
        'linux-arm64',
      ),
      _ => root,
    };
  }

  /// 解析仅供 Windows ARM64 与 Linux ARM64 使用的 FFmpeg 开发路径。
  String _developmentFfmpegPath(String executableName) {
    // 独立 FFmpeg 文件统一存放在 native_bins/ffmpeg 下。
    final root = p.join(_workingDirectory, 'native_bins', 'ffmpeg');
    // 仅两个 CLI 后端平台具有专用子目录，其余分支只是安全回退。
    return switch ((_platform.operatingSystem, _platform.architecture)) {
      (HostOperatingSystem.windows, CpuArchitecture.arm64) => p.join(
        root,
        'windows-arm64',
        executableName,
      ),
      (HostOperatingSystem.linux, CpuArchitecture.arm64) => p.join(
        root,
        'linux-arm64',
        executableName,
      ),
      _ => p.join(root, executableName),
    };
  }

  /// 返回候选列表中第一个存在的文件，并规范化其路径。
  Future<String?> _firstExistingFile(Iterable<String> candidates) async {
    // 保留候选顺序，优先使用安装包内文件。
    for (final candidate in candidates) {
      if (await File(candidate).exists()) return p.normalize(candidate);
    }
    return null;
  }

  /// 要求指定工具文件存在，否则抛出带工具名和路径的错误。
  Future<void> _requireFile(String path, String toolName) async {
    // 启动进程前验证路径，可把部署缺失问题提前暴露给界面。
    if (!await File(path).exists()) {
      throw NativeToolException('$toolName is missing: $path');
    }
  }
}

/// 原生工具目录或文件解析失败时使用的统一异常。
final class NativeToolException implements Exception {
  /// 保存可直接展示或记录的错误说明。
  const NativeToolException(this.message);

  /// 具体的路径解析失败原因。
  final String message;

  /// 输出包含异常类型的诊断文本。
  @override
  String toString() => 'NativeToolException: $message';
}
