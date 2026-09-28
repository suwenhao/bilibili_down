import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging/app_debug_log.dart';

/// 提供桌面首次启动说明与真实运行能力检查。
final desktopRuntimeAccessServiceProvider = Provider(
  (Ref ref) => const DesktopRuntimeAccessService(),
);

/// 桌面运行能力门禁当前所处阶段。
enum DesktopRuntimeAccessPhase {
  checking,
  needsConfirmation,
  verifying,
  blocked,
  ready,
}

/// 保存桌面目录写入与下载服务启动的检查结果。
final class DesktopRuntimeAccessState {
  /// 创建一份不可变的桌面能力门禁状态。
  const DesktopRuntimeAccessState({
    required this.phase,
    this.directoryPath,
    this.storageAvailable = false,
    this.downloadServiceAvailable = false,
    this.errorMessage,
  });

  /// 当前检查或交互阶段。
  final DesktopRuntimeAccessPhase phase;

  /// 本次检查对应的实际下载目录。
  final String? directoryPath;

  /// 下载目录是否已经通过真实创建和写入检查。
  final bool storageAvailable;

  /// 当前桌面下载后端是否能够完成初始化。
  final bool downloadServiceAvailable;

  /// 能力不足时展示给用户的可操作错误说明。
  final String? errorMessage;
}

/// 执行不伪造系统授权结果的桌面运行能力检查。
final class DesktopRuntimeAccessService {
  /// 创建无状态桌面能力检查服务。
  const DesktopRuntimeAccessService();

  /// SharedPreferences 中保存首次说明已确认状态的稳定键。
  static const String _acknowledgedKey = 'desktop.runtime_access_acknowledged';

  /// 返回用户是否已经确认过桌面网络与目录用途说明。
  Future<bool> hasAcknowledged() async {
    // 首次启动说明属于非敏感偏好，使用跨平台本地设置保存。
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_acknowledgedKey) ?? false;
  }

  /// 仅在两项真实能力检查都成功后保存用户确认状态。
  Future<void> saveAcknowledged() async {
    // 能力检查成功后落盘，后续启动仍会重新检查而不是盲目信任旧结果。
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_acknowledgedKey, true);
  }

  /// 检查目录可写性并验证桌面下载服务组件。
  Future<DesktopRuntimeAccessState> verify({
    required String directoryPath,
    required Future<void> Function() verifyDownloadService,
  }) async {
    // 下载目录必须能够真实创建和写入，不能只依据路径是否存在判断权限。
    try {
      final directory = Directory(directoryPath);
      await directory.create(recursive: true);
      // 固定探针文件避免每次启动制造大量创建删除行为而触发安全软件误报。
      final accessProbe = File(
        '${directory.path}${Platform.pathSeparator}.bilidown-access-check',
      );
      await accessProbe.writeAsString(
        'BiliDown desktop storage access check\n',
        flush: true,
      );
    } on FileSystemException catch (error) {
      // 系统或安全软件拒绝写入时保留门禁，并引导用户重新选择可写目录。
      AppDebugLog.app('Desktop storage access check failed: $error');
      return DesktopRuntimeAccessState(
        phase: DesktopRuntimeAccessPhase.blocked,
        directoryPath: directoryPath,
        errorMessage: '当前保存位置无法使用。请重新选择文件夹，或在安全软件中允许 BiliDown 访问。',
      );
    } catch (error) {
      // 非标准文件系统异常同样不能绕过门禁，错误文本用于定位平台插件问题。
      AppDebugLog.app('Desktop storage capability check failed: $error');
      return DesktopRuntimeAccessState(
        phase: DesktopRuntimeAccessPhase.blocked,
        directoryPath: directoryPath,
        errorMessage: '无法检查当前保存位置，请选择其他文件夹后重试。',
      );
    }

    // 目录可用后再检查 aria2 组件，版本检查不会加载会话或恢复下载任务。
    try {
      await verifyDownloadService();
    } catch (error) {
      // 下载组件无法执行时禁止进入任务页，重试不会修改用户已有任务记录。
      AppDebugLog.aria2('Desktop download service check failed: $error');
      return DesktopRuntimeAccessState(
        phase: DesktopRuntimeAccessPhase.blocked,
        directoryPath: directoryPath,
        storageAvailable: true,
        errorMessage: '下载功能无法启动。请在安全软件中允许 BiliDown 运行，或重新安装后重试。',
      );
    }

    // 两项能力同时可用后才允许应用创建路由和下载调度器。
    return DesktopRuntimeAccessState(
      phase: DesktopRuntimeAccessPhase.ready,
      directoryPath: directoryPath,
      storageAvailable: true,
      downloadServiceAvailable: true,
    );
  }
}
