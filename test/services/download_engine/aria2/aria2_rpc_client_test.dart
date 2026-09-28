import 'package:bilibili_down/services/download_engine/aria2/aria2_rpc_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// 提供可控制 JSON-RPC 响应的 Dio 测试替身。
final class _MockDio extends Mock implements Dio {}

void main() {
  test('兼容 application/json-rpc 返回的字符串 JSON', () async {
    // 创建不会发起真实本机网络请求的 Dio 替身。
    final dio = _MockDio();
    // aria2 的 MIME 类型可能让 Dio 保留字符串，此处复现真实运行时响应。
    when(() => dio.post<Object?>(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => Response<Object?>(
        requestOptions: RequestOptions(path: '/jsonrpc'),
        statusCode: 200,
        data:
            '{"jsonrpc":"2.0","id":1,'
            '"result":{"version":"1.37.0"}}',
      ),
    );
    // 使用注入的 Dio 创建客户端，密钥仅为测试占位符。
    final client = Aria2RpcClient(port: 6800, secret: 'test', dio: dio);

    // 调用版本接口并验证字符串响应已经恢复为类型安全对象。
    final version = await client.getVersion();

    // 真实版本字段必须能够被业务层读取。
    expect(version['version'], '1.37.0');
  });

  /// 验证 B 站返回的备用 CDN 地址会与主地址一并提交给 aria2。
  test('addUri 保留主地址和去重后的备用地址', () async {
    // 保存 mock 收到的 JSON-RPC 请求体，避免测试访问本机 aria2 端口。
    Object? requestData;
    final dio = _MockDio();
    when(() => dio.post<Object?>(any(), data: any(named: 'data'))).thenAnswer((
      invocation,
    ) async {
      // Dio data 命名参数就是客户端构造的完整 JSON-RPC 对象。
      requestData = invocation.namedArguments[#data];
      return Response<Object?>(
        requestOptions: RequestOptions(path: '/jsonrpc'),
        statusCode: 200,
        data: <String, Object?>{'jsonrpc': '2.0', 'id': 1, 'result': 'gid-1'},
      );
    });
    // 测试密钥只用于补齐 aria2 RPC 参数，不会写入断言输出。
    final client = Aria2RpcClient(port: 6800, secret: 'test', dio: dio);

    // 重复主地址用于确认发送前会去重，备用地址顺序必须保留。
    await client.addUri(
      Uri.parse('https://primary.example/video.m4s'),
      directory: '/tmp',
      outputName: 'video.m4s',
      gid: '0123456789abcdef',
      backupUris: <Uri>[
        Uri.parse('https://backup.example/video.m4s'),
        Uri.parse('https://primary.example/video.m4s'),
      ],
    );

    // params 第一项是 RPC token，第二项才是 aria2.addUri 的 URI 列表。
    final body = requestData! as Map<String, Object?>;
    final parameters = body['params']! as List<Object?>;
    expect(parameters[1], <String>[
      'https://primary.example/video.m4s',
      'https://backup.example/video.m4s',
    ]);
  });

  test('HTTP 400 的 JSON-RPC 错误会解析为 Aria2RpcException', () async {
    // aria2 可能用 HTTP 400 表示业务错误，例如 GID 已存在。
    final dio = _MockDio();
    when(() => dio.post<Object?>(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => Response<Object?>(
        requestOptions: RequestOptions(path: '/jsonrpc'),
        statusCode: 400,
        data: <String, Object?>{
          'jsonrpc': '2.0',
          'id': 1,
          'error': <String, Object?>{
            'code': 1,
            'message': 'GID 0123456789abcdef is not unique.',
          },
        },
      ),
    );
    // 使用注入 Dio 避免测试访问本机 aria2 服务。
    final client = Aria2RpcClient(port: 6800, secret: 'test', dio: dio);

    // 业务错误必须进入 RPC 异常分支，而不是被 Dio 的 bad response 截断。
    await expectLater(
      client.addUri(
        Uri.parse('https://primary.example/video.m4s'),
        directory: '/tmp',
        outputName: 'video.m4s',
        gid: '0123456789abcdef',
      ),
      throwsA(
        isA<Aria2RpcException>()
            .having((error) => error.code, 'code', 1)
            .having((error) => error.message, 'message', contains('GID')),
      ),
    );
  });

  test('remove 活动任务失败时继续清理下载结果记录', () async {
    // 保存调用顺序，确认活动任务删除失败后会走 stopped/result 清理。
    final methods = <String>[];
    final dio = _MockDio();
    when(() => dio.post<Object?>(any(), data: any(named: 'data'))).thenAnswer((
      invocation,
    ) async {
      final body = invocation.namedArguments[#data] as Map<String, Object?>;
      final method = body['method']!.toString();
      methods.add(method);
      if (method == 'aria2.remove') {
        return Response<Object?>(
          requestOptions: RequestOptions(path: '/jsonrpc'),
          statusCode: 400,
          data: <String, Object?>{
            'jsonrpc': '2.0',
            'id': 1,
            'error': <String, Object?>{
              'code': 1,
              'message': 'GID was not found.',
            },
          },
        );
      }
      return Response<Object?>(
        requestOptions: RequestOptions(path: '/jsonrpc'),
        statusCode: 200,
        data: <String, Object?>{'jsonrpc': '2.0', 'id': 2, 'result': 'OK'},
      );
    });
    // 客户端不访问真实 aria2，只验证 RPC 方法选择。
    final client = Aria2RpcClient(port: 6800, secret: 'test', dio: dio);

    await client.remove('0123456789abcdef');

    expect(methods, <String>['aria2.remove', 'aria2.removeDownloadResult']);
  });

  test('changeGlobalDownloadLimit 使用 aria2 全局限速选项', () async {
    // 保存 mock 收到的请求体，验证限速设置不会访问真实 aria2。
    Object? requestData;
    final dio = _MockDio();
    when(() => dio.post<Object?>(any(), data: any(named: 'data'))).thenAnswer((
      invocation,
    ) async {
      // 捕获完整 JSON-RPC 请求体，后续断言 method 和 options。
      requestData = invocation.namedArguments[#data];
      return Response<Object?>(
        requestOptions: RequestOptions(path: '/jsonrpc'),
        statusCode: 200,
        data: <String, Object?>{'jsonrpc': '2.0', 'id': 1, 'result': 'OK'},
      );
    });
    // 测试密钥只用于补齐 aria2 RPC token。
    final client = Aria2RpcClient(port: 6800, secret: 'test', dio: dio);

    await client.changeGlobalDownloadLimit(32);

    // aria2 全局限速必须通过 changeGlobalOption 设置 max-overall-download-limit。
    final body = requestData! as Map<String, Object?>;
    expect(body['method'], 'aria2.changeGlobalOption');
    final parameters = body['params']! as List<Object?>;
    expect(parameters[1], <String, Object?>{
      'max-overall-download-limit': '32M',
    });
  });
}
