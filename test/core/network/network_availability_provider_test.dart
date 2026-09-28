import 'package:bilibili_down/core/network/network_availability_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 验证无接口状态会暂停下载调度。
  test('空集合和 none 判定为离线', () {
    // 插件可能返回空集合或显式 none，两种情况都不能发起新任务。
    expect(
      connectivityResultsHaveNetwork(const <ConnectivityResult>[]),
      isFalse,
    );
    expect(
      connectivityResultsHaveNetwork(const <ConnectivityResult>[
        ConnectivityResult.none,
      ]),
      isFalse,
    );
  });

  /// 验证任一真实网络接口存在即可恢复等待队列。
  test('任一真实接口判定为网络可用', () {
    // 多接口设备只要存在 Wi-Fi 或移动网络就允许真实请求继续验证。
    expect(
      connectivityResultsHaveNetwork(const <ConnectivityResult>[
        ConnectivityResult.none,
        ConnectivityResult.wifi,
      ]),
      isTrue,
    );
    expect(
      connectivityResultsHaveNetwork(const <ConnectivityResult>[
        ConnectivityResult.mobile,
      ]),
      isTrue,
    );
  });
}
