import 'dart:io';

import 'package:bilibili_down/features/downloads/application/resources/download_resource_converter.dart';
import 'package:bilibili_down/features/downloads/domain/download_extra_resource.dart';
import 'package:bilibili_down/features/downloads/domain/download_task_phase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 验证附加资源仍写入原有产物分类，避免迁移后影响清理和完整性校验。
  test('附加资源类型保持原产物分类', () {
    // 封面、音频、弹幕和字幕覆盖全部资源枚举分支。
    expect(
      artifactKindForExtraResource(DownloadExtraResource.cover),
      DownloadArtifactKind.cover,
    );
    expect(
      artifactKindForExtraResource(DownloadExtraResource.audio),
      DownloadArtifactKind.output,
    );
    expect(
      artifactKindForExtraResource(DownloadExtraResource.danmakuXml),
      DownloadArtifactKind.danmaku,
    );
    expect(
      artifactKindForExtraResource(DownloadExtraResource.danmakuAss),
      DownloadArtifactKind.danmaku,
    );
    expect(
      artifactKindForExtraResource(DownloadExtraResource.subtitles),
      DownloadArtifactKind.subtitle,
    );
  });

  /// 验证弹幕时间、颜色、实体和 ASS 控制字符按迁移前规则转换。
  test('XML 弹幕转换为带转义文本的 ASS', () {
    // 红色顶部弹幕包含 XML 实体和花括号，覆盖颜色反转及控制字符转义。
    const xml = '<i><d p="1.5,5,25,16711680">A&amp;B{C}</d></i>';
    // 转换结果应保留固定头部并生成一条顶部对齐事件。
    final ass = biliDanmakuXmlToAss(xml);
    expect(ass, contains('[Events]'));
    expect(ass, contains(r'{\an8}'));
    expect(ass, contains(r'\c&H0000FF&'));
    expect(ass, contains(r'A&B\{C\}'));
    expect(ass, contains('0:00:01.50,0:00:06.50'));
  });

  /// 验证文件转换可处理跨块的大 XML，并保持与内存转换相同的 ASS 语义。
  test('XML 弹幕文件使用流式转换并清理输入外文本', () async {
    // 临时目录隔离真实文件读写，测试结束后递归清理全部产物。
    final directory = await Directory.systemTemp.createTemp(
      'bilidown-danmaku-',
    );
    addTearDown(() => directory.delete(recursive: true));
    // 输入包含较长无关头部和两条弹幕，迫使 UTF-8 文件流经过多个数据块。
    final input = File('${directory.path}/source.xml');
    final output = File('${directory.path}/output.ass');
    // 大段无关 XML 文本用于覆盖跨文件流块的标签定位逻辑。
    final padding = List<String>.filled(20000, 'x').join();
    await input.writeAsString(
      '<i>$padding'
      '<d p="1.5,5,25,16711680">第一条</d>'
      '<d p="2,4,25,16777215">第二条</d></i>',
    );

    // 流式接口直接生成文件，不向测试进程返回完整 ASS 字符串。
    await convertBiliDanmakuXmlFileToAss(
      inputPath: input.path,
      outputPath: output.path,
    );
    final ass = await output.readAsString();
    expect(ass, contains('第一条'));
    expect(ass, contains('第二条'));
    expect(
      RegExp(r'^Dialogue:', multiLine: true).allMatches(ass),
      hasLength(2),
    );
  });

  /// 验证 BCC 正文连续编号并使用 SRT 毫秒时间格式。
  test('BCC 字幕转换为连续编号的 SRT', () {
    // 中间坏数据必须跳过，后续合法字幕仍使用连续序号。
    const source =
        '{"body":[{"from":0.25,"to":1.5,"content":"第一句"},'
        '{"from":"bad"},'
        '{"from":2,"to":3.125,"content":"第二句"}]}';
    final srt = biliSubtitleJsonToSrt(source);
    expect(srt, contains('1\n00:00:00,250 --> 00:00:01,500\n第一句'));
    expect(srt, contains('2\n00:00:02,000 --> 00:00:03,125\n第二句'));
  });

  /// 验证字幕文件在读取完整字符串前执行字节上限检查。
  test('超大 BCC 字幕文件拒绝转换且不创建输出', () async {
    // 使用很小的测试上限覆盖正式十六兆保护分支，避免测试本身分配大文件。
    final directory = await Directory.systemTemp.createTemp(
      'bilidown-subtitle-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final input = File('${directory.path}/source.json');
    final output = File('${directory.path}/output.srt');
    await input.writeAsString('{"body":[]}${List.filled(64, 'x').join()}');

    // 文件超过调用上限时应直接失败，不能留下看似有效的空 SRT。
    await expectLater(
      convertBiliSubtitleJsonFileToSrt(
        inputPath: input.path,
        outputPath: output.path,
        maximumInputBytes: 16,
      ),
      throwsA(isA<FormatException>()),
    );
    expect(await output.exists(), isFalse);
  });

  /// 验证空字幕仍被识别为接口异常，而不是生成成功的空文件。
  test('空字幕正文抛出格式异常', () {
    // 没有合法字幕段时保持协调器原有失败语义。
    expect(
      () => biliSubtitleJsonToSrt('{"body":[]}'),
      throwsA(isA<FormatException>()),
    );
  });
}
