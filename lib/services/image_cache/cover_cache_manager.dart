import 'dart:io' as io;

import 'package:file/file.dart' hide FileSystem;
import 'package:file/local.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../core/platform/application_data_directory.dart';
import '../cache/cache_delete_policy.dart';
import '../media_output/desktop_trash_service.dart';

/// 封面缓存的持久化命名空间，跟正式应用标识保持一致，避免在桌面端生成旧项目名缓存记录。
const String _coverCacheNamespace = 'com.bilidown.app.covers';

/// 将 CachedNetworkImage 的网络封面统一保存到应用目录 covers。
final class CoverCacheManager extends CacheManager {
  /// 私有单例在应用启动时完成目录解析后创建。
  static CoverCacheManager? _instance;

  /// 返回已经初始化的封面缓存管理器。
  static CoverCacheManager get instance {
    // 图片组件构建前 main 必须完成初始化，缺失时立即暴露生命周期错误。
    final manager = _instance;
    if (manager == null) {
      throw StateError('CoverCacheManager 尚未初始化。');
    }
    return manager;
  }

  /// 在 runApp 前解析平台目录并创建唯一缓存实例。
  static Future<void> initialize() async {
    // 热重启或重复初始化继续复用已有实例，避免并发数据库连接。
    if (_instance != null) return;
    // 缓存文件直接落在应用数据目录的 covers 子目录。
    final cacheDirectory = await resolveCoverCacheDirectory();
    _instance = CoverCacheManager._(cacheDirectory.path);
  }

  /// 创建带自定义文件系统的缓存管理器。
  CoverCacheManager._(String cachePath)
    : super(
        Config(
          _coverCacheNamespace,
          stalePeriod: const Duration(days: 60),
          maxNrOfCacheObjects: 500,
          fileSystem: _CoverCacheFileSystem(cachePath),
        ),
      );

  /// 统计当前封面缓存占用字节数。
  static Future<int> sizeInBytes() async {
    try {
      // 递归统计 covers 内缓存文件，目录和损坏项不计入大小。
      final directory = await resolveCoverCacheDirectory();
      var total = 0;
      await for (final entity in directory.list(recursive: true)) {
        // 只有真实文件占用空间，子目录本身不累计。
        if (entity is io.File) total += await entity.length();
      }
      return total;
    } on io.FileSystemException {
      // 系统临时锁定缓存文件时设置页显示零，不阻断其他设置。
      return 0;
    }
  }

  /// 清除磁盘索引、封面文件和 Flutter 内存图片缓存。
  static Future<void> clear({bool moveFilesToTrash = false}) async {
    if (moveFilesToTrash) {
      // 桌面端先把封面缓存实体移入系统回收站，避免清缓存表现为 AppData 内批量硬删除。
      await _moveCacheContentsToTrash();
    }
    // CacheManager 清理索引和可能残留的缓存文件；桌面端文件已进回收站时这里主要清理元数据。
    await instance.emptyCache();
    // 自定义目录可能已由 emptyCache 删除，统一重建供下一次下载使用。
    final directory = await resolveCoverCacheDirectory();
    if (!moveFilesToTrash) {
      // 移动端和无回收站平台保留 covers 根目录，只清理白名单缓存文件。
      await CacheDeletePolicy.clearDirectoryContents(directory);
    } else {
      // 回收站操作后只恢复根目录，下一次封面下载仍可直接写入固定位置。
      await directory.create(recursive: true);
    }
    // 已解码图片还可能停留在 Flutter 内存缓存，清理后必须同步释放。
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }

  /// 把 covers 根目录下的当前缓存实体作为一个批次移入系统回收站。
  static Future<void> _moveCacheContentsToTrash() async {
    // 确保缓存根目录存在，目录缺失代表没有需要处理的磁盘缓存。
    final directory = await resolveCoverCacheDirectory();
    // 只提交 covers 的直接子项，保留根目录本身避免后续 FileSystem 适配器路径失效。
    final paths = <String>[];
    await for (final entity in directory.list(followLinks: false)) {
      // 普通文件、子目录和链接都属于封面缓存目录内部实体，可交给系统回收站处理。
      paths.add(entity.path);
    }
    // 空缓存不调用平台通道，避免没有实际文件时弹出系统错误。
    if (paths.isEmpty) return;
    await DesktopTrashService.movePathsToTrash(paths);
  }
}

/// 把 flutter_cache_manager 的文件创建请求定向到 covers 目录。
final class _CoverCacheFileSystem implements FileSystem {
  /// 创建指向固定缓存根目录的文件系统适配器。
  const _CoverCacheFileSystem(this.basePath);

  /// 缓存文件实际写入的绝对目录。
  final String basePath;

  /// 创建缓存管理器要求的本地文件对象。
  @override
  Future<File> createFile(String name) async {
    // package:file 提供 CacheManager 需要的抽象文件接口。
    const fileSystem = LocalFileSystem();
    // 清除缓存后目录可能暂时不存在，写入前必须递归恢复。
    final directory = fileSystem.directory(basePath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.childFile(name);
  }
}
