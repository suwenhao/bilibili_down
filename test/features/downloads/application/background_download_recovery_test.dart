import 'package:bilibili_down/features/downloads/application/lifecycle/background_download_recovery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart';

void main() {
  /// 验证后台入口只接受本应用注册的恢复任务和 iOS 系统回调。
  test('后台恢复任务白名单拒绝无关系统任务', () {
    // 三种业务任务名分别覆盖周期恢复、网络恢复和显式恢复入口。
    final supportedTasks = <String>[
      backgroundDownloadRecoveryTask,
      periodicRecoveryUniqueName,
      networkRecoveryUniqueName,
      Workmanager.iOSBackgroundTask,
    ];

    for (final task in supportedTasks) {
      // 白名单任务必须进入恢复流程，避免系统唤醒后静默跳过。
      expect(isBackgroundDownloadRecoveryTask(task), isTrue);
    }
    // 其他插件或旧版本遗留任务不得打开数据库和启动下载调度器。
    expect(
      isBackgroundDownloadRecoveryTask('unrelated.background.task'),
      isFalse,
    );
  });

  /// 验证应用首次观察到离线状态时会登记联网恢复兜底。
  test('未知状态进入离线时注册恢复', () {
    // previous 为空代表 Provider 刚建立监听，当前值明确为离线。
    final shouldRegister = shouldRegisterNetworkRecovery(
      previousAvailability: null,
      currentAvailability: false,
    );

    expect(shouldRegister, isTrue);
  });

  /// 验证持续离线不会重复覆盖同一个 WorkManager 系统任务。
  test('持续离线不重复注册恢复', () {
    // 前后两次均离线属于网络事件抖动，不是新的断网边沿。
    final shouldRegister = shouldRegisterNetworkRecovery(
      previousAvailability: false,
      currentAvailability: false,
    );

    expect(shouldRegister, isFalse);
  });

  /// 验证联网或未知状态不会错误登记等待网络任务。
  test('在线与未知状态不注册恢复', () {
    // 恢复在线时调度器由前台网络监听继续执行，无需再写系统队列。
    expect(
      shouldRegisterNetworkRecovery(
        previousAvailability: false,
        currentAvailability: true,
      ),
      isFalse,
    );
    // 当前网络仍未得出结论时不得把暂态当作断网。
    expect(
      shouldRegisterNetworkRecovery(
        previousAvailability: true,
        currentAvailability: null,
      ),
      isFalse,
    );
  });
}
