import 'dart:collection';

import 'package:flutter/foundation.dart';

/// 统一输出仅供开发阶段诊断的下载与媒体处理日志。
abstract final class AppDebugLog {
  /// 内存环形缓冲最多保留最近一千条脱敏记录，避免长期下载无限增长。
  static const int _maximumEntries = 1000;

  /// 所有构建模式都可导出的脱敏日志环形缓冲。
  static final ListQueue<String> _entries = ListQueue<String>();

  /// 输出带 aria2 分类前缀的 Debug 日志。
  static void aria2(String message) {
    // 所有构建都保留脱敏内存记录，只有 Debug 额外写控制台。
    _write('aria2', message);
  }

  /// 输出应用生命周期、路由和恢复流程相关日志。
  static void app(String message) {
    // 应用级日志不绑定下载后端，避免诊断时被误判为 aria2 问题。
    _write('app', message);
  }

  /// 输出账号登录、退出和会话失效相关日志。
  static void account(String message) {
    // 账号日志禁止写入 Cookie，只记录阶段、结果和脱敏错误。
    _write('account', message);
  }

  /// 输出缓存清理和应用本地数据维护日志。
  static void cache(String message) {
    // 缓存日志只记录大小与操作结果，避免输出具体文件名。
    _write('cache', message);
  }

  /// 输出数据库打开、迁移和恢复相关日志。
  static void database(String message) {
    // 数据库路径会经过统一脱敏，记录迁移和损坏恢复便于定位启动问题。
    _write('database', message);
  }

  /// 输出下载任务页操作和下载业务状态日志。
  static void download(String message) {
    // 下载业务日志记录任务数量和阶段，具体底层 RPC 仍由 aria2 分类记录。
    _write('download', message);
  }

  /// 输出带 FFmpeg 分类前缀的 Debug 日志。
  static void ffmpeg(String message) {
    // Release 不写控制台，但用户仍可主动导出脱敏诊断记录。
    _write('ffmpeg', message);
  }

  /// 输出首次引导流程日志。
  static void onboarding(String message) {
    // 引导只记录完成标记写入结果，不记录任何用户输入。
    _write('onboarding', message);
  }

  /// 输出解析页和解析历史相关日志。
  static void parser(String message) {
    // 解析日志只记录目标类型、分集数量和错误，不保存原始链接。
    _write('parser', message);
  }

  /// 输出系统通知相关日志。
  static void notification(String message) {
    // 通知失败不会中断下载，但用户导出诊断时需要看到平台错误。
    _write('notification', message);
  }

  /// 输出短提示音播放相关日志。
  static void sound(String message) {
    // 声音播放属于可降级体验问题，仍进入脱敏诊断方便排查设备兼容性。
    _write('sound', message);
  }

  /// 输出设置保存、目录选择和诊断导出相关日志。
  static void settings(String message) {
    // 设置日志记录操作结果，具体路径和错误会被统一脱敏。
    _write('settings', message);
  }

  /// 输出用户中心历史、稿件、收藏和点赞列表相关日志。
  static void user(String message) {
    // 用户中心日志只记录来源和数量，不记录视频标题。
    _write('user', message);
  }

  /// 返回不包含查询参数、Cookie 或签名信息的媒体地址摘要。
  static String safeUri(Uri uri) {
    // 只保留协议和主机，避免短期 CDN 查询参数出现在截图或日志中。
    return '${uri.scheme}://${uri.host}/<redacted>';
  }

  /// 对日志添加固定分类前缀并清除常见敏感文本。
  static void _write(String scope, String message) {
    final sanitized = sanitize(message);
    // UTC ISO 时间便于跨时区排查，同时不暴露设备区域设置。
    final entry =
        '${DateTime.now().toUtc().toIso8601String()} '
        '[BiliDown][$scope] $sanitized';
    _entries.addLast(entry);
    // 超过上限时只移除最旧记录，保留最近错误上下文。
    while (_entries.length > _maximumEntries) {
      _entries.removeFirst();
    }
    // Debug 控制台便于开发，Release 仅在用户主动导出时产生文件。
    if (kDebugMode) debugPrint(entry);
  }

  /// 清除 URL、凭据、IP 和用户本地绝对路径等常见敏感文本。
  static String sanitize(String message) {
    // 先处理完整 URL，防止查询参数中的令牌逃过后续键值规则。
    return message
        .replaceAll(RegExp(r'https?://\S+'), '<redacted-url>')
        .replaceAll(
          RegExp(
            r'\b(SESSDATA|bili_jct|refresh_token|access_key|cookie|token)\s*[:=]\s*[^\s,;\]\}]+',
            caseSensitive: false,
          ),
          '<redacted-credential>',
        )
        // Windows 用户目录和任意绝对路径不能进入用户可分享文件。
        .replaceAll(
          RegExp(r'\b[A-Za-z]:\\[^\s,;\]\}]+'),
          '<redacted-local-path>',
        )
        // macOS、Linux、Android 常见用户数据根目录统一隐藏。
        .replaceAll(
          RegExp(r'/(Users|home|data/user|storage/emulated)/[^\s,;\]\}]+'),
          '<redacted-local-path>',
        )
        // 网络诊断不需要保存用户公网或局域网 IPv4 地址。
        .replaceAll(RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'), '<redacted-ip>');
  }

  /// 生成带格式说明的当前脱敏日志文本快照。
  static String exportText() {
    // 文档头明确日志已经脱敏且只包含本进程最近记录。
    return <String>[
      '# BiliDown diagnostic log',
      '# Generated: ${DateTime.now().toUtc().toIso8601String()}',
      '# Sensitive credentials, URLs, IP addresses and local paths are redacted.',
      ..._entries,
      '',
    ].join('\n');
  }

  /// 测试或新会话开始时清空内存日志。
  static void clear() => _entries.clear();
}
