import 'dart:io';

import 'package:docman/docman.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'app_settings_controller.dart';

/// 提供设置页和任务页共用的系统下载目录选择流程。
final downloadDirectorySelectionServiceProvider = Provider(
  (Ref ref) => const DownloadDirectorySelectionService(),
);

/// 根据平台保存普通文件系统目录。
final class DownloadDirectorySelectionService {
  /// 无状态目录选择服务。
  const DownloadDirectorySelectionService();

  /// 打开平台目录选择器，保存成功返回 true，用户取消返回 false。
  Future<bool> chooseAndSave({
    required AppSettingsController controller,
    required String currentDisplayPath,
  }) async {
    // 等待设置恢复完成，防止首帧默认值覆盖已有目录。
    await controller.loadReadySettings();
    // Android 借助系统目录选择器定位目录，但最终只保存真实文件路径。
    if (Platform.isAndroid) {
      final selected = await DocMan.pick.directory();
      // 用户关闭系统选择器时保持现有设置。
      if (selected == null) return false;
      // 只有可创建文件的可写目录才能作为成品目标。
      if (!selected.exists ||
          !selected.isDirectory ||
          !selected.canWrite ||
          !selected.canCreate) {
        throw const FileSystemException('所选 Android 目录没有持久写入权限。');
      }
      final realPath = _androidDirectoryFilePath(selected.uri);
      // 无法转换为真实路径的外置提供器不进入下载链路。
      if (realPath == null) {
        throw const FileSystemException('当前只支持内部存储中的真实目录路径。');
      }
      // 保存真实路径，后续下载、转换和删除都直接使用文件系统。
      await controller.setDownloadDirectoryPath(realPath);
      return true;
    }

    // iOS 目录选择需要保存 security-scoped bookmark，普通路径不能作为持久授权使用。
    if (Platform.isIOS) {
      throw UnsupportedError('iOS 下载文件固定保存在应用文件目录中。');
    }

    // 桌面平台继续使用 Flutter 官方文件选择器返回普通目录路径。
    final selectedPath = await getDirectoryPath(
      initialDirectory: currentDisplayPath,
      confirmButtonText: '选择此目录',
    );
    // 用户取消或选择原目录时无需写入设置。
    if (selectedPath == null ||
        selectedPath.trim().isEmpty ||
        selectedPath == currentDisplayPath) {
      return false;
    }
    // 桌面路径由现有设置控制器持久化。
    await controller.setDownloadDirectoryPath(selectedPath);
    return true;
  }

  /// 从 Android 内部存储选择结果解析真实文件路径。
  String? _androidDirectoryFilePath(String uriString) {
    // 无法解析的选择结果不能进入真实路径链路。
    final uri = Uri.tryParse(uriString);
    if (uri == null) return null;
    // tree 后一段是形如 `primary:Movies/BiliDown` 的文档 ID。
    final treeIndex = uri.pathSegments.indexOf('tree');
    if (treeIndex < 0 || treeIndex + 1 >= uri.pathSegments.length) return null;
    // Uri.pathSegments 通常已经解码，额外解码用于兼容文档提供器差异。
    final documentId = Uri.decodeComponent(uri.pathSegments[treeIndex + 1]);
    final separatorIndex = documentId.indexOf(':');
    if (separatorIndex < 0) return null;
    final volume = documentId.substring(0, separatorIndex);
    final relativePath = documentId.substring(separatorIndex + 1);
    // 只接受主用户内部共享存储，外置盘和第三方提供器没有稳定真实路径。
    if (volume != 'primary') return null;
    if (relativePath.isEmpty) return '/storage/emulated/0';
    return p.posix.join('/storage/emulated/0', relativePath);
  }
}
