import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 返回保存数据库、封面缓存等持久应用数据的统一目录。
Future<Directory> resolveApplicationDataDirectory() async {
  // 统一交给 path_provider 选择平台推荐的应用支持目录；Windows 目录由 Runner.rc 版本资源固定为 com.bilidown.app。
  final rootDirectory = await getApplicationSupportDirectory();
  // 首次启动或用户手动清理后确保应用支持目录重新存在。
  await rootDirectory.create(recursive: true);
  return rootDirectory;
}

/// 返回网络封面文件的专用缓存目录。
Future<Directory> resolveCoverCacheDirectory() async {
  // covers 位于统一应用目录下，桌面和移动端不依赖公共下载目录权限。
  final applicationDirectory = await resolveApplicationDataDirectory();
  final coversDirectory = Directory(
    p.join(applicationDirectory.path, 'covers'),
  );
  // CachedNetworkImage 第一次写入前必须确保目录存在。
  await coversDirectory.create(recursive: true);
  return coversDirectory;
}
