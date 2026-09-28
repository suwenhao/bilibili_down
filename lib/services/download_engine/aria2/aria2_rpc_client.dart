import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/logging/app_debug_log.dart';

/// 封装 aria2 JSON-RPC 请求、鉴权和响应校验。
final class Aria2RpcClient {
  /// 按本机端口和随机密钥创建只连接回环地址的 RPC 客户端。
  factory Aria2RpcClient({
    required int port,
    required String secret,
    Dio? dio,
  }) {
    // 外部未注入 Dio 时创建带短超时的本机 HTTP 客户端。
    return Aria2RpcClient._(
      secret,
      dio ??
          Dio(
            BaseOptions(
              baseUrl: 'http://127.0.0.1:$port',
              connectTimeout: const Duration(seconds: 2),
              receiveTimeout: const Duration(seconds: 5),
              sendTimeout: const Duration(seconds: 5),
              // aria2 的 JSON-RPC 业务错误可能使用 HTTP 400 承载，必须先解析 body。
              validateStatus: (_) => true,
            ),
          ),
    );
  }

  /// 保存已经配置完成的鉴权密钥和 Dio 客户端。
  Aria2RpcClient._(this._secret, this._dio);

  /// 负责发送 JSON-RPC HTTP 请求的客户端。
  final Dio _dio;

  /// aria2 RPC 鉴权密钥，每次调用都作为 token 参数发送。
  final String _secret;

  /// 单调递增的 JSON-RPC 请求编号。
  int _requestId = 0;

  /// 调用任意 aria2 RPC 方法并统一处理协议错误。
  Future<Object?> call(
    String method, [
    List<Object?> parameters = const [],
  ]) async {
    // 单独保存请求编号，日志和请求体必须引用同一个稳定值。
    final requestId = ++_requestId;
    // 高频就绪探测和进度轮询由各自上层记录状态，避免每秒刷屏。
    final logRequest =
        method != 'aria2.getVersion' && method != 'aria2.tellStatus';
    if (logRequest) {
      // 不输出参数，因为参数可能包含 RPC 密钥、Cookie、URL 或请求头。
      AppDebugLog.aria2('RPC -> method=$method id=$requestId');
    }
    try {
      // 发送 JSON-RPC 2.0 请求，并把密钥放在业务参数之前。
      final response = await _dio.post<Object?>(
        '/jsonrpc',
        data: <String, Object?>{
          'jsonrpc': '2.0',
          'id': requestId,
          'method': method,
          'params': <Object?>['token:$_secret', ...parameters],
        },
      );
      // aria2 使用 application/json-rpc，Dio 可能因此把有效 JSON 保留成字符串。
      Object? body = response.data;
      if (body is String) {
        try {
          // 显式解码字符串响应，兼容 aria2 的非标准 JSON MIME 类型。
          body = jsonDecode(body);
        } on FormatException catch (error) {
          // JSON 文本损坏时保留底层解析原因供控制台诊断。
          throw Aria2RpcException(
            'Invalid JSON-RPC text response for $method.',
            cause: error,
          );
        }
      }
      if (logRequest) {
        // 只记录状态码和响应类型，不输出可能包含任务详情的响应正文。
        AppDebugLog.aria2(
          'RPC <- method=$method id=$requestId '
          'status=${response.statusCode} type=${body.runtimeType}',
        );
      }
      // 响应不是对象说明 aria2 或代理返回了无效协议内容。
      if (body is! Map) {
        throw Aria2RpcException('Invalid JSON-RPC response for $method.');
      }
      // JSON-RPC error 字段存在时转换为项目异常。
      final error = body['error'];
      if (error is Map) {
        throw Aria2RpcException(
          error['message']?.toString() ?? 'aria2 RPC call failed: $method',
          code: error['code'] as int?,
        );
      }
      if ((response.statusCode ?? 0) >= 400) {
        // 非 JSON-RPC 错误但 HTTP 已失败时，保留状态码供上层判断连接或协议问题。
        throw Aria2RpcException(
          'aria2 RPC HTTP ${response.statusCode} for $method.',
        );
      }
      // 成功响应只向上层返回 result 字段。
      return body['result'];
    } catch (error) {
      // 失败日志只包含方法和异常，不输出原始请求参数。
      AppDebugLog.aria2('RPC !! method=$method id=$requestId error=$error');
      rethrow;
    }
  }

  /// 查询 aria2 版本，用于确认 RPC 服务已经就绪。
  Future<Map<String, Object?>> getVersion() async {
    // 将动态 JSON 对象转换成字符串键 Map。
    return _asStringMap(await call('aria2.getVersion'));
  }

  /// 添加一个带目标目录、文件名和请求头的下载任务。
  Future<String> addUri(
    Uri uri, {
    required String directory,
    required String outputName,
    required String gid,
    List<Uri> backupUris = const <Uri>[],
    Map<String, String> headers = const {},
  }) async {
    // 使用有序集合保留 B 站 CDN 优先级，同时去除与主地址或彼此重复的地址。
    final uriStrings = _downloadableUriStrings(uri, backupUris);
    // 历史任务或异常播放接口可能产生空地址，不能把空列表提交给 aria2。
    if (uriStrings.isEmpty) {
      throw const Aria2RpcException('No URI to download.');
    }
    AppDebugLog.aria2(
      'RPC addUri prepared uriCount=${uriStrings.length} '
      'schemes=${_uriSchemeSummary(uriStrings)}',
    );
    // 组装 aria2 单任务选项，禁止自动改名并允许断点续传。
    final options = <String, Object?>{
      'dir': directory,
      'out': outputName,
      'gid': gid,
      'continue': 'true',
      'auto-file-renaming': 'false',
      'allow-overwrite': 'true',
      // B 站地址需要 Referer、Cookie 等请求头时才发送 header 选项。
      if (headers.isNotEmpty)
        'header': headers.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .toList(),
    };
    // 调用 addUri 并同时传入业务生成的稳定 GID。
    final result = await call('aria2.addUri', [uriStrings, options]);
    // aria2 返回的 GID 统一转为字符串。
    return result.toString();
  }

  /// 归一化主地址和备用地址，只保留 aria2 可直接下载的 HTTP(S) 地址。
  List<String> _downloadableUriStrings(Uri primary, List<Uri> backups) {
    // 使用有序集合保留 CDN 优先级，trim 后再去重，避免空格和重复地址污染 RPC 参数。
    final normalized = <String>{};
    for (final uri in <Uri>[primary, ...backups]) {
      // aria2 只处理 HTTP(S) 下载，其他协议或相对地址必须在业务层失败。
      if (uri.scheme != 'http' && uri.scheme != 'https') continue;
      final value = uri.toString().trim();
      if (value.isEmpty) continue;
      normalized.add(value);
    }
    return normalized.toList(growable: false);
  }

  /// 生成脱敏 scheme 摘要，只用于确认 RPC 是否拿到了 URL 列表。
  String _uriSchemeSummary(List<String> uriStrings) {
    // 只输出 scheme 和数量，不记录域名、路径、Cookie 参数或临时鉴权查询。
    final counts = <String, int>{};
    for (final uriString in uriStrings) {
      final scheme = Uri.tryParse(uriString)?.scheme;
      final label = (scheme == null || scheme.isEmpty) ? 'unknown' : scheme;
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return counts.entries
        .map((entry) => '${entry.key}:${entry.value}')
        .join(',');
  }

  /// 暂停指定 GID。
  Future<void> pause(String gid) async => call('aria2.pause', [gid]);

  /// 恢复指定 GID。
  Future<void> resume(String gid) async => call('aria2.unpause', [gid]);

  /// 删除活动任务；已结束任务则删除其结果记录。
  Future<void> remove(String gid) async {
    // 优先按活动任务删除。
    try {
      await call('aria2.remove', [gid]);
    } on Aria2RpcException {
      // 活动任务删除失败通常表示任务已结束，改删下载结果记录。
      await call('aria2.removeDownloadResult', [gid]);
    }
  }

  /// 查询指定任务的状态、进度和错误字段。
  Future<Map<String, Object?>> tellStatus(String gid) async {
    // 仅请求界面和任务恢复需要的字段，减少轮询响应体积。
    final result = await call('aria2.tellStatus', [
      gid,
      [
        'gid',
        'status',
        'totalLength',
        'completedLength',
        'downloadSpeed',
        'errorCode',
        'errorMessage',
      ],
    ]);
    // 将 aria2 动态结果转换为类型稳定的字符串键 Map。
    return _asStringMap(result);
  }

  /// 要求 aria2 立即保存当前会话。
  Future<void> saveSession() async => call('aria2.saveSession');

  /// 修改 aria2 全局下载速度上限。
  Future<void> changeGlobalDownloadLimit(int megabytesPerSecond) async {
    // aria2 使用全局选项限制全部活动任务的总下载速度。
    await call('aria2.changeGlobalOption', [
      <String, Object?>{'max-overall-download-limit': '${megabytesPerSecond}M'},
    ]);
  }

  /// 通过 RPC 请求 aria2 正常退出。
  Future<void> shutdown() async => call('aria2.shutdown');

  /// 在超时范围内轮询版本接口，等待 aria2 RPC 启动完成。
  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // 记录就绪探测总时限，便于区分进程启动慢和协议解析失败。
    AppDebugLog.aria2(
      'RPC readiness check started timeout=${timeout.inMilliseconds}ms',
    );
    // 计算绝对截止时间，避免每轮重试累积新的超时窗口。
    final deadline = DateTime.now().add(timeout);
    // 保存最后一次错误，超时时作为根因附加到异常。
    Object? lastError;
    // 统计实际探测次数，但不逐次打印以避免控制台刷屏。
    var attempts = 0;
    // RPC 进程可能需要短暂启动时间，因此使用小间隔重试。
    while (DateTime.now().isBefore(deadline)) {
      try {
        // 每次进入循环先累加探测次数。
        attempts++;
        // 版本接口成功即代表 RPC 已经可以接受业务请求。
        await getVersion();
        // 记录最终成功次数，用户截图即可确认 RPC 是否已经就绪。
        AppDebugLog.aria2('RPC ready attempts=$attempts');
        return;
      } catch (error) {
        // 记录本轮错误并短暂等待后继续探测。
        lastError = error;
        // 首次失败提供根因，后续相同重试不重复输出。
        if (attempts == 1) {
          AppDebugLog.aria2('RPC not ready yet error=$error');
        }
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }
    // 到达截止时间时输出最终错误与总尝试次数。
    AppDebugLog.aria2(
      'RPC readiness timeout attempts=$attempts lastError=$lastError',
    );
    // 截止时间后仍未就绪，向上层返回最后一次连接错误。
    throw Aria2RpcException(
      'aria2 RPC did not become ready.',
      cause: lastError,
    );
  }

  /// 验证动态 JSON 值是对象并统一转换键类型。
  Map<String, Object?> _asStringMap(Object? value) {
    // 非对象结果不符合当前 RPC 方法的协议约定。
    if (value is! Map) {
      throw const Aria2RpcException('Expected a JSON object from aria2.');
    }
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
}

/// aria2 RPC 连接、协议或业务错误。
final class Aria2RpcException implements Exception {
  /// 保存错误消息、可选 RPC 错误码和底层原因。
  const Aria2RpcException(this.message, {this.code, this.cause});

  /// 可读错误说明。
  final String message;

  /// aria2 返回的 JSON-RPC 错误码。
  final int? code;

  /// 连接失败等底层异常。
  final Object? cause;

  /// 输出便于日志定位的错误码与消息。
  @override
  String toString() => 'Aria2RpcException(code: $code, message: $message)';
}
