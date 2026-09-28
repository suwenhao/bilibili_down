/// 设置页中长耗时操作的忙碌状态。
final class SettingsPageState {
  /// 创建设置页动作状态。
  const SettingsPageState({
    required this.choosingDirectory,
    required this.resettingDirectory,
    required this.clearingCache,
    required this.exportingDiagnosticLog,
  });

  /// 初始状态没有任何页面动作进行中。
  factory SettingsPageState.initial() {
    return const SettingsPageState(
      choosingDirectory: false,
      resettingDirectory: false,
      clearingCache: false,
      exportingDiagnosticLog: false,
    );
  }

  /// 是否正在调用系统目录选择器并同步待下载任务。
  final bool choosingDirectory;

  /// 是否正在恢复默认目录并同步待下载任务。
  final bool resettingDirectory;

  /// 是否正在清理本地缓存。
  final bool clearingCache;

  /// 是否正在导出脱敏诊断日志。
  final bool exportingDiagnosticLog;

  /// 返回替换部分状态后的新快照。
  SettingsPageState copyWith({
    bool? choosingDirectory,
    bool? resettingDirectory,
    bool? clearingCache,
    bool? exportingDiagnosticLog,
  }) {
    return SettingsPageState(
      choosingDirectory: choosingDirectory ?? this.choosingDirectory,
      resettingDirectory: resettingDirectory ?? this.resettingDirectory,
      clearingCache: clearingCache ?? this.clearingCache,
      exportingDiagnosticLog:
          exportingDiagnosticLog ?? this.exportingDiagnosticLog,
    );
  }
}
