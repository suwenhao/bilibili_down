import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_debug_log.dart';
import '../../../../core/platform/android_app_permissions.dart';
import '../../../../core/platform/android_shared_storage_permission.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../application/onboarding_controller.dart';

/// 引导页完成动作和 busy 状态入口。
final onboardingPageControllerProvider =
    NotifierProvider<OnboardingPageController, OnboardingPageState>(
      OnboardingPageController.new,
    );

/// 引导页页面动作状态。
final class OnboardingPageState {
  /// 创建引导页页面状态。
  const OnboardingPageState({
    required this.completing,
    required this.fileManagementGranted,
    required this.notificationGranted,
    required this.requestingFileManagement,
    required this.requestingNotification,
    required this.refreshingPermissions,
  });

  /// 初始状态没有保存动作。
  factory OnboardingPageState.initial() {
    return const OnboardingPageState(
      completing: false,
      fileManagementGranted: false,
      notificationGranted: false,
      requestingFileManagement: false,
      requestingNotification: false,
      refreshingPermissions: false,
    );
  }

  /// 是否正在写入已完成标记。
  final bool completing;

  /// 文件管理授权当前是否已经满足保存、转换和删除文件的需要。
  final bool fileManagementGranted;

  /// 通知授权当前是否已经满足下载、合并和转换进度提示的需要。
  final bool notificationGranted;

  /// 文件管理授权按钮当前是否正在等待系统权限流程。
  final bool requestingFileManagement;

  /// 通知授权按钮当前是否正在等待系统权限流程。
  final bool requestingNotification;

  /// 页面恢复前台或进入引导时是否正在刷新权限状态。
  final bool refreshingPermissions;

  /// 最后一页“开始使用”需要满足的全部必需授权。
  bool get requiredPermissionsGranted =>
      fileManagementGranted && notificationGranted;

  /// 返回替换部分字段后的新状态。
  OnboardingPageState copyWith({
    bool? completing,
    bool? fileManagementGranted,
    bool? notificationGranted,
    bool? requestingFileManagement,
    bool? requestingNotification,
    bool? refreshingPermissions,
  }) {
    return OnboardingPageState(
      completing: completing ?? this.completing,
      fileManagementGranted:
          fileManagementGranted ?? this.fileManagementGranted,
      notificationGranted: notificationGranted ?? this.notificationGranted,
      requestingFileManagement:
          requestingFileManagement ?? this.requestingFileManagement,
      requestingNotification:
          requestingNotification ?? this.requestingNotification,
      refreshingPermissions:
          refreshingPermissions ?? this.refreshingPermissions,
    );
  }
}

/// 承接首次引导页的完成保存和错误反馈。
final class OnboardingPageController extends Notifier<OnboardingPageState> {
  /// 创建初始页面动作状态。
  @override
  OnboardingPageState build() {
    // 初次构建后异步刷新授权状态，避免 build 阶段直接执行平台通道调用。
    Future<void>.microtask(refreshPermissionStatus);
    return OnboardingPageState.initial();
  }

  /// 刷新引导页必需权限状态，供首次进入和从系统设置返回时使用。
  Future<void> refreshPermissionStatus() async {
    // 防止生命周期恢复和页面切换同时触发重复平台查询。
    if (state.refreshingPermissions) return;
    state = state.copyWith(refreshingPermissions: true);
    try {
      // 只读取权限状态，不主动弹系统授权框，保证用户点击授权前没有打扰。
      final permissionStatus = await _readRequiredAndroidPermissionStatus();
      state = state.copyWith(
        fileManagementGranted: permissionStatus.fileManagementGranted,
        notificationGranted: permissionStatus.notificationGranted,
      );
    } finally {
      state = state.copyWith(refreshingPermissions: false);
    }
  }

  /// 用户点击文件管理授权按钮后，依次处理旧存储权限和 Android 11+ 文件管理开关。
  Future<void> requestFileManagementPermission(BuildContext context) async {
    // 已经授权时不重复打开系统页，避免用户误触。
    if (state.fileManagementGranted || state.requestingFileManagement) return;
    state = state.copyWith(requestingFileManagement: true);
    try {
      // Android 9 及以下仍可能需要普通共享存储权限弹窗。
      final legacyStorageGranted = await ensureAndroidSharedStoragePermission();
      // Android 11+ 需要进入“管理所有文件”系统页开启开关。
      final allFilesGranted =
          await AndroidAppPermissions.ensureAllFilesAccess();
      final granted = legacyStorageGranted && allFilesGranted;
      state = state.copyWith(fileManagementGranted: granted);
      if (!granted && context.mounted) {
        AppSnackBar.show(
          context,
          message: '请在系统设置中开启文件管理授权后再继续。',
          type: AppSnackBarType.error,
        );
      }
    } catch (error) {
      AppDebugLog.onboarding('File permission request failed error=$error');
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message: '文件管理授权失败，请重试。',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      state = state.copyWith(requestingFileManagement: false);
    }
  }

  /// 用户点击通知授权按钮后，请求系统通知权限并同步显示状态。
  Future<void> requestNotificationPermission(BuildContext context) async {
    // 已经授权时不重复弹权限框，避免系统拒绝后体验混乱。
    if (state.notificationGranted || state.requestingNotification) return;
    state = state.copyWith(requestingNotification: true);
    try {
      // Android 13+ 会弹系统通知权限；旧系统原生侧直接返回已满足。
      final granted =
          await AndroidAppPermissions.ensureNotificationPermission();
      state = state.copyWith(notificationGranted: granted);
      if (!granted && context.mounted) {
        AppSnackBar.show(
          context,
          message: '请允许通知权限后再继续。',
          type: AppSnackBarType.error,
        );
      }
    } catch (error) {
      AppDebugLog.onboarding(
        'Notification permission request failed error=$error',
      );
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message: '通知权限授权失败，请重试。',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      state = state.copyWith(requestingNotification: false);
    }
  }

  /// 保存当前引导版本已完成，并在失败时留在原页提示用户。
  Future<void> complete(BuildContext context) async {
    // 防止快速重复点击并发写入 SharedPreferences。
    if (state.completing) return;
    // 按钮切换为进度状态，明确说明正在保存。
    state = state.copyWith(completing: true);
    try {
      // Android 首次引导只校验已授权状态，不在开始使用按钮里突然拉起系统页。
      if (Platform.isAndroid) await _assertRequiredAndroidPermissionsGranted();
      // 应用控制器完成持久化后，根组件会自动恢复主应用路由。
      await ref.read(onboardingControllerProvider.notifier).complete();
      AppDebugLog.onboarding('Onboarding completed');
    } catch (error) {
      AppDebugLog.onboarding('Onboarding completion failed error=$error');
      // 页面仍存在时恢复按钮并展示可重试错误提示。
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        message: _onboardingPermissionMessage(error),
        type: AppSnackBarType.error,
      );
    } finally {
      state = state.copyWith(completing: false);
    }
  }

  /// 只读取 Android 权限状态，供按钮启用和完成前防御性校验使用。
  Future<_RequiredAndroidPermissionStatus>
  _readRequiredAndroidPermissionStatus() async {
    // 非 Android 平台没有文件管理和通知运行时授权，默认满足引导条件。
    if (!Platform.isAndroid) {
      return const _RequiredAndroidPermissionStatus(
        fileManagementGranted: true,
        notificationGranted: true,
      );
    }
    // 旧共享存储权限和 Android 11+ 文件管理开关共同组成文件管理授权。
    final legacyStorageGranted = await hasAndroidSharedStoragePermission();
    final allFilesGranted = await AndroidAppPermissions.hasAllFilesAccess();
    // 通知权限由原生侧按系统版本判断，Android 12 及以下会返回已满足。
    final notificationGranted =
        await AndroidAppPermissions.hasNotificationPermission();
    return _RequiredAndroidPermissionStatus(
      fileManagementGranted: legacyStorageGranted && allFilesGranted,
      notificationGranted: notificationGranted,
    );
  }

  /// 检查 Android 下载器必需权限，未满足时不写入引导完成状态。
  Future<void> _assertRequiredAndroidPermissionsGranted() async {
    // 完成前重新读取一次状态，避免系统设置返回后 UI 未及时刷新。
    final permissionStatus = await _readRequiredAndroidPermissionStatus();
    state = state.copyWith(
      fileManagementGranted: permissionStatus.fileManagementGranted,
      notificationGranted: permissionStatus.notificationGranted,
    );
    if (!permissionStatus.fileManagementGranted) {
      throw const FileSystemException('Android 文件管理授权未开启。');
    }
    if (!permissionStatus.notificationGranted) {
      throw const FileSystemException('Android 通知权限未授权。');
    }
  }
}

/// 引导页必需 Android 权限的快照。
final class _RequiredAndroidPermissionStatus {
  /// 创建文件管理和通知权限状态快照。
  const _RequiredAndroidPermissionStatus({
    required this.fileManagementGranted,
    required this.notificationGranted,
  });

  /// 文件管理权限是否已满足。
  final bool fileManagementGranted;

  /// 通知权限是否已满足。
  final bool notificationGranted;
}

/// 将引导权限异常转换为用户可执行的简短提示。
String _onboardingPermissionMessage(Object error) {
  final message = error.toString();
  // 文件管理授权需要跳转系统设置，用户返回后再次点击完成即可。
  if (message.contains('文件管理')) {
    return '请开启文件管理授权后再继续。转换、删除文件和保存成品都需要此权限。';
  }
  // 通知权限用于下载服务和媒体处理服务的前台通知。
  if (message.contains('通知')) {
    return '请允许通知权限后再继续。下载、合并和转换进度需要通过系统通知保持稳定。';
  }
  // 旧设备的普通存储权限仍保留独立文案。
  if (message.contains('存储')) {
    return '请允许存储权限后再继续。';
  }
  return '需要完成文件管理和通知授权后才能继续。';
}
