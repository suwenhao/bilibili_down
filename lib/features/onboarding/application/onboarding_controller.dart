import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 提供首次引导恢复、完成和设置页重看能力。
final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );

/// 首次引导当前是否仍在读取本地状态，以及本次会话是否需要展示。
final class OnboardingState {
  /// 创建不可变的引导状态快照。
  const OnboardingState({required this.isRestoring, required this.isCompleted});

  /// SharedPreferences 是否仍在恢复版本化完成标记。
  final bool isRestoring;

  /// 当前引导版本是否已经完成。
  final bool isCompleted;
}

/// 管理移动端首次引导的版本化本地标记。
final class OnboardingController extends Notifier<OnboardingState> {
  /// v1 内容变化时可升级键名，让旧用户只在确有必要时看到新版引导。
  static const String _completedStorageKey = 'onboarding.completed.v1';

  /// 本次会话主动操作次数，避免较晚完成的恢复覆盖重看或完成操作。
  int _changeRevision = 0;

  /// 创建等待恢复的初始状态，并异步读取本地完成标记。
  @override
  OnboardingState build() {
    // 偏好读取不阻塞 Provider 创建，根组件会在恢复期间显示主题化启动页。
    unawaited(_restore());
    // 首次安装默认未完成，读取结束前通过 isRestoring 防止引导闪现。
    return const OnboardingState(isRestoring: true, isCompleted: false);
  }

  /// 持久化当前版本已完成，并让根组件恢复主应用路由。
  Future<void> complete() async {
    // 主动完成会使正在进行的旧恢复结果失效。
    _changeRevision++;
    // 获取跨平台非敏感偏好存储；引导标记不包含账号或下载信息。
    final preferences = await SharedPreferences.getInstance();
    // 先确认写入成功，避免存储失败后下次启动意外重复展示。
    final saved = await preferences.setBool(_completedStorageKey, true);
    // 平台实现拒绝写入时抛出明确异常，由页面反馈并保留当前步骤。
    if (!saved) throw StateError('无法保存使用引导完成状态。');
    // 写入成功后结束引导，当前 MaterialApp 会切回原路由页面。
    state = const OnboardingState(isRestoring: false, isCompleted: true);
  }

  /// 仅在当前会话重新展示引导，不清除已完成标记，防止中途退出后再次强制出现。
  void showAgain() {
    // 设置页主动重看会使尚未完成的旧恢复结果失效。
    _changeRevision++;
    // 保留磁盘上的完成标记，只让根组件在本次会话切换到引导页。
    state = const OnboardingState(isRestoring: false, isCompleted: false);
  }

  /// 从 SharedPreferences 恢复当前引导版本的完成状态。
  Future<void> _restore() async {
    // 保存读取开始时的修订号，用于识别期间发生的用户操作。
    final startedRevision = _changeRevision;
    // 获取跨平台偏好实例并读取版本化布尔标记。
    final preferences = await SharedPreferences.getInstance();
    // 未保存时代表首次安装或首次使用当前引导版本。
    final isCompleted = preferences.getBool(_completedStorageKey) ?? false;
    // 用户已经触发重看或完成时不允许旧读取覆盖新状态。
    if (startedRevision != _changeRevision) return;
    // 恢复结束后由根组件依据完成值决定展示引导或主应用。
    state = OnboardingState(isRestoring: false, isCompleted: isCompleted);
  }
}
