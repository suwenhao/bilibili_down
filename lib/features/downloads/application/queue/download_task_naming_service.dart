import 'package:path/path.dart' as p;

import '../../../../core/platform/output_path_policy.dart';
import '../../../../services/bilibili/models/bili_media_info.dart';
import '../../../settings/domain/app_settings.dart';
import '../../../settings/domain/file_naming_template.dart';

/// 负责渲染下载名称、目录模板并清理跨平台路径。
final class DownloadTaskNamingService {
  /// 创建无状态任务命名服务。
  const DownloadTaskNamingService();

  /// 使用设置中心模板渲染一条任务的输出基础名称。
  String renderNamingTemplate({
    required AppSettings settings,
    required BiliMediaInfo media,
    required BiliEpisodeInfo episode,
    required String videoQuality,
    required String audioQuality,
    DateTime? downloadDate,
  }) {
    // 空模板始终回退分集标题，避免生成无意义文件名。
    final template = settings.namingTemplate.trim().isEmpty
        ? '%title%'
        : settings.namingTemplate;
    // 调用设置页预览共用的渲染器，避免预览与真实文件名规则漂移。
    final rendered = renderFileNamingTemplate(
      template,
      _createNamingValues(
        media: media,
        episode: episode,
        audioQuality: audioQuality,
        videoQuality: videoQuality,
        sanitizeForFolder: false,
        downloadDate: downloadDate,
      ),
    );
    // 用户模板只包含未知变量时仍保留结果供文件名清理器处理。
    return rendered;
  }

  /// 使用高级存储模板渲染下载根目录下的相对子目录。
  String renderFolderTemplate({
    required AppSettings settings,
    required BiliMediaInfo media,
    required BiliEpisodeInfo episode,
    required String videoQuality,
    required String audioQuality,
    DateTime? downloadDate,
  }) {
    // 空模板表示不创建额外子目录。
    if (settings.folderTemplate.trim().isEmpty) return '';
    // 变量值先清理路径分隔符，只有用户模板中的分隔符能创建层级。
    return renderFileNamingTemplate(
      settings.folderTemplate,
      _createNamingValues(
        media: media,
        episode: episode,
        audioQuality: audioQuality,
        videoQuality: videoQuality,
        sanitizeForFolder: true,
        downloadDate: downloadDate,
      ),
    );
  }

  /// 创建文件名和文件夹预览共用的变量值。
  FileNamingValues _createNamingValues({
    required BiliMediaInfo media,
    required BiliEpisodeInfo episode,
    required String videoQuality,
    required String audioQuality,
    required bool sanitizeForFolder,
    DateTime? downloadDate,
  }) {
    // 同步旧任务时保持原创建日期，新任务则使用当前本地时间。
    final effectiveDownloadDate = downloadDate ?? DateTime.now();
    // 分集发布时间优先于合集发布时间，缺失时使用下载日期避免空值。
    final publishDate =
        episode.publishedAt ?? media.publishedAt ?? effectiveDownloadDate;
    // 文件夹变量必须清除外部标题中的路径分隔符。
    String normalize(String value) =>
        sanitizeForFolder ? safeFileName(value) : value;
    // 返回完整变量快照。
    return FileNamingValues(
      title: normalize(episode.title),
      collectionTitle: normalize(media.title),
      publisherName: normalize(media.publisherName ?? '未知UP主'),
      publisherId: media.publisherId ?? 0,
      audioQuality: normalize(audioQuality),
      videoQuality: normalize(videoQuality),
      videoType: _videoTypeLabel(media, episode),
      bvid: episode.bvid,
      cid: episode.cid,
      downloadDate: effectiveDownloadDate,
      publishDate: publishDate,
      index: episode.index,
    );
  }

  /// 将内容类型和分集数量转换为文件夹变量使用的短文案。
  String _videoTypeLabel(BiliMediaInfo media, BiliEpisodeInfo episode) {
    // PGC 内容统一标记为番剧分集。
    if (episode.contentType == BiliContentType.pgc) return '番剧分集';
    // 多个普通视频分集标记为合集分集。
    if (media.episodes.length > 1) return '合集分集';
    // 单个 UGC 分集标记为普通视频。
    return '普通视频';
  }

  /// 把用户模板渲染结果转换为不能越出下载根目录的相对路径。
  String safeRelativeFolderPath(String value) {
    // 同时接受 Windows 和 Unix 分隔符，便于配置跨平台同步。
    final rawSegments = value.split(RegExp(r'[\\/]+'));
    // 清理每层目录并移除空值、当前目录和父目录跳转。
    final safeSegments = rawSegments
        .map((String segment) => segment.trim())
        .where(
          (String segment) =>
              segment.isNotEmpty && segment != '.' && segment != '..',
        )
        .map(safeFileName)
        .where((String segment) => segment.isNotEmpty)
        .toList(growable: false);
    // 没有有效目录段时保持下载根目录。
    if (safeSegments.isEmpty) return '';
    // 使用当前系统分隔符拼接安全相对路径。
    return p.joinAll(safeSegments);
  }

  /// 清理 Windows、macOS 和 Linux 都不安全的文件名字符。
  String safeFileName(String value) {
    // 统一策略同时处理非法字符、Windows 设备名和多字节标题长度。
    return sanitizeOutputPathSegment(value);
  }
}
