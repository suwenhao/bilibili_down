import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../core/logging/app_debug_log.dart';

/// 桌面回收站操作失败时向界面提供不暴露平台通道细节的说明。
final class DesktopTrashException implements Exception {
  /// 保存可直接展示给用户的处理建议。
  const DesktopTrashException(this.message);

  /// 面向用户的简短错误说明。
  final String message;

  /// SnackBar 拼接异常时只显示说明，不暴露 MethodChannel 或 Shell 实现。
  @override
  String toString() => message;
}

/// 将桌面端用户可见文件交给系统回收站或废纸篓处理。
abstract final class DesktopTrashService {
  /// Dart 与三个桌面 Runner 共用的稳定平台通道名称。
  static const MethodChannel _channel = MethodChannel('bilidown/system_trash');

  /// 把一批存在的普通文件或目录作为一次系统回收站操作提交。
  static Future<void> movePathsToTrash(Iterable<String> paths) async {
    // 移动端没有桌面回收站语义，不能调用桌面 Runner 通道。
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      throw UnsupportedError('当前平台不支持桌面系统回收站。');
    }
    // 规范化并去重，避免同一产物因数据库旧记录被重复提交给系统 Shell。
    final normalizedPaths = paths
        .where((String path) => path.trim().isNotEmpty)
        .map((String path) => p.normalize(p.absolute(path)))
        .toSet();
    // 系统回收站只接收当前仍存在的对象，缺失文件继续视为删除成功。
    final existingPaths = <String>[];
    for (final path in normalizedPaths) {
      // 不跟随符号链接读取类型，防止检查阶段跳到数据库未登记的真实目标。
      final entityType = await FileSystemEntity.type(path, followLinks: false);
      if (entityType != FileSystemEntityType.notFound) {
        existingPaths.add(path);
      }
    }
    // 全部文件已经不存在时无需调用平台通道。
    if (existingPaths.isEmpty) return;
    try {
      // Runner 负责调用 Windows Shell、macOS NSWorkspace 或 Linux GIO Trash。
      await _channel.invokeMethod<void>('movePathsToTrash', <String, Object>{
        'paths': existingPaths,
      });
    } on MissingPluginException catch (error) {
      // 热重载不会重新编译 Windows Runner，旧进程缺少通道时使用等价回收站兼容入口。
      AppDebugLog.aria2('Desktop trash channel unavailable: $error');
      if (Platform.isWindows) {
        await _moveWindowsPathsToTrash(existingPaths);
        return;
      }
      // macOS 与 Linux 没有稳定的跨发行版兼容命令，要求完整重启以加载原生实现。
      throw const DesktopTrashException('系统回收站功能尚未加载，请完全退出应用后重新打开。');
    } on PlatformException catch (error) {
      // 原生 Shell 拒绝操作时保留全部任务记录，并隐藏通道名和底层错误码。
      AppDebugLog.aria2('Desktop trash operation failed: $error');
      throw const DesktopTrashException('无法把下载文件移入回收站，请检查文件占用或安全软件提示后重试。');
    }
  }

  /// Windows 旧 Runner 缺少平台通道时，通过固定 PowerShell 脚本调用系统回收站。
  static Future<void> _moveWindowsPathsToTrash(List<String> paths) async {
    // 使用系统目录中的 PowerShell，避免 PATH 被第三方同名程序替换。
    final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final executable = p.join(
      systemRoot,
      'System32',
      'WindowsPowerShell',
      'v1.0',
      'powershell.exe',
    );
    // 脚本只从标准输入读取 JSON 路径，不把用户文件名拼入命令行，避免命令注入。
    const script = r'''
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class BiliDownRecycleBinBatch {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  private struct SHFILEOPSTRUCT {
    public IntPtr hwnd;
    public uint wFunc;
    public IntPtr pFrom;
    public IntPtr pTo;
    public ushort fFlags;
    [MarshalAs(UnmanagedType.Bool)] public bool fAnyOperationsAborted;
    public IntPtr hNameMappings;
    [MarshalAs(UnmanagedType.LPWStr)] public string lpszProgressTitle;
  }

  [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
  private static extern int SHFileOperation(ref SHFILEOPSTRUCT operation);

  // 把全部路径组成双空字符结尾的 Shell 批次，一次移入系统回收站。
  public static int MoveToRecycleBin(string[] paths) {
    string sources = string.Join("\0", paths) + "\0\0";
    IntPtr sourcePointer = Marshal.StringToHGlobalUni(sources);
    try {
      SHFILEOPSTRUCT operation = new SHFILEOPSTRUCT {
        wFunc = 3,
        pFrom = sourcePointer,
        fFlags = 0x0454
      };
      int result = SHFileOperation(ref operation);
      if (result != 0) return result;
      if (operation.fAnyOperationsAborted) return 1223;
      return 0;
    } finally {
      Marshal.FreeHGlobal(sourcePointer);
    }
  }
}
'@
$paths = [Console]::In.ReadToEnd() | ConvertFrom-Json
$result = [BiliDownRecycleBinBatch]::MoveToRecycleBin([string[]]@($paths))
if ($result -ne 0) {
  throw "Windows 回收站操作失败，错误码：$result"
}
''';
    try {
      // 禁用 Profile 和交互提示，确保只执行应用内固定脚本且不会弹出独立终端窗口。
      final process = await Process.start(
        executable,
        const <String>[
          '-NoLogo',
          '-NoProfile',
          '-NonInteractive',
          '-WindowStyle',
          'Hidden',
          '-Command',
          script,
        ],
        runInShell: false,
        mode: ProcessStartMode.normal,
      );
      // 路径通过标准输入传递，JSON 编码完整保留空格、中文和特殊字符。
      process.stdin.write(jsonEncode(paths));
      await process.stdin.close();
      // 同时消费输出流，避免系统错误文本填满管道后阻塞退出。
      final outputFuture = process.stdout.transform(utf8.decoder).join();
      final errorFuture = process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;
      final output = await outputFuture;
      final error = await errorFuture;
      // 非零退出表示文件占用、安全软件阻止或回收站服务不可用，数据库记录必须保留。
      if (exitCode != 0) {
        AppDebugLog.aria2(
          'Windows trash fallback failed exit=$exitCode output=$output error=$error',
        );
        throw const DesktopTrashException('无法把下载文件移入回收站，请检查文件占用或安全软件提示后重试。');
      }
    } on DesktopTrashException {
      // 已转换的用户错误保持原样，避免被再次包装成技术异常。
      rethrow;
    } catch (error) {
      // PowerShell 缺失或无法启动时给出恢复方式，任务记录和文件均保持不变。
      AppDebugLog.aria2('Windows trash fallback unavailable: $error');
      throw const DesktopTrashException('系统回收站功能尚未加载，请完全退出应用后重新打开。');
    }
  }
}
