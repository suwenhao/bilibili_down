import 'dart:io' as io;

import 'package:path/path.dart' as p;

import '../../core/logging/app_debug_log.dart';
import '../../core/platform/application_data_directory.dart';
import '../image_cache/cover_cache_manager.dart';

/// 聚合应用可以由用户主动清理的缓存文件。
abstract final class AppCacheManager {
  /// 返回设置页展示的缓存总大小，包含封面缓存和 aria2 运行日志。
  static Future<int> sizeInBytes() async {
    // 封面缓存由专用管理器维护索引和图片内存缓存。
    final coverSize = await CoverCacheManager.sizeInBytes();
    // aria2 日志用于下载诊断，属于可重新生成的运行缓存。
    final aria2LogSize = await _aria2LogSizeInBytes();
    AppDebugLog.cache(
      'Cache size calculated cover=$coverSize aria2Log=$aria2LogSize',
    );
    return coverSize + aria2LogSize;
  }

  /// 清除封面缓存和 aria2 日志，保留下载恢复所需的 aria2 会话与任务文件。
  static Future<void> clear() async {
    AppDebugLog.cache('Cache clear started');
    // 桌面端把封面缓存移入回收站，移动端继续按应用沙箱缓存直接清理。
    final moveCoverFilesToTrash =
        io.Platform.isWindows || io.Platform.isMacOS || io.Platform.isLinux;
    // 先清封面缓存，确保 CacheManager 索引、磁盘文件和内存图片同步释放。
    await CoverCacheManager.clear(moveFilesToTrash: moveCoverFilesToTrash);
    // aria2.session、runtime.json、tasks.json 关系恢复，不属于安全缓存清理范围。
    await _clearAria2Log();
    AppDebugLog.cache('Cache clear completed');
  }

  /// 计算 aria2.log 的字节数，文件不存在或暂时不可读时按零处理。
  static Future<int> _aria2LogSizeInBytes() async {
    try {
      // 日志文件由 aria2 启动配置写入应用支持目录的 aria2 子目录。
      final logFile = await _resolveAria2LogFile();
      if (!await logFile.exists()) return 0;
      return logFile.length();
    } on io.FileSystemException {
      // 文件可能正被 aria2 写入或被系统安全软件短暂锁定，设置页不能因此报错。
      AppDebugLog.cache('Aria2 log size unavailable');
      return 0;
    }
  }

  /// 清空 aria2.log 内容，保留文件本身以降低安全软件对删除行为的误判。
  static Future<void> _clearAria2Log() async {
    // 固定日志路径用于清理 aria2 运行诊断文件，不触碰同目录的恢复状态文件。
    final logFile = await _resolveAria2LogFile();
    if (!await logFile.exists()) return;
    try {
      // 日志属于可再生成缓存，截断比删除更像普通应用维护，避免 AppData 内批量删除特征。
      await logFile.writeAsString('');
      AppDebugLog.cache('Aria2 log truncated');
    } on io.FileSystemException {
      // Windows 上运行中的 aria2 或安全软件可能短暂持有日志句柄，清缓存不能因此失败。
      AppDebugLog.cache('Aria2 log truncate skipped');
    }
  }

  /// 返回 aria2 运行日志的固定文件路径。
  static Future<io.File> _resolveAria2LogFile() async {
    // 应用支持目录现在由 path_provider 统一管理，桌面和移动端保持同一入口。
    final supportDirectory = await resolveApplicationDataDirectory();
    return io.File(p.join(supportDirectory.path, 'aria2', 'aria2.log'));
  }
}
