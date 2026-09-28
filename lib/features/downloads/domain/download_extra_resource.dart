import 'dart:convert';

/// “更多”菜单支持单独下载的附加资源。
enum DownloadExtraResource {
  /// 视频封面原图。
  cover,

  /// 当前任务选中的音频流。
  audio,

  /// B 站原始 XML 弹幕。
  danmakuXml,

  /// 从 XML 弹幕转换得到的 ASS 弹幕。
  danmakuAss,

  /// 当前视频提供的人工字幕轨道。
  subtitles,

  /// B 站播放器已生成的 AI 字幕轨道。
  aiSubtitles,
}

/// 附加资源写入任务记录时使用的稳定前缀。
const downloadExtraResourcePrefix = 'resource.';

/// 把附加资源转换为任务记录中的稳定内容类型。
String downloadExtraResourceCode(
  DownloadExtraResource resource, {
  String? variant,
}) {
  // 字幕语言等变体追加在稳定资源名后，旧版本仍可识别冒号前的基础类型。
  final normalizedVariant = variant?.trim();
  return '$downloadExtraResourcePrefix${resource.name}'
      '${normalizedVariant == null || normalizedVariant.isEmpty ? '' : ':$normalizedVariant'}';
}

/// 从任务内容类型恢复附加资源类型。
DownloadExtraResource? downloadExtraResourceFromCode(String? code) {
  // 普通 UGC、PGC 和旧任务没有资源前缀。
  if (code == null || !code.startsWith(downloadExtraResourcePrefix)) {
    return null;
  }
  // 去除前缀后按稳定枚举名称匹配。
  final name = code
      .substring(downloadExtraResourcePrefix.length)
      .split(':')
      .first;
  for (final resource in DownloadExtraResource.values) {
    // 命中后返回对应资源类型。
    if (resource.name == name) return resource;
  }
  // 未知新类型由旧版本安全忽略。
  return null;
}

/// 从任务内容类型恢复字幕语言等资源变体。
String? downloadExtraResourceVariantFromCode(String? code) {
  // 普通任务或旧资源任务没有冒号变体。
  if (code == null || !code.startsWith(downloadExtraResourcePrefix)) {
    return null;
  }
  final resourceCode = code.substring(downloadExtraResourcePrefix.length);
  final separatorIndex = resourceCode.indexOf(':');
  if (separatorIndex < 0 || separatorIndex + 1 >= resourceCode.length) {
    return null;
  }
  // 返回稳定语言代码，显示名称仍由播放器轨道元数据提供。
  return resourceCode.substring(separatorIndex + 1);
}

/// 返回附加资源在任务卡和菜单中的中文名称。
String downloadExtraResourceLabel(DownloadExtraResource resource) =>
    switch (resource) {
      DownloadExtraResource.cover => '封面',
      DownloadExtraResource.audio => '音频',
      DownloadExtraResource.danmakuXml => 'XML弹幕',
      DownloadExtraResource.danmakuAss => 'ASS弹幕',
      DownloadExtraResource.subtitles => '字幕',
      DownloadExtraResource.aiSubtitles => 'AI 字幕',
    };

/// 把主任务勾选的附加资源编码成稳定 JSON 字符串数组。
String encodeDownloadExtraResources(Iterable<DownloadExtraResource> resources) {
  // 按领域枚举顺序去重，保证相同选择产生一致 JSON，便于测试和变更判断。
  final selected = resources.toSet();
  final names = DownloadExtraResource.values
      .where(selected.contains)
      .map((DownloadExtraResource resource) => resource.name)
      .toList(growable: false);
  // JSON 数组只保存稳定枚举名，不保存界面文案或短期下载地址。
  return jsonEncode(names);
}

/// 从主任务 JSON 数组恢复当前版本认识的附加资源集合。
Set<DownloadExtraResource> decodeDownloadExtraResources(String? json) {
  // 空值和空字符串兼容新增字段之前的普通视频任务。
  if (json == null || json.trim().isEmpty) return <DownloadExtraResource>{};
  try {
    // 非数组或损坏 JSON 按无选择处理，不能阻止任务列表加载。
    final decoded = jsonDecode(json);
    if (decoded is! List) return <DownloadExtraResource>{};
    // 仅接受当前枚举中的字符串名称，未来版本字段由旧版本安全忽略。
    final names = decoded.whereType<String>().toSet();
    return DownloadExtraResource.values
        .where(
          (DownloadExtraResource resource) => names.contains(resource.name),
        )
        .toSet();
  } on FormatException {
    // 用户数据库中的损坏值保持可恢复，界面显示为未选择附加资源。
    return <DownloadExtraResource>{};
  }
}
