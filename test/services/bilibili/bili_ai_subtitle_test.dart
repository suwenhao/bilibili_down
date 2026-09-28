import 'dart:convert';
import 'dart:typed_data';

import 'package:bilibili_down/core/network/bili_network_client.dart';
import 'package:bilibili_down/features/downloads/domain/download_extra_resource.dart';
import 'package:bilibili_down/features/downloads/application/resources/download_resource_converter.dart';
import 'package:bilibili_down/services/bilibili/bili_cookie_store.dart';
import 'package:bilibili_down/services/bilibili/bili_input_normalizer.dart';
import 'package:bilibili_down/services/bilibili/bili_subtitle_metadata.dart';
import 'package:bilibili_down/services/bilibili/bilibili_parser_service.dart';
import 'package:bilibili_down/services/bilibili/models/bili_media_info.dart';
import 'package:bilibili_down/services/bilibili/wbi_signer.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// 用合成 Protobuf 和内存 HTTP 响应验证 AI 字幕发现与下载计划，不访问真实接口。
void main() {
  // 同一投稿同时提供人工字幕和仅新版接口可见的 AI 字幕。
  const episode = BiliEpisodeInfo(
    contentType: BiliContentType.ugc,
    bvid: 'BV1test',
    cid: 123,
    index: 1,
    title: 'AI 字幕测试',
    duration: Duration(seconds: 10),
  );

  test('新版元数据解析多语言并跳过未知字段', () {
    // 字段 7 的定长内容用于验证未来新增字段不会破坏现有轨道解析。
    final tracks = decodeBiliSubtitleMetadata(_metadata());
    expect(tracks.map((track) => track['lan']), <String>['ai-zh', 'ai-en']);
    expect(tracks.first['subtitle_url'], '//subtitle.example/ai-zh.json');
  });

  test('AI 字幕正文沿用 BCC 到 SRT 转换', () {
    // 合成一段自动字幕，确认最终文件带时间轴而非原始 JSON。
    final srt = biliSubtitleJsonToSrt(
      jsonEncode(<String, Object?>{
        'body': <Object?>[
          <String, Object?>{'from': 0.5, 'to': 2, 'content': '测试 AI 字幕'},
        ],
      }),
    );
    expect(srt, contains('00:00:00,500 --> 00:00:02,000'));
    expect(srt, contains('测试 AI 字幕'));
    expect(
      artifactKindForExtraResource(DownloadExtraResource.aiSubtitles),
      artifactKindForExtraResource(DownloadExtraResource.subtitles),
    );
  });

  test('截断和非法 wire 数据不能伪装成空字幕', () {
    // 覆盖无效 tag、长度越界、整数截断和超长整数。
    for (final bytes in <List<int>>[
      <int>[0],
      <int>[10, 4, 1],
      <int>[128],
      List<int>.filled(11, 255),
    ]) {
      expect(
        () => decodeBiliSubtitleMetadata(Uint8List.fromList(bytes)),
        throwsFormatException,
      );
    }
  });

  test('人工字幕不访问 AI 接口，AI 下载计划补查新版接口并携带登录态', () async {
    // 测试 Cookie 仅在内存中提供，用于断言统一网络客户端传递现有登录态。
    final store = _CookieStore();
    when(
      store.readCookieHeader,
    ).thenAnswer((_) async => 'SESSDATA=test-session');
    final adapter = _SubtitleAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final client = BiliNetworkClient(dio: dio, cookieStore: store);
    final parser = BilibiliParserService(
      client,
      BiliInputNormalizer(client),
      WbiSigner(client),
    );
    addTearDown(() => dio.close(force: true));

    final manual = await parser.loadSubtitleTracks(episode, aiGenerated: false);
    expect(manual.single.languageCode, 'zh-Hans');
    expect(adapter.paths, <String>['/x/player/wbi/v2']);

    // 明确 AI 资源类型后必须选中 ai-zh，不能回退到现有人工字幕。
    final plan = await parser.createExtraResourcePlan(
      taskId: 'ai-subtitle',
      episode: episode,
      resource: DownloadExtraResource.aiSubtitles,
      resourceVariant: 'ai-zh',
      temporaryPath: '/tmp/ai-subtitle.download',
    );
    expect(
      plan.resource?.url.toString(),
      'https://subtitle.example/ai-zh.json',
    );
    expect(plan.resource?.headers['Cookie'], 'SESSDATA=test-session');
    expect(adapter.paths, contains('/x/v2/subtitle/web/view'));
    expect(adapter.subtitleCookie, 'SESSDATA=test-session');
    expect(adapter.paths, isNot(contains('/x/web-interface/view')));
    // 旧版已持久化的 AI 语言任务仍可恢复，不能因新增选项改成下载人工字幕。
    final legacyPlan = await parser.createExtraResourcePlan(
      taskId: 'legacy-ai-subtitle',
      episode: episode,
      resource: DownloadExtraResource.subtitles,
      resourceVariant: 'ai-zh',
      temporaryPath: '/tmp/legacy-ai-subtitle.download',
    );
    expect(legacyPlan.resource?.url, plan.resource?.url);
  });

  test('播放器缺少 aid 时补查视频元数据', () async {
    final adapter = _SubtitleAdapter(includeAid: false);
    final dio = Dio()..httpClientAdapter = adapter;
    final client = BiliNetworkClient(dio: dio);
    final parser = BilibiliParserService(
      client,
      BiliInputNormalizer(client),
      WbiSigner(client),
    );
    addTearDown(() => dio.close(force: true));
    final tracks = await parser.loadSubtitleTracks(episode, aiGenerated: true);
    expect(tracks.map((track) => track.languageCode), <String>[
      'ai-zh',
      'ai-en',
    ]);
    expect(adapter.paths, contains('/x/web-interface/view'));
  });

  test('AI 接口失败不丢弃人工轨道，但 AI 专用下载必须报错', () async {
    final adapter = _SubtitleAdapter(malformed: true);
    final dio = Dio()..httpClientAdapter = adapter;
    final client = BiliNetworkClient(dio: dio);
    final parser = BilibiliParserService(
      client,
      BiliInputNormalizer(client),
      WbiSigner(client),
    );
    addTearDown(() => dio.close(force: true));
    expect(
      (await parser.loadSubtitleTracks(episode)).single.languageCode,
      'zh-Hans',
    );
    await expectLater(
      parser.loadSubtitleTracks(episode, aiGenerated: true),
      throwsFormatException,
    );
  });
}

/// 生成仅含合成文本和 example 主机名的字幕元数据。
Uint8List _metadata() {
  // 两个 AI 轨道分别模拟中文和英文字幕，附带不使用的整数与定长字段。
  final tracks = <int>[];
  for (final language in <String>['ai-zh', 'ai-en']) {
    final track = <int>[
      8,
      1,
      ..._field(3, utf8.encode(language)),
      ..._field(4, utf8.encode('AI 字幕')),
      ..._field(5, utf8.encode('//subtitle.example/$language.json')),
      61,
      0,
      0,
      0,
      0,
    ];
    tracks.addAll(_field(3, track));
  }
  return Uint8List.fromList(_field(1, tracks));
}

/// 编码测试所需的长度字段，支持超过 127 字节的外层消息。
List<int> _field(int field, List<int> bytes) {
  // 长度按 Protobuf 无符号 varint 编码，不复用待测解码器。
  final lengthBytes = <int>[];
  var length = bytes.length;
  do {
    final remaining = length >> 7;
    lengthBytes.add((length & 127) | (remaining == 0 ? 0 : 128));
    length = remaining;
  } while (length != 0);
  return <int>[(field << 3) | 2, ...lengthBytes, ...bytes];
}

/// 安全存储替身只提供内存 Cookie，不读取系统钥匙串。
final class _CookieStore extends Mock implements BiliCookieStore {}

/// 模拟播放器、视频信息和新版二进制字幕接口。
final class _SubtitleAdapter implements HttpClientAdapter {
  /// 控制是否需要补查 aid，以及二进制接口是否返回损坏数据。
  _SubtitleAdapter({this.includeAid = true, this.malformed = false});

  /// 旧播放器接口是否已经包含视频 aid。
  final bool includeAid;

  /// 模拟新版接口响应被截断。
  final bool malformed;

  /// 记录请求路径，断言人工字幕不额外调用 AI 端点。
  final List<String> paths = <String>[];

  /// 新版字幕请求实际携带的测试 Cookie，用来检查登录态透传。
  String? subtitleCookie;

  /// 内存响应无需释放套接字。
  @override
  void close({bool force = false}) {}

  /// 按路径构造固定响应，并检查新接口身份参数与响应类型。
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    if (options.uri.path == '/x/v2/subtitle/web/view') {
      subtitleCookie = options.headers['Cookie'] as String?;
      expect(options.uri.queryParameters['oid'], '123');
      expect(options.uri.queryParameters['pid'], '456');
      expect(options.uri.queryParameters['preferred_language'], 'ai-zh');
      expect(options.responseType, ResponseType.stream);
      expect(options.followRedirects, isFalse);
      return ResponseBody.fromBytes(
        malformed ? <int>[10, 4, 1] : _metadata(),
        200,
      );
    }
    // aid 查询与播放器响应共享标准 JSON 包装。
    final Map<String, Object?> data;
    if (options.uri.path == '/x/web-interface/view') {
      data = <String, Object?>{'aid': 456};
    } else {
      expect(options.uri.path, '/x/player/wbi/v2');
      data = <String, Object?>{
        if (includeAid) 'aid': 456,
        'subtitle': <String, Object?>{
          'subtitles': <Object?>[
            <String, Object?>{
              'lan': 'zh-Hans',
              'lan_doc': '中文',
              'subtitle_url': '//subtitle.example/manual.json',
            },
          ],
        },
      };
    }
    return ResponseBody.fromString(
      jsonEncode(<String, Object?>{'code': 0, 'data': data}),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }
}
