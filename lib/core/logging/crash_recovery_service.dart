import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../platform/application_data_directory.dart';
import 'app_debug_log.dart';

/// 上次未处理异常的脱敏恢复信息。
final class CrashRecoveryReport {
  /// 创建可展示但不包含原始敏感数据的报告。
  const CrashRecoveryReport({
    required this.occurredAt,
    required this.errorSummary,
    required this.stackTraceSummary,
  });

  /// 异常记录的 UTC 时间。
  final DateTime occurredAt;

  /// 已经过统一日志规则脱敏的异常摘要。
  final String errorSummary;

  /// 已经过统一日志规则脱敏并截断的堆栈摘要。
  final String stackTraceSummary;
}

/// 持久化未处理异常标记，并在下一次启动提供恢复提示。
abstract final class CrashRecoveryService {
  /// 崩溃标记使用固定文件名，不包含用户或任务信息。
  static const String _markerFileName = 'last_crash.json';

  /// 应用启动阶段读取到、等待用户确认的上次异常。
  static CrashRecoveryReport? pendingReport;

  /// 初始化标记路径并读取上次未确认异常。
  static Future<void> initialize() async {
    final marker = await _markerFile();
    pendingReport = await readReport(marker);
    final report = pendingReport;
    if (report != null) {
      // 把恢复事件加入本次诊断环形缓冲，用户导出时能看到启动上下文。
      AppDebugLog.app(
        'Previous crash detected at=${report.occurredAt.toIso8601String()} '
        'summary=${report.errorSummary}',
      );
      // 上次崩溃的堆栈只写入脱敏诊断日志，不直接展示在恢复弹窗正文中。
      AppDebugLog.app('Previous crash stack=${report.stackTraceSummary}');
    }
  }

  /// 最佳努力记录未处理异常；记录失败不能再次抛入异常处理器。
  static Future<void> record(Object error, StackTrace stackTrace) async {
    try {
      final marker = await _markerFile();
      await writeReport(marker, error: error, stackTrace: stackTrace);
    } catch (_) {
      // 崩溃处理路径禁止因存储不可用形成递归异常。
    }
  }

  /// 用户确认恢复提示后删除标记，防止下次启动重复显示。
  static Future<void> dismiss() async {
    try {
      final marker = await _markerFile();
      if (await marker.exists()) await marker.delete();
    } finally {
      // 即使文件已被系统清理，内存提示也应立即消失。
      pendingReport = null;
    }
  }

  /// 把异常与堆栈脱敏后写入指定文件，供单元测试验证格式。
  static Future<void> writeReport(
    File file, {
    required Object error,
    required StackTrace stackTrace,
    DateTime? occurredAt,
  }) async {
    // 错误和堆栈分别脱敏，限制长度避免异常对象生成超大标记文件。
    final sanitizedError = AppDebugLog.sanitize(error.toString());
    final sanitizedStack = AppDebugLog.sanitize(stackTrace.toString());
    final data = <String, Object?>{
      'occurredAt': (occurredAt ?? DateTime.now()).toUtc().toIso8601String(),
      'error': _truncate(sanitizedError, 2000),
      'stackTrace': _truncate(sanitizedStack, 12000),
    };
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data), flush: true);
  }

  /// 从指定标记读取可展示摘要，损坏文件按无报告处理。
  static Future<CrashRecoveryReport?> readReport(File file) async {
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final occurredAt = DateTime.tryParse(
        decoded['occurredAt']?.toString() ?? '',
      );
      final errorSummary = decoded['error']?.toString().trim();
      if (occurredAt == null || errorSummary == null || errorSummary.isEmpty) {
        return null;
      }
      return CrashRecoveryReport(
        occurredAt: occurredAt.toUtc(),
        errorSummary: errorSummary,
        stackTraceSummary: decoded['stackTrace']?.toString().trim() ?? '',
      );
    } on FormatException {
      // 半写入或外部损坏的标记不能阻止应用启动。
      return null;
    }
  }

  /// 返回统一应用数据目录中的崩溃标记文件。
  static Future<File> _markerFile() async {
    final directory = await resolveApplicationDataDirectory();
    return File(p.join(directory.path, _markerFileName));
  }

  /// 按 Unicode 字符长度裁剪诊断字段，避免标记文件无限增长。
  static String _truncate(String value, int maximumLength) =>
      value.length <= maximumLength ? value : value.substring(0, maximumLength);
}
