import 'dart:io';

import 'package:flutter/services.dart';

/// Android 系统级权限桥接，集中处理文件管理和通知授权状态。
abstract final class AndroidAppPermissions {
  /// 原生 MethodChannel 名称必须与 MainActivity 保持一致。
  static const MethodChannel _channel = MethodChannel(
    'com.bilidown.app/android_permissions',
  );

  /// 判断 Android 11+ 是否已允许应用管理所有文件。
  static Future<bool> hasAllFilesAccess() async {
    // 非 Android 平台没有该系统开关，调用方可以直接继续文件操作。
    if (!Platform.isAndroid) return true;
    final granted = await _channel.invokeMethod<bool>('hasAllFilesAccess');
    return granted ?? false;
  }

  /// 打开 Android 文件管理授权设置页，由用户在系统页面完成开关。
  static Future<void> openAllFilesAccessSettings() async {
    // 非 Android 平台没有授权页面，保持跨平台调用安全。
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('openAllFilesAccessSettings');
  }

  /// 确保文件管理授权可用；未授权时打开系统设置并返回当前状态。
  static Future<bool> ensureAllFilesAccess() async {
    // 先读取一次状态，避免每次操作都打断已经授权的用户。
    if (await hasAllFilesAccess()) return true;
    await openAllFilesAccessSettings();
    // 系统设置页通常异步返回，调用方可根据 false 停留并提示用户回来重试。
    return hasAllFilesAccess();
  }

  /// 判断 Android 13+ 通知运行时权限是否已授予。
  static Future<bool> hasNotificationPermission() async {
    // 非 Android 或旧 Android 没有这个运行时权限，统一视为已满足。
    if (!Platform.isAndroid) return true;
    final granted = await _channel.invokeMethod<bool>(
      'hasNotificationPermission',
    );
    return granted ?? false;
  }

  /// 请求 Android 13+ 通知权限，并返回用户本次授权后的状态。
  static Future<bool> requestNotificationPermission() async {
    // 非 Android 平台不需要通过原生通道请求通知运行时权限。
    if (!Platform.isAndroid) return true;
    final granted = await _channel.invokeMethod<bool>(
      'requestNotificationPermission',
    );
    return granted ?? false;
  }

  /// 确保通知权限可用，供首次引导和后台下载服务启动前统一调用。
  static Future<bool> ensureNotificationPermission() async {
    // 已授权时不再重复弹系统权限框。
    if (await hasNotificationPermission()) return true;
    return requestNotificationPermission();
  }
}
