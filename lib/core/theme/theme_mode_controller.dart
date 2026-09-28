import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 保存并恢复应用主题模式。
final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

/// 管理跟随系统、亮色和暗色三种主题状态。
final class ThemeModeController extends Notifier<ThemeMode> {
  /// SharedPreferences 中保存主题名称的键。
  static const String _storageKey = 'appearance.theme_mode';

  /// 用户主动切换次数，用于阻止较晚完成的恢复覆盖新选择。
  int _changeRevision = 0;

  /// 创建默认主题并异步恢复用户选择。
  @override
  ThemeMode build() {
    // 恢复过程不阻塞首帧，初始使用跟随系统模式。
    unawaited(_restore());
    // 未保存设置时遵循操作系统亮暗主题。
    return ThemeMode.system;
  }

  /// 保存并立即应用新的主题模式。
  Future<void> setThemeMode(ThemeMode mode) async {
    // 用户每次主动切换都增加修订号，使旧恢复结果失效。
    _changeRevision++;
    // 先更新内存状态，让界面立即切换。
    state = mode;
    // SharedPreferences 只保存非敏感主题设置。
    final preferences = await SharedPreferences.getInstance();
    // 使用枚举名称保存稳定文本，避免依赖枚举序号。
    await preferences.setString(_storageKey, mode.name);
  }

  /// 从本地设置恢复主题模式。
  Future<void> _restore() async {
    // 记录恢复开始时的修订号。
    final startedRevision = _changeRevision;
    // 获取跨平台偏好设置实例。
    final preferences = await SharedPreferences.getInstance();
    // 读取上次保存的枚举名称。
    final savedName = preferences.getString(_storageKey);
    // 恢复期间用户已经切换主题时不再覆盖当前选择。
    if (startedRevision != _changeRevision) return;
    // 没有保存值时保留跟随系统默认值。
    if (savedName == null) return;
    // 查找能够匹配当前版本枚举的主题模式。
    for (final mode in ThemeMode.values) {
      if (mode.name == savedName) {
        // 找到有效值后更新应用主题并结束循环。
        state = mode;
        return;
      }
    }
  }
}
