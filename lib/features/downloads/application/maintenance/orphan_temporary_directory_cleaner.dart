import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/platform/default_download_directory.dart';

/// 一次孤立临时目录扫描后的可观测结果。
final class OrphanTemporaryCleanupResult {
  /// 保存删除、保护、等待和失败数量。
  const OrphanTemporaryCleanupResult({
    required this.deleted,
    required this.protected,
    required this.tooRecent,
    required this.failed,
  });

  /// 已经安全递归删除的孤立任务目录数量。
  final int deleted;

  /// 因数据库仍有任务引用而保留的目录数量。
  final int protected;

  /// 因尚未超过安全等待期而保留的未知目录数量。
  final int tooRecent;

  /// 因枚举、状态读取或删除异常而保留的目录数量。
  final int failed;
}

/// 只清理应用临时根目录下无数据库任务引用的陈旧一级子目录。
final class OrphanTemporaryDirectoryCleaner {
  /// 创建使用指定安全等待期的清理器。
  const OrphanTemporaryDirectoryCleaner({
    this.minimumOrphanAge = const Duration(hours: 24),
  });

  /// 新目录可能属于尚未完成入库的任务，达到该时长前一律保留。
  final Duration minimumOrphanAge;

  /// 扫描多个下载根目录，并以全部数据库任务临时路径作为保护白名单。
  Future<OrphanTemporaryCleanupResult> cleanup({
    required Iterable<Directory> downloadRoots,
    required Iterable<String> protectedTemporaryDirectories,
    DateTime? now,
  }) async {
    // 规范化白名单，兼容数据库中的相对片段和 Windows 大小写差异。
    final protectedPaths = protectedTemporaryDirectories
        .where((String path) => path.trim().isNotEmpty)
        .map(_normalizedComparisonPath)
        .toSet();
    // 根目录去重，防止默认目录与用户目录相同时重复扫描和计数。
    final rootPaths = downloadRoots
        .map((Directory root) => p.normalize(p.absolute(root.path)))
        .toSet();
    // 单次扫描使用固定时间，避免大量目录跨越等待期边界产生不一致结果。
    final effectiveNow = now ?? DateTime.now();
    var deleted = 0;
    var protected = 0;
    var tooRecent = 0;
    var failed = 0;
    for (final rootPath in rootPaths) {
      // 同时兼容当前 `.temp` 与旧版本 `.bilidown` 临时根目录。
      for (final temporaryRootName in const <String>[
        downloadTemporaryDirectoryName,
        legacyDownloadTemporaryDirectoryName,
      ]) {
        final temporaryRoot = Directory(p.join(rootPath, temporaryRootName));
        // 不存在的临时根不需要创建，也不计为清理失败。
        if (!await temporaryRoot.exists()) continue;
        try {
          // 禁止跟随符号链接，只处理应用任务布局中的一级真实目录。
          await for (final entity in temporaryRoot.list(followLinks: false)) {
            if (entity is! Directory) continue;
            final candidatePath = p.normalize(p.absolute(entity.path));
            // 再次确认候选直属当前临时根，防止异常路径绕过递归删除边界。
            if (!_samePath(p.dirname(candidatePath), temporaryRoot.path)) {
              failed++;
              continue;
            }
            // 任意数据库任务仍引用该目录时完整保留，不区分活动、失败或终态。
            if (protectedPaths.contains(
              _normalizedComparisonPath(candidatePath),
            )) {
              protected++;
              continue;
            }
            try {
              // 刚创建但尚未来得及入库的目录需要等待，避免启动竞态误删下载文件。
              final stat = await entity.stat();
              if (effectiveNow.difference(stat.modified) < minimumOrphanAge) {
                tooRecent++;
                continue;
              }
              // 删除范围已经限制为临时根的一级真实目录，可安全递归移除其内容。
              await entity.delete(recursive: true);
              deleted++;
            } catch (_) {
              // 单个目录失败时保留原内容并继续扫描其他候选。
              failed++;
            }
          }
        } catch (_) {
          // 临时根整体不可枚举时记录一次失败，不能阻断下载协调器启动。
          failed++;
        }
      }
    }
    // 返回稳定统计供启动日志和测试确认清理边界。
    return OrphanTemporaryCleanupResult(
      deleted: deleted,
      protected: protected,
      tooRecent: tooRecent,
      failed: failed,
    );
  }

  /// 根据当前平台的路径大小写规则生成白名单比较键。
  String _normalizedComparisonPath(String path) {
    // Windows 文件系统通常不区分大小写，其他平台保留原始大小写语义。
    final normalized = p.normalize(p.absolute(path));
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  /// 判断两个目录路径是否指向同一规范位置。
  bool _samePath(String left, String right) =>
      _normalizedComparisonPath(left) == _normalizedComparisonPath(right);
}
