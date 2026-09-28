import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'native_tool_resolver.dart';
import 'runtime_platform.dart';

/// 向业务层提供一次统一的平台与架构检测结果。
final runtimePlatformProvider = Provider<RuntimePlatform>((ref) {
  // 创建当前运行环境描述，避免各服务重复直接读取 Platform。
  return RuntimePlatform.current();
});

/// 按当前平台创建原生工具路径解析器。
final nativeToolResolverProvider = Provider<NativeToolResolver>((ref) {
  // 监听平台 Provider，测试或平台状态替换时可自动重建解析器。
  return NativeToolResolver(platform: ref.watch(runtimePlatformProvider));
});

/// 异步解析当前安装包内可用的 aria2c 与 FFmpeg 路径。
final nativeToolPathsProvider = FutureProvider<NativeToolPaths>((ref) {
  // 调用解析器执行文件存在性检查，并把错误交由 Riverpod 暴露给界面。
  return ref.watch(nativeToolResolverProvider).resolve();
});
