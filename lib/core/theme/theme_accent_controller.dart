import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题色明暗滑块的中性值，保持品牌原始色不变。
const double defaultThemeAccentBrightness = 0.5;

/// 按滑块位置将不透明主题色稳定地调暗或调亮。
Color adjustThemeAccentBrightness(Color color, double level) {
  // 外部恢复值先限制在滑块范围，避免旧设置或损坏数据产生非法颜色。
  final normalizedLevel = level.clamp(0.0, 1.0);
  // 中点必须原样返回品牌色，保证默认设置与历史视觉完全一致。
  if (normalizedLevel == defaultThemeAccentBrightness) return color;
  // 两端最多混合 65% 黑白色，保留原主题色辨识度并维持完全不透明。
  final blendAmount =
      (normalizedLevel - defaultThemeAccentBrightness).abs() * 1.3;
  // 左半段向黑色混合，右半段向白色混合，实现确定的暗到亮方向。
  final target = normalizedLevel < defaultThemeAccentBrightness
      ? Colors.black
      : Colors.white;
  return Color.lerp(color, target, blendAmount)!;
}

/// 应用可选的知名软件品牌主题色。
enum ThemeAccent {
  original('BiliDown 默认绿', 0xFF3F9E6E, darkArgb: 0xFF56B887),
  bilibili('哔哩哔哩粉', 0xFFFB7299),
  taobao('淘宝红', 0xFFFF5000),
  alipay('支付宝蓝', 0xFF1677FF),
  wechat('微信绿', 0xFF07C160),
  jd('京东红', 0xFFE2231A),
  weibo('微博橙', 0xFFFF8200),
  qq('QQ 蓝', 0xFF12B7F5),
  douyin('抖音红', 0xFFFE2C55),
  xiaohongshu('小红书红', 0xFFFF2442),
  spotify('Spotify 绿', 0xFF1ED760),
  youtube('YouTube 红', 0xFFFF0000),
  netflix('Netflix 红', 0xFFE50914),
  discord('Discord 紫', 0xFF5865F2),
  telegram('Telegram 蓝', 0xFF229ED9);

  /// 创建一个带展示名称和 ARGB 色值的主题色选项。
  const ThemeAccent(this.label, this.argb, {int? darkArgb})
    : darkArgb = darkArgb ?? argb;

  /// 设置页显示的品牌颜色名称。
  final String label;

  /// 用于稳定持久化与构造 Flutter Color 的完整 ARGB 色值。
  final int argb;

  /// 暗色模式使用的 ARGB 色值；普通品牌色与亮色保持一致。
  final int darkArgb;

  /// 返回供主题和色块使用的 Flutter 颜色。
  Color get color => Color(argb);

  /// 返回暗色模式实际使用的主题色。
  Color get darkColor => Color(darkArgb);

  /// 根据当前亮暗模式返回界面实际生效的主题色。
  Color colorFor(Brightness brightness) {
    // 原始主题在暗色模式使用历史高对比绿色，其余选项保持品牌原色。
    return brightness == Brightness.dark ? darkColor : color;
  }

  /// 返回在当前主题色上对比度更高的黑色或白色前景。
  Color get foregroundColor => color.computeLuminance() > 0.179
      ? const Color(0xFF000000)
      : const Color(0xFFFFFFFF);

  /// 返回指定亮暗模式主题色上对比度更高的黑色或白色前景。
  Color foregroundColorFor(Brightness brightness) {
    // 依据实际生效颜色计算前景，避免默认绿在暗色模式沿用亮色判断。
    return colorFor(brightness).computeLuminance() > 0.179
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
  }

  /// 返回设置菜单显示的六位十六进制色值。
  String get hex =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// 返回指定亮暗模式下实际生效颜色的六位十六进制值。
  String hexFor(Brightness brightness) {
    // 色值来源于当前模式对应的 ARGB，设置菜单展示结果与界面保持一致。
    final activeArgb = colorFor(brightness).toARGB32();
    return '#${(activeArgb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

/// 保存并恢复全局品牌主题色。
final themeAccentControllerProvider =
    NotifierProvider<ThemeAccentController, ThemeAccent>(
      ThemeAccentController.new,
    );

/// 保存并恢复主题色明暗级别。
final themeAccentBrightnessControllerProvider =
    NotifierProvider<ThemeAccentBrightnessController, double>(
      ThemeAccentBrightnessController.new,
    );

/// 管理主题色明暗的即时预览与延迟持久化。
final class ThemeAccentBrightnessController extends Notifier<double> {
  /// SharedPreferences 中保存主题色明暗级别的键。
  static const String _storageKey = 'appearance.theme_accent_brightness';

  /// 用户主动调整次数，用于阻止异步恢复覆盖较新的滑块值。
  int _changeRevision = 0;

  /// 合并连续拖动产生的高频偏好设置写入。
  Timer? _persistTimer;

  /// 创建保持原品牌色的中性明暗值并异步恢复上次设置。
  @override
  double build() {
    // Provider 销毁时取消尚未执行的延迟写入，避免生命周期结束后继续回调。
    ref.onDispose(() => _persistTimer?.cancel());
    // 恢复不阻塞首帧，应用先使用不会改变原色的中点。
    unawaited(_restore());
    return defaultThemeAccentBrightness;
  }

  /// 即时应用滑块值，并在用户停止拖动后写入本地偏好。
  void setBrightness(double value) {
    // 滑块值限制在零到一之间，状态含义为从最暗到最亮。
    final normalizedValue = value.clamp(0.0, 1.0);
    _changeRevision++;
    state = normalizedValue;
    // 连续拖动只保留最后一次写入，减少平台通道和磁盘压力。
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 180), () async {
      // 明暗值属于非敏感外观设置，通过跨平台偏好设置持久化。
      final preferences = await SharedPreferences.getInstance();
      await preferences.setDouble(_storageKey, normalizedValue);
    });
  }

  /// 从本地偏好设置恢复有效的主题色明暗值。
  Future<void> _restore() async {
    // 记录恢复开始时的用户调整版本，防止慢读取覆盖新操作。
    final startedRevision = _changeRevision;
    // 读取此前保存的零到一范围明暗级别。
    final preferences = await SharedPreferences.getInstance();
    final savedValue = preferences.getDouble(_storageKey);
    // 没有历史值或恢复期间用户已操作时继续保留当前状态。
    if (savedValue == null || startedRevision != _changeRevision) return;
    // 损坏或旧版本越界值安全收敛到滑块范围。
    state = savedValue.clamp(0.0, 1.0);
  }
}

/// 管理主题色即时切换和本地持久化。
final class ThemeAccentController extends Notifier<ThemeAccent> {
  /// SharedPreferences 中保存主题色枚举名称的键。
  static const String _storageKey = 'appearance.theme_accent';

  /// 用户主动选择次数，用于阻止异步恢复覆盖较新的选择。
  int _changeRevision = 0;

  /// 创建应用原始绿色主题并异步恢复用户上次选择。
  @override
  ThemeAccent build() {
    // 恢复不阻塞首帧，避免启动时等待平台偏好设置通道。
    unawaited(_restore());
    // 首次安装恢复多主题功能上线前的原始亮暗绿色。
    return ThemeAccent.original;
  }

  /// 立即应用并持久化新的品牌主题色。
  Future<void> setThemeAccent(ThemeAccent accent) async {
    // 用户选择后使尚未完成的旧恢复结果失效。
    _changeRevision++;
    // 先更新内存状态，让整个 MaterialApp 即时换色。
    state = accent;
    // 主题色属于非敏感外观设置，保存在跨平台偏好设置中。
    final preferences = await SharedPreferences.getInstance();
    // 保存稳定的枚举名称，避免以后调整选项顺序破坏已有设置。
    await preferences.setString(_storageKey, accent.name);
  }

  /// 从本地偏好设置恢复上次选择的有效主题色。
  Future<void> _restore() async {
    // 记录恢复开始时的用户选择修订号。
    final startedRevision = _changeRevision;
    // 通过平台偏好设置读取已保存的主题色名称。
    final preferences = await SharedPreferences.getInstance();
    // 空值表示首次使用，继续保留 BiliDown 原始默认绿。
    final savedName = preferences.getString(_storageKey);
    // 恢复期间发生用户选择时必须保留用户最新操作。
    if (startedRevision != _changeRevision || savedName == null) return;
    // 只接受当前版本仍存在的枚举值，未知旧值安全回退默认色。
    for (final accent in ThemeAccent.values) {
      if (accent.name == savedName) {
        // 找到有效选项后更新全局主题并结束恢复。
        state = accent;
        return;
      }
    }
  }
}
