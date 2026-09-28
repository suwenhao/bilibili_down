import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bilibili_down/features/downloads/domain/download_extra_resource.dart';
import 'package:bilibili_down/services/bilibili/bili_input_normalizer.dart';
import 'package:bilibili_down/services/bilibili/bilibili_parser_service.dart';
import 'package:bilibili_down/services/bilibili/models/bili_media_info.dart';
import 'package:bilibili_down/services/bilibili/wbi_signer.dart';
import 'package:bilibili_down/core/network/bili_network_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 验证播放器全部语言字幕会解析、去重并规范化协议相对地址。
  test('解析多语言字幕并按语言代码去重', () async {
    // 内存网络响应包含简中、英文及同语言的独立 AI 轨道。
    final dio = Dio()..httpClientAdapter = const _SubtitleHttpAdapter();
    final client = BiliNetworkClient(dio: dio);
    final parser = BilibiliParserService(
      client,
      BiliInputNormalizer(client),
      WbiSigner(client),
    );
    const episode = BiliEpisodeInfo(
      contentType: BiliContentType.pgc,
      bvid: 'BV1subtitle',
      cid: 123,
      episodeId: 456,
      seasonId: 789,
      index: 1,
      title: '多语言分集',
      duration: Duration(minutes: 1),
    );

    final tracks = await parser.loadSubtitleTracks(episode);

    expect(
      tracks.map((BiliSubtitleTrack track) => track.languageCode),
      <String>['zh-Hans', 'en-US', 'ai-zh-Hans'],
    );
    expect(tracks.first.languageLabel, '中文（简体）');
    expect(tracks.first.uri.scheme, 'https');
    // 下载选项必须精确筛选，人工与 AI 同时存在时不能互相替代。
    expect(
      (await parser.loadSubtitleTracks(episode, aiGenerated: false)).length,
      2,
    );
    expect(
      (await parser.loadSubtitleTracks(
        episode,
        aiGenerated: true,
      )).single.isAiGenerated,
      isTrue,
    );
  });

  /// 验证语言变体可持久化在内容类型中并由旧基础类型解析器兼容读取。
  test('字幕语言变体可稳定写入并恢复', () {
    // 新代码附加语言，基础资源解析仍返回 subtitles 供旧流程识别。
    final code = downloadExtraResourceCode(
      DownloadExtraResource.subtitles,
      variant: 'en-US',
    );
    expect(code, 'resource.subtitles:en-US');
    expect(
      downloadExtraResourceFromCode(code),
      DownloadExtraResource.subtitles,
    );
    expect(downloadExtraResourceVariantFromCode(code), 'en-US');
  });

  /// 验证 AV 号会通过 aid 参数调用普通视频 view 接口。
  test('使用 AV 号解析普通视频信息', () async {
    // 内存适配器只接受 aid 查询，避免 BVID 分支误通过测试。
    final dio = Dio()..httpClientAdapter = const _AvidViewHttpAdapter();
    final client = BiliNetworkClient(dio: dio);
    final parser = BilibiliParserService(
      client,
      BiliInputNormalizer(client),
      WbiSigner(client),
    );

    // 标准化目标直接模拟输入层产物，聚焦解析服务的 aid 查询行为。
    final media = await parser.parseTarget(
      const BiliInputTarget.numeric(BiliInputKind.avid, 170001),
    );

    expect(media.title, 'AV 普通视频');
    expect(media.publisherName, '测试 UP');
    expect(media.episodes.single.bvid, 'BV1nfj86AEAo');
    expect(media.episodes.single.cid, 987654);
  });

  /// 验证弹幕解码兼容 raw deflate、zlib deflate、gzip 和安全大小上限。
  test('兼容弹幕压缩边界并限制解压大小', () {
    // 使用真实 XML 字节分别编码三种服务端可能返回的压缩形式。
    final xml = Uint8List.fromList(utf8.encode('<i><d p="1">测试</d></i>'));
    final rawDeflate = Uint8List.fromList(ZLibEncoder(raw: true).convert(xml));
    final zlibDeflate = Uint8List.fromList(zlib.encode(xml));
    final gzipPayload = Uint8List.fromList(gzip.encode(xml));
    expect(decodeDanmakuPayload(rawDeflate, contentEncoding: 'deflate'), xml);
    expect(decodeDanmakuPayload(zlibDeflate, contentEncoding: 'deflate'), xml);
    expect(decodeDanmakuPayload(gzipPayload, contentEncoding: 'gzip'), xml);
    expect(
      () => decodeDanmakuPayload(xml, maximumDecodedBytes: xml.length - 1),
      throwsA(isA<FormatException>()),
    );
    // 压缩正文同样必须在分块输出超过上限时中止，不能只检查最终完整结果。
    expect(
      () => decodeDanmakuPayload(
        gzipPayload,
        contentEncoding: 'gzip',
        maximumDecodedBytes: xml.length - 1,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  /// 验证新版 PGC v2 的 result.video_info 包装可以归一化为 DASH 清单。
  test('解析 PGC v2 嵌套播放信息', () async {
    // 新版端点响应通过独立适配器提供，避免回退旧接口掩盖结构问题。
    final dio = Dio()..httpClientAdapter = const _PgcPlayurlHttpAdapter();
    final client = BiliNetworkClient(dio: dio);
    final parser = BilibiliParserService(
      client,
      BiliInputNormalizer(client),
      WbiSigner(client),
    );
    const episode = BiliEpisodeInfo(
      contentType: BiliContentType.pgc,
      bvid: 'BV1pgcv2',
      cid: 321,
      episodeId: 654,
      seasonId: 987,
      index: 1,
      title: '新版 PGC',
      duration: Duration(minutes: 1),
    );

    final manifest = await parser.loadDashManifest(episode);

    expect(manifest.videoStreams, hasLength(1));
    expect(manifest.audioStreams, hasLength(1));
    expect(manifest.duration, const Duration(seconds: 60));
  });
}

/// 返回 AV 号普通视频 view 数据的 Dio 适配器。
final class _AvidViewHttpAdapter implements HttpClientAdapter {
  /// 无状态测试适配器。
  const _AvidViewHttpAdapter();

  @override
  void close({bool force = false}) {
    // 内存响应没有连接需要释放。
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // AV 解析必须命中普通视频 view 接口并携带 aid 参数。
    expect(options.uri.path, '/x/web-interface/view');
    expect(options.uri.queryParameters['aid'], '170001');
    expect(options.uri.queryParameters.containsKey('bvid'), isFalse);
    final body = <String, Object?>{
      'code': 0,
      'data': <String, Object?>{
        'bvid': 'BV1nfj86AEAo',
        'title': 'AV 普通视频',
        'pic': 'https://i.example/cover.jpg',
        'desc': 'AV 兼容测试',
        'pubdate': 1780000000,
        'owner': <String, Object?>{'mid': 42, 'name': '测试 UP'},
        'pages': <Object?>[
          <String, Object?>{
            'cid': 987654,
            'page': 1,
            'part': '第一页',
            'duration': 66,
            'dimension': <String, Object?>{'width': 1920, 'height': 1080},
          },
        ],
      },
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }
}

/// 返回 PGC v2 多层包装 DASH 数据的测试适配器。
final class _PgcPlayurlHttpAdapter implements HttpClientAdapter {
  /// 无状态测试适配器。
  const _PgcPlayurlHttpAdapter();

  @override
  void close({bool force = false}) {
    // 内存响应不持有连接。
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(options.uri.path, '/pgc/player/web/v2/playurl');
    final streamBase = <String, Object?>{
      'bandwidth': 1000000,
      'backup_url': <Object?>[],
    };
    final body = <String, Object?>{
      'code': 0,
      'result': <String, Object?>{
        'video_info': <String, Object?>{
          'dash': <String, Object?>{
            'duration': 60,
            'video': <Object?>[
              <String, Object?>{
                ...streamBase,
                'id': 80,
                'base_url': 'https://cdn.example/video.m4s',
                'mime_type': 'video/mp4',
                'codecs': 'avc1.640028',
                'codecid': 7,
              },
            ],
            'audio': <Object?>[
              <String, Object?>{
                ...streamBase,
                'id': 30280,
                'base_url': 'https://cdn.example/audio.m4s',
                'mime_type': 'audio/mp4',
                'codecs': 'mp4a.40.2',
                'codecid': 0,
              },
            ],
          },
        },
      },
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }
}

/// 返回固定播放器字幕列表的 Dio 适配器。
final class _SubtitleHttpAdapter implements HttpClientAdapter {
  /// 无状态测试适配器。
  const _SubtitleHttpAdapter();

  @override
  void close({bool force = false}) {
    // 内存响应没有连接需要释放。
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // PGC 字幕查询应携带分集、季度和媒体身份参数。
    expect(options.uri.path, '/x/player/wbi/v2');
    expect(options.uri.queryParameters['ep_id'], '456');
    expect(options.uri.queryParameters['season_id'], '789');
    final body = <String, Object?>{
      'code': 0,
      'data': <String, Object?>{
        'subtitle': <String, Object?>{
          'subtitles': <Object?>[
            <String, Object?>{
              'lan': 'zh-Hans',
              'lan_doc': '中文（简体）',
              'subtitle_url': '//subtitle.example/zh.json',
            },
            <String, Object?>{
              'lan': 'en-US',
              'lan_doc': '英语（美国）',
              'subtitle_url': 'https://subtitle.example/en.json',
            },
            <String, Object?>{
              'lan': 'zh-Hans',
              'lan_doc': '中文（自动生成）',
              'ai_type': 1,
              'subtitle_url': '//subtitle.example/ai-zh.json',
            },
            <String, Object?>{
              'lan': 'zh-Hans',
              'lan_doc': '重复人工字幕',
              'subtitle_url': '//subtitle.example/duplicate.json',
            },
          ],
        },
      },
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }
}
