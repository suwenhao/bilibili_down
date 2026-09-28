import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/app_settings_controller.dart';
import '../../settings/domain/app_settings.dart';

/// 从剪贴板文本提取受支持的 B 站输入候选。
String? extractBiliClipboardCandidate(String text) {
  // 限制扫描长度，避免异常大剪贴板造成不必要的正则开销。
  final input = text.trim().length > 8192
      ? text.trim().substring(0, 8192)
      : text.trim();
  if (input.isEmpty) return null;
  // 优先查找分享文案中的 HTTP 链接，保留短链供正常解析器展开。
  final urlPattern = RegExp(r'https?://\S+', caseSensitive: false);
  // 出现链接但域名不受信任时不能再从该链接文本中提取伪造 BVID。
  var sawUrl = false;
  for (final match in urlPattern.allMatches(input)) {
    // 记录存在 URL，全部 URL 均不受信任时直接拒绝整段内容。
    sawUrl = true;
    // 分享文案末尾标点不属于 URL，先清理再校验域名。
    final candidate = match
        .group(0)!
        .replaceFirst(RegExp(r'[)\]}>）】》」』，。！？；、"]+$'), '');
    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.isEmpty) continue;
    // 只接受 B 站正式域名和 b23.tv 短链，拒绝相似钓鱼域名。
    final host = uri.host.toLowerCase();
    if (host == 'b23.tv' ||
        host == 'bilibili.com' ||
        host == 'www.bilibili.com' ||
        host == 'm.bilibili.com') {
      return candidate;
    }
  }
  // 含有非白名单链接的文本不能回退为纯标识解析，避免钓鱼链接触发提示。
  if (sawUrl) return null;
  // 没有链接时允许从纯文本中提取标准 BV、AV、EP、SS 标识。
  final identifier = RegExp(
    r'\b(BV1[0-9A-Za-z]{9}|av\d+|ep\d+|ss\d+)\b',
    caseSensitive: false,
  ).firstMatch(input);
  // 返回规范前缀，主体字符保留原值交给统一解析器校验。
  final value = identifier?.group(1);
  if (value == null) return null;
  if (value.toLowerCase().startsWith('bv')) return 'BV${value.substring(2)}';
  return value.toLowerCase();
}

/// 剪贴板识别后等待根组件消费的解析建议。
final class ClipboardParseSuggestion {
  /// 创建一个可自动写入解析页的候选建议。
  const ClipboardParseSuggestion(this.input);

  /// 将写入解析页输入框的标准链接或标识。
  final String input;
}

/// 监听设置并管理跨平台剪贴板解析提示。
final clipboardMonitorControllerProvider =
    NotifierProvider<ClipboardMonitorController, ClipboardParseSuggestion?>(
      ClipboardMonitorController.new,
    );

/// 在用户开启后按平台限制检查剪贴板，去重产生 B 站自动解析建议。
final class ClipboardMonitorController
    extends Notifier<ClipboardParseSuggestion?> {
  /// 桌面剪贴板轮询间隔，兼顾响应速度和平台通道开销。
  static const Duration pollInterval = Duration(seconds: 2);

  /// 唯一周期计时器，设置关闭时立即释放。
  Timer? _timer;

  /// 移动端生命周期监听器，只在回到前台时主动读取一次。
  AppLifecycleListener? _lifecycleListener;

  /// 最近一次已经检查的候选，用于避免相同内容重复提示。
  String? _lastObservedCandidate;

  /// 是否已有平台通道读取正在执行，防止慢调用重叠。
  bool _polling = false;

  /// 当前设置是否允许应用读取剪贴板。
  bool _enabled = false;

  /// 创建空提示并根据持久化设置启停监听。
  @override
  ClipboardParseSuggestion? build() {
    // 设置恢复或用户切换时同步更新监听生命周期。
    ref.listen<AppSettings>(appSettingsControllerProvider, (
      AppSettings? previous,
      AppSettings next,
    ) {
      _applyEnabledSetting(next);
    }, fireImmediately: true);
    // Provider 销毁时停止轮询和生命周期回调，避免后台继续读取剪贴板。
    ref.onDispose(() {
      _timer?.cancel();
      _lifecycleListener?.dispose();
    });
    return null;
  }

  /// 根组件消费候选并返回输入，同时关闭当前建议。
  String? accept() {
    // 先保存输入，再清空状态以避免同一候选重复触发跳转。
    final input = state?.input;
    state = null;
    return input;
  }

  /// 解析页进入前台时触发一次移动端剪贴板检查。
  void checkOnParserPageVisible() {
    // 解析页可见属于用户明确进入输入场景，移动端允许进行一次前台读取。
    if (!_isMobile) return;
    unawaited(_poll());
  }

  /// 根据设置和平台能力启动或停止剪贴板监听。
  void _applyEnabledSetting(AppSettings settings) {
    // 设置集合决定用户是否明确授权应用读取剪贴板。
    final enabled = settings.downloadContents.contains(
      DownloadContentOption.monitorClipboard,
    );
    // 保存当前授权状态，供解析页手动触发和迟到轮询统一判断。
    _enabled = enabled;
    if (!enabled) {
      // 关闭设置后停止计时并移除尚未处理的提示。
      _timer?.cancel();
      _timer = null;
      _lifecycleListener?.dispose();
      _lifecycleListener = null;
      state = null;
      return;
    }
    if (_isDesktop) {
      // 桌面允许低频前台轮询，保持原有复制后自动出现提示的体验。
      _ensureDesktopPolling();
      return;
    }
    if (_isMobile) {
      // 移动端系统限制后台读取，只在启用、回前台或进入解析页时读一次。
      _stopDesktopPolling();
      _ensureMobileLifecycleListener();
      unawaited(_poll());
      return;
    }
    // 其他平台没有明确支持策略时关闭提示，避免误读剪贴板。
    _stopDesktopPolling();
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    state = null;
  }

  /// 桌面平台是否支持安全轮询剪贴板。
  bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// 移动平台只能在前台用户场景下读取剪贴板。
  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  /// 启动桌面低频轮询。
  void _ensureDesktopPolling() {
    // 桌面模式不需要移动生命周期监听，切换设置时先释放。
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    // 已经监听时不重复创建计时器。
    if (_timer != null) return;
    // 开启后立即检查一次，随后低频轮询剪贴板变化。
    unawaited(_poll());
    _timer = Timer.periodic(pollInterval, (_) => unawaited(_poll()));
  }

  /// 停止桌面轮询计时器。
  void _stopDesktopPolling() {
    // 移动端不能沿用桌面轮询，必须明确关闭周期读取。
    _timer?.cancel();
    _timer = null;
  }

  /// 为移动端注册回到前台时的一次性读取触发。
  void _ensureMobileLifecycleListener() {
    // 生命周期监听器只需要创建一次，重复设置不应叠加回调。
    if (_lifecycleListener != null) return;
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        // 用户回到应用前台后读取一次，候选由根组件统一决定是否跳转解析。
        unawaited(_poll());
      },
    );
  }

  /// 读取纯文本剪贴板并在发现新候选时发布提示。
  Future<void> _poll() async {
    // 设置关闭后即使有迟到生命周期回调也不能读取系统剪贴板。
    if (!_enabled) return;
    // 平台通道尚未返回时跳过本轮，避免堆积读取请求。
    if (_polling) return;
    _polling = true;
    try {
      // 只读取纯文本格式，图片和文件剪贴板不属于解析范围。
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      // 识别逻辑不发网络请求，短链接只在解析页实际解析时才展开。
      final candidate = extractBiliClipboardCandidate(data?.text ?? '');
      // 无候选时记录空变化，下一次复制相同旧链接仍可重新提示。
      if (candidate == null) {
        _lastObservedCandidate = null;
        return;
      }
      // 剪贴板未变化时不重复提示，也不覆盖用户已忽略的决定。
      if (candidate == _lastObservedCandidate) return;
      _lastObservedCandidate = candidate;
      // 发布建议后由根组件跳转解析页，不在监听层直接发起网络请求。
      state = ClipboardParseSuggestion(candidate);
    } on PlatformException {
      // 剪贴板暂时被其他程序占用时跳过本轮，下个周期自动重试。
    } finally {
      // 无论读取结果如何都允许下一周期继续检查。
      _polling = false;
    }
  }
}
