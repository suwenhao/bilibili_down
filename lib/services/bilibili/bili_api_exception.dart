/// B 站接口错误的稳定业务分类。
enum BiliApiErrorKind {
  /// 用户输入无法识别或缺少必要参数。
  invalidInput,

  /// 网络连接、DNS 或请求超时失败。
  network,

  /// HTTP 或 JSON 响应不符合接口约定。
  invalidResponse,

  /// 接口要求登录或登录状态已经失效。
  unauthorized,

  /// 请求被风控或没有资源访问权限。
  forbidden,

  /// 视频、分集或播放资源不存在。
  notFound,

  /// 当前 IP 所在地区不能播放该内容。
  regionRestricted,

  /// B 站接口返回其他未单独分类的业务错误。
  api,
}

/// 统一承载 B 站业务码、HTTP 状态和底层异常。
final class BiliApiException implements Exception {
  /// 创建一条可由界面和日志共同处理的接口异常。
  const BiliApiException({
    required this.kind,
    required this.message,
    this.apiCode,
    this.httpStatusCode,
    this.cause,
  });

  /// 稳定错误分类。
  final BiliApiErrorKind kind;

  /// 面向用户或日志的错误说明。
  final String message;

  /// B 站 JSON 响应中的业务码。
  final int? apiCode;

  /// HTTP 响应状态码。
  final int? httpStatusCode;

  /// Dio 或解析过程产生的底层异常。
  final Object? cause;

  /// 根据 B 站业务码映射稳定错误分类。
  factory BiliApiException.fromApi({
    required int code,
    required String message,
  }) {
    // 常见业务码单独分类，其余保留为通用 API 错误。
    final kind = switch (code) {
      -101 => BiliApiErrorKind.unauthorized,
      -403 || -412 || -352 || -10403 => BiliApiErrorKind.forbidden,
      -404 || 10003 => BiliApiErrorKind.notFound,
      _ => BiliApiErrorKind.api,
    };
    // 返回同时保留原始业务码的异常。
    return BiliApiException(kind: kind, message: message, apiCode: code);
  }

  /// 输出包含分类、业务码和 HTTP 状态的诊断文本。
  @override
  String toString() =>
      'BiliApiException(kind: ${kind.name}, apiCode: $apiCode, '
      'httpStatusCode: $httpStatusCode, message: $message)';
}

/// 把内部异常转换为适合界面展示的短文案。
String biliUserMessage(Object error, {required String fallback}) {
  // B 站业务异常本身已经携带用户可读说明，不能把诊断 toString 暴露到界面。
  if (error is BiliApiException) return error.message;
  // 格式异常通常来自本地解析或响应结构校验，可直接展示其 message。
  if (error is FormatException && error.message.isNotEmpty) {
    return error.message;
  }
  // 其他未知异常保留兜底文案，详细诊断交给日志。
  return fallback;
}
