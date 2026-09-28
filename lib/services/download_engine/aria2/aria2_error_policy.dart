import 'aria2_rpc_client.dart';

/// aria2 错误的业务分类，用于统一重试、清理和用户提示。
enum Aria2ErrorKind {
  gidConflict,
  gidMissing,
  noUri,
  httpStatus,
  network,
  protocol,
  busyState,
  rpcTransport,
  storage,
  unknown,
}

/// 根据 aria2 RPC 异常或下载错误文本识别稳定业务分类。
Aria2ErrorKind classifyAria2Error(Object error) {
  // RPC 异常只取 message 和底层 cause，避免把异常类型名展示给用户。
  final message = error is Aria2RpcException
      ? error.message.toLowerCase()
      : error.toString().toLowerCase();
  // GID 冲突来自 aria2 源码 str2Gid 分支，代表旧任务或结果占用了稳定 GID。
  if (message.contains('gid') && message.contains('not unique')) {
    return Aria2ErrorKind.gidConflict;
  }
  // GID 不存在通常发生在用户快速暂停、恢复、删除时，属于状态已经变化。
  if ((message.contains('gid') || message.contains('unknown aria2 task')) &&
      (message.contains('not found') || message.contains('was not found'))) {
    return Aria2ErrorKind.gidMissing;
  }
  // AddUri 或 CreateRequest 没有得到可用地址时，按播放地址不可用处理。
  if (message.contains('no uri to download') ||
      message.contains('no uri available')) {
    return Aria2ErrorKind.noUri;
  }
  // aria2 对不能暂停的终态任务会返回 cannot be paused now。
  if (message.contains('cannot be paused now')) {
    return Aria2ErrorKind.busyState;
  }
  // HTTP 状态异常由 aria2 errorCode=22 或 status=xxx 表达。
  if (message.contains('errorcode=22') ||
      RegExp(
        r'(?:http\s+|status(?:\s+code)?\s*[=:]?\s*)[1-5]\d\d',
      ).hasMatch(message)) {
    return Aria2ErrorKind.httpStatus;
  }
  // TLS 或协议收包异常通常换 CDN 后可恢复。
  if (message.contains('protocol error') || message.contains('ssl')) {
    return Aria2ErrorKind.protocol;
  }
  // 常见连接层错误，允许调度层按网络或 CDN 问题处理。
  if (message.contains('timeout') ||
      message.contains('timed out') ||
      message.contains('connection reset') ||
      message.contains('connection closed') ||
      message.contains('failed host lookup') ||
      message.contains('network is unreachable') ||
      message.contains('socketexception')) {
    return Aria2ErrorKind.network;
  }
  // JSON-RPC 连接和协议错误通常代表 aria2 后端不可用或进程状态异常。
  if (message.contains('/jsonrpc') ||
      message.contains('json-rpc') ||
      message.contains('connection refused') ||
      (message.contains('http') && error is Aria2RpcException)) {
    return Aria2ErrorKind.rpcTransport;
  }
  // 文件系统错误应提示用户检查保存目录或权限。
  if (message.contains('permission') ||
      message.contains('denied') ||
      message.contains('disk') ||
      message.contains('no space') ||
      message.contains('file system')) {
    return Aria2ErrorKind.storage;
  }
  // 没有命中已知文本时交给调用方兜底。
  return Aria2ErrorKind.unknown;
}

/// 判断是否是可以通过清理旧 aria2 结果后重试的稳定 GID 冲突。
bool isAria2GidConflict(Object error) {
  // 只把源码明确的 GID not unique 归为冲突，不能把 No URI 合并进来。
  return classifyAria2Error(error) == Aria2ErrorKind.gidConflict;
}

/// 判断错误是否代表 aria2 RPC 或进程链路整体不可用。
bool isAria2TransportFailure(Object error) {
  // 全局失败会阻塞后续任务，业务级地址错误不能进入该分支。
  return classifyAria2Error(error) == Aria2ErrorKind.rpcTransport;
}

/// 转换 aria2 相关错误为用户可读文案，避免暴露 RPC、Dio 或源码类名。
String aria2UserMessage(Object error, {required String fallback}) {
  // 先按稳定分类生成处理建议，再由调用方决定是否展示为 SnackBar 或任务错误。
  return switch (classifyAria2Error(error)) {
    Aria2ErrorKind.gidConflict => '下载状态正在清理，请稍后重试。',
    Aria2ErrorKind.gidMissing => '任务状态已变化，请刷新后重试。',
    Aria2ErrorKind.noUri => '播放地址不可用，请重新解析后重试。',
    Aria2ErrorKind.httpStatus => _httpStatusUserMessage(error),
    Aria2ErrorKind.network => '网络连接异常，请稍后重试。',
    Aria2ErrorKind.protocol => '连接协议异常，已尝试换源后仍失败。',
    Aria2ErrorKind.busyState => '任务状态已变化，请稍后重试。',
    Aria2ErrorKind.rpcTransport => '下载引擎连接失败，请重启应用或稍后重试。',
    Aria2ErrorKind.storage => '保存文件失败，请检查目录权限或剩余空间。',
    Aria2ErrorKind.unknown => fallback,
  };
}

/// 根据 HTTP 状态码生成更贴近 B 站播放地址的提示。
String _httpStatusUserMessage(Object error) {
  // 只解析状态码，不输出原始 URL 或鉴权参数。
  final message = error.toString().toLowerCase();
  final status = RegExp(
    r'(?:http\s+|status(?:\s+code)?\s*[=:]?\s*)([1-5]\d\d)',
  ).firstMatch(message)?.group(1);
  return switch (status) {
    '401' || '403' => '播放地址已过期，请重新解析后重试。',
    '404' => '资源地址不存在，请重新解析后重试。',
    _ when status != null && status.startsWith('5') => '当前 CDN 响应异常，请稍后重试。',
    _ => '下载地址响应异常，请重新解析或稍后重试。',
  };
}
