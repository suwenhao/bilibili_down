import 'package:bilibili_down/services/download_engine/aria2/aria2_process_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 验证 Android CA bundle 会被显式传给 aria2，且证书校验始终开启。
  test('Android 启动参数包含系统 CA bundle', () {
    // 配置使用测试占位路径，只检查参数序列化，不启动真实进程。
    const config = Aria2LaunchConfig(
      executablePath: '/native/libaria2c.so',
      port: 6800,
      secret: 'test-secret',
      downloadDirectory: '/downloads',
      sessionFile: '/runtime/session',
      logFile: '/runtime/aria2.log',
      maxOverallDownloadLimitMegabytesPerSecond: 25,
      caCertificatePath: '/runtime/android-ca.pem',
    );

    // HTTPS 校验和 CA 文件必须同时存在，不能退化为不安全下载。
    expect(config.arguments, contains('--check-certificate=true'));
    expect(
      config.arguments,
      contains('--ca-certificate=/runtime/android-ca.pem'),
    );
    expect(config.arguments, contains('--max-overall-download-limit=25M'));
  });

  /// 验证 CA 路径能够跨 Android 前台 isolate 持久化和恢复。
  test('启动配置保留 CA bundle 路径', () {
    // 前台服务使用 JSON 在主 isolate 与任务 isolate 之间传递配置。
    const original = Aria2LaunchConfig(
      executablePath: '/native/libaria2c.so',
      port: 6800,
      secret: 'test-secret',
      downloadDirectory: '/downloads',
      sessionFile: '/runtime/session',
      logFile: '/runtime/aria2.log',
      maxOverallDownloadLimitMegabytesPerSecond: 25,
      caCertificatePath: '/runtime/android-ca.pem',
    );

    // 恢复后的路径必须与生成 bundle 的主 isolate 完全一致。
    final restored = Aria2LaunchConfig.fromJson(original.toJson());
    expect(restored.caCertificatePath, '/runtime/android-ca.pem');
    expect(restored.maxOverallDownloadLimitMegabytesPerSecond, 25);
  });
}
