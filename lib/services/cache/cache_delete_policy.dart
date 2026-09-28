import 'dart:io' as io;

import 'package:path/path.dart' as p;

import '../../core/logging/app_debug_log.dart';

/// 安全软件友好的缓存删除策略，只清理明确传入的缓存目录内容。
abstract final class CacheDeletePolicy {
  /// 清空目录内部文件并保留根目录，避免递归删除应用数据根被安全软件误判。
  static Future<void> clearDirectoryContents(io.Directory directory) async {
    // 缓存目录可能刚被第三方 CacheManager 删除，先恢复根目录再进入逐项清理。
    await directory.create(recursive: true);
    // 规范化根路径用于确认后续所有删除目标都仍在缓存目录内。
    final rootPath = p.normalize(directory.absolute.path);
    // 子目录延后处理，先删文件再只移除已经变空的目录。
    final childDirectories = <io.Directory>[];
    // 统计结果只进入脱敏日志，不暴露用户本地路径。
    var deletedFiles = 0;
    // 遍历时禁止跟随链接，避免缓存目录中的异常链接把删除范围带到外部。
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      // 删除前再次确认路径边界，防止异常路径或链接逃出当前缓存目录。
      if (!_isInside(rootPath, entity.absolute.path)) {
        AppDebugLog.cache('Cache delete skipped outside target');
        continue;
      }
      if (entity is io.Directory) {
        // 目录需要等内部文件删除后再尝试移除。
        childDirectories.add(entity);
        continue;
      }
      if (entity is io.File || entity is io.Link) {
        try {
          // 文件和链接逐个删除，行为比整目录递归删除更接近普通缓存维护。
          await entity.delete();
          deletedFiles++;
        } on io.FileSystemException catch (error) {
          // 被占用的缓存文件下次仍可继续清理，当前操作不应失败整个设置项。
          AppDebugLog.cache('Cache file delete skipped error=$error');
        }
      }
    }
    // 深层目录优先，根目录本身始终保留。
    childDirectories.sort(
      (left, right) => right.path.length.compareTo(left.path.length),
    );
    for (final child in childDirectories) {
      try {
        // 只删除已经为空的缓存子目录，绝不使用 recursive 删除目录树。
        await child.delete();
      } on io.FileSystemException {
        // 非空或被占用目录可以安全保留，不影响后续缓存重新生成。
      }
    }
    // 清理后再次确保根目录存在，下一次封面下载无需重新推断路径。
    await directory.create(recursive: true);
    AppDebugLog.cache('Cache directory contents cleared files=$deletedFiles');
  }

  /// 判断候选路径是否位于缓存根目录内部。
  static bool _isInside(String rootPath, String candidatePath) {
    // path 包的边界判断可避免 `C:\foo2` 被误认为 `C:\foo` 的子目录。
    final normalizedCandidate = p.normalize(candidatePath);
    return p.equals(rootPath, normalizedCandidate) ||
        p.isWithin(rootPath, normalizedCandidate);
  }
}
