import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/application/app_settings_controller.dart';
import '../logging/app_debug_log.dart';

/// 应用支持的三类短提示音。
enum AppSoundEffect { tap, success, error }

/// 提供全应用唯一的短音效播放器集合。
final appSoundServiceProvider = Provider<AppSoundService>((Ref ref) {
  // 播放瞬间按音效类型读取独立开关，设置变化后无需重建播放器。
  final service = AppSoundService((AppSoundEffect effect) {
    // 获取当前设置快照，保证快速切换后立即应用最新值。
    final settings = ref.read(appSettingsControllerProvider);
    // tap 仅受按钮提示音控制，成功和错误继续受系统提示音控制。
    return effect == AppSoundEffect.tap
        ? settings.tapSoundEnabled
        : settings.systemSoundEnabled;
  });
  // Provider 销毁时释放全部原生音频资源。
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

/// 使用独立播放器播放按钮、成功和错误音，避免状态音被按钮音打断。
final class AppSoundService {
  /// 创建音效服务并注入按音效类型读取的实时开关。
  AppSoundService(this._isEnabled);

  /// tap.wav 使用的独立起播位置。
  static const Duration _tapStartPosition = Duration.zero;

  /// 每次播放前读取当前音效对应开关的最新值。
  final bool Function(AppSoundEffect effect) _isEnabled;

  /// 每种音效使用独立播放器，允许状态音与按钮音自然重叠。
  final Map<AppSoundEffect, AudioPlayer> _players =
      <AppSoundEffect, AudioPlayer>{
        for (final effect in AppSoundEffect.values) effect: AudioPlayer(),
      };

  /// 同种音效串行停止并重播，避免快速点击导致异步调用乱序。
  final Map<AppSoundEffect, Future<void>> _playQueues =
      <AppSoundEffect, Future<void>>{
        for (final effect in AppSoundEffect.values)
          effect: Future<void>.value(),
      };

  /// 请求播放指定音效；播放失败只跳过声音，不能中断业务操作。
  void play(AppSoundEffect effect) {
    // 当前音效对应开关关闭时不触碰平台播放器。
    if (!_isEnabled(effect)) return;
    // 把同种音效接到已有播放任务之后，确保快速点击始终从头播放。
    _playQueues[effect] = _playQueues[effect]!
        .then((_) => _restart(effect))
        .catchError((Object error, StackTrace stackTrace) {
          // 音频设备或平台插件异常不应影响按钮和下载状态机，但需留下诊断信息。
          AppDebugLog.sound('播放 ${effect.name} 失败: $error');
        });
  }

  /// 停止同种旧声音并从资源开头播放。
  Future<void> _restart(AppSoundEffect effect) async {
    // 播放排队期间用户可能关闭对应提示音，需要再次校验最新设置。
    if (!_isEnabled(effect)) return;
    // 获取该音效专属播放器。
    final player = _players[effect]!;
    // 重复点击时先停止旧实例，保证短 tap 音反馈清晰。
    await player.stop();
    // AssetSource 路径相对 pubspec 中声明的 assets 根目录；仅点击音使用独立起播位置。
    await player.play(
      AssetSource('sounds/${effect.name}.wav'),
      position: effect == AppSoundEffect.tap ? _tapStartPosition : null,
    );
  }

  /// 等待未完成播放操作并释放全部平台播放器。
  Future<void> dispose() async {
    // 先等待每种音效的串行队列收尾，避免释放后仍调用原生播放器。
    await Future.wait<void>(_playQueues.values);
    // 三个播放器可以并行释放，缩短应用关闭等待时间。
    await Future.wait<void>(
      _players.values.map((AudioPlayer player) => player.dispose()),
    );
  }
}
