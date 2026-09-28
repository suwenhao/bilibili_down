import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../services/bilibili/bili_api_exception.dart';
import '../../services/bilibili/bili_cookie_store.dart';

/// 一次 B 站 JSON 请求的正文和响应元数据。
final class BiliJsonResponse {
  /// 创建不可变 JSON 响应快照。
  BiliJsonResponse({
    required Map<String, Object?> body,
    required Map<String, List<String>> headers,
    required this.realUri,
    required this.statusCode,
  }) : body = Map<String, Object?>.unmodifiable(body),
       headers = Map<String, List<String>>.unmodifiable(
         headers.map(
           (String key, List<String> value) => MapEntry<String, List<String>>(
             key,
             List<String>.unmodifiable(value),
           ),
         ),
       );

  /// 已经转换为字符串键的 JSON 根对象。
  final Map<String, Object?> body;

  /// 保留多值结构的响应头，二维码登录需要读取全部 Set-Cookie。
  final Map<String, List<String>> headers;

  /// Dio 完成请求后记录的最终地址。
  final Uri realUri;

  /// 成功 HTTP 状态码。
  final int statusCode;

  /// 按不区分大小写的名称读取全部响应头值。
  List<String> headerValues(String name) {
    // HTTP 响应头名称不区分大小写，因此逐项比较规范化名称。
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
    }
    // 响应未携带目标头时返回不可变空列表。
    return const <String>[];
  }
}

/// 统一封装 B 站 API、短链接和媒体请求需要的网络策略。
final class BiliNetworkClient {
  /// 使用可注入 Dio 和 Cookie 存储创建客户端。
  factory BiliNetworkClient({
    Dio? dio,
    BiliCookieStore? cookieStore,
    void Function()? onSessionExpired,
  }) {
    // 外部未提供 Dio 时创建使用统一超时的客户端。
    final resolvedDio = dio ?? Dio(_defaultOptions());
    // 私有构造函数直接保存已经解析的依赖，避免重复初始化。
    return BiliNetworkClient._(resolvedDio, cookieStore, onSessionExpired);
  }

  /// 保存最终 Dio 和可选 Cookie 存储。
  BiliNetworkClient._(this._dio, this._cookieStore, this._onSessionExpired);

  /// 模拟常见桌面浏览器的 User-Agent，避免接口返回移动端差异结构。
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/131.0.0.0 Safari/537.36';

  /// 普通视频 API 和 CDN 默认 Referer。
  static const String defaultReferer = 'https://www.bilibili.com/';

  /// 执行 HTTP 请求的 Dio 客户端。
  final Dio _dio;

  /// 可选安全 Cookie 存储；未登录解析时允许为空。
  final BiliCookieStore? _cookieStore;

  /// 在 Cookie 失效后通知账号权限回落游客状态。
  final void Function()? _onSessionExpired;

  /// 创建统一连接、发送和接收超时配置。
  static BaseOptions _defaultOptions() {
    // API 请求使用短超时，媒体文件下载由下载引擎单独处理。
    return BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      responseType: ResponseType.json,
      validateStatus: (int? status) => status != null && status < 600,
    );
  }

  /// 请求 JSON 对象，并对临时网络错误和服务端错误执行有限重试。
  Future<Map<String, Object?>> getJson(
    Uri uri, {
    Map<String, Object?> queryParameters = const <String, Object?>{},
    bool includeCookie = true,
    String referer = defaultReferer,
    String? cookieHeaderOverride,
    CancelToken? cancelToken,
  }) async {
    // 普通解析流程只需要 JSON 正文，登录流程可改用完整响应方法。
    final response = await getJsonResponse(
      uri,
      queryParameters: queryParameters,
      includeCookie: includeCookie,
      referer: referer,
      cookieHeaderOverride: cookieHeaderOverride,
      cancelToken: cancelToken,
    );
    // 返回不可变响应中的 JSON 正文。
    return response.body;
  }

  /// 请求 JSON 对象并保留响应头、最终地址和 HTTP 状态。
  Future<BiliJsonResponse> getJsonResponse(
    Uri uri, {
    Map<String, Object?> queryParameters = const <String, Object?>{},
    bool includeCookie = true,
    String referer = defaultReferer,
    String? cookieHeaderOverride,
    CancelToken? cancelToken,
  }) async {
    // 最多执行一次初始请求和两次指数退避重试。
    const maximumAttempts = 3;
    // 保存最后一个 Dio 异常供重试耗尽后作为原因返回。
    Object? lastError;
    // 失效 Cookie 只在本次首次请求携带，清除后立即用游客身份重试。
    var includeCookieForAttempt = includeCookie;
    for (var attempt = 0; attempt < maximumAttempts; attempt++) {
      try {
        // 为每次请求重新读取 Cookie，二维码登录完成后无需重建客户端。
        final headers = await requestHeaders(
          referer: referer,
          includeCookie: includeCookieForAttempt,
          cookieHeaderOverride: cookieHeaderOverride,
        );
        // 是否实际携带 Cookie 决定未授权后能否安全回退游客重试。
        final hadCookie = headers.containsKey('Cookie');
        // getUri 不接收独立查询参数，因此先把参数安全合并到 URI。
        final requestUri = uri.replace(
          queryParameters: <String, String>{
            ...uri.queryParameters,
            ...queryParameters.map(
              (String key, Object? value) =>
                  MapEntry(key, value?.toString() ?? ''),
            ),
          },
        );
        // 发送只读 GET 请求，不在此处自动跟随业务 API 重定向。
        final response = await _dio.getUri<Object?>(
          requestUri,
          options: Options(headers: headers, followRedirects: false),
          cancelToken: cancelToken,
        );
        // 读取 HTTP 状态用于错误分类和重试判断。
        final status = response.statusCode ?? 0;
        // 服务器临时错误在剩余次数内退避重试。
        if (status >= 500 && attempt + 1 < maximumAttempts) {
          await _waitBeforeRetry(attempt);
          continue;
        }
        // 非成功 HTTP 状态转换成统一异常。
        if (status < 200 || status >= 300) {
          if (status == 401) {
            // 失效登录态先清除；原请求携带 Cookie 时立即改用游客身份重试。
            await _handleSessionExpired();
            if (hadCookie) {
              includeCookieForAttempt = false;
              // 游客回退不消耗网络错误重试次数。
              attempt--;
              continue;
            }
          }
          throw BiliApiException(
            kind: _apiKindForStatus(status),
            message: 'B 站请求返回 HTTP $status',
            httpStatusCode: status,
          );
        }
        // Dio 自动解码后根节点必须是 JSON 对象。
        final data = response.data;
        if (data is! Map) {
          throw const BiliApiException(
            kind: BiliApiErrorKind.invalidResponse,
            message: 'B 站接口响应不是 JSON 对象。',
          );
        }
        // 将动态键统一转为字符串，后续解析不直接依赖 dynamic。
        final body = data.map(
          (Object? key, Object? value) => MapEntry(key.toString(), value),
        );
        // JSON 业务码 -101 表示 Cookie 已失效；普通解析优先无 Cookie 重试。
        if (body['code'] == -101 || body['code'] == '-101') {
          await _handleSessionExpired();
          if (hadCookie) {
            includeCookieForAttempt = false;
            // 账号失效不是网络重试，不占用瞬时错误次数。
            attempt--;
            continue;
          }
        }
        // 返回正文和登录流程需要的全部响应元数据。
        return BiliJsonResponse(
          body: body,
          headers: response.headers.map,
          realUri: response.realUri,
          statusCode: status,
        );
      } on BiliApiException {
        // 已分类的 HTTP 或响应错误不盲目重试。
        rethrow;
      } on DioException catch (error) {
        // 保存本次网络异常用于最终错误链。
        lastError = error;
        // 主动取消和非临时错误不能自动重试。
        if (!_shouldRetry(error) || attempt + 1 >= maximumAttempts) break;
        // 使用短指数退避降低网络抖动和接口压力。
        await _waitBeforeRetry(attempt);
      }
    }
    // 所有重试耗尽后返回稳定网络错误。
    throw BiliApiException(
      kind: BiliApiErrorKind.network,
      message: '无法连接 B 站接口，请检查网络后重试。',
      cause: lastError,
    );
  }

  /// 解析受信任的 b23.tv 短链接并返回最终地址。
  Future<Uri> resolveShortLink(Uri uri, {CancelToken? cancelToken}) async {
    // 仅允许 HTTPS b23.tv，避免该方法被当作任意 URL 代理使用。
    if (uri.scheme != 'https' || uri.host.toLowerCase() != 'b23.tv') {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidInput,
        message: '只允许解析 HTTPS b23.tv 短链接。',
      );
    }
    try {
      try {
        // 先用 HEAD 读取 b23.tv 第一跳 Location，避免跟到最终页面后受到页面策略影响。
        return await _resolveShortLinkRedirect(
          uri,
          method: 'HEAD',
          cancelToken: cancelToken,
        );
      } on DioException catch (error) {
        // 用户取消解析时必须立即停止，不能继续发起 GET 回退请求。
        if (error.type == DioExceptionType.cancel) rethrow;
        // 部分 b23.tv 短码或中间 CDN 会拒绝 HEAD，必须回退 GET 读取第一跳 Location。
        return _resolveShortLinkByGet(uri, cancelToken: cancelToken);
      } on BiliApiException {
        // HEAD 未给出可用跳转地址时，也回退 GET 获取 Location。
        return _resolveShortLinkByGet(uri, cancelToken: cancelToken);
      }
    } on DioException catch (error) {
      // 短链接失败统一映射为网络错误并保留 Dio 原因。
      throw BiliApiException(
        kind: BiliApiErrorKind.network,
        message: 'b23.tv 短链接解析失败。',
        cause: error,
      );
    }
  }

  /// 使用 GET 回退解析 b23.tv 短链接并返回最终地址。
  Future<Uri> _resolveShortLinkByGet(
    Uri uri, {
    CancelToken? cancelToken,
  }) async {
    // GET 仍只读取 b23.tv 第一跳 Location，不下载最终 B 站页面正文。
    return _resolveShortLinkRedirect(
      uri,
      method: 'GET',
      cancelToken: cancelToken,
    );
  }

  /// 读取 b23.tv 短链响应头中的第一跳 Location，避免依赖平台自动重定向结果。
  Future<Uri> _resolveShortLinkRedirect(
    Uri uri, {
    required String method,
    CancelToken? cancelToken,
  }) async {
    // 当前待探测地址始终限制在 b23.tv，防止短链解析被滥用为开放跳转代理。
    var currentUri = uri;
    // b23.tv 极少数情况下会多跳到另一个 b23.tv 短码，最多跟 5 次避免循环。
    for (var redirectCount = 0; redirectCount < 5; redirectCount++) {
      // 请求头保持与其他 B 站接口一致，但不携带登录 Cookie。
      final headers = await requestHeaders(includeCookie: false);
      // 关闭自动跳转，只读取服务端返回的 Location。
      final response = await _dio.requestUri<Object?>(
        currentUri,
        options: Options(
          method: method,
          headers: headers,
          followRedirects: false,
          responseType: ResponseType.plain,
          validateStatus: (int? status) =>
              status != null && status >= 300 && status < 400,
        ),
        cancelToken: cancelToken,
      );
      // Location 是短链真正指向的地址，可能是绝对 URL 或相对路径。
      final location = response.headers.value('location')?.trim();
      if (location == null || location.isEmpty) {
        throw const BiliApiException(
          kind: BiliApiErrorKind.invalidResponse,
          message: 'b23.tv 短链接没有返回跳转地址。',
        );
      }
      // 按当前短链地址解析相对 Location，兼容服务端返回相对路径。
      final redirectedUri = currentUri.resolve(location);
      // 同域短码继续展开，最终必须离开 b23.tv 才交给上层白名单解析。
      if (redirectedUri.scheme == 'https' &&
          redirectedUri.host.toLowerCase() == 'b23.tv') {
        currentUri = redirectedUri;
        continue;
      }
      // 返回第一条非 b23.tv 落地地址，由上层判断是否为 B 站视频页或 App deep link。
      return redirectedUri;
    }
    // 多次跳转仍没有离开 b23.tv，通常代表短码异常或循环。
    throw const BiliApiException(
      kind: BiliApiErrorKind.notFound,
      message: 'b23.tv 短链接已失效或不存在。',
    );
  }

  /// 构造 API 或 CDN 请求需要的 User-Agent、Referer 和可选 Cookie。
  Future<Map<String, String>> requestHeaders({
    String referer = defaultReferer,
    bool includeCookie = true,
    String? cookieHeaderOverride,
  }) async {
    // 所有 B 站请求都固定携带浏览器标识和来源页。
    final headers = <String, String>{
      'User-Agent': userAgent,
      'Referer': referer,
      'Origin': 'https://www.bilibili.com',
    };
    // 登录接口和高画质播放地址需要完整 Cookie。
    if (cookieHeaderOverride != null &&
        cookieHeaderOverride.trim().isNotEmpty) {
      // 刷新确认必须临时使用尚未落盘的新 Cookie，显式覆盖优先级最高。
      headers['Cookie'] = cookieHeaderOverride;
    } else if (includeCookie && _cookieStore != null) {
      // 从系统安全存储读取当前会话。
      final cookie = await _cookieStore.readCookieHeader();
      // 只有非空 Cookie 才添加请求头。
      if (cookie != null && cookie.trim().isNotEmpty) {
        headers['Cookie'] = cookie;
      }
    }
    // 返回本次请求独立的可变 Map。
    return headers;
  }

  /// 从当前 Cookie 中读取表单类接口需要的 bili_jct。
  Future<String> readCsrfToken() async {
    final cookie = await _cookieStore?.readCookieHeader();
    final csrf = _cookieValue(cookie, 'bili_jct');
    if (csrf == null || csrf.isEmpty) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.unauthorized,
        message: '本地会话缺少操作历史所需的 bili_jct。',
      );
    }
    return csrf;
  }

  /// 按 Cookie 名称提取单个值，供需要 csrf 的写操作复用。
  String? _cookieValue(String? cookieHeader, String name) {
    final cookie = cookieHeader;
    if (cookie == null || cookie.trim().isEmpty) return null;
    for (final segment in cookie.split(';')) {
      final index = segment.indexOf('=');
      if (index <= 0) continue;
      final key = segment.substring(0, index).trim();
      if (key != name) continue;
      return segment.substring(index + 1).trim();
    }
    return null;
  }

  /// 获取字幕等小型二进制元数据，沿用当前登录态并限制响应大小。
  Future<Uint8List> getBytes(Uri uri, {String referer = defaultReferer}) async {
    // 此入口仅服务 B 站 API，禁止把账号 Cookie 发送到外部地址。
    if (uri.scheme != 'https' || uri.host != 'api.bilibili.com') {
      throw ArgumentError('二进制元数据仅允许请求 B 站 HTTPS API。');
    }
    // 流式请求在超限或异常时主动取消，避免后台继续接收响应。
    final cancelToken = CancelToken();
    try {
      // 新版字幕元数据是 Protobuf，不能让 Dio 自动按 JSON 解码。
      final response = await _dio.getUri<ResponseBody>(
        uri,
        options: Options(
          headers: await requestHeaders(referer: referer),
          responseType: ResponseType.stream,
          followRedirects: false,
        ),
        cancelToken: cancelToken,
      );
      // 字幕请求的 HTTP 错误必须显式反馈，不能当成没有字幕。
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300 || response.data == null) {
        throw BiliApiException(
          kind: _formApiKindForStatus(status),
          message: 'B 站字幕元数据请求返回 HTTP $status。',
          httpStatusCode: status,
        );
      }
      // 元数据仅含轨道地址；一兆上限足以容纳多语言，异常响应不能无限占用内存。
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.data!.stream.timeout(
        const Duration(seconds: 12),
      )) {
        if (builder.length + chunk.length > 1024 * 1024) {
          throw const FormatException('字幕元数据超过大小上限。');
        }
        builder.add(chunk);
      }
      return builder.takeBytes();
    } on DioException catch (error) {
      // 网络错误保留原始原因，不在用户提示中暴露 Cookie 或签名参数。
      throw BiliApiException(
        kind: BiliApiErrorKind.network,
        message: '无法获取 B 站字幕元数据，请稍后重试。',
        cause: error,
      );
    } finally {
      // 请求结束或解码前检查失败后释放仍可能活跃的响应流。
      cancelToken.cancel();
    }
  }

  /// 请求纯文本页面，供 Cookie 刷新流程解析实时 refresh_csrf。
  Future<String> getText(
    Uri uri, {
    String? cookieHeaderOverride,
    CancelToken? cancelToken,
  }) async {
    try {
      // 文本端点仍使用统一浏览器请求头和当前安全存储 Cookie。
      final response = await _dio.getUri<String>(
        uri,
        options: Options(
          headers: await requestHeaders(
            cookieHeaderOverride: cookieHeaderOverride,
          ),
          responseType: ResponseType.plain,
          followRedirects: false,
        ),
        cancelToken: cancelToken,
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300 || response.data == null) {
        // 登录维护端点失效时清除本地凭据并通知账号状态降级。
        if (status == 401) await _handleSessionExpired();
        throw BiliApiException(
          kind: status == 404
              ? BiliApiErrorKind.notFound
              : BiliApiErrorKind.invalidResponse,
          message: 'B 站文本请求返回 HTTP $status',
          httpStatusCode: status,
        );
      }
      return response.data!;
    } on BiliApiException {
      rethrow;
    } on DioException catch (error) {
      // 文本刷新端点失败沿用统一网络错误，不泄露请求中的敏感路径和 Cookie。
      throw BiliApiException(
        kind: BiliApiErrorKind.network,
        message: '无法获取 B 站会话刷新口令。',
        cause: error,
      );
    }
  }

  /// 发送表单并保留 JSON 响应头，供 Cookie 换新和确认接口使用。
  Future<BiliJsonResponse> postFormJsonResponse(
    Uri uri, {
    required Map<String, String> formFields,
    String? cookieHeaderOverride,
    CancelToken? cancelToken,
  }) async {
    try {
      // Dio 按 application/x-www-form-urlencoded 编码表单，不能误发 JSON。
      final response = await _dio.postUri<Object?>(
        uri,
        data: formFields,
        options: Options(
          headers: await requestHeaders(
            cookieHeaderOverride: cookieHeaderOverride,
          ),
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
          followRedirects: false,
        ),
        cancelToken: cancelToken,
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        // 表单维护端点未授权时清除旧凭据，不影响游客业务请求。
        if (status == 401) await _handleSessionExpired();
        throw BiliApiException(
          kind: _formApiKindForStatus(status),
          message: 'B 站表单请求返回 HTTP $status',
          httpStatusCode: status,
        );
      }
      final data = response.data;
      if (data is! Map) {
        throw const BiliApiException(
          kind: BiliApiErrorKind.invalidResponse,
          message: 'B 站表单接口响应不是 JSON 对象。',
        );
      }
      final body = data.map(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      );
      if (body['code'] == -101 || body['code'] == '-101') {
        // 刷新、确认等表单业务码 -101 代表本地登录权限已经失效。
        await _handleSessionExpired();
      }
      return BiliJsonResponse(
        body: body,
        headers: response.headers.map,
        realUri: response.realUri,
        statusCode: status,
      );
    } on BiliApiException {
      rethrow;
    } on DioException catch (error) {
      // 表单请求异常不包含敏感正文，原会话由调用方继续保留。
      throw BiliApiException(
        kind: BiliApiErrorKind.network,
        message: 'B 站会话刷新请求失败。',
        cause: error,
      );
    }
  }

  /// 将普通接口 HTTP 状态码映射为业务错误类型。
  BiliApiErrorKind _apiKindForStatus(int status) {
    // 登录失效由上层触发 Cookie 清理和游客重试。
    if (status == 401) return BiliApiErrorKind.unauthorized;
    // 权限不足通常代表账号等级或资源限制。
    if (status == 403) return BiliApiErrorKind.forbidden;
    // 资源不存在单独映射，便于 UI 展示下架或失效提示。
    if (status == 404) return BiliApiErrorKind.notFound;
    // 其他非 2xx 响应统一视为接口异常。
    return BiliApiErrorKind.invalidResponse;
  }

  /// 将表单维护接口 HTTP 状态码映射为业务错误类型。
  BiliApiErrorKind _formApiKindForStatus(int status) {
    // 表单接口不区分 404 资源语义，只需要账号和权限边界。
    if (status == 401) return BiliApiErrorKind.unauthorized;
    if (status == 403) return BiliApiErrorKind.forbidden;
    return BiliApiErrorKind.invalidResponse;
  }

  /// 清除失效 Cookie 并通知账号界面降级，下载任务和页面导航不参与处理。
  Future<void> _handleSessionExpired() async {
    try {
      // 移除 Cookie 与刷新令牌，后续普通 API 将自然以游客身份请求。
      await _cookieStore?.clear();
    } catch (_) {
      // 安全存储暂时不可写不能阻止当前请求继续执行无 Cookie 游客回退。
    }
    try {
      // 回调只更新账号权限，不显示模态遮罩或关联任务生命周期。
      _onSessionExpired?.call();
    } catch (_) {
      // 账号界面已经销毁时仍必须允许当前业务请求继续游客回退。
    }
  }

  /// 判断 Dio 异常是否属于可短暂重试的连接问题。
  bool _shouldRetry(DioException error) {
    // 取消、证书和明确的非 5xx 响应不应重试。
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      DioExceptionType.badResponse => (error.response?.statusCode ?? 0) >= 500,
      _ => false,
    };
  }

  /// 按请求次数执行 250、500 毫秒指数退避。
  Future<void> _waitBeforeRetry(int attempt) {
    // 位移计算二的幂，限制在当前最多两次重试范围。
    final milliseconds = 250 * (1 << attempt);
    // 异步等待不会阻塞 Flutter UI isolate。
    return Future<void>.delayed(Duration(milliseconds: milliseconds));
  }
}
