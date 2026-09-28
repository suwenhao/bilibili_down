import '../../../../services/download_engine/download_engine.dart';
import '../../domain/download_task_phase.dart';

/// 把统一下载状态映射为媒体分流持久化状态。
DownloadStreamPhase streamPhaseFor(DownloadStatus status) {
  // resolving 是引擎级准备状态，在分流层仍视为已经排队。
  return switch (status) {
    DownloadStatus.queued ||
    DownloadStatus.resolving => DownloadStreamPhase.queued,
    DownloadStatus.downloading => DownloadStreamPhase.downloading,
    DownloadStatus.paused => DownloadStreamPhase.paused,
    DownloadStatus.completed => DownloadStreamPhase.completed,
    DownloadStatus.failed => DownloadStreamPhase.failed,
    DownloadStatus.canceled => DownloadStreamPhase.canceled,
  };
}

/// 从下载错误文本提取可用于刷新 URL 的稳定错误码。
String? downloadErrorCodeFor(String? message, {String? aria2ErrorCode}) {
  // 没有错误说明时无法提取稳定错误码。
  if (message == null && aria2ErrorCode == null) return null;
  // aria2 errorCode=22 代表 HTTP 响应异常，具体状态码优先从 message 提取。
  final normalizedAria2Code = aria2ErrorCode?.trim();
  // 统一转小写，后续文本规则不依赖后端大小写。
  final lowerMessage = message?.toLowerCase() ?? '';
  // Windows Schannel 无法访问吊销服务时允许换 CDN；不能把证书已吊销或不受信任误判为网络故障。
  if (lowerMessage.contains('80092013') ||
      lowerMessage.contains('crypt_e_revocation_offline') ||
      lowerMessage.contains('revocation server was offline') ||
      lowerMessage.contains('吊销服务器已脱机') ||
      lowerMessage.contains('吊销服务器脱机')) {
    return 'certificate_revocation_unavailable';
  }
  // aria2 AddUri 或 CreateRequest 没拿到可用 URI，说明当前播放地址或 CDN 列表不可用。
  if (lowerMessage.contains('no uri to download') ||
      lowerMessage.contains('no uri available')) {
    return 'no_uri';
  }
  // aria2/OpenSSL 的 TLS 收包中断使用稳定业务码，触发有限的换 CDN 重试。
  if (lowerMessage.contains('protocol error')) {
    return 'protocol_error';
  }
  // 常见 socket、DNS、超时和连接中断错误允许有限轮换备用 CDN。
  if (lowerMessage.contains('timeout') ||
      lowerMessage.contains('timed out') ||
      lowerMessage.contains('connection reset') ||
      lowerMessage.contains('connection closed') ||
      lowerMessage.contains('failed host lookup') ||
      lowerMessage.contains('network is unreachable') ||
      lowerMessage.contains('socketexception')) {
    return 'network_error';
  }
  // 同时兼容系统下载器的“HTTP 403”和 aria2 的“status=403”格式。
  final match = RegExp(
    r'(?:HTTP\s+|status(?:\s+code)?\s*[=:]?\s*)([1-5]\d\d)',
    caseSensitive: false,
  ).firstMatch(message ?? '');
  // 401/403/404 可明确重新解析；5xx 或 514 这类 CDN 异常走 http_error 轮换。
  final httpStatus = match?.group(1);
  if (httpStatus == '401' || httpStatus == '403' || httpStatus == '404') {
    return httpStatus;
  }
  if (httpStatus != null) return 'http_error';
  // 官方手册说明 tellStatus.errorCode 对应 EXIT STATUS；22 是 HTTP 响应头异常。
  if (normalizedAria2Code == '22') return 'http_error';
  // 匹配失败时交由调用方使用通用错误码。
  return null;
}

/// 为已识别的下载错误提供处理建议，分流记录仍保留原始错误用于诊断。
String? downloadErrorMessageFor(String? message, {String? errorCode}) {
  // 吊销服务不可达不等于证书已吊销，换源耗尽后需要用户检查网络访问条件。
  if (errorCode == 'certificate_revocation_unavailable') {
    return '无法连接证书吊销服务器，备用下载线路仍不可用。请检查网络、代理或防火墙后重试。';
  }
  // 未识别的错误保留原文，避免丢失下载后端提供的排障信息。
  return message;
}

/// 按固定规则生成分流和下载引擎共同使用的任务 ID。
String downloadStreamId(String taskId, DownloadStreamKind kind) {
  // 内部 ID 不包含标题或路径，避免外部输入影响引擎标识。
  return '$taskId.${kind.name}';
}

/// 按重试次数把下一个备用 CDN 移到首位，并去除重复地址。
List<Uri> orderedCdnRetryUrls({
  required Uri primary,
  required List<Uri> backups,
  required int retryCount,
  required bool rotate,
}) {
  // 集合字面量保留接口原始优先顺序并去除重复地址。
  final candidates = <Uri>{primary, ...backups}.toList(growable: false);
  // 鉴权刷新或没有备用地址时继续使用最新主地址。
  if (!rotate || candidates.length < 2) return candidates;
  // 首次自动重试选择第一个备用地址，后续依次轮换并安全取模。
  final selectedIndex = (retryCount + 1) % candidates.length;
  // 被选地址放首位，其余地址保持原顺序作为 aria2 后续备用。
  return <Uri>[
    candidates[selectedIndex],
    for (var index = 0; index < candidates.length; index++)
      if (index != selectedIndex) candidates[index],
  ];
}
