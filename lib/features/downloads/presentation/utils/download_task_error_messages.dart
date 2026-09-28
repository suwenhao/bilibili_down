import 'dart:io';

import '../../../../services/bilibili/bili_api_exception.dart';
import '../../../../services/download_engine/aria2/aria2_error_policy.dart';

/// 把文件系统异常转换为用户可读说明，避免暴露异常类名和内部路径。
String deletionErrorMessage(Object error) {
  // 文件删除错误只展示业务消息，路径仍留在异常对象中供诊断日志使用。
  if (error is FileSystemException) {
    // 当前删除链路只走真实文件路径，直接展示文件系统给出的简短原因。
    return error.message;
  }
  // 其他异常同样不能把内部类型名暴露给用户。
  return userErrorMessage(error, fallback: '删除失败，请稍后重试。');
}

/// 把启动下载异常转换为可操作的简短提示。
String startDownloadErrorMessage(Object error) {
  // 下载后端启动失败时提示用户处理应用状态，不展示 Dio、RPC 或进程异常名。
  final message = error.toString().toLowerCase();
  final aria2Message = aria2UserMessage(error, fallback: '');
  if (aria2Message.isNotEmpty) return aria2Message;
  if (message.contains('aria2') ||
      message.contains('/jsonrpc') ||
      message.contains('connection refused')) {
    return '下载引擎启动失败，请重启应用或稍后重试。';
  }
  // B 站接口或链接问题走业务异常文案，其它错误使用稳定兜底。
  return userErrorMessage(error, fallback: '下载准备失败，请重试。');
}

/// 把异常转换为当前页面可展示的简短文案。
String userErrorMessage(Object error, {required String fallback}) {
  // B 站业务异常使用接口层提供的用户说明，其他异常使用场景兜底。
  return biliUserMessage(error, fallback: fallback);
}
