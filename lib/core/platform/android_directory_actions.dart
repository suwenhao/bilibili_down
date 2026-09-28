import 'dart:io';

import 'package:flutter/services.dart';

/// Android 目录动作桥接，用系统文件管理器打开可浏览、可操作的真实目录。
final class AndroidDirectoryActions {
  /// 禁止实例化，所有入口都通过静态方法调用平台通道。
  const AndroidDirectoryActions._();

  /// 原生 MethodChannel 名称必须与 MainActivity 保持一致。
  static const MethodChannel _channel = MethodChannel(
    'com.bilidown.app/android_directory_actions',
  );

  /// 在 Android 系统文件管理器中打开指定目录，非 Android 平台直接返回 false。
  static Future<bool> openDirectory(String path) async {
    // 桌面端沿用各自系统文件管理器，不走 Android DocumentsUI。
    if (!Platform.isAndroid) return false;
    // 空目录无法转换为 DocumentsProvider 的 documentId。
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) return false;
    final opened = await _channel.invokeMethod<bool>(
      'openDirectory',
      <String, String>{'path': normalizedPath},
    );
    // 原生侧只有成功发起系统文件管理器时返回 true。
    return opened == true;
  }
}
