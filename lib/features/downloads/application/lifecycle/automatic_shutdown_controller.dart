import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 自动关机倒计时和执行状态。
final class AutomaticShutdownState {
  /// 创建倒计时、执行中或失败状态。
  const AutomaticShutdownState({
    required this.remainingSeconds,
    this.executing = false,
    this.errorMessage,
  });

  /// 距离发送系统关机命令的剩余秒数。
  final int remainingSeconds;

  /// 是否已经开始调用系统关机命令。
  final bool executing;

  /// 系统命令启动失败时显示给用户的错误信息。
  final String? errorMessage;

  /// 返回替换剩余秒数的新状态。
  AutomaticShutdownState withRemainingSeconds(int seconds) =>
      AutomaticShutdownState(remainingSeconds: seconds);
}

/// 仅在当前进程有效、且绑定一批明确下载任务的自动关机计划。
final class AutomaticShutdownPlan {
  /// 创建用户从下载中列表确认的一次性计划。
  AutomaticShutdownPlan({required this.delay, required Set<String> taskIds})
    : taskIds = Set<String>.unmodifiable(taskIds);

  /// 当前批次全部完成后等待多久再执行关机。
  final Duration delay;

  /// 用户确认时下载中列表内的任务 ID，完成批次必须精确匹配。
  final Set<String> taskIds;
}

/// 提供进程内一次性自动关机计划；应用启动时始终为空。
final automaticShutdownPlanProvider =
    NotifierProvider<AutomaticShutdownPlanController, AutomaticShutdownPlan?>(
      AutomaticShutdownPlanController.new,
    );

/// 只允许下载任务列表显式创建或解除自动关机计划。
final class AutomaticShutdownPlanController
    extends Notifier<AutomaticShutdownPlan?> {
  /// 新进程默认关闭自动关机，不从本地偏好恢复任何旧选择。
  @override
  AutomaticShutdownPlan? build() => null;

  /// 绑定当前下载中任务和用户选择的延迟，创建一次性计划。
  void arm({required Duration delay, required Iterable<String> taskIds}) {
    // 至少保留一分钟，防止误触后立即进入不可逆系统操作。
    if (delay < const Duration(minutes: 1)) {
      throw ArgumentError.value(delay, 'delay', '自动关机时间不能少于一分钟。');
    }
    // 清理空 ID 并固化集合，后续列表变化不能修改已确认计划。
    final normalizedTaskIds = taskIds
        .where((String taskId) => taskId.trim().isNotEmpty)
        .toSet();
    // 没有活动下载任务时禁止创建脱离任务链的关机计划。
    if (normalizedTaskIds.isEmpty) {
      throw StateError('没有可绑定的下载中任务。');
    }
    // 发布新计划供任务页展示，且仅在本次进程生命周期有效。
    state = AutomaticShutdownPlan(delay: delay, taskIds: normalizedTaskIds);
  }

  /// 解除当前一次性计划；重复调用保持幂等。
  void disarm() {
    // 空状态无需产生重复通知。
    if (state == null) return;
    state = null;
  }

  /// 当失败或取消批次包含已绑定任务时解除计划，避免授权泄漏到下一批。
  void disarmForBatch(Iterable<String> taskIds) {
    // 没有计划时无需扫描批次集合。
    final current = state;
    if (current == null) return;
    // 只要终止批次命中任一绑定任务，整份一次性计划即失效。
    final containsPlannedTask = taskIds.any(current.taskIds.contains);
    if (containsPlannedTask) state = null;
  }
}

/// 提供可替换的系统关机命令执行器，测试环境可以安全覆盖。
final systemShutdownLauncherProvider = Provider<SystemShutdownLauncher>((
  Ref ref,
) {
  // 正式应用通过当前桌面平台选择原生命令。
  return const ProcessSystemShutdownLauncher();
});

/// 抽象系统关机操作，隔离不可逆平台调用。
abstract interface class SystemShutdownLauncher {
  /// 启动系统关机命令；命令无法启动时抛出异常。
  Future<void> launch();
}

/// 使用桌面系统命令执行关机。
final class ProcessSystemShutdownLauncher implements SystemShutdownLauncher {
  /// 创建无状态的系统命令执行器。
  const ProcessSystemShutdownLauncher();

  /// 根据当前操作系统启动关机命令。
  @override
  Future<void> launch() async {
    // 开发和调试运行绝不允许调用真实系统关机，防止热重载或测试误触开发机。
    if (!kReleaseMode) {
      throw StateError('非发布模式已阻止真实自动关机命令。');
    }
    if (Platform.isWindows) {
      // Windows 使用系统目录中的 shutdown.exe，避免依赖 shell PATH。
      final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
      await _runAndRequireSuccess(
        '$systemRoot\\System32\\shutdown.exe',
        const <String>['/s', '/t', '0'],
      );
      return;
    }
    if (Platform.isMacOS) {
      // macOS 通过 System Events 请求关机，系统仍可显示权限确认。
      await _runAndRequireSuccess('/usr/bin/osascript', const <String>[
        '-e',
        'tell application "System Events" to shut down',
      ]);
      return;
    }
    if (Platform.isLinux) {
      // Linux 使用 systemd 标准关机入口，权限不足会由系统策略拒绝。
      await _runAndRequireSuccess('/usr/bin/systemctl', const <String>[
        'poweroff',
      ]);
      return;
    }
    // 移动端和未知平台不允许伪装成已经执行关机。
    throw UnsupportedError('当前平台不支持自动关机。');
  }

  /// 执行系统命令并把非零退出码转换为可展示的失败。
  Future<void> _runAndRequireSuccess(
    String executable,
    List<String> arguments,
  ) async {
    // 直接调用可执行文件，不经过 shell，避免参数被解释或注入。
    final result = await Process.run(executable, arguments, runInShell: false);
    if (result.exitCode != 0) {
      // 仅返回系统错误文本，空文本时保留退出码用于诊断。
      final detail = result.stderr.toString().trim();
      throw ProcessException(
        executable,
        arguments,
        detail.isEmpty ? '退出码 ${result.exitCode}' : detail,
        result.exitCode,
      );
    }
  }
}

/// 管理整轮下载完成后的自动关机倒计时。
final automaticShutdownControllerProvider =
    NotifierProvider<AutomaticShutdownController, AutomaticShutdownState?>(
      AutomaticShutdownController.new,
    );

/// 读取设置、维护倒计时并执行可取消的系统关机。
final class AutomaticShutdownController
    extends Notifier<AutomaticShutdownState?> {
  /// 每秒更新一次界面的倒计时计时器。
  Timer? _timer;

  /// 创建空闲状态并注册生命周期清理。
  @override
  AutomaticShutdownState? build() {
    // Provider 销毁时取消计时器，防止退出期间继续触发系统命令。
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  /// 在一整轮下载全部成功后校验一次性计划并启动用户选择的倒计时。
  Future<void> scheduleAfterCompletedBatch(Set<String> completedTaskIds) async {
    // 已经存在倒计时、执行或错误提示时不创建重复关机任务。
    if (state != null) return;
    // 手机系统不允许第三方应用关机，因此只在桌面平台继续。
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
    // 计划只可能由下载中列表在本次进程显式创建，应用启动不会恢复旧值。
    final plan = ref.read(automaticShutdownPlanProvider);
    // 没有本次会话计划时，任何历史或开发测试任务完成都不能触发关机。
    if (plan == null) {
      return;
    }
    // 完成集合必须和用户确认时的下载中列表完全一致，新增、暂停或删除均判定失效。
    final matchesConfirmedBatch =
        completedTaskIds.length == plan.taskIds.length &&
        completedTaskIds.every(plan.taskIds.contains);
    // 本次完成事件消费并解除计划，防止后续其他批次误用旧授权。
    ref.read(automaticShutdownPlanProvider.notifier).disarm();
    // 批次不完全匹配时静默保持关闭，不创建倒计时或系统调用。
    if (!matchesConfirmedBatch) return;
    // 使用用户在任务列表弹窗明确选择的时间发布可取消倒计时。
    state = AutomaticShutdownState(remainingSeconds: plan.delay.inSeconds);
    // 防御性取消旧计时器后创建唯一周期任务。
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// 由用户取消倒计时或关闭错误提示。
  void cancel() {
    // 执行命令前取消计时器并回到空闲状态。
    _timer?.cancel();
    _timer = null;
    state = null;
  }

  /// 推进一秒倒计时，到零后执行系统命令。
  void _tick() {
    // Provider 已恢复空闲时终止迟到计时回调。
    final current = state;
    if (current == null || current.executing || current.errorMessage != null) {
      return;
    }
    if (current.remainingSeconds > 1) {
      // 未到零时只更新剩余秒数供界面重建。
      state = current.withRemainingSeconds(current.remainingSeconds - 1);
      return;
    }
    // 到零后先停表并显示正在执行，避免重复发送关机命令。
    _timer?.cancel();
    _timer = null;
    state = const AutomaticShutdownState(remainingSeconds: 0, executing: true);
    // Timer 回调不能等待平台命令，异步执行并保留失败反馈。
    unawaited(_launchShutdown());
  }

  /// 调用平台执行器并把启动失败转换为可关闭的界面状态。
  Future<void> _launchShutdown() async {
    try {
      // 不可逆系统调用集中由可替换执行器完成。
      await ref.read(systemShutdownLauncherProvider).launch();
    } catch (error) {
      // 命令无法启动时展示明确错误，用户确认后才能关闭提示。
      state = AutomaticShutdownState(
        remainingSeconds: 0,
        errorMessage: error.toString(),
      );
    }
  }
}
