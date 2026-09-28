import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/platform/output_path_policy.dart';
import '../../../../core/platform/platform_providers.dart';
import '../../../../core/platform/runtime_platform.dart';
import '../../data/download_task_repository.dart';
import '../../domain/download_task_phase.dart';

/// 创建使用当前数据库仓库和运行平台的文件删除计划器。
final downloadFileDeletionPlannerProvider = Provider(
  (Ref ref) => DownloadFileDeletionPlanner(
    ref.watch(downloadTaskRepositoryProvider),
    ref.watch(runtimePlatformProvider),
  ),
);

/// 删除确认弹窗与执行阶段共用的不可变文件快照。
final class DownloadFileDeletionPlan {
  /// 保存一次计划中的平台标识、文件数量、目录数量、占用空间和范围。
  const DownloadFileDeletionPlan({
    required this.storageIdentifiers,
    required this.fileCount,
    required this.directoryCount,
    required this.totalBytes,
    required this.scopeDescriptions,
  });

  /// 一次提交给平台发布器或桌面系统 Shell 的去重目标。
  final List<String> storageIdentifiers;

  /// 计划覆盖的实际文件或符号链接数量。
  final int fileCount;

  /// 计划整体回收的安全标题目录数量。
  final int directoryCount;

  /// 数据库记录或文件系统实际统计得到的总字节数。
  final int totalBytes;

  /// 用户可读的媒体库或文件系统目录范围。
  final List<String> scopeDescriptions;

  /// 判断确认后重新扫描的计划是否仍与弹窗展示范围完全一致。
  bool matches(DownloadFileDeletionPlan other) {
    // 文件数量、目录数量和容量变化都需要用户重新确认，不能静默扩大或缩小范围。
    if (fileCount != other.fileCount ||
        directoryCount != other.directoryCount ||
        totalBytes != other.totalBytes) {
      return false;
    }
    // 标识和展示范围按集合比较，文件系统枚举顺序变化不应制造误报。
    return _sameStrings(storageIdentifiers, other.storageIdentifiers) &&
        _sameStrings(scopeDescriptions, other.scopeDescriptions);
  }

  /// 比较两个已经去重列表是否包含完全相同的字符串。
  bool _sameStrings(List<String> left, List<String> right) {
    // 长度不同必然存在新增或移除项，无需继续构造集合。
    if (left.length != right.length) return false;
    final rightValues = right.toSet();
    return left.every(rightValues.contains);
  }
}

/// 构建删除计划时保存单个仍存在产物的路径、类型和容量。
final class _DeletionCandidate {
  /// 创建真实文件系统路径候选。
  const _DeletionCandidate({
    required this.identifier,
    required this.sizeBytes,
    required this.isDirectory,
    this.normalizedPath,
  });

  /// 发布器删除时使用的绝对文件路径。
  final String identifier;

  /// 文件实际大小或数据库最近记录的字节数。
  final int sizeBytes;

  /// 候选是否为目录；普通文件和链接均为 false。
  final bool isDirectory;

  /// 文件系统对象的绝对规范路径，非真实路径保持为空。
  final String? normalizedPath;
}

/// 汇总任务登记产物，并选择整目录或单文件级安全回收目标。
final class DownloadFileDeletionPlanner {
  /// 创建绑定数据库仓库和当前运行平台的计划器。
  const DownloadFileDeletionPlanner(this._repository, this._platform);

  /// 提供任务及其保留产物的一次性数据库查询。
  final DownloadTaskRepository _repository;

  /// 决定是否允许把完全匹配的标题目录作为桌面回收目标。
  final RuntimePlatform _platform;

  /// 为一批任务生成统计展示和实际执行共用的稳定快照。
  Future<DownloadFileDeletionPlan> build(List<DownloadTaskRecord> tasks) async {
    // 最终标识保持插入顺序且全局去重，Shell 不会收到重复文件。
    final plannedIdentifiers = <String>{};
    // 已覆盖普通路径用于处理旧记录重复引用同一成品。
    final coveredFileSystemPaths = <String>{};
    // 删除范围按目录或平台媒体库去重后展示。
    final scopes = <String>{};
    var fileCount = 0;
    var directoryCount = 0;
    var totalBytes = 0;

    for (final task in tasks) {
      // 每个任务先形成独立候选，只有完全匹配时才允许把整个标题目录回收。
      final artifacts = await _repository.loadRetainedArtifacts(task.taskId);
      final candidateSizes = <String, int>{};
      for (final artifact in artifacts) {
        // 只有真实文件路径才能参与删除计划，旧非文件标识直接跳过。
        final artifactPath = _artifactDeletionPath(artifact);
        if (artifactPath == null) continue;
        candidateSizes[artifactPath] = artifact.sizeBytes ?? 0;
      }
      // 主视频尚未登记时仍需把 outputPath 纳入统计和执行计划。
      final hasOutputArtifact = artifacts.any(
        (DownloadArtifactRecord artifact) =>
            artifact.kind == DownloadArtifactKind.output &&
            _artifactDeletionPath(artifact) != null,
      );
      final outputPath = task.outputPath;
      if (!hasOutputArtifact &&
          outputPath != null &&
          _isAbsoluteFilePath(outputPath)) {
        candidateSizes.putIfAbsent(outputPath, () => 0);
      }

      // 只保留当前仍存在的真实路径，非文件系统标识不进入删除执行链路。
      final candidates = <_DeletionCandidate>[];
      for (final entry in candidateSizes.entries) {
        final identifier = entry.key;
        // 普通路径统一转成绝对规范形式，并且检查时不跟随符号链接。
        final normalizedPath = p.normalize(p.absolute(identifier));
        final entityType = await FileSystemEntity.type(
          normalizedPath,
          followLinks: false,
        );
        if (entityType == FileSystemEntityType.notFound) continue;
        var sizeBytes = entry.value;
        // 数据库没有记录大小时只读取文件元数据，不加载媒体内容。
        if (sizeBytes <= 0 && entityType == FileSystemEntityType.file) {
          try {
            sizeBytes = await File(normalizedPath).length();
          } on FileSystemException {
            // 文件可能在统计期间被外部程序锁定，保留零大小但仍纳入删除计划。
          }
        }
        candidates.add(
          _DeletionCandidate(
            identifier: normalizedPath,
            sizeBytes: sizeBytes,
            isDirectory: entityType == FileSystemEntityType.directory,
            normalizedPath: normalizedPath,
          ),
        );
      }

      // 新版单视频目录只有在直属内容与当前任务登记产物完全一致时才整体回收。
      var plannedWholeTitleDirectory = false;
      if (_platform.isDesktop &&
          outputPath != null &&
          outputPath.trim().isNotEmpty &&
          candidates.every(
            (_DeletionCandidate candidate) =>
                candidate.normalizedPath != null && !candidate.isDirectory,
          )) {
        final normalizedOutputPath = p.normalize(p.absolute(outputPath));
        final outputDirectory = Directory(p.dirname(normalizedOutputPath));
        final safeTitleDirectory = _isSafeTaskBoundaryDirectory(
          directory: outputDirectory,
          outputPath: normalizedOutputPath,
          task: task,
        );
        if (safeTitleDirectory && await outputDirectory.exists()) {
          // 只枚举直属内容，出现子目录或未知文件时必须回退登记文件级回收。
          final directEntities = await outputDirectory
              .list(followLinks: false)
              .toList();
          final directPaths = directEntities
              .map(
                (FileSystemEntity entity) =>
                    p.normalize(p.absolute(entity.path)),
              )
              .toSet();
          final candidatePaths = candidates
              .map((_DeletionCandidate candidate) => candidate.normalizedPath!)
              .toSet();
          final containsSubdirectory = directEntities.any(
            (FileSystemEntity entity) => entity is Directory,
          );
          if (!containsSubdirectory &&
              directPaths.length == candidatePaths.length &&
              directPaths.containsAll(candidatePaths)) {
            final normalizedDirectory = p.normalize(
              p.absolute(outputDirectory.path),
            );
            if (plannedIdentifiers.add(normalizedDirectory)) {
              directoryCount++;
              scopes.add(normalizedDirectory);
              for (final candidate in candidates) {
                // 目录整体回收时仍按内部真实文件数量和容量展示影响范围。
                final candidatePath = candidate.normalizedPath!;
                if (coveredFileSystemPaths.add(candidatePath)) {
                  fileCount++;
                  totalBytes += candidate.sizeBytes;
                }
              }
            }
            plannedWholeTitleDirectory = true;
          }
        }
      }
      // 目录含未知内容、旧版平铺输出或移动端标识时逐项加入统一批次。
      if (!plannedWholeTitleDirectory) {
        for (final candidate in candidates) {
          final normalizedPath = candidate.normalizedPath;
          if (normalizedPath != null &&
              !coveredFileSystemPaths.add(normalizedPath)) {
            continue;
          }
          if (!plannedIdentifiers.add(candidate.identifier)) continue;
          if (candidate.isDirectory) {
            directoryCount++;
            scopes.add(candidate.identifier);
          } else {
            fileCount++;
            totalBytes += candidate.sizeBytes;
            scopes.add(
              normalizedPath == null ? '本地文件系统' : p.dirname(normalizedPath),
            );
          }
        }
      }
    }

    // 计划在弹窗展示和确认执行之间保持不变，防止统计与实际范围漂移。
    return DownloadFileDeletionPlan(
      storageIdentifiers: plannedIdentifiers.toList(growable: false),
      fileCount: fileCount,
      directoryCount: directoryCount,
      totalBytes: totalBytes,
      scopeDescriptions: scopes.toList(growable: false),
    );
  }
}

/// 返回当前删除链路可执行的真实文件路径。
String? _artifactDeletionPath(DownloadArtifactRecord artifact) {
  // 空路径和非绝对路径都不能直接交给 File.delete 或桌面回收站。
  final artifactPath = artifact.path.trim();
  if (artifactPath.isEmpty) return null;
  if (!_isAbsoluteFilePath(artifactPath)) return null;
  return artifactPath;
}

/// 判断路径是否为可执行删除的绝对文件路径。
bool _isAbsoluteFilePath(String storageIdentifier) {
  // 下载记录只允许真实路径参与删除，URI 和相对路径都跳过。
  final path = storageIdentifier.trim();
  return path.isNotEmpty && p.isAbsolute(path);
}

/// 判断目录是否为当前任务可整体回收的视频标题目录或合集目录。
bool _isSafeTaskBoundaryDirectory({
  required Directory directory,
  required String outputPath,
  required DownloadTaskRecord task,
}) {
  // 父目录名来自真实输出路径，只允许命中应用生成的边界目录。
  final directoryName = p.basename(directory.path);
  // 附加资源任务会创建“视频名/成品文件”的目录结构。
  final safeNames = <String>{p.basenameWithoutExtension(outputPath)};
  // 合集或多 P 默认会进入合集标题目录，删除最后一个视频后也允许清空该空目录。
  final collectionTitle = task.collectionTitle?.trim();
  if (collectionTitle != null && collectionTitle.isNotEmpty) {
    safeNames.add(sanitizeOutputPathSegment(collectionTitle));
  }
  // 目录名完全一致才允许后续执行整目录计划或空目录删除。
  return safeNames.contains(directoryName);
}
