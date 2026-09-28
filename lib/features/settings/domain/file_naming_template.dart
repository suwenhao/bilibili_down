/// 命名模板渲染时需要的一条视频真实数据。
final class FileNamingValues {
  /// 创建完整命名变量快照。
  const FileNamingValues({
    required this.title,
    required this.collectionTitle,
    required this.publisherName,
    required this.publisherId,
    required this.audioQuality,
    required this.videoQuality,
    required this.videoType,
    required this.bvid,
    required this.cid,
    required this.downloadDate,
    required this.publishDate,
    required this.index,
  });

  /// 当前分集标题。
  final String title;

  /// 合集或季度标题，兼容旧版模板。
  final String collectionTitle;

  /// UP 主昵称。
  final String publisherName;

  /// UP 主数字 ID。
  final int publisherId;

  /// 实际选择的音质和编码说明。
  final String audioQuality;

  /// 实际选择的画质和编码说明。
  final String videoQuality;

  /// 普通视频、合集分集或番剧分集类型说明。
  final String videoType;

  /// 当前分集 BVID。
  final String bvid;

  /// 当前分集 CID。
  final int cid;

  /// 创建下载任务的本地时间。
  final DateTime downloadDate;

  /// 视频或分集发布时间。
  final DateTime publishDate;

  /// 当前分集的一开始序号。
  final int index;
}

/// 使用设置中心支持的稳定变量渲染文件名模板。
String renderFileNamingTemplate(String template, FileNamingValues values) {
  // 同时支持参考软件变量与早期 BiliDown 已保存变量。
  return template
      .replaceAll('%upnn-uid%', '${values.publisherName}-${values.publisherId}')
      .replaceAll('%uid-upnn%', '${values.publisherId}-${values.publisherName}')
      .replaceAll('%title%', values.title)
      .replaceAll('%collection%', values.collectionTitle)
      .replaceAll('%upnn%', values.publisherName)
      .replaceAll('%uid%', values.publisherId.toString())
      .replaceAll('%aqn%', values.audioQuality)
      .replaceAll('%vqn%', values.videoQuality)
      .replaceAll('%vtype%', values.videoType)
      .replaceAll('%bvid%', values.bvid)
      .replaceAll('%bv%', values.bvid)
      .replaceAll('%cid%', values.cid.toString())
      .replaceAll('%dd:YYYYMMDD%', _compactDate(values.downloadDate))
      .replaceAll('%dd:YYYY%', values.downloadDate.year.toString())
      .replaceAll(
        '%dd:MM%',
        values.downloadDate.month.toString().padLeft(2, '0'),
      )
      .replaceAll('%dd:DD%', values.downloadDate.day.toString().padLeft(2, '0'))
      .replaceAll('%dd%', _compactDate(values.downloadDate))
      .replaceAll('%pd:YYYYMMDD%', _compactDate(values.publishDate))
      .replaceAll('%pd:YYYY%', values.publishDate.year.toString())
      .replaceAll(
        '%pd:MM%',
        values.publishDate.month.toString().padLeft(2, '0'),
      )
      .replaceAll('%pd:DD%', values.publishDate.day.toString().padLeft(2, '0'))
      .replaceAll('%pd%', _compactDate(values.publishDate))
      .replaceAll(
        '%index:00%',
        (values.index - 1).clamp(0, 9999).toString().padLeft(2, '0'),
      )
      .replaceAll(
        '%index:01%',
        values.index.clamp(1, 9999).toString().padLeft(2, '0'),
      )
      .replaceAll('%index:0%', (values.index - 1).clamp(0, 9999).toString())
      .replaceAll('%index%', values.index.toString());
}

/// 将日期转换为命名模板使用的八位数字格式。
String _compactDate(DateTime value) {
  // 月份固定两位。
  final month = value.month.toString().padLeft(2, '0');
  // 日期固定两位。
  final day = value.day.toString().padLeft(2, '0');
  // 返回 YYYYMMDD 格式。
  return '${value.year}$month$day';
}
