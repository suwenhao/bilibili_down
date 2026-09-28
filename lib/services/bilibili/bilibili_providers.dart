import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/bili_network_client.dart';
import '../../core/platform/platform_providers.dart';
import '../../features/user/application/bili_session_invalidation_controller.dart';
import 'bili_cookie_store.dart';
import 'bili_auth_service.dart';
import 'bili_input_normalizer.dart';
import 'bili_user_content_service.dart';
import 'bilibili_parser_service.dart';
import 'secure_bili_cookie_store.dart';
import 'wbi_signer.dart';

/// 提供系统安全存储支持的 B 站 Cookie 仓库。
final biliCookieStoreProvider = Provider<BiliCookieStore>((Ref ref) {
  // Cookie 存储本身无长连接，直接创建跨平台安全实现。
  return SecureBiliCookieStore();
});

/// 提供统一 B 站网络客户端。
final biliNetworkClientProvider = Provider<BiliNetworkClient>((Ref ref) {
  // 注入安全 Cookie 存储，使登录完成后所有新请求自动携带完整会话。
  return BiliNetworkClient(
    cookieStore: ref.watch(biliCookieStoreProvider),
    onSessionExpired: () {
      // 失效会话只通知账号权限降级，不阻断游客解析、下载或任务记录。
      ref
          .read(biliSessionInvalidationControllerProvider.notifier)
          .notifyExpired();
    },
  );
});

/// 提供二维码登录、状态校验和本地退出服务。
final biliAuthServiceProvider = Provider<BiliAuthService>((Ref ref) {
  // 登录服务复用统一网络策略，并把敏感会话写入同一个安全仓库。
  return BiliAuthService(
    ref.watch(biliNetworkClientProvider),
    ref.watch(biliCookieStoreProvider),
    ref.watch(runtimePlatformProvider),
  );
});

/// 提供 BV/AV/EP/SS 和短链接输入归一化器。
final biliInputNormalizerProvider = Provider<BiliInputNormalizer>((Ref ref) {
  // 短链接解析复用统一网络策略和域名限制。
  return BiliInputNormalizer(ref.watch(biliNetworkClientProvider));
});

/// 提供带十分钟密钥缓存的 WBI 签名器。
final wbiSignerProvider = Provider<WbiSigner>((Ref ref) {
  // 签名器通过 nav 接口动态获取密钥，不硬编码易失效密钥。
  return WbiSigner(ref.watch(biliNetworkClientProvider));
});

/// 提供 B 站基础信息和 DASH 播放流解析服务。
final bilibiliParserServiceProvider = Provider<BilibiliParserService>((
  Ref ref,
) {
  // 在组合根注入网络、输入和签名组件，解析页只依赖该服务。
  return BilibiliParserService(
    ref.watch(biliNetworkClientProvider),
    ref.watch(biliInputNormalizerProvider),
    ref.watch(wbiSignerProvider),
  );
});

/// 提供用户中心历史、稿件、收藏和最近点赞列表服务。
final biliUserContentServiceProvider = Provider<BiliUserContentService>((
  Ref ref,
) {
  // 用户列表接口复用登录 Cookie 与 WBI 签名，避免新增一套网络实现。
  return BiliUserContentService(
    ref.watch(biliNetworkClientProvider),
    ref.watch(wbiSignerProvider),
  );
});
