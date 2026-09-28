import 'package:bilibili_down/features/downloads/application/lifecycle/automatic_shutdown_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 测试使用的关机执行器，禁止触碰真实系统命令。
final class _FakeShutdownLauncher implements SystemShutdownLauncher {
  /// 执行次数用于确认倒计时取消后没有调用系统关机。
  int launchCount = 0;

  /// 只记录调用，不执行任何平台操作。
  @override
  Future<void> launch() async {
    // 测试只验证控制器行为，不允许启动真实关机命令。
    launchCount++;
  }
}

void main() {
  /// 验证开发测试构建中的真实执行器被硬阻止，不可能触碰系统关机命令。
  test('非发布模式禁止调用真实系统关机', () async {
    // Flutter 测试始终为非发布模式，调用必须在任何平台命令之前抛错。
    await expectLater(
      const ProcessSystemShutdownLauncher().launch(),
      throwsA(isA<StateError>()),
    );
  });

  /// 验证每次启动默认关闭，历史任务完成不能创建关机倒计时。
  test('没有任务页一次性计划时保持关闭', () async {
    // 注入不会触碰操作系统的关机执行器。
    final launcher = _FakeShutdownLauncher();
    final container = ProviderContainer(
      overrides: [systemShutdownLauncherProvider.overrideWithValue(launcher)],
    );
    addTearDown(container.dispose);
    // 新 Provider 容器模拟一次全新应用启动，计划必须为空。
    expect(container.read(automaticShutdownPlanProvider), isNull);
    // 即使收到完成事件，没有任务页授权也必须保持关闭。
    final controller = container.read(
      automaticShutdownControllerProvider.notifier,
    );
    await controller.scheduleAfterCompletedBatch(<String>{'task-a'});
    expect(container.read(automaticShutdownControllerProvider), isNull);
    expect(launcher.launchCount, 0);
  });

  /// 验证任务页绑定的批次完全匹配后使用用户选择的时间创建倒计时。
  test('匹配当前任务批次后创建可取消倒计时', () async {
    // 注入只记录次数的执行器，测试全程不会调用真实系统关机命令。
    final launcher = _FakeShutdownLauncher();
    final container = ProviderContainer(
      overrides: [systemShutdownLauncherProvider.overrideWithValue(launcher)],
    );
    addTearDown(container.dispose);
    // 模拟用户在下载中列表明确选择五分钟并绑定两条任务。
    container
        .read(automaticShutdownPlanProvider.notifier)
        .arm(
          delay: const Duration(minutes: 5),
          taskIds: const <String>['task-a', 'task-b'],
        );
    // 完成事件携带同一批次时才允许消费一次性计划。
    final controller = container.read(
      automaticShutdownControllerProvider.notifier,
    );
    await controller.scheduleAfterCompletedBatch(<String>{'task-a', 'task-b'});
    // 倒计时采用用户选择的五分钟，不能回退硬编码短时间。
    expect(
      container.read(automaticShutdownControllerProvider)?.remainingSeconds,
      300,
    );
    // 计划消费后立即解除，后续批次不能重复使用同一授权。
    expect(container.read(automaticShutdownPlanProvider), isNull);
    // 用户取消后立即清空提示并且不得执行系统命令。
    controller.cancel();
    expect(container.read(automaticShutdownControllerProvider), isNull);
    expect(launcher.launchCount, 0);
  });

  /// 验证列表变化导致批次不匹配时撤销计划且不创建倒计时。
  test('完成批次与确认列表不一致时安全关闭', () async {
    // 测试执行器确保任何误调用都能通过计数暴露。
    final launcher = _FakeShutdownLauncher();
    final container = ProviderContainer(
      overrides: [systemShutdownLauncherProvider.overrideWithValue(launcher)],
    );
    addTearDown(container.dispose);
    // 用户确认时绑定两条任务，模拟其中一条后来暂停或被移除。
    container
        .read(automaticShutdownPlanProvider.notifier)
        .arm(
          delay: const Duration(minutes: 10),
          taskIds: const <String>['task-a', 'task-b'],
        );
    // 只有一条完成不满足精确批次匹配，必须消费并撤销旧授权。
    await container
        .read(automaticShutdownControllerProvider.notifier)
        .scheduleAfterCompletedBatch(<String>{'task-a'});
    expect(container.read(automaticShutdownPlanProvider), isNull);
    expect(container.read(automaticShutdownControllerProvider), isNull);
    expect(launcher.launchCount, 0);
  });
}
