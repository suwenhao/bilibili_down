import 'dart:convert';
import 'dart:typed_data';

import 'package:bilibili_down/core/network/bili_network_client.dart';
import 'package:bilibili_down/core/platform/runtime_platform.dart';
import 'package:bilibili_down/services/bilibili/bili_auth_service.dart';
import 'package:bilibili_down/services/bilibili/bili_cookie_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 验证扫码登录使用 PC Electron 设备态参数并补齐设备 Cookie。
  test('二维码登录使用设备态参数并保存补齐后的 Cookie', () async {
    // 固定设备 ID 便于验证轮询 Cookie 和最终保存 Cookie 一致。
    final store = _MemoryCookieStore(cookieHeader: null, refreshToken: null)
      ..loginDeviceId = 'device-id-fixed';
    final adapter = _QrLoginHttpAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final service = BiliAuthService(
      BiliNetworkClient(dio: dio, cookieStore: store),
      store,
      _testPlatform,
    );

    final request = await service.createQrLogin();
    await service.pollQrLogin(request.qrCodeKey);

    expect(adapter.generateSource, 'main_electron_pc');
    expect(adapter.pollSource, 'main_electron_pc');
    expect(adapter.pollCookie, contains('mobi_app=pc_electron'));
    expect(adapter.pollCookie, contains('device_id=device-id-fixed'));
    expect(adapter.pollCookie, contains('device_name=BiliDown Windows'));
    expect(store.cookieHeader, contains('SESSDATA=new-session'));
    expect(store.cookieHeader, contains('_uuid='));
    expect(store.cookieHeader, contains('buvid3='));
    expect(store.cookieHeader, contains('device_id=device-id-fixed'));
    expect(store.cookieHeader, contains('device_name=BiliDown Windows'));
    expect(store.refreshToken, 'new-refresh');
  });

  /// 验证首次设备态扫码会创建安装级唯一设备 ID。
  test('首次二维码登录生成并复用安装级设备 ID', () async {
    // 初始安全存储没有设备 ID，登录服务应生成一次并持久化。
    final store = _MemoryCookieStore(cookieHeader: null, refreshToken: null);
    final adapter = _QrLoginHttpAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final service = BiliAuthService(
      BiliNetworkClient(dio: dio, cookieStore: store),
      store,
      _testPlatform,
    );

    final request = await service.createQrLogin();
    await service.pollQrLogin(request.qrCodeKey);

    final generatedDeviceId = store.loginDeviceId;
    expect(
      generatedDeviceId,
      matches(RegExp(r'^[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}$')),
    );
    expect(adapter.pollCookie, contains('device_id=$generatedDeviceId'));
    expect(store.cookieHeader, contains('device_id=$generatedDeviceId'));
  });

  /// 验证完整换新链只在确认成功后提交新 Cookie 与 Refresh Token。
  test('自动刷新合并 Cookie 并在确认后保存新会话', () async {
    // 旧会话包含刷新响应不会重发的 buvid3，换新后必须继续保留。
    final store = _MemoryCookieStore(
      cookieHeader: 'SESSDATA=old; bili_jct=old-csrf; buvid3=device-id',
      refreshToken: 'old-refresh',
    );
    final adapter = _RefreshHttpAdapter(confirmStatusCode: 200);
    final dio = Dio()..httpClientAdapter = adapter;
    final service = BiliAuthService(
      BiliNetworkClient(dio: dio, cookieStore: store),
      store,
      _testPlatform,
    );

    final refreshed = await service.refreshLoginSessionIfNeeded();

    expect(refreshed, isTrue);
    expect(store.writeCount, 1);
    expect(store.cookieHeader, contains('SESSDATA=new-session'));
    expect(store.cookieHeader, contains('bili_jct=new-csrf'));
    expect(store.cookieHeader, contains('buvid3=device-id'));
    expect(store.refreshToken, 'new-refresh');
    // 确认请求必须携带尚未写入存储的新 Cookie，而不是旧会话。
    expect(adapter.confirmCookie, contains('SESSDATA=new-session'));
    expect(adapter.confirmCookie, contains('buvid3=device-id'));
  });

  /// 验证确认旧令牌失败时安全存储仍保留完整旧会话。
  test('刷新确认失败不会覆盖旧会话', () async {
    // 记录刷新前的敏感值，失败后逐项确认没有部分写入。
    final store = _MemoryCookieStore(
      cookieHeader: 'SESSDATA=old; bili_jct=old-csrf; buvid3=device-id',
      refreshToken: 'old-refresh',
    );
    final dio = Dio()
      ..httpClientAdapter = _RefreshHttpAdapter(confirmStatusCode: 500);
    final service = BiliAuthService(
      BiliNetworkClient(dio: dio, cookieStore: store),
      store,
      _testPlatform,
    );

    await expectLater(
      service.refreshLoginSessionIfNeeded(),
      throwsA(isA<Exception>()),
    );
    expect(store.writeCount, 0);
    expect(
      store.cookieHeader,
      'SESSDATA=old; bili_jct=old-csrf; buvid3=device-id',
    );
    expect(store.refreshToken, 'old-refresh');
  });

  /// 验证退出登录只清除本地 Cookie 与 Refresh Token。
  test('退出登录只清除本机会话且不请求远端注销', () async {
    // 当前软件退出登录不应影响 B 站账号其他端会话。
    final store = _MemoryCookieStore(
      cookieHeader: 'SESSDATA=old; bili_jct=old-csrf',
      refreshToken: 'old-refresh',
    );
    final adapter = _NoNetworkHttpAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final service = BiliAuthService(
      BiliNetworkClient(dio: dio, cookieStore: store),
      store,
      _testPlatform,
    );

    await service.logout();

    expect(adapter.requestCount, 0);
    expect(store.cookieHeader, isNull);
    expect(store.refreshToken, isNull);
  });

  /// 验证普通业务请求遇到失效 Cookie 后不会强制登录，而是自动回退游客请求。
  test('登录失效后清除凭据并以游客身份重试', () async {
    // 初始会话模拟已经过期的旧 Cookie 和刷新令牌。
    final store = _MemoryCookieStore(
      cookieHeader: 'SESSDATA=expired; bili_jct=expired',
      refreshToken: 'expired-refresh',
    );
    // 适配器对带 Cookie 请求返回 -101，对游客请求返回正常数据。
    final adapter = _GuestFallbackHttpAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    // 事件计数只验证账号权限收到一次降级通知，不关联任何下载任务。
    var invalidationCount = 0;
    final client = BiliNetworkClient(
      dio: dio,
      cookieStore: store,
      onSessionExpired: () => invalidationCount++,
    );

    final body = await client.getJson(
      Uri.https('api.bilibili.com', '/x/web-interface/view'),
    );

    expect(body['code'], 0);
    expect(adapter.cookiePresence, <bool>[true, false]);
    expect(store.cookieHeader, isNull);
    expect(store.refreshToken, isNull);
    expect(invalidationCount, 1);
  });
}

/// 验证二维码登录请求参数和响应 Cookie 保存的测试适配器。
final class _QrLoginHttpAdapter implements HttpClientAdapter {
  /// 生成二维码接口收到的 source 参数。
  String? generateSource;

  /// 轮询接口收到的 source 参数。
  String? pollSource;

  /// 轮询接口收到的 Cookie 请求头。
  String? pollCookie;

  @override
  void close({bool force = false}) {
    // 内存适配器没有网络资源需要释放。
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/qrcode/generate')) {
      generateSource = options.uri.queryParameters['source'];
      return _jsonResponse(<String, Object?>{
        'code': 0,
        'data': <String, Object?>{
          'url': 'https://passport.bilibili.com/h5-app/passport/login/scan',
          'qrcode_key': 'qr-key',
        },
      });
    }
    if (path.endsWith('/qrcode/poll')) {
      pollSource = options.uri.queryParameters['source'];
      pollCookie = options.headers['Cookie']?.toString();
      expect(options.uri.queryParameters['qrcode_key'], 'qr-key');
      return _jsonResponse(
        <String, Object?>{
          'code': 0,
          'data': <String, Object?>{
            'code': 0,
            'message': 'ok',
            'refresh_token': 'new-refresh',
          },
        },
        headers: <String, List<String>>{
          'set-cookie': <String>[
            'SESSDATA=new-session; Path=/; HttpOnly',
            'bili_jct=new-csrf; Path=/',
          ],
        },
      );
    }
    return _jsonResponse(<String, Object?>{'code': -404}, statusCode: 404);
  }

  /// 创建带 JSON 内容类型的响应。
  ResponseBody _jsonResponse(
    Map<String, Object?> body, {
    int statusCode = 200,
    Map<String, List<String>> headers = const <String, List<String>>{},
  }) {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
        ...headers,
      },
    );
  }
}

/// 仅保存在内存中的测试会话仓库。
final class _MemoryCookieStore implements BiliCookieStore {
  /// 创建带初始 Cookie 和刷新令牌的仓库。
  _MemoryCookieStore({required this.cookieHeader, required this.refreshToken});

  /// 当前请求 Cookie 文本。
  String? cookieHeader;

  /// 当前刷新令牌。
  String? refreshToken;

  /// 当前设备态登录使用的测试设备 ID。
  String? loginDeviceId;

  /// 成功提交新会话的次数。
  int writeCount = 0;

  @override
  Future<void> clear() async {
    // 测试退出时同步清空两类敏感值。
    cookieHeader = null;
    refreshToken = null;
  }

  @override
  Future<String?> readCookieHeader() async {
    // 返回当前内存 Cookie 快照。
    return cookieHeader;
  }

  @override
  Future<String?> readRefreshToken() async {
    // 返回当前内存刷新令牌。
    return refreshToken;
  }

  @override
  Future<String?> readLoginDeviceId() async {
    // 返回当前测试设备 ID。
    return loginDeviceId;
  }

  @override
  Future<void> writeLoginDeviceId(String deviceId) async {
    // 记录设备态登录生成的稳定设备 ID。
    loginDeviceId = deviceId;
  }

  @override
  Future<void> writeLoginSession({
    required String cookieHeader,
    String? refreshToken,
  }) async {
    // 两项作为一次测试提交记录，模拟安全存储最终状态。
    this.cookieHeader = cookieHeader;
    this.refreshToken = refreshToken;
    writeCount++;
  }
}

/// 测试环境固定使用 Windows 平台名，避免依赖运行测试的宿主系统。
const _testPlatform = RuntimePlatform(
  operatingSystem: HostOperatingSystem.windows,
  architecture: CpuArchitecture.x64,
);

/// 按刷新协议路径返回确定性响应并记录确认请求 Cookie。
final class _RefreshHttpAdapter implements HttpClientAdapter {
  /// 创建可控制确认接口 HTTP 状态的适配器。
  _RefreshHttpAdapter({required this.confirmStatusCode});

  /// 确认接口返回状态，用于覆盖成功和失败安全分支。
  final int confirmStatusCode;

  /// 最近一次确认请求携带的新 Cookie。
  String? confirmCookie;

  @override
  void close({bool force = false}) {
    // 内存适配器没有网络资源需要释放。
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/cookie/info')) {
      return _jsonResponse(<String, Object?>{
        'code': 0,
        'data': <String, Object?>{'refresh': true},
      });
    }
    if (path.startsWith('/correspond/1/')) {
      // 真实 RSA 密文长度应为 1024 位公钥对应的一百二十八字节十六进制。
      expect(path.split('/').last, hasLength(256));
      return ResponseBody.fromString(
        '<html><div id="1-name">live-refresh-csrf</div></html>',
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['text/html'],
        },
      );
    }
    if (path.endsWith('/cookie/refresh')) {
      final form = options.data! as Map<String, String>;
      expect(form['csrf'], 'old-csrf');
      expect(form['refresh_token'], 'old-refresh');
      return _jsonResponse(
        <String, Object?>{
          'code': 0,
          'data': <String, Object?>{'refresh_token': 'new-refresh'},
        },
        headers: <String, List<String>>{
          'set-cookie': <String>[
            'SESSDATA=new-session; Path=/; HttpOnly',
            'bili_jct=new-csrf; Path=/',
          ],
        },
      );
    }
    if (path.endsWith('/confirm/refresh')) {
      confirmCookie = options.headers['Cookie']?.toString();
      return _jsonResponse(<String, Object?>{
        'code': 0,
        'data': <String, Object?>{},
      }, statusCode: confirmStatusCode);
    }
    return _jsonResponse(<String, Object?>{'code': -404}, statusCode: 404);
  }

  /// 创建带 JSON 内容类型的 Dio 底层响应。
  ResponseBody _jsonResponse(
    Map<String, Object?> body, {
    int statusCode = 200,
    Map<String, List<String>> headers = const <String, List<String>>{},
  }) {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
        ...headers,
      },
    );
  }
}

/// 退出登录场景下不应该被调用的网络适配器。
final class _NoNetworkHttpAdapter implements HttpClientAdapter {
  /// 记录网络请求次数，用于确认退出登录只动本地安全存储。
  int requestCount = 0;

  @override
  void close({bool force = false}) {
    // 内存响应不持有需要释放的连接。
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // 如果退出登录触发网络请求，说明又误回到远端注销语义。
    requestCount++;
    throw StateError('退出登录不应该请求远端接口：${options.uri}');
  }
}

/// 首次拒绝过期 Cookie、随后接受游客请求的测试适配器。
final class _GuestFallbackHttpAdapter implements HttpClientAdapter {
  /// 保存每次请求是否携带 Cookie，用于验证游客回退顺序。
  final List<bool> cookiePresence = <bool>[];

  @override
  void close({bool force = false}) {
    // 内存适配器不持有网络连接。
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // 普通解析接口只因旧 Cookie 失效而拒绝首次请求。
    final hasCookie = options.headers.containsKey('Cookie');
    cookiePresence.add(hasCookie);
    // 第二次游客请求返回可继续解析的普通响应。
    final body = hasCookie
        ? <String, Object?>{'code': -101, 'message': '账号未登录'}
        : <String, Object?>{
            'code': 0,
            'data': <String, Object?>{'title': '游客可解析视频'},
          };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }
}
