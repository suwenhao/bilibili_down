import 'package:bilibili_down/core/notifications/app_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// 记录通知业务调用且不触碰真实平台通道的测试客户端。
final class _FakeNotificationClient implements AppNotificationClient {
  /// 初始化调用次数。
  int initializeCount = 0;

  /// 权限请求调用次数。
  int permissionCount = 0;

  /// 已显示通知的稳定 ID 列表。
  final shownIds = <int>[];

  /// 记录初始化调用。
  @override
  Future<void> initialize() async {
    // 测试只累加次数，不注册真实系统通道。
    initializeCount++;
  }

  /// 记录权限请求调用。
  @override
  Future<void> requestPermissions() async {
    // 测试环境禁止弹出真实权限窗口。
    permissionCount++;
  }

  /// 记录通知 ID，正文由业务方法单独保证。
  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    // 稳定 ID 是同类通知不会无限堆积的关键契约。
    shownIds.add(id);
  }
}

void main() {
  /// 验证关闭系统提示时不会触碰通知后端。
  test('系统提示关闭时不初始化也不发送通知', () async {
    // 假客户端记录所有可能产生平台副作用的调用。
    final client = _FakeNotificationClient();
    final service = AppNotificationService(client, () => false);
    // 完成和失败事件都必须实时遵守关闭状态。
    await service.showBatchCompleted();
    await service.showTasksFailed(2);
    expect(client.initializeCount, 0);
    expect(client.permissionCount, 0);
    expect(client.shownIds, isEmpty);
  });

  /// 验证开启后初始化复用且两类通知使用不同稳定 ID。
  test('系统提示开启时复用初始化并发送完成失败通知', () async {
    // 假客户端确保测试不会显示真实系统通知。
    final client = _FakeNotificationClient();
    final service = AppNotificationService(client, () => true);
    // 权限请求显式执行一次，后续通知复用同一初始化 Future。
    await service.initializeAndRequestPermissions();
    await service.showBatchCompleted();
    await service.showTasksFailed(1);
    expect(client.initializeCount, 1);
    expect(client.permissionCount, 1);
    expect(client.shownIds, <int>[1001, 1002]);
  });
}
