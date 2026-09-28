import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

import '../../services/media_output/media_output_publisher.dart';
import '../platform/application_data_directory.dart';
import '../platform/default_download_directory.dart';
import '../platform/runtime_platform.dart';
import 'app_debug_log.dart';

/// 打开系统保存对话框并导出脱敏诊断日志。
abstract final class DiagnosticLogExportService {
  /// 让用户选择目标文件并写入当前日志，取消选择时返回 false。
  static Future<bool> export() async {
    // 文件名只包含 UTC 日期，不暴露用户、任务或设备信息。
    final fileName = _diagnosticFileName();
    // Android 没有实现 file_selector 的保存对话框，改用项目已有公共下载发布流程。
    if (Platform.isAndroid) return _exportOnAndroid(fileName);

    final location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: '日志文件', extensions: <String>['log', 'txt']),
      ],
      confirmButtonText: '导出日志',
    );
    // 用户取消保存对话框不创建任何文件。
    if (location == null) return false;
    final target = File(location.path);
    // 父目录通常由系统选择器保证存在，自定义实现仍提前创建以兼容桌面平台。
    await target.parent.create(recursive: true);
    await target.writeAsString(AppDebugLog.exportText(), flush: true);
    return true;
  }

  /// 生成本次导出的稳定日志文件名。
  static String _diagnosticFileName() {
    // 日期使用 UTC，避免把用户所在时区写入可分享日志名称。
    final date = DateTime.now().toUtc().toIso8601String().split('T').first;
    return 'bilidown-diagnostic-$date.log';
  }

  /// 在 Android 上导出到公共 Download/BiliDown，绕开未实现的保存对话框。
  static Future<bool> _exportOnAndroid(String fileName) async {
    // 默认下载根目录就是用户可见真实路径，诊断日志直接写入该目录。
    final workingRoot = await resolveDefaultDownloadDirectory();
    final requestedOutputPath = p.join(workingRoot.path, fileName);

    // 诊断日志先写入应用支持目录下的专用临时区，避免污染下载任务临时目录。
    final supportDirectory = await resolveApplicationDataDirectory();
    final temporaryDirectory = Directory(
      p.join(supportDirectory.path, 'diagnostic_exports'),
    );
    await temporaryDirectory.create(recursive: true);

    // 复用下载成品发布器，统一校验真实文件路径并登记输出。
    final publisher = createMediaOutputPublisher(RuntimePlatform.current());
    final workingOutputPath = await publisher.prepareOutputPath(
      requestedOutputPath: requestedOutputPath,
      temporaryDirectory: temporaryDirectory.path,
    );
    final target = File(workingOutputPath);
    // 写入前确保父目录存在，兼容未来发布器返回子目录工作路径的情况。
    await target.parent.create(recursive: true);
    await target.writeAsString(AppDebugLog.exportText(), flush: true);
    await publisher.publish(
      workingOutputPath: workingOutputPath,
      requestedOutputPath: requestedOutputPath,
    );
    return true;
  }
}
