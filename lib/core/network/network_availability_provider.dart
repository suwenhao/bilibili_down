import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 把 connectivity_plus 返回的网络类型集合转换为是否存在网络接口。
bool connectivityResultsHaveNetwork(List<ConnectivityResult> results) {
  // 空集合或仅包含 none 表示当前没有可用网络接口。
  return results.isNotEmpty &&
      results.any(
        (ConnectivityResult result) => result != ConnectivityResult.none,
      );
}

/// 持续提供网络接口可用信号，供调度器暂停和恢复认领任务。
final networkAvailabilityProvider = StreamProvider<bool>((Ref ref) async* {
  // 插件实例同时负责启动快照和后续平台网络变化流。
  final connectivity = Connectivity();
  try {
    // 首个值来自当前接口状态，应用启动时即可阻止离线任务被认领。
    final initial = await connectivity.checkConnectivity();
    yield connectivityResultsHaveNetwork(initial);
  } catch (_) {
    // 平台查询异常不能永久锁死下载，回退允许调度并由真实请求判断网络。
    yield true;
  }
  try {
    // 后续变化只作为调度信号，真实互联网可用性仍以下载请求结果为准。
    await for (final results in connectivity.onConnectivityChanged) {
      yield connectivityResultsHaveNetwork(results);
    }
  } catch (_) {
    // 平台事件流异常时回退允许调度，避免等待队列永远停住。
    yield true;
  }
});
