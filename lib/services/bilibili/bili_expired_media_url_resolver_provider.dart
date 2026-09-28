import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';
import '../../features/downloads/application/runtime/expired_media_url_resolver.dart';
import 'bili_expired_media_url_resolver.dart';
import 'bilibili_providers.dart';

/// 提供由 B 站播放接口驱动的过期媒体地址刷新器。
final expiredMediaUrlResolverProvider = Provider<ExpiredMediaUrlResolver>((
  Ref ref,
) {
  // 刷新器读取持久化任务选择，并复用应用级解析服务。
  return BiliExpiredMediaUrlResolver(
    ref.watch(bilibiliParserServiceProvider),
    ref.watch(downloadTaskRepositoryProvider),
  );
});
