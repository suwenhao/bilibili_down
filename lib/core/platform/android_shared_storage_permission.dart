import 'dart:io';

import 'package:background_downloader/background_downloader.dart';

/// 读取 Android 旧版共享存储权限状态，不主动弹出系统授权框。
Future<bool> hasAndroidSharedStoragePermission() async {
  // 非 Android 平台没有旧共享存储权限，直接视为可继续。
  if (!Platform.isAndroid) return true;

  // background_downloader 统一封装 Android 9 及以下 WRITE_EXTERNAL_STORAGE 状态。
  final permissions = FileDownloader().permissions;
  final currentStatus = await permissions.status(
    PermissionType.androidSharedStorage,
  );
  return currentStatus == PermissionStatus.granted;
}

/// 确保 Android 公共下载目录发布所需的共享存储权限已经可用。
Future<bool> ensureAndroidSharedStoragePermission() async {
  // 非 Android 平台没有旧共享存储权限，直接视为可继续。
  if (!Platform.isAndroid) return true;

  // background_downloader 统一封装 Android 9 及以下 WRITE_EXTERNAL_STORAGE 请求。
  final permissions = FileDownloader().permissions;
  // Android 10+ 与已经授权的 Android 9 设备都会走到这里。
  if (await hasAndroidSharedStoragePermission()) return true;

  // 只有旧系统未授权时才触发系统权限弹窗，避免新系统出现无意义请求。
  final requestedStatus = await permissions.request(
    PermissionType.androidSharedStorage,
  );
  return requestedStatus == PermissionStatus.granted;
}
