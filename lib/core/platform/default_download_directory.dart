import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 新任务在应用专属工作根目录下统一使用的临时子目录名称。
const String downloadTemporaryDirectoryName = '.temp';

/// 旧版本任务仍可能保存的临时子目录名称，仅用于兼容清理。
const String legacyDownloadTemporaryDirectoryName = '.bilidown';

/// 用户可见的默认成品目录名称，Android 公共 Download 与桌面下载目录保持一致。
const String defaultDownloadProductDirectoryName = 'BiliDown';

/// Android 全文件权限模式下直接使用的公共下载根目录。
const String androidPublicDownloadRootPath = '/storage/emulated/0/Download';

/// 判断路径是否为当前任务的专属临时目录。
bool isDownloadTemporaryTaskDirectory({
  required String directoryPath,
  required String taskId,
}) {
  // 规范化后的目录名必须等于任务 ID，避免删除同一临时根下的其他任务。
  final normalizedPath = p.normalize(p.absolute(directoryPath));
  // 直接父目录必须是当前或旧版临时根，祖先目录重名不能扩大递归删除范围。
  final temporaryRootName = p.basename(p.dirname(normalizedPath));
  return p.basename(normalizedPath) == taskId &&
      (temporaryRootName == downloadTemporaryDirectoryName ||
          temporaryRootName == legacyDownloadTemporaryDirectoryName);
}

/// 解析各平台实际执行下载与合并的默认工作目录，并确保产品子目录已经创建。
Future<Directory> resolveDefaultDownloadDirectory() async {
  if (Platform.isAndroid) {
    // Android 已在引导阶段要求文件管理权限，直接使用公共下载目录真实路径。
    final directory = Directory(
      p.join(
        androidPublicDownloadRootPath,
        defaultDownloadProductDirectoryName,
      ),
    );
    await directory.create(recursive: true);
    await ensureAndroidNoMediaMarker(directory);
    return directory;
  }

  // 桌面平台优先使用系统下载目录，便于用户直接找到导出的文件。
  final downloadsDirectory = await getDownloadsDirectory();
  if (downloadsDirectory != null) {
    // 桌面下载目录统一使用 BiliDown 子目录，方便用户定位成品。
    final directory = Directory(
      p.join(downloadsDirectory.path, defaultDownloadProductDirectoryName),
    );
    await directory.create(recursive: true);
    return directory;
  }

  // iOS 等不提供公共下载目录的平台继续回退应用文档目录。
  final documentsDirectory = await getApplicationDocumentsDirectory();
  final directory = Directory(
    p.join(documentsDirectory.path, defaultDownloadProductDirectoryName),
  );
  await directory.create(recursive: true);
  return directory;
}

/// 在 Android 目录中写入 .nomedia，阻止媒体扫描器索引下载工作文件。
Future<void> ensureAndroidNoMediaMarker(Directory directory) async {
  if (!Platform.isAndroid) return;
  try {
    // 调用方传入的目录可能刚创建，也可能是任务临时目录，统一先确保存在。
    await directory.create(recursive: true);
    final marker = File(p.join(directory.path, '.nomedia'));
    if (await marker.exists()) return;
    // 空文件即可阻止相册和媒体库扫描该目录及其子目录。
    await marker.writeAsBytes(const <int>[], flush: true);
  } on FileSystemException {
    // 某些厂商系统可能限制工作目录写入隐藏文件，失败不能阻断下载流程。
  }
}

/// 解析设置页和任务页应展示给用户的默认成品目录。
Future<String> resolveDefaultDownloadDisplayPath() async {
  // 默认展示路径和实际写入路径保持一致，避免显示逻辑目录但写入其他位置。
  return (await resolveDefaultDownloadDirectory()).path;
}
