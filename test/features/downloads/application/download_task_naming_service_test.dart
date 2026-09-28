import 'package:bilibili_down/features/downloads/application/queue/download_task_naming_service.dart';
import 'package:bilibili_down/features/settings/domain/app_settings.dart';
import 'package:bilibili_down/services/bilibili/models/bili_media_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  /// 验证产品默认设置会按合集标题创建动态子目录。
  test('默认文件夹模板使用合集标题', () {
    final settings = AppSettings.defaults();
    // 存储高级设置的默认规则应与产品预期一致，而不是直接落到下载根目录。
    expect(settings.folderTemplate, '%collection%');
  });

  /// 创建命名测试共用的单分集媒体快照。
  BiliEpisodeInfo episode() => const BiliEpisodeInfo(
    contentType: BiliContentType.ugc,
    bvid: 'BV1TEST',
    cid: 100,
    index: 1,
    title: '第/一集',
    duration: Duration(minutes: 2),
  );

  /// 创建包含路径分隔符的发布者和合集信息。
  BiliMediaInfo media(BiliEpisodeInfo item) => BiliMediaInfo(
    contentType: BiliContentType.ugc,
    title: '测/试合集',
    publisherName: 'UP/主',
    publisherId: 123,
    episodes: <BiliEpisodeInfo>[item],
  );

  /// 验证文件名模板继续使用真实渲染器和原始标题值。
  test('文件名模板保持原始标题渲染语义', () {
    const service = DownloadTaskNamingService();
    final item = episode();
    final settings = AppSettings.defaults().copyWith(namingTemplate: '%title%');
    final result = service.renderNamingTemplate(
      settings: settings,
      media: media(item),
      episode: item,
      videoQuality: '1080P AVC',
      audioQuality: '192K',
      downloadDate: DateTime(2026, 7, 12),
    );
    // 文件名模板先渲染原始值，最终非法字符由独立安全清理步骤处理。
    expect(result, '第/一集');
    expect(service.safeFileName(result), '第_一集');
  });

  /// 验证文件夹变量不能通过外部标题中的分隔符创建额外层级。
  test('文件夹模板先清理变量再保留用户层级', () {
    const service = DownloadTaskNamingService();
    final item = episode();
    final settings = AppSettings.defaults().copyWith(
      folderTemplate: '%upnn%/%title%',
    );
    final rendered = service.renderFolderTemplate(
      settings: settings,
      media: media(item),
      episode: item,
      videoQuality: '1080P AVC',
      audioQuality: '192K',
      downloadDate: DateTime(2026, 7, 12),
    );
    // 只有模板自身的斜杠形成目录层级，变量中的斜杠被替换为下划线。
    expect(service.safeRelativeFolderPath(rendered), p.join('UP_主', '第_一集'));
  });

  /// 验证父目录跳转和空目录段被移除。
  test('相对目录清理父目录跳转', () {
    const service = DownloadTaskNamingService();
    // 用户模板不能通过 .. 越出下载根目录。
    expect(service.safeRelativeFolderPath('../UP//./视频'), p.join('UP', '视频'));
  });
}
