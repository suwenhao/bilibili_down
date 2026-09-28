import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../../../core/logging/app_debug_log.dart';
import '../../../core/platform/native_tool_resolver.dart';
import '../../../core/platform/runtime_platform.dart';
import 'aria2_process_controller.dart';
import 'aria2_rpc_client.dart';

/// 管理 aria2 进程、RPC 客户端以及会话配置文件的生命周期。
final class Aria2Runtime {
  /// 使用已解析工具路径和应用目录创建运行时。
  Aria2Runtime({
    required NativeToolPaths toolPaths,
    required this.supportDirectory,
    required this.downloadDirectory,
    required int initialMaxOverallDownloadLimitMegabytesPerSecond,
    Aria2ProcessController? processController,
  }) : _toolPaths = toolPaths,
       _maxOverallDownloadLimitMegabytesPerSecond =
           initialMaxOverallDownloadLimitMegabytesPerSecond,
       _processController =
           processController ?? _defaultController(toolPaths.platform) {
    // 控制器比 RPC 客户端更贴近底层进程生命周期，收到失效信号时立即丢弃旧客户端。
    _processController.setRuntimeInvalidationHandler(
      _invalidateClientFromController,
    );
  }

  /// 当前平台的原生工具路径。
  final NativeToolPaths _toolPaths;

  /// 保存运行配置、日志和任务映射的应用支持目录。
  final Directory supportDirectory;

  /// aria2 默认下载目录。
  final Directory downloadDirectory;

  /// 负责在本机或 Android 前台服务中启动 aria2 的控制器。
  final Aria2ProcessController _processController;

  /// 当前要应用到 aria2 全局选项的下载速度上限，单位为 MB/s。
  int _maxOverallDownloadLimitMegabytesPerSecond;

  /// 运行时启动成功后持有的 RPC 客户端。
  Aria2RpcClient? _client;

  /// 底层进程或服务主动报告失效时清理主 isolate 缓存的 RPC 客户端。
  void _invalidateClientFromController(String reason) {
    // 没有缓存客户端时无需重复记录，避免桌面 stop 过程产生日志噪音。
    if (_client == null) return;
    // 只清理 RPC 客户端，不在回调里停止进程，避免进程退出回调和 stop 互相递归。
    _client = null;
    AppDebugLog.aria2('Runtime RPC client invalidated reason=$reason');
  }

  /// 获取已经就绪的 RPC 客户端，未启动时拒绝业务调用。
  Aria2RpcClient get client {
    // 复制字段值便于空安全提升。
    final value = _client;
    // 没有客户端说明 start 尚未完成或运行时已经停止。
    if (value == null) {
      throw StateError('Aria2Runtime has not been started.');
    }
    return value;
  }

  /// 业务任务 ID 与 aria2 GID 的持久化映射文件。
  File get taskMapFile =>
      File(p.join(supportDirectory.path, 'aria2', 'tasks.json'));

  /// 更新 aria2 全局下载速度上限，运行时未启动时仅记录待应用值。
  Future<void> updateMaxOverallDownloadLimit(int megabytesPerSecond) async {
    // 设置页和恢复流程都必须限制在产品允许的一到一百 MB/s。
    final normalizedLimit = megabytesPerSecond.clamp(1, 100);
    // 记录最新设置，下一次启动或复用进程时会继续使用。
    _maxOverallDownloadLimitMegabytesPerSecond = normalizedLimit;
    // 没有运行中的 RPC 客户端时不能为保存设置而主动启动 aria2。
    final currentClient = _client;
    if (currentClient == null) return;
    // 已运行的 aria2 通过全局选项立即更新总下载限速。
    await _applyDownloadLimit(currentClient);
  }

  /// 启动或复用 aria2 进程，并等待 RPC 服务可用。
  Future<void> start() async {
    // 已有客户端只代表主 isolate 保存过 RPC 参数，仍要确认端口背后的进程还活着。
    final currentClient = _client;
    if (currentClient != null) {
      // Android 前台服务停止后 RPC 一定不可用，先避开无意义的端口探测。
      if (await _processController.isKnownUnavailable()) {
        // 旧端口背后的服务已确定不可用，直接清理后重新启动。
        AppDebugLog.aria2(
          'Runtime controller reported unavailable; dropping RPC client.',
        );
        _client = null;
        await _processController.stop();
      } else {
        try {
          // Android 前台服务或桌面子进程可能被系统结束，复用前先做一次短健康检查。
          await currentClient.getVersion().timeout(
            const Duration(milliseconds: 700),
          );
          // 复用中的进程可能还保持旧设置，启动路径统一刷新全局限速。
          await _applyDownloadLimit(currentClient);
          AppDebugLog.aria2('Runtime already ready; reusing RPC client.');
          return;
        } catch (error) {
          // 旧端口已不可用时丢弃内存客户端并停止残留服务，随后走完整启动流程。
          AppDebugLog.aria2('Runtime stale RPC client detected error=$error');
          _client = null;
          await _processController.stop();
        }
      }
    }
    // 读取当前平台解析出的 aria2c 路径。
    final executable = _toolPaths.aria2Executable;
    // 系统下载后端平台没有 aria2c，禁止错误启动。
    if (executable == null) {
      throw const Aria2ProcessException(
        'aria2 is unavailable on this platform.',
      );
    }
    // 只记录可执行文件位置，不输出随机 RPC 密钥。
    AppDebugLog.aria2('Runtime start requested executable=$executable');

    // 为 aria2 会话、日志与运行配置创建独立目录。
    final runtimeDirectory = Directory(p.join(supportDirectory.path, 'aria2'));
    // 确保运行目录和下载目录在启动进程前存在。
    await runtimeDirectory.create(recursive: true);
    await downloadDirectory.create(recursive: true);

    // runtime.json 用于应用重启后探测仍在运行的 aria2 服务。
    final configFile = File(p.join(runtimeDirectory.path, 'runtime.json'));
    // 尝试读取上次保存的端口和鉴权密钥。
    final existing = await _readConfig(configFile);
    // Android 旧配置没有系统 CA bundle，不能复用，否则 HTTPS 下载仍会校验失败。
    final existingHasRequiredCa =
        _toolPaths.platform.operatingSystem != HostOperatingSystem.android ||
        existing?.caCertificatePath != null;
    // 只有工具路径和平台必需配置都一致时才复用旧运行时，防止版本、架构或 CA 策略切换。
    // Android 的 aria2 由前台服务承载，服务不存在时旧 runtime.json 不可能仍可连接。
    final canProbeExistingProcess = !await _processController
        .isKnownUnavailable();
    if (canProbeExistingProcess &&
        existing != null &&
        existing.executablePath == executable &&
        existingHasRequiredCa) {
      // 按旧配置创建临时客户端进行存活探测。
      final existingClient = Aria2RpcClient(
        port: existing.port,
        secret: existing.secret,
      );
      try {
        // 使用较短超时检查旧进程，避免阻塞正常的新进程启动。
        await existingClient.waitUntilReady(
          timeout: const Duration(milliseconds: 700),
        );
        // 探测成功后保存旧客户端，跳过重复启动。
        _client = existingClient;
        // 跨会话复用旧进程时必须补发当前设置，覆盖旧启动参数。
        await _applyDownloadLimit(existingClient);
        // 记录复用端口，便于区分旧进程和本次新进程。
        AppDebugLog.aria2('Reused existing process port=${existing.port}');
        return;
      } catch (error) {
        // 旧进程已经退出或端口失效，继续创建新进程。
        AppDebugLog.aria2('Existing process unavailable error=$error');
      }
    }

    // aria2 会话文件用于恢复未完成任务。
    final sessionFile = File(p.join(runtimeDirectory.path, 'aria2.session'));
    // 首次启动时创建空会话文件，满足 --input-file 参数要求。
    if (!await sessionFile.exists()) await sessionFile.create(recursive: true);
    // 为新进程生成可用端口、随机密钥及运行文件路径。
    final config = Aria2LaunchConfig(
      executablePath: executable,
      port: await _findAvailablePort(),
      secret: _createSecret(),
      downloadDirectory: downloadDirectory.path,
      sessionFile: sessionFile.path,
      logFile: p.join(runtimeDirectory.path, 'aria2.log'),
      maxOverallDownloadLimitMegabytesPerSecond:
          _maxOverallDownloadLimitMegabytesPerSecond,
      caCertificatePath: await _prepareCaCertificate(runtimeDirectory),
    );
    // 先原子写入配置，前台任务和应用重启流程才能读取同一份参数。
    await _writeConfig(configFile, config);
    // 记录不含密钥的启动配置摘要。
    AppDebugLog.aria2(
      'Launching process port=${config.port} log=${config.logFile}',
    );
    // 交由平台控制器实际创建 aria2 进程。
    await _processController.start(config);

    // 使用新进程的端口和密钥创建业务 RPC 客户端。
    final rpcClient = Aria2RpcClient(port: config.port, secret: config.secret);
    try {
      // 等待 RPC 监听成功后才向上层公布客户端。
      await rpcClient.waitUntilReady();
    } catch (error) {
      // RPC 启动失败时回收已创建的进程，避免后台残留。
      AppDebugLog.aria2('Runtime startup failed error=$error');
      await _processController.stop();
      rethrow;
    }
    // 启动全部成功后再赋值，保证 client getter 不会拿到未就绪实例。
    _client = rpcClient;
    // 新进程已经带启动参数，此处再同步一次可覆盖 aria2 复用配置文件的边界情况。
    await _applyDownloadLimit(rpcClient);
    // 通知调试控制台运行时已经可以接受下载任务。
    AppDebugLog.aria2('Runtime ready port=${config.port}');
  }

  /// 把当前内存中的速度上限写入指定 RPC 客户端。
  Future<void> _applyDownloadLimit(Aria2RpcClient client) async {
    // 保存当前值到局部变量，日志和 RPC 参数保持同一份快照。
    final limit = _maxOverallDownloadLimitMegabytesPerSecond;
    // RPC 更新只包含限速选项，不影响 aria2 里的会话和任务状态。
    await client.changeGlobalDownloadLimit(limit);
    AppDebugLog.aria2('Runtime download limit applied limit=${limit}M');
  }

  /// Android 将系统哈希证书目录合并为 aria2 静态 OpenSSL 可读取的 PEM bundle。
  Future<String?> _prepareCaCertificate(Directory runtimeDirectory) async {
    // 桌面系统由 aria2 使用自身默认 CA 搜索路径，不额外改变现有证书策略。
    if (_toolPaths.platform.operatingSystem != HostOperatingSystem.android) {
      return null;
    }

    // 新版 Android 优先由 Conscrypt APEX 提供证书，旧版继续使用 system 目录。
    final candidateDirectories = <Directory>[
      Directory('/apex/com.android.conscrypt/cacerts'),
      Directory('/system/etc/security/cacerts'),
    ];
    // 保存最终选中的系统证书文件，按路径排序保证生成结果稳定。
    var certificates = <File>[];
    for (final directory in candidateDirectories) {
      // 当前系统没有该目录时尝试下一个兼容路径。
      if (!await directory.exists()) continue;
      // Android 证书目录只读取普通文件，忽略目录或其他特殊节点。
      List<File> files;
      try {
        files = await directory
            .list(followLinks: true)
            .where((entity) => entity is File)
            .cast<File>()
            .toList();
      } on FileSystemException {
        // 某些系统暴露 APEX 路径但禁止应用遍历，此时继续尝试兼容的 system 目录。
        continue;
      }
      // 找到有效目录后停止回退，避免同一根证书被重复写入。
      if (files.isNotEmpty) {
        certificates = files;
        break;
      }
    }
    // 没有系统根证书时必须中止启动，不能通过关闭 HTTPS 校验掩盖安全问题。
    if (certificates.isEmpty) {
      throw const Aria2ProcessException(
        'Android system CA certificates are unavailable.',
      );
    }
    certificates.sort((left, right) => left.path.compareTo(right.path));

    // 临时文件避免生成中断时留下半份 CA bundle。
    final bundle = File(
      p.join(runtimeDirectory.path, 'android-system-ca-bundle.pem'),
    );
    final temporaryBundle = File('${bundle.path}.tmp');
    // 顺序拼接每一份 PEM，并补换行防止相邻证书边界粘连。
    final sink = temporaryBundle.openWrite();
    try {
      for (final certificate in certificates) {
        // 系统证书是只读 PEM 文件，原样复制可保留完整签名数据。
        sink.add(await certificate.readAsBytes());
        sink.writeln();
      }
      // 确保全部证书落盘后再替换正式文件。
      await sink.flush();
      await sink.close();
    } catch (error) {
      // 写入失败时关闭句柄并删除临时文件，避免后续启动误用损坏数据。
      await sink.close();
      if (await temporaryBundle.exists()) await temporaryBundle.delete();
      rethrow;
    }
    // Windows 不会进入此分支；Android rename 前先移除上一轮生成文件。
    if (await bundle.exists()) await bundle.delete();
    await temporaryBundle.rename(bundle.path);
    // 返回应用私有目录中的稳定路径，供前台服务 isolate 启动 aria2。
    return bundle.path;
  }

  /// 保存会话并关闭 RPC 与底层进程。
  Future<void> stop() async {
    // 标记停止流程开始，便于识别热重启导致的正常关闭。
    AppDebugLog.aria2('Runtime stop requested.');
    // 先取出并清空字段，阻止停止过程中继续发起新任务。
    final rpcClient = _client;
    _client = null;
    // 仅已启动的运行时需要执行 RPC 正常关闭流程。
    if (rpcClient != null) {
      try {
        // 先保存未完成任务，再请求 aria2 正常退出。
        await rpcClient.saveSession();
        await rpcClient.shutdown();
      } catch (_) {
        // RPC 已断开时忽略异常，下面仍会通过进程控制器强制回收。
      }
    }
    // 无论 RPC 是否成功都执行最终进程清理。
    await _processController.stop();
    // 所有运行时资源已经释放。
    AppDebugLog.aria2('Runtime stopped.');
  }

  /// 安全读取上次运行配置，缺失或损坏时返回空。
  Future<Aria2LaunchConfig?> _readConfig(File file) async {
    // 首次运行没有配置文件，不视为错误。
    if (!await file.exists()) return null;
    try {
      // 解析 JSON 文本并校验根节点类型。
      final data = jsonDecode(await file.readAsString());
      if (data is! Map) return null;
      // 转换动态键后恢复强类型启动配置。
      return Aria2LaunchConfig.fromJson(
        data.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (_) {
      // 配置损坏时放弃复用，后续会创建新的安全配置。
      return null;
    }
  }

  /// 通过临时文件替换方式原子保存运行配置。
  Future<void> _writeConfig(File file, Aria2LaunchConfig config) async {
    // 临时文件与目标同目录，便于最后一步原子重命名。
    final temporary = File('${file.path}.tmp');
    // 写入并刷盘，确保前台服务能读取完整 JSON。
    await temporary.writeAsString(jsonEncode(config.toJson()), flush: true);
    // 删除旧文件后用新文件替换，避免残留旧端口和密钥。
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  /// 让系统分配一个当前可用的本机 TCP 端口。
  Future<int> _findAvailablePort() async {
    // 绑定 0 端口请求操作系统自动选择空闲端口。
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    // 在关闭探测套接字前记录实际分配的端口。
    final port = socket.port;
    // 释放端口，随后由 aria2 RPC 监听使用。
    await socket.close();
    return port;
  }

  /// 生成 256 位随机 RPC 密钥，避免本机其他进程未经授权调用。
  String _createSecret() {
    // 使用密码学安全随机源生成密钥字节。
    final random = Random.secure();
    // 转成 URL 安全的 Base64 文本供命令行和 JSON-RPC 使用。
    return base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)));
  }

  /// 根据平台选择本地进程或 Android 前台服务控制器。
  static Aria2ProcessController _defaultController(RuntimePlatform platform) {
    // Android 必须借助前台服务满足长时间后台下载要求。
    if (platform.operatingSystem == HostOperatingSystem.android) {
      return AndroidAria2ProcessController();
    }
    // 桌面端直接由 Flutter 进程管理 aria2 子进程。
    return LocalAria2ProcessController();
  }
}
