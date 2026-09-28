import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:dio/dio.dart';
import 'package:pointycastle/export.dart';

import '../../core/network/bili_network_client.dart';
import '../../core/platform/runtime_platform.dart';
import 'bili_api_exception.dart';
import 'bili_cookie_store.dart';
import 'bili_json.dart';
import 'models/bili_auth_models.dart';

/// 管理 B 站二维码登录、状态校验和本地退出。
final class BiliAuthService {
  /// 注入统一网络客户端和安全会话存储。
  BiliAuthService(this._networkClient, this._cookieStore, this._platform);

  /// B 站通行证主机。
  static const String _passportHost = 'passport.bilibili.com';

  /// B 站业务 API 主机。
  static const String _apiHost = 'api.bilibili.com';

  /// 统一处理超时、响应状态和请求头的网络客户端。
  final BiliNetworkClient _networkClient;

  /// 保存完整 Cookie 和刷新令牌的系统安全存储。
  final BiliCookieStore _cookieStore;

  /// 当前宿主平台，用于生成手机扫码确认页展示的设备名称。
  final RuntimePlatform _platform;

  /// 并发触发账号检查时复用同一次令牌轮换，防止旧 Refresh Token 被重复消费。
  Future<bool>? _refreshFuture;

  /// B 站网页 correspondPath 使用的 RSA 公钥。
  static const String _refreshPublicKey = '''-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDLgd2OAkcGVtoE3ThUREbio0Eg
Uc/prcajMKXvkCKFCWhJYJcLkcM2DKKcSeFpD/j6Boy538YXnR6VhcuUJOhH2x71
nzPjfdTcqMz7djHum0qSZA0AyCBDABUqCrfNgCiJ00Ra7GmRj+YCK1NJEuewlb40
JNrRuoEUXpabUzGB8QIDAQAB
-----END PUBLIC KEY-----''';

  /// 创建新的网页二维码登录请求。
  Future<BiliQrLoginRequest> createQrLogin({CancelToken? cancelToken}) async {
    // 生成接口无需携带旧 Cookie，避免过期会话影响新登录。
    final response = await _networkClient.getJson(
      Uri.https(_passportHost, '/x/passport-login/web/qrcode/generate'),
      queryParameters: const <String, Object?>{'source': 'main_electron_pc'},
      includeCookie: false,
      cancelToken: cancelToken,
    );
    // 校验顶层业务码并读取二维码数据。
    final data = biliEnvelopeData(response);
    // 二维码内容必须是 HTTPS B 站登录地址。
    final qrCodeUrl = Uri.tryParse(biliJsonString(data['url']));
    // 轮询键不能为空，否则无法继续登录流程。
    final qrCodeKey = biliJsonString(data['qrcode_key']);
    if (qrCodeUrl == null || qrCodeUrl.scheme != 'https' || qrCodeKey.isEmpty) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidResponse,
        message: '二维码登录接口没有返回有效地址或轮询键。',
      );
    }
    // 使用本地时间保存创建时刻，界面无需依赖服务端时钟。
    return BiliQrLoginRequest(
      qrCodeUrl: qrCodeUrl,
      qrCodeKey: qrCodeKey,
      createdAt: DateTime.now(),
    );
  }

  /// 查询一次二维码扫码状态，成功时立即安全保存会话。
  Future<BiliQrLoginPollResult> pollQrLogin(
    String qrCodeKey, {
    CancelToken? cancelToken,
  }) async {
    // 空轮询键属于调用错误，不能发送无意义请求。
    if (qrCodeKey.trim().isEmpty) {
      throw ArgumentError.value(qrCodeKey, 'qrCodeKey', '二维码轮询键不能为空');
    }
    // 设备态扫码登录需要稳定设备 ID 和可读设备名，便于手机确认页识别当前软件。
    final loginDevice = await _loginDeviceIdentity();
    // 每轮轮询使用临时 _uuid，登录成功时把当轮身份补进最终 Cookie。
    final requestUuid = _randomLoginUuid();
    // 与 wiliwili 一致，按 PC Electron 客户端形态提交设备 Cookie。
    final pollingCookie = _formatCookieHeader(<String, String>{
      'appkey': '27eb53fc9058f8c3',
      'mobi_app': 'pc_electron',
      'device': 'mac',
      'innersign': '0',
      'buvid3': requestUuid,
      'device_id': loginDevice.deviceId,
      'device_name': loginDevice.deviceName,
    });
    // 完整响应用于同时读取 JSON 状态与 Set-Cookie。
    final response = await _networkClient.getJsonResponse(
      Uri.https(_passportHost, '/x/passport-login/web/qrcode/poll'),
      queryParameters: <String, Object?>{
        'qrcode_key': qrCodeKey,
        'source': 'main_electron_pc',
      },
      includeCookie: false,
      cookieHeaderOverride: pollingCookie,
      cancelToken: cancelToken,
    );
    // 顶层 code 表示接口调用本身是否成功。
    final data = biliEnvelopeData(response.body);
    // data.code 表示二维码当前业务状态。
    final statusCode = biliJsonInt(data['code']);
    // 状态码缺失说明接口结构已经变化。
    if (statusCode == null) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidResponse,
        message: '二维码状态接口没有返回状态码。',
      );
    }
    // 优先使用接口说明，缺失时使用本地稳定文案。
    final message = biliJsonString(data['message']);
    // 按 B 站网页二维码协议转换状态。
    switch (statusCode) {
      case 86101:
        // 二维码仍有效但尚未被手机扫描。
        return BiliQrLoginPollResult(
          status: BiliQrLoginStatus.waitingForScan,
          message: message.isEmpty ? '等待扫码。' : message,
        );
      case 86090:
        // 手机已经扫描，等待用户在客户端确认。
        return BiliQrLoginPollResult(
          status: BiliQrLoginStatus.waitingForConfirmation,
          message: message.isEmpty ? '已扫码，请在手机上确认。' : message,
        );
      case 86038:
        // 当前键已过期，调用方应停止轮询并允许重新生成。
        return BiliQrLoginPollResult(
          status: BiliQrLoginStatus.expired,
          message: message.isEmpty ? '二维码已过期。' : message,
        );
      case 0:
        // 成功响应必须同时携带完整 Cookie，否则无法建立真实登录会话。
        final loginCookies = _extractCookieMap(
          response.headerValues('set-cookie'),
        );
        if (loginCookies.isEmpty) {
          throw const BiliApiException(
            kind: BiliApiErrorKind.invalidResponse,
            message: '扫码成功，但响应没有返回登录 Cookie。',
          );
        }
        final cookieHeader = _formatCookieHeader(<String, String>{
          '_uuid': requestUuid,
          'buvid3': _randomHex(32),
          'device_id': loginDevice.deviceId,
          'device_name': loginDevice.deviceName,
          ...loginCookies,
        });
        // refresh_token 用于后续会话刷新，缺失时仍保存可用 Cookie。
        final refreshToken = biliJsonString(data['refresh_token']);
        // 敏感会话只写入系统安全存储。
        await _cookieStore.writeLoginSession(
          cookieHeader: cookieHeader,
          refreshToken: refreshToken.isEmpty ? null : refreshToken,
        );
        // 通知界面扫码流程已经完成。
        return BiliQrLoginPollResult(
          status: BiliQrLoginStatus.success,
          message: message.isEmpty ? '登录成功。' : message,
        );
      default:
        // 未识别状态不能当作持续等待，避免无限轮询。
        throw BiliApiException.fromApi(
          code: statusCode,
          message: message.isEmpty ? '二维码登录失败。' : message,
        );
    }
  }

  /// 按固定间隔轮询二维码，成功、过期或超时后自动结束。
  Stream<BiliQrLoginPollResult> watchQrLogin(
    BiliQrLoginRequest request, {
    Duration interval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 3),
    CancelToken? cancelToken,
  }) async* {
    // 轮询间隔和总时长都必须为正数。
    if (interval <= Duration.zero || timeout <= Duration.zero) {
      throw ArgumentError('二维码轮询间隔和超时时长必须大于零。');
    }
    // 使用单调运行时间计算超时，不受系统时间调整影响。
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      // 每轮调用一次状态接口并向界面发送快照。
      final result = await pollQrLogin(
        request.qrCodeKey,
        cancelToken: cancelToken,
      );
      // 先发送结果，界面才能展示最终成功或过期状态。
      yield result;
      // 终态到达后结束生成器并停止网络请求。
      if (result.isTerminal) return;
      // 仅在仍需等待时延迟下一次请求。
      await Future<void>.delayed(interval);
    }
    // 本地总超时按二维码过期处理，避免界面永久停留在扫码中。
    yield const BiliQrLoginPollResult(
      status: BiliQrLoginStatus.expired,
      message: '二维码登录等待超时，请重新生成。',
    );
  }

  /// 向 nav 接口校验当前 Cookie 并读取账号基础资料。
  Future<BiliLoginProfile> checkLogin({CancelToken? cancelToken}) async {
    // 未保存 Cookie 时直接返回未登录，减少一次无效请求。
    final cookieHeader = await _cookieStore.readCookieHeader();
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      return const BiliLoginProfile.loggedOut();
    }
    // nav 校验前按服务端标记自动轮换临近过期会话，减少任务中途掉登录。
    await refreshLoginSessionIfNeeded(cancelToken: cancelToken);
    // nav 接口会校验 Cookie 并返回用户、头像和大会员状态。
    final envelope = await _networkClient.getJson(
      Uri.https(_apiHost, '/x/web-interface/nav'),
      cancelToken: cancelToken,
    );
    // -101 是正常的会话失效结果，不作为页面错误抛出。
    final code = biliJsonInt(envelope['code']);
    if (code == -101) return const BiliLoginProfile.loggedOut();
    // 其他非零业务码仍交给统一异常映射。
    final data = biliEnvelopeData(envelope);
    // 接口明确标记未登录时返回空资料。
    if (data['isLogin'] != true) return const BiliLoginProfile.loggedOut();
    // 头像 URL 无效时保留空值，不影响登录状态。
    final avatarUrl = Uri.tryParse(biliJsonString(data['face']));
    // vipStatus 大于零代表当前大会员有效。
    final vipStatus = biliJsonInt(data['vipStatus']) ?? 0;
    // 返回适合账号页直接消费的不可变资料。
    return BiliLoginProfile(
      isLoggedIn: true,
      userId: biliJsonInt(data['mid']),
      userName: biliJsonString(data['uname']),
      avatarUrl: avatarUrl?.hasScheme == true ? avatarUrl : null,
      isVip: vipStatus > 0,
    );
  }

  /// 服务端标记需要刷新时安全轮换 Cookie 与 Refresh Token。
  Future<bool> refreshLoginSessionIfNeeded({CancelToken? cancelToken}) {
    // 同一进程只允许一条轮换链，其他调用等待相同结果。
    final existing = _refreshFuture;
    if (existing != null) return existing;
    final future = _refreshLoginSessionIfNeeded(cancelToken: cancelToken);
    _refreshFuture = future;
    return future.whenComplete(() {
      // 只清除仍对应本次操作的引用，避免迟到回调覆盖后续刷新。
      if (identical(_refreshFuture, future)) _refreshFuture = null;
    });
  }

  /// 执行一次完整检查、换新、确认和最终安全存储提交。
  Future<bool> _refreshLoginSessionIfNeeded({CancelToken? cancelToken}) async {
    final oldCookie = await _cookieStore.readCookieHeader();
    final oldRefreshToken = await _cookieStore.readRefreshToken();
    // 缺少二维码登录凭据时无法自动换新，保持现有 Cookie 交给 nav 正常判断。
    if (oldCookie == null ||
        oldCookie.trim().isEmpty ||
        oldRefreshToken == null ||
        oldRefreshToken.trim().isEmpty) {
      return false;
    }
    // 官方网页检查端点决定当前会话是否已经进入刷新窗口。
    final infoEnvelope = await _networkClient.getJson(
      Uri.https(_passportHost, '/x/passport-login/web/cookie/info'),
      cancelToken: cancelToken,
    );
    final info = biliEnvelopeData(infoEnvelope);
    if (info['refresh'] != true) return false;
    final oldCsrf = _cookieValue(oldCookie, 'bili_jct');
    if (oldCsrf == null || oldCsrf.isEmpty) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidResponse,
        message: '本地会话缺少刷新所需的 bili_jct。',
      );
    }
    // correspondPath 使用当前毫秒时间戳的 RSA-OAEP SHA-256 密文。
    final correspondPath = _createCorrespondPath(DateTime.now());
    final correspondHtml = await _networkClient.getText(
      Uri.https('www.bilibili.com', '/correspond/1/$correspondPath'),
      cancelToken: cancelToken,
    );
    final refreshCsrf = RegExp(
      r'''<div\s+id=["']1-name["']>([^<]+)</div>''',
      caseSensitive: false,
    ).firstMatch(correspondHtml)?.group(1)?.trim();
    if (refreshCsrf == null || refreshCsrf.isEmpty) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidResponse,
        message: 'B 站没有返回有效的实时刷新口令。',
      );
    }
    // 换新响应需要同时读取 JSON 中的新令牌和多条 Set-Cookie。
    final refreshResponse = await _networkClient.postFormJsonResponse(
      Uri.https(_passportHost, '/x/passport-login/web/cookie/refresh'),
      formFields: <String, String>{
        'csrf': oldCsrf,
        'refresh_csrf': refreshCsrf,
        'source': 'main_web',
        'refresh_token': oldRefreshToken,
      },
      cancelToken: cancelToken,
    );
    final refreshData = biliEnvelopeData(refreshResponse.body);
    final newRefreshToken = biliJsonString(refreshData['refresh_token']);
    final refreshedCookies = _extractCookieMap(
      refreshResponse.headerValues('set-cookie'),
    );
    if (newRefreshToken.isEmpty || refreshedCookies.isEmpty) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidResponse,
        message: 'B 站刷新响应缺少新 Cookie 或 Refresh Token。',
      );
    }
    // 保留 buvid 等未在刷新响应中重发的 Cookie，并让新认证 Cookie 覆盖旧值。
    final mergedCookies = <String, String>{
      ..._parseCookieHeader(oldCookie),
      ...refreshedCookies,
    }..removeWhere((String name, String value) => value.isEmpty);
    final newCookie = _formatCookieHeader(mergedCookies);
    final newCsrf = mergedCookies['bili_jct'];
    if (newCookie.isEmpty || newCsrf == null || newCsrf.isEmpty) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidResponse,
        message: '刷新后的会话缺少确认所需的 bili_jct。',
      );
    }
    // 确认请求必须使用新 Cookie 和旧 Refresh Token，使旧会话正式失效。
    final confirmResponse = await _networkClient.postFormJsonResponse(
      Uri.https(_passportHost, '/x/passport-login/web/confirm/refresh'),
      formFields: <String, String>{
        'csrf': newCsrf,
        'refresh_token': oldRefreshToken,
      },
      cookieHeaderOverride: newCookie,
      cancelToken: cancelToken,
    );
    biliEnvelopeData(confirmResponse.body);
    // 全链路确认成功后才原子语义地替换安全存储，失败时旧会话保持不变。
    await _cookieStore.writeLoginSession(
      cookieHeader: newCookie,
      refreshToken: newRefreshToken,
    );
    return true;
  }

  /// 使用 B 站网页公钥生成毫秒时间戳 correspondPath。
  String _createCorrespondPath(DateTime now) {
    // 服务端允许小时间误差，提前二十秒避免本机时钟略快导致路径立即过期。
    final timestamp = now.millisecondsSinceEpoch - 20000;
    final publicKey = CryptoUtils.rsaPublicKeyFromPem(_refreshPublicKey);
    final cipher = OAEPEncoding.withSHA256(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    final encrypted = cipher.process(
      Uint8List.fromList(utf8.encode('refresh_$timestamp')),
    );
    // URL 路径使用小写十六进制，不包含需要额外转义的字符。
    return encrypted
        .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// 读取或创建当前设备用于扫码登录的稳定设备身份。
  Future<_BiliLoginDeviceIdentity> _loginDeviceIdentity() async {
    // 设备 ID 不属于账号凭据，复用可减少 B 站设备列表里反复出现新设备。
    final storedDeviceId = await _cookieStore.readLoginDeviceId();
    if (storedDeviceId != null && storedDeviceId.isNotEmpty) {
      return _BiliLoginDeviceIdentity(
        deviceId: storedDeviceId,
        deviceName: _loginDeviceName(),
      );
    }
    // 首次登录创建类似 wiliwili 的 UUID 形态设备 ID。
    final generatedDeviceId =
        '${_randomHex(8)}-${_randomHex(4)}-${_randomHex(4)}-'
        '${_randomHex(4)}-${_randomHex(12)}';
    await _cookieStore.writeLoginDeviceId(generatedDeviceId);
    return _BiliLoginDeviceIdentity(
      deviceId: generatedDeviceId,
      deviceName: _loginDeviceName(),
    );
  }

  /// 生成 B 站 App 里展示的扫码登录设备名称。
  String _loginDeviceName() {
    // 名称按当前宿主平台展示，方便用户在手机确认页识别当前设备。
    final platformName = switch (_platform.operatingSystem) {
      HostOperatingSystem.android => 'Android',
      HostOperatingSystem.ios => 'iOS',
      HostOperatingSystem.windows => 'Windows',
      HostOperatingSystem.macos => 'macOS',
      HostOperatingSystem.linux => 'Linux',
      HostOperatingSystem.unsupported => 'Device',
    };
    return 'BiliDown $platformName';
  }

  /// 创建 wiliwili 风格的扫码临时 _uuid。
  String _randomLoginUuid() {
    // B 站客户端历史上常见 _uuid 末尾带 infoc，保持同类形态。
    return '${_randomHex(8)}-${_randomHex(4)}-${_randomHex(4)}-'
        '${_randomHex(4)}-${_randomHex(17)}infoc';
  }

  /// 使用安全随机数生成大写十六进制片段。
  String _randomHex(int length) {
    // 设备 ID 和 buvid3 参与登录设备识别，使用 Random.secure 避免可预测序列。
    final random = math.Random.secure();
    const seed = '0123456789ABCDEF';
    return String.fromCharCodes(
      List<int>.generate(
        length,
        (_) => seed.codeUnitAt(random.nextInt(seed.length)),
        growable: false,
      ),
    );
  }

  /// 清除当前设备保存的登录 Cookie 和刷新令牌。
  Future<void> logout() async {
    // 退出当前软件只移除本机凭据，不调用 B 站远端注销接口，避免影响账号其他端会话。
    await _cookieStore.clear();
  }

  /// 从多条 Set-Cookie 中提取最后生效的 name=value 映射。
  Map<String, String> _extractCookieMap(List<String> setCookieHeaders) {
    final cookies = <String, String>{};
    for (final header in setCookieHeaders) {
      // Set-Cookie 的第一段才是请求时需要回传的 name=value。
      final cookiePair = header.split(';').first.trim();
      // 第一个等号之前是名称，之后的内容完整保留。
      final separatorIndex = cookiePair.indexOf('=');
      if (separatorIndex <= 0) continue;
      // 提取并清理 Cookie 名称。
      final name = cookiePair.substring(0, separatorIndex).trim();
      // 空名称不能加入请求头。
      if (name.isEmpty) continue;
      // 保存包括空值在内的最新 Cookie 对。
      cookies[name] = cookiePair.substring(separatorIndex + 1);
    }
    return cookies;
  }

  /// 解析安全存储中的请求 Cookie 文本。
  Map<String, String> _parseCookieHeader(String cookieHeader) {
    final cookies = <String, String>{};
    for (final part in cookieHeader.split(';')) {
      final separatorIndex = part.indexOf('=');
      if (separatorIndex <= 0) continue;
      final name = part.substring(0, separatorIndex).trim();
      if (name.isEmpty) continue;
      cookies[name] = part.substring(separatorIndex + 1).trim();
    }
    return cookies;
  }

  /// 从请求 Cookie 中读取指定名称的值。
  String? _cookieValue(String cookieHeader, String name) =>
      _parseCookieHeader(cookieHeader)[name];

  /// 按浏览器请求头格式拼接 Cookie 映射。
  String _formatCookieHeader(Map<String, String> cookies) => cookies.entries
      .map((MapEntry<String, String> entry) => '${entry.key}=${entry.value}')
      .join('; ');
}

/// B 站扫码登录设备身份。
final class _BiliLoginDeviceIdentity {
  /// 保存稳定设备 ID 和手机端展示名称。
  const _BiliLoginDeviceIdentity({
    required this.deviceId,
    required this.deviceName,
  });

  /// 稳定设备 ID，用于 B 站登录设备识别。
  final String deviceId;

  /// 手机扫码确认页展示的设备名称。
  final String deviceName;
}
