import 'dart:typed_data';

import 'package:bilibili_down/core/network/bili_network_client.dart';
import 'package:bilibili_down/services/bilibili/bili_api_exception.dart';
import 'package:bilibili_down/services/bilibili/bili_input_normalizer.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 验证解析输入框可以直接识别裸 BV 号。
  test('解析直接输入的裸 BV 号', () async {
    // 裸 BV 不需要网络，大小写前缀统一规范为 BV。
    final normalizer = BiliInputNormalizer(BiliNetworkClient());

    final target = await normalizer.normalize('bv1nfj86AEAo');

    expect(target.kind, BiliInputKind.bvid);
    expect(target.canonicalId, 'BV1nfj86AEAo');
  });

  /// 验证 B 站 App 复制的标题与链接混合文案能够提取出视频目标。
  test('解析 App 分享文案中的标准视频链接', () async {
    // 标准站点链接无需网络跳转，客户端仅用于满足归一化器依赖。
    final normalizer = BiliInputNormalizer(BiliNetworkClient());

    // 输入模拟 App 分享文本，并覆盖链接末尾紧邻中文标点的情况。
    final target = await normalizer.normalize(
      '【测试视频-哔哩哔哩】 https://www.bilibili.com/video/BV1nfj86AEAo。',
    );

    // 分享文案应归一化为与纯 BVID 输入相同的标准目标。
    expect(target.kind, BiliInputKind.bvid);
    expect(target.canonicalId, 'BV1nfj86AEAo');
  });

  /// 验证文案中存在其他网址时仍优先寻找受支持的 B 站视频链接。
  test('跳过分享文案中的非 B 站链接', () async {
    // 标准站点解析不发起请求，因此测试不会访问外部网络。
    final normalizer = BiliInputNormalizer(BiliNetworkClient());

    // 非受信任网址位于前面，用于验证扫描不会误选第一个 URL。
    final target = await normalizer.normalize(
      '说明 https://example.com 【视频】https://m.bilibili.com/video/BV1nfj86AEAo',
    );

    // 只有白名单中的 B 站地址应参与视频标识解析。
    expect(target.canonicalId, 'BV1nfj86AEAo');
  });

  /// 验证旧 AV 号输入和网页路径都能归一化为普通视频目标。
  test('解析 AV 标识和视频路径', () async {
    // AV 号无需网络跳转，大小写前缀都应被兼容。
    final normalizer = BiliInputNormalizer(BiliNetworkClient());

    // 直接输入 AV 号时应保留数字并统一为小写前缀。
    final direct = await normalizer.normalize('AV170001');
    expect(direct.kind, BiliInputKind.avid);
    expect(direct.canonicalId, 'av170001');

    // 老网页路径中的 av 标识也应走同一普通视频解析入口。
    final url = await normalizer.normalize(
      'https://www.bilibili.com/video/av170001',
    );
    expect(url.kind, BiliInputKind.avid);
    expect(url.canonicalId, 'av170001');
  });

  /// 验证解析输入框可以直接识别纯数字 AV 号。
  test('解析直接输入的裸数字 AV 号', () async {
    // 解析页输入框是明确视频目标场景，纯数字按旧 AV 稿件号处理。
    final normalizer = BiliInputNormalizer(BiliNetworkClient());

    final target = await normalizer.normalize('170001');

    expect(target.kind, BiliInputKind.avid);
    expect(target.canonicalId, 'av170001');
  });

  /// 验证用户手输的说明文本中可以提取独立视频标识。
  test('解析普通文本里的单个视频号', () async {
    // 没有链接时允许从普通文本中找独立 BV/AV 标识。
    final normalizer = BiliInputNormalizer(BiliNetworkClient());

    final bvid = await normalizer.normalize('BV号：BV1nfj86AEAo');
    final avid = await normalizer.normalize('AV号：av170001');

    expect(bvid.canonicalId, 'BV1nfj86AEAo');
    expect(avid.canonicalId, 'av170001');
  });

  /// 验证非白名单链接不能夹带裸视频号绕过域名校验。
  test('拒绝非 B 站链接夹带的视频号', () async {
    // 只要文本包含非白名单 URL，就不能再回退扫描其中的 BV。
    final normalizer = BiliInputNormalizer(BiliNetworkClient());

    expect(
      () => normalizer.normalize('https://example.com/watch BV1nfj86AEAo'),
      throwsA(isA<BiliApiException>()),
    );
  });

  /// 验证视频网页里的 p 参数会保留给解析页默认选中对应分 P。
  test('解析视频链接中的分 P 参数', () async {
    // 标准网页链接不需要网络，p 参数只影响前端默认选中项。
    final normalizer = BiliInputNormalizer(BiliNetworkClient());

    final target = await normalizer.normalize(
      'https://www.bilibili.com/video/BV16gckzzE6p?p=3',
    );

    expect(target.kind, BiliInputKind.bvid);
    expect(target.canonicalId, 'BV16gckzzE6p');
    expect(target.pageNumber, 3);
  });

  /// 验证 App 分享的 b23.tv 随机短码会通过 GET 回退展开为真实 B 站链接。
  test('解析 App 分享文案中的 b23.tv 短码', () async {
    // 内存 Dio 适配器模拟真实短链服务拒绝 HEAD、但 GET 能完成跳转。
    final adapter = _B23ShortLinkHttpAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final normalizer = BiliInputNormalizer(BiliNetworkClient(dio: dio));

    // App 分享短码后缀不是 BV 号，必须依赖跳转地址才能识别视频目标。
    final target = await normalizer.normalize(
      '【测试视频-哔哩哔哩】 https://b23.tv/aB9xYz1 复制链接后打开',
    );

    // 短码应解析到 GET 跳转后的标准 BVID，且确实触发了 HEAD 到 GET 的回退链路。
    expect(target.kind, BiliInputKind.bvid);
    expect(target.canonicalId, 'BV1nfj86AEAo');
    expect(adapter.headRequests, 1);
    expect(adapter.getRequests, 1);
  });

  /// 验证 b23.tv 落到 B 站 App deep link 时也能继续解析。
  test('解析跳转到 App deep link 的 b23.tv 短码', () async {
    // 移动端短链可能最终跳转到 bilibili://，不能按网页域名直接拒绝。
    final adapter = _B23ShortLinkHttpAdapter(
      redirectedUri: Uri.parse('bilibili://video/170001'),
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final normalizer = BiliInputNormalizer(BiliNetworkClient(dio: dio));

    final target = await normalizer.normalize('https://b23.tv/appLink');

    expect(target.kind, BiliInputKind.avid);
    expect(target.canonicalId, 'av170001');
    expect(adapter.getRequests, 1);
  });

  /// 验证 b23.tv 随机短码不会被当成路径里的媒体标识。
  test('b23 短码看似媒体标识时仍先展开', () async {
    // ss28770 在普通路径里像季度号，但作为 b23 路径时只是随机短码。
    final adapter = _B23ShortLinkHttpAdapter(
      redirectedUri: Uri.parse('https://www.bilibili.com/video/BV18qMY6vE8m'),
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final normalizer = BiliInputNormalizer(BiliNetworkClient(dio: dio));

    final target = await normalizer.normalize('https://b23.tv/ss28770');

    expect(target.kind, BiliInputKind.bvid);
    expect(target.canonicalId, 'BV18qMY6vE8m');
    expect(adapter.getRequests, 1);
  });

  /// 验证用户直接粘贴裸 b23.tv 短链时也必须走短链展开。
  test('解析直接粘贴的裸 b23.tv 短链', () async {
    // 真实短码本身不包含视频 ID，必须依赖跳转后的 B 站地址。
    final adapter = _B23ShortLinkHttpAdapter(
      redirectedUri: Uri.parse('https://www.bilibili.com/video/BV18qMY6vE8m'),
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final normalizer = BiliInputNormalizer(BiliNetworkClient(dio: dio));

    final target = await normalizer.normalize('https://b23.tv/6C7V90s');

    expect(target.kind, BiliInputKind.bvid);
    expect(target.canonicalId, 'BV18qMY6vE8m');
    expect(adapter.getRequests, 1);
  });
}

/// b23.tv 短链解析测试用内存 HTTP 适配器。
final class _B23ShortLinkHttpAdapter implements HttpClientAdapter {
  /// 创建可自定义最终跳转地址的短链适配器。
  _B23ShortLinkHttpAdapter({Uri? redirectedUri})
    : redirectedUri =
          redirectedUri ??
          Uri.parse('https://www.bilibili.com/video/BV1nfj86AEAo');

  /// GET 跳转链最终落地地址。
  final Uri redirectedUri;

  /// 已收到的 HEAD 请求次数，用来确认先尝试轻量跳转探测。
  int headRequests = 0;

  /// 已收到的 GET 请求次数，用来确认 HEAD 失败后能回退解析。
  int getRequests = 0;

  @override
  void close({bool force = false}) {
    // 测试适配器不持有真实网络连接，无需释放资源。
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // 短链解析只允许访问测试中的 b23.tv 主机，避免误测其他接口。
    expect(options.uri.host, 'b23.tv');
    // 真实服务可能拒绝 HEAD，因此这里用 405 触发客户端 GET 回退。
    if (options.method == 'HEAD') {
      headRequests++;
      return ResponseBody.fromString('', 405);
    }
    // GET 请求通过 Location 模拟真实 b23.tv 第一跳，客户端不应依赖自动重定向 realUri。
    if (options.method == 'GET') {
      getRequests++;
      return ResponseBody.fromString(
        '',
        302,
        headers: <String, List<String>>{
          'location': <String>[redirectedUri.toString()],
        },
      );
    }
    // 未预期方法说明短链解析实现越过了测试约束。
    return ResponseBody.fromString('', 405);
  }
}
