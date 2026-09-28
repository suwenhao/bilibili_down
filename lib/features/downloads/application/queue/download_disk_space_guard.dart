import 'dart:io';
import 'dart:math';

import 'package:disk_usage/disk_usage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/logging/app_debug_log.dart';

/// 查询指定路径所在卷剩余字节数的可替换接口。
abstract interface class DiskSpaceProbe {
  /// 返回路径所在文件系统的可用字节；查询失败时返回空。
  Future<int?> freeBytes(String path);
}

/// 使用五端 disk_usage 插件查询磁盘空间。
final class PluginDiskSpaceProbe implements DiskSpaceProbe {
  /// 创建无状态磁盘查询器。
  const PluginDiskSpaceProbe();

  /// 调用原生文件系统 API 查询目标卷剩余空间。
  @override
  Future<int?> freeBytes(String path) async {
    // Windows 插件 1.0.0 无法正确处理中文路径，按目标盘符根目录查询可得到同一卷空间。
    if (Platform.isWindows) {
      final root = diskSpaceFallbackRoot(path, style: p.Style.windows);
      return DiskUsage.freeSpace(root.isEmpty ? path : root);
    }
    // 其他平台优先查询目标目录，兼容独立挂载点和外置存储。
    final availableBytes = await DiskUsage.freeSpace(path);
    if (availableBytes != null) return availableBytes;
    // 目标目录暂不存在或插件拒绝子路径时，最后回退同一绝对路径的根前缀。
    final root = diskSpaceFallbackRoot(path);
    if (root.isEmpty || root == path) return null;
    return DiskUsage.freeSpace(root);
  }
}

/// 返回磁盘空间插件可安全查询的卷根路径，Windows 支持盘符和 UNC 根目录。
String diskSpaceFallbackRoot(String path, {p.Style? style}) {
  // 显式上下文保证测试可覆盖 Windows 路径，不依赖运行测试的宿主平台。
  final context = p.Context(style: style ?? p.style);
  // 规范化后提取根前缀；相对路径没有可证明的目标卷，返回空交给调用方处理。
  return context.rootPrefix(context.normalize(path));
}

/// 下载启动前磁盘空间不足或无法查询。
final class InsufficientDiskSpaceException implements Exception {
  /// 创建包含所需和可用字节数的用户可读异常。
  const InsufficientDiskSpaceException({
    required this.requiredBytes,
    required this.availableBytes,
  });

  /// 本次下载、合并和安全余量合计需求。
  final int requiredBytes;

  /// 目标卷当前可用空间；无法读取时为空。
  final int? availableBytes;

  /// 返回适合任务卡错误区域展示的中文说明。
  @override
  String toString() {
    // 无法查询时阻止不可验证的写入，并提示用户检查目标目录。
    if (availableBytes == null) return '无法读取目标磁盘剩余空间，请检查下载目录权限。';
    return '磁盘空间不足：至少需要 ${_formatBytes(requiredBytes)}，'
        '当前可用 ${_formatBytes(availableBytes!)}。';
  }
}

/// 下载启动前检查目标卷并为音视频合并预留工作空间。
final class DownloadDiskSpaceGuard {
  /// 创建使用指定磁盘查询器的空间保护器。
  const DownloadDiskSpaceGuard(this._probe);

  /// 查询目标文件系统剩余字节数的平台适配器。
  final DiskSpaceProbe _probe;

  /// 最低安全余量，覆盖数据库、封面和文件系统临时开销。
  static const int minimumSafetyBytes = 128 * 1024 * 1024;

  /// 未知大小任务使用的保守最低需求。
  static const int unknownTaskRequiredBytes = 256 * 1024 * 1024;

  /// 查询目标输出卷并在空间不足时阻止任务启动。
  Future<void> ensureAvailable({
    required String outputPath,
    required int? estimatedVideoBytes,
    required int? estimatedAudioBytes,
    required bool requiresMerge,
  }) async {
    // 需求计算同时覆盖下载分流、最终成品和不可压缩的安全余量。
    final requiredBytes = requiredDiskBytes(
      estimatedVideoBytes: estimatedVideoBytes,
      estimatedAudioBytes: estimatedAudioBytes,
      requiresMerge: requiresMerge,
    );
    // 查询文件所在目录而不是进程根卷，支持用户选择其他盘符或挂载点。
    final outputDirectory = p.dirname(outputPath);
    final availableBytes = await _probe.freeBytes(outputDirectory);
    // 诊断只记录字节数，不输出用户目录路径。
    AppDebugLog.aria2(
      'Disk space check required=$requiredBytes available=${availableBytes ?? -1}',
    );
    // 查询失败或空间不足都不能继续创建大型临时文件。
    if (availableBytes == null || availableBytes < requiredBytes) {
      throw InsufficientDiskSpaceException(
        requiredBytes: requiredBytes,
        availableBytes: availableBytes,
      );
    }
  }
}

/// 提供应用级磁盘空间保护器。
final downloadDiskSpaceGuardProvider = Provider<DownloadDiskSpaceGuard>((
  Ref ref,
) {
  // 正式运行使用五端原生磁盘空间查询实现。
  return const DownloadDiskSpaceGuard(PluginDiskSpaceProbe());
});

/// 计算下载及合并期间需要保留的总字节数。
int requiredDiskBytes({
  required int? estimatedVideoBytes,
  required int? estimatedAudioBytes,
  required bool requiresMerge,
}) {
  // 只累计正数估计，接口缺失或异常负值不能减少需求。
  final estimatedBytes =
      max(0, estimatedVideoBytes ?? 0).toInt() +
      max(0, estimatedAudioBytes ?? 0).toInt();
  // 没有可靠大小时使用保守最低需求，仍能阻止磁盘接近耗尽。
  if (estimatedBytes == 0) {
    return DownloadDiskSpaceGuard.unknownTaskRequiredBytes;
  }
  // 合并阶段会同时保留下载分流和最终成品，因此按两份媒体大小计算。
  final workingBytes = requiresMerge ? estimatedBytes * 2 : estimatedBytes;
  // 安全余量取媒体大小 10% 和固定 128 MiB 中较大值。
  final safetyBytes = max(
    DownloadDiskSpaceGuard.minimumSafetyBytes,
    (estimatedBytes * 0.1).ceil(),
  ).toInt();
  return workingBytes + safetyBytes;
}

/// 把字节数格式化为简短 MiB/GiB 文案。
String _formatBytes(int bytes) {
  // 超过 1 GiB 时使用 GiB，其他情况使用 MiB 并向上取整。
  const gibibyte = 1024 * 1024 * 1024;
  const mebibyte = 1024 * 1024;
  if (bytes >= gibibyte) return '${(bytes / gibibyte).toStringAsFixed(2)} GiB';
  return '${(bytes / mebibyte).ceil()} MiB';
}
