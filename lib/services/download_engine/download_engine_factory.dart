import 'dart:async';

import '../../core/platform/native_tool_resolver.dart';
import '../../core/platform/runtime_platform.dart';
import 'download_engine.dart';

/// 使用已解析的原生工具同步或异步创建下载引擎的函数签名。
typedef DownloadEngineBuilder =
    FutureOr<DownloadEngine> Function(NativeToolPaths paths);

/// 按平台后端选择结果创建对应的下载引擎。
final class DownloadEngineFactory {
  /// 注入 aria2 和系统下载引擎构造器。
  const DownloadEngineFactory({
    required this.aria2Builder,
    required this.systemBuilder,
  });

  /// aria2 后端构造器。
  final DownloadEngineBuilder aria2Builder;

  /// 系统下载后端构造器。
  final DownloadEngineBuilder systemBuilder;

  /// 根据工具路径携带的后端类型异步调用对应构造器。
  Future<DownloadEngine> create(NativeToolPaths paths) async {
    // 分支只负责选择实现，具体异步依赖由注入的构造器组装。
    final engine = switch (paths.downloadBackend) {
      DownloadBackendKind.aria2 => aria2Builder(paths),
      DownloadBackendKind.system => systemBuilder(paths),
    };
    // FutureOr 允许简单后端同步返回，也允许等待应用目录等异步依赖。
    return engine;
  }
}
