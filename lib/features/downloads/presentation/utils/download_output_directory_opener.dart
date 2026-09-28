import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file_manager/open_file_manager.dart';

import '../../../../core/platform/android_directory_actions.dart';
import '../../../../core/widgets/app_snack_bar.dart';

/// 调用系统文件管理器打开可操作的下载输出目录。
Future<void> openDownloadOutputDirectory(
  BuildContext context,
  String directoryPath,
) async {
  try {
    // Android 必须走浏览态目录入口，避免 ACTION_OPEN_DOCUMENT 选择器限制文件操作。
    if (Platform.isAndroid) {
      final opened = await AndroidDirectoryActions.openDirectory(directoryPath);
      if (opened) return;
      // 个别设备不支持 DocumentsProvider 浏览态时，回退到旧插件入口。
      await openFileManager(
        androidConfig: AndroidConfig(
          folderType: AndroidFolderType.other,
          folderPath: directoryPath,
        ),
      );
      return;
    }
    // 目录必须仍然存在，否则系统文件管理器无法定位。
    if (!await Directory(directoryPath).exists()) {
      throw FileSystemException('文件所在目录不存在。', directoryPath);
    }
    // 按桌面系统选择原生文件管理器命令。
    if (Platform.isWindows) {
      await Process.start('explorer.exe', <String>[directoryPath]);
    } else if (Platform.isMacOS) {
      await Process.start('open', <String>[directoryPath]);
    } else if (Platform.isLinux) {
      await Process.start('xdg-open', <String>[directoryPath]);
    } else {
      // 当前入口只用于 Android 和桌面端文件管理器。
      throw UnsupportedError('当前平台不支持直接打开目录。');
    }
  } catch (error) {
    // 异步系统调用返回时先确认页面仍在 Widget 树中。
    if (!context.mounted) return;
    // 文件管理器启动失败时用可覆盖弹窗的非阻塞提示反馈原因。
    AppSnackBar.show(
      context,
      message: '打开目录失败：$error',
      type: AppSnackBarType.error,
      position: AppSnackBarPosition.top,
    );
  }
}
