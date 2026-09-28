import 'package:bilibili_down/features/parser/application/parser_controller.dart';
import 'package:bilibili_down/services/bilibili/bili_api_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 验证用户重复提交相同空输入时每次都产生新的提示事件。
  test('重复空输入会递增错误反馈序号', () async {
    // 空输入分支不会访问网络服务，使用最小 Provider 容器即可验证状态事件。
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(parserControllerProvider.notifier);

    // 第一次提交产生本地输入校验错误。
    await controller.parse();
    final firstState = container.read(parserControllerProvider);
    // 第二次相同点击必须保留同一文案但产生不同反馈序号。
    await controller.parse();
    final secondState = container.read(parserControllerProvider);

    expect(firstState.errorMessage, secondState.errorMessage);
    expect(secondState.errorRevision, greaterThan(firstState.errorRevision));
  });

  /// 验证 B 站异常展示给用户时只保留业务文案。
  test('B 站异常不会展示内部类型名称', () {
    // 异常对象本身包含调试字段，但界面提示只能使用 message。
    const error = BiliApiException(
      kind: BiliApiErrorKind.invalidInput,
      message: '链接中未找到视频标识。',
    );

    final message = biliUserMessage(error, fallback: '解析失败');

    expect(message, '链接中未找到视频标识。');
    expect(message, isNot(contains('BiliApiException')));
  });
}
