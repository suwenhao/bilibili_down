import 'dart:ffi';
import 'dart:io';

/// 应用支持识别的宿主操作系统。
enum HostOperatingSystem { android, ios, windows, macos, linux, unsupported }

/// 当前进程使用的 CPU 指令集架构。
enum CpuArchitecture { arm32, arm64, x86, x64, unsupported }

/// 下载模块可选择的底层实现。
enum DownloadBackendKind { aria2, system }

/// 音视频合并模块可选择的底层实现。
enum MediaMergeBackendKind { ffmpegKit, bundledFfmpeg }

/// 汇总运行时平台信息，并负责选择当前平台对应的原生能力。
final class RuntimePlatform {
  /// 使用已经检测完成的系统和架构创建平台描述。
  const RuntimePlatform({
    required this.operatingSystem,
    required this.architecture,
  });

  /// 从 Dart 运行时读取当前操作系统和 ABI。
  factory RuntimePlatform.current() {
    // 同时保存系统与架构，后续下载和合并模块只依赖这一份平台判断。
    return RuntimePlatform(
      operatingSystem: _detectOperatingSystem(),
      architecture: _architectureFromAbi(Abi.current()),
    );
  }

  /// 当前宿主操作系统。
  final HostOperatingSystem operatingSystem;

  /// 当前进程的 CPU 架构。
  final CpuArchitecture architecture;

  /// 桌面端可以直接启动随安装包分发的可执行文件。
  bool get isDesktop => switch (operatingSystem) {
    HostOperatingSystem.windows ||
    HostOperatingSystem.macos ||
    HostOperatingSystem.linux => true,
    _ => false,
  };

  /// 判断当前系统与架构是否存在随包分发的 aria2c。
  bool get supportsBundledAria2 => switch (operatingSystem) {
    HostOperatingSystem.android =>
      architecture == CpuArchitecture.arm32 ||
          architecture == CpuArchitecture.arm64 ||
          architecture == CpuArchitecture.x64,
    HostOperatingSystem.windows ||
    HostOperatingSystem.macos ||
    HostOperatingSystem.linux =>
      architecture == CpuArchitecture.arm64 ||
          architecture == CpuArchitecture.x64,
    _ => false,
  };

  /// 根据是否存在 aria2c 决定首选下载后端。
  DownloadBackendKind get primaryDownloadBackend => supportsBundledAria2
      ? DownloadBackendKind.aria2
      : DownloadBackendKind.system;

  /// Windows ARM64 与 Linux ARM64 使用独立 FFmpeg，其余平台交给 FFmpegKit。
  MediaMergeBackendKind get mediaMergeBackend =>
      switch ((operatingSystem, architecture)) {
        (HostOperatingSystem.windows, CpuArchitecture.arm64) ||
        (
          HostOperatingSystem.linux,
          CpuArchitecture.arm64,
        ) => MediaMergeBackendKind.bundledFfmpeg,
        _ => MediaMergeBackendKind.ffmpegKit,
      };

  /// 将 CPU 架构转换为原生二进制目录名称。
  String get architectureDirectoryName => switch (architecture) {
    CpuArchitecture.arm32 => 'arm32',
    CpuArchitecture.arm64 => 'arm64',
    CpuArchitecture.x86 => 'x86',
    CpuArchitecture.x64 => 'x86_64',
    CpuArchitecture.unsupported => 'unsupported',
  };

  /// 按 Dart 的平台布尔值识别宿主系统。
  static HostOperatingSystem _detectOperatingSystem() {
    // 每个判断均对应一个互斥平台，命中后立即返回，避免继续匹配。
    if (Platform.isAndroid) return HostOperatingSystem.android;
    if (Platform.isIOS) return HostOperatingSystem.ios;
    if (Platform.isWindows) return HostOperatingSystem.windows;
    if (Platform.isMacOS) return HostOperatingSystem.macos;
    if (Platform.isLinux) return HostOperatingSystem.linux;
    // 未知平台保留为 unsupported，由上层给出明确的不支持提示。
    return HostOperatingSystem.unsupported;
  }

  /// 将 Dart FFI 的 ABI 枚举归一化为项目内部架构枚举。
  static CpuArchitecture _architectureFromAbi(Abi abi) {
    // 32 位 ARM ABI 共用 arm32 原生资源。
    if (abi == Abi.androidArm || abi == Abi.iosArm || abi == Abi.linuxArm) {
      return CpuArchitecture.arm32;
    }
    // 各系统的 64 位 ARM ABI 共用 arm64 原生资源。
    if (abi == Abi.androidArm64 ||
        abi == Abi.iosArm64 ||
        abi == Abi.linuxArm64 ||
        abi == Abi.macosArm64 ||
        abi == Abi.windowsArm64) {
      return CpuArchitecture.arm64;
    }
    // IA32 ABI 使用 x86 标识，便于后续扩展 32 位桌面资源。
    if (abi == Abi.androidIA32 ||
        abi == Abi.linuxIA32 ||
        abi == Abi.windowsIA32) {
      return CpuArchitecture.x86;
    }
    // 所有 x64 ABI 统一映射到 x86_64 资源目录。
    if (abi == Abi.androidX64 ||
        abi == Abi.iosX64 ||
        abi == Abi.linuxX64 ||
        abi == Abi.macosX64 ||
        abi == Abi.windowsX64) {
      return CpuArchitecture.x64;
    }
    // Dart 新增但项目尚未适配的 ABI 不应误选其他平台二进制。
    return CpuArchitecture.unsupported;
  }
}
