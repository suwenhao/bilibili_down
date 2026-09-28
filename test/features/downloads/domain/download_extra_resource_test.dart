import 'package:bilibili_down/features/downloads/domain/download_extra_resource.dart';
import 'package:flutter_test/flutter_test.dart';

/// 验证主任务附加资源 JSON 的稳定编码和损坏数据兼容行为。
void main() {
  // 两种字幕必须使用不同持久化标识，重启和重试不能变回人工字幕。
  test('AI 字幕资源与语言可独立持久化', () {
    final code = downloadExtraResourceCode(
      DownloadExtraResource.aiSubtitles,
      variant: 'ai-zh',
    );
    expect(code, 'resource.aiSubtitles:ai-zh');
    expect(
      downloadExtraResourceFromCode(code),
      DownloadExtraResource.aiSubtitles,
    );
    expect(downloadExtraResourceVariantFromCode(code), 'ai-zh');
    expect(
      decodeDownloadExtraResources(
        encodeDownloadExtraResources(<DownloadExtraResource>[
          DownloadExtraResource.subtitles,
          DownloadExtraResource.aiSubtitles,
        ]),
      ),
      <DownloadExtraResource>{
        DownloadExtraResource.subtitles,
        DownloadExtraResource.aiSubtitles,
      },
    );
  });

  group('download extra resource json', () {
    test('按枚举顺序去重编码并完整恢复', () {
      // 输入故意乱序且重复，验证数据库内容不会受界面点击顺序影响。
      final source = <DownloadExtraResource>[
        DownloadExtraResource.subtitles,
        DownloadExtraResource.cover,
        DownloadExtraResource.subtitles,
        DownloadExtraResource.audio,
      ];

      final encoded = encodeDownloadExtraResources(source);
      final decoded = decodeDownloadExtraResources(encoded);

      expect(encoded, '["cover","audio","subtitles"]');
      expect(decoded, <DownloadExtraResource>{
        DownloadExtraResource.cover,
        DownloadExtraResource.audio,
        DownloadExtraResource.subtitles,
      });
    });

    test('忽略未知名称并把损坏 JSON 安全降级为空集合', () {
      // 未来版本新增资源时旧版本只忽略未知项，已知选择仍应保留。
      expect(
        decodeDownloadExtraResources('["cover","futureResource"]'),
        <DownloadExtraResource>{DownloadExtraResource.cover},
      );
      // 用户数据库字段损坏不能阻止任务列表启动和展示。
      expect(decodeDownloadExtraResources('{broken'), isEmpty);
    });
  });
}
