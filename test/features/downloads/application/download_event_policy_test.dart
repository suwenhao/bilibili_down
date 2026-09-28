import 'package:bilibili_down/features/downloads/application/runtime/download_event_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// 验证 Windows 吊销检查故障能恢复，同时不放宽真正无效证书的处理。
void main() {
  // 系统语言和 aria2 构建不同，错误可能只含中文、英文或 Windows 错误码。
  const offlineMessages = <String>[
    'SSL/TLS handshake failure: Error: 由于吊销服务器已脱机，吊销功能无法检查吊销。',
    'SSL/TLS handshake failure: The revocation function was unable to check '
        'revocation because the revocation server was offline.',
    'SSL/TLS handshake failure: Error: (80092013)',
    'CRYPT_E_REVOCATION_OFFLINE',
  ];
  // 每种系统错误格式都应进入同一有上限的换源流程。
  for (final message in offlineMessages) {
    test('吊销服务不可达识别：$message', () {
      expect(
        downloadErrorCodeFor(message, aria2ErrorCode: '1'),
        'certificate_revocation_unavailable',
      );
    });
  }

  // 已吊销、不受信任、域名不符和过期证书必须继续作为失败处理。
  const invalidCertificateMessages = <String>[
    'SSL/TLS handshake failure: certificate revoked (800B010C)',
    'SSL/TLS handshake failure: certificate has been revoked (80092010)',
    'SSL/TLS handshake failure: 证书已吊销。',
    'SSL/TLS handshake failure: untrusted root (800B0109)',
    'SSL/TLS handshake failure: certificate name mismatch',
    'SSL/TLS handshake failure: certificate expired',
  ];
  // 不能因为错误包含 SSL 或 certificate 就当作吊销服务暂时不可达。
  for (final message in invalidCertificateMessages) {
    test('无效证书不误判为吊销服务离线：$message', () {
      expect(downloadErrorCodeFor(message, aria2ErrorCode: '1'), isNull);
      expect(downloadErrorMessageFor(message), message);
    });
  }

  // 最终提示必须解释可采取的措施，避免用户误以为视频或保存目录损坏。
  test('吊销服务不可达提供网络排障提示', () {
    expect(
      downloadErrorMessageFor(
        offlineMessages.first,
        errorCode: 'certificate_revocation_unavailable',
      ),
      '无法连接证书吊销服务器，备用下载线路仍不可用。请检查网络、代理或防火墙后重试。',
    );
    expect(downloadErrorMessageFor(null), isNull);
  });
}
