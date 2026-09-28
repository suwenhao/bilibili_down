import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/platform/output_path_policy.dart';
import '../../core/platform/runtime_platform.dart';
import 'desktop_trash_service.dart';

/// 合并完成后可持久化的成品位置。
final class PublishedMediaOutput {
  /// 保存成品真实文件路径。
  const PublishedMediaOutput({required this.storageIdentifier});

  /// 用于后续打开、删除和恢复的稳定位置标识。
  final String storageIdentifier;
}

/// 平台成品存在性、大小和基础格式检查结果。
final class MediaOutputInspection {
  /// 保存平台检查返回的稳定状态。
  const MediaOutputInspection({
    required this.exists,
    required this.sizeBytes,
    required this.basicIntegrityValid,
  });

  /// 产物标识当前是否仍能访问。
  final bool exists;

  /// 平台报告的真实字节数，不存在时为零。
  final int sizeBytes;

  /// 文件非空且基础文件头符合扩展名要求。
  final bool basicIntegrityValid;
}

/// 将应用工作目录中的合并成品发布到平台用户可见存储区。
abstract interface class MediaOutputPublisher {
  /// 根据最终目标和任务临时目录确定 FFmpeg 实际写入路径。
  Future<String> prepareOutputPath({
    required String requestedOutputPath,
    required String? temporaryDirectory,
  });

  /// 发布工作成品并返回平台可持久化的位置标识。
  Future<PublishedMediaOutput> publish({
    required String workingOutputPath,
    required String requestedOutputPath,
  });

  /// 检查此前发布的成品是否存在、非空并具有基本格式完整性。
  Future<MediaOutputInspection> inspect(
    String storageIdentifier, {
    required String requestedOutputPath,
  });

  /// 删除此前发布的成品；文件已经不存在时视为成功。
  Future<void> delete(String storageIdentifier);

  /// 批量删除此前发布的成品；桌面端用户文件应作为一次系统回收站操作提交。
  Future<void> deleteAll(Iterable<String> storageIdentifiers);
}

/// 创建当前平台对应的成品发布器。
MediaOutputPublisher createMediaOutputPublisher(RuntimePlatform _) {
  // 当前所有端都走真实文件路径发布，平台参数只保留旧调用方的构造形态。
  return const _FileSystemMediaOutputPublisher();
}

/// 所有平台直接保留合并器生成的真实文件路径。
final class _FileSystemMediaOutputPublisher implements MediaOutputPublisher {
  /// 无状态文件系统发布器。
  const _FileSystemMediaOutputPublisher();

  @override
  Future<String> prepareOutputPath({
    required String requestedOutputPath,
    required String? temporaryDirectory,
  }) async {
    // 普通文件系统可以直接让 FFmpeg 写入最终目标。
    return requestedOutputPath;
  }

  @override
  Future<PublishedMediaOutput> publish({
    required String workingOutputPath,
    required String requestedOutputPath,
  }) async {
    // 发布前重新校验数据库保存的路径，拦截旧任务或外部修改产生的非法目标。
    validateOutputPath(
      requestedOutputPath,
      operatingSystem: RuntimePlatform.current().operatingSystem,
    );
    // 合并器已经把成品写到最终位置，发布阶段只需返回绝对路径。
    return PublishedMediaOutput(storageIdentifier: workingOutputPath);
  }

  @override
  Future<void> delete(String storageIdentifier) async {
    // 单文件入口复用批量语义，确保桌面成品不会意外永久删除。
    await deleteAll(<String>[storageIdentifier]);
  }

  @override
  Future<void> deleteAll(Iterable<String> storageIdentifiers) async {
    // 删除器只执行绝对真实路径；非文件路径标识直接丢弃，避免误删相对目录。
    final fileSystemIdentifiers = storageIdentifiers
        .where(_isAbsoluteFilePath)
        .toList(growable: false);
    // Windows、macOS 和 Linux 的用户可见成品统一交给系统回收站。
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      await DesktopTrashService.movePathsToTrash(fileSystemIdentifiers);
      return;
    }
    // Android 和 iOS 都按普通文件语义删除；目录只允许调用方显式传入后递归清理。
    for (final storageIdentifier in fileSystemIdentifiers) {
      // 真实路径删除必须幂等，文件被系统或用户提前移除时仍视为成功。
      await _deleteFileSystemPathIfExists(storageIdentifier);
    }
  }

  @override
  Future<MediaOutputInspection> inspect(
    String storageIdentifier, {
    required String requestedOutputPath,
  }) async {
    // 普通文件路径可直接读取大小和少量文件头，不加载大型媒体内容。
    final file = File(storageIdentifier);
    if (!await file.exists()) {
      return const MediaOutputInspection(
        exists: false,
        sizeBytes: 0,
        basicIntegrityValid: false,
      );
    }
    final sizeBytes = await file.length();
    final basicIntegrityValid = await _hasBasicFileIntegrity(
      file,
      requestedOutputPath,
      sizeBytes,
    );
    return MediaOutputInspection(
      exists: true,
      sizeBytes: sizeBytes,
      basicIntegrityValid: basicIntegrityValid,
    );
  }
}

/// 判断存储标识是否为可直接操作的绝对文件路径。
bool _isAbsoluteFilePath(String storageIdentifier) {
  // 空值和 URI 等非文件路径不能传给 File.delete 或 FFmpeg。
  final path = storageIdentifier.trim();
  return path.isNotEmpty && p.isAbsolute(path);
}

/// 删除真实文件路径，并把并发删除或文件已不存在视为成功。
Future<void> _deleteFileSystemPathIfExists(String path) async {
  try {
    // 不跟随符号链接读取类型，防止删除记录跳到未登记的真实目标。
    final entityType = await FileSystemEntity.type(path, followLinks: false);
    // 文件缺失代表目标清理结果已经达成。
    if (entityType == FileSystemEntityType.notFound) return;
    if (entityType == FileSystemEntityType.directory) {
      // 调用方已经规划过目录范围，这里只负责执行递归清理。
      await Directory(path).delete(recursive: true);
      return;
    }
    // 普通文件和链接均作为文件实体删除。
    await File(path).delete();
  } on FileSystemException {
    // 删除过程中目标可能刚好被系统、用户或前一次重试移除，需要复查后决定是否忽略。
    final entityType = await FileSystemEntity.type(path, followLinks: false);
    if (entityType == FileSystemEntityType.notFound) return;
    rethrow;
  }
}

/// 对普通文件执行不会读取完整媒体内容的基础格式检查。
Future<bool> _hasBasicFileIntegrity(
  File file,
  String requestedOutputPath,
  int sizeBytes,
) async {
  // 空文件对所有资源类型都无效。
  if (sizeBytes <= 0) return false;
  final extension = p.extension(requestedOutputPath).toLowerCase();
  if (extension != '.mp4' && extension != '.m4a') return true;
  // MP4/M4A 至少需要 box 长度和 `ftyp` 类型字段。
  if (sizeBytes < 8) return false;
  final bytes = await file
      .openRead(0, 8)
      .fold<List<int>>(
        <int>[],
        (List<int> collected, List<int> chunk) => collected..addAll(chunk),
      );
  // ISO BMFF 文件的首个 box 通常为 ftyp，用它排除 HTML 错误页或截断空壳。
  return bytes.length >= 8 &&
      bytes[4] == 0x66 &&
      bytes[5] == 0x74 &&
      bytes[6] == 0x79 &&
      bytes[7] == 0x70;
}
