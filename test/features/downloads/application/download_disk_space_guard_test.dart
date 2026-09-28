import 'package:bilibili_down/features/downloads/application/queue/download_disk_space_guard.dart';
import 'package:bilibili_down/features/downloads/domain/download_task_phase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 返回固定剩余空间的测试磁盘查询器。
final class _FakeDiskSpaceProbe implements DiskSpaceProbe {
  /// 创建返回指定字节数的查询器。
  const _FakeDiskSpaceProbe(this.availableBytes);

  /// 模拟目标卷可用字节；空值表示平台查询失败。
  final int? availableBytes;

  /// 测试不访问真实文件系统，只返回固定结果。
  @override
  Future<int?> freeBytes(String path) async => availableBytes;
}

void main() {
  /// 验证双流合并会预留两份媒体空间和固定安全余量。
  test('音视频合并预留分流与最终成品空间', () {
    // 100 MiB 视频加 20 MiB 音频，工作空间为两倍并至少加 128 MiB。
    const mib = 1024 * 1024;
    expect(
      requiredDiskBytes(
        estimatedVideoBytes: 100 * mib,
        estimatedAudioBytes: 20 * mib,
        requiresMerge: true,
      ),
      368 * mib,
    );
  });

  /// 验证未知大小和磁盘不足都会阻止任务启动。
  test('未知大小使用保守需求且空间不足抛出异常', () async {
    // 未知资源至少要求 256 MiB，当前只提供 128 MiB。
    const mib = 1024 * 1024;
    final guard = DownloadDiskSpaceGuard(const _FakeDiskSpaceProbe(128 * mib));
    await expectLater(
      guard.ensureAvailable(
        outputPath: '/downloads/video.mp4',
        estimatedVideoBytes: null,
        estimatedAudioBytes: null,
        requiresMerge: false,
      ),
      throwsA(isA<InsufficientDiskSpaceException>()),
    );
  });

  /// 验证空间充足时允许任务继续。
  test('目标卷空间充足时检查通过', () async {
    // 1 GiB 可用空间足以容纳小型单资源任务和安全余量。
    const gib = 1024 * 1024 * 1024;
    final guard = DownloadDiskSpaceGuard(const _FakeDiskSpaceProbe(gib));
    await guard.ensureAvailable(
      outputPath: '/downloads/cover.jpg',
      estimatedVideoBytes: 2 * 1024 * 1024,
      estimatedAudioBytes: null,
      requiresMerge: false,
    );
  });

  /// 验证 Windows 中文标题目录会回退到同一盘符根目录查询空间。
  test('Windows 中文目录提取目标盘符根路径', () {
    // 插件原生层无法处理中文子路径，但 C 盘根目录与目标文件属于同一卷。
    expect(
      diskSpaceFallbackRoot(
        r'C:\Users\测试\Downloads\视频标题',
        style: p.Style.windows,
      ),
      r'C:\',
    );
  });

  /// 验证失败任务能够交给并发调度器重新排队。
  test('失败任务允许进入等待启动阶段', () {
    // “排队重试”由调度器先写 waitingToStart，状态机必须显式允许该路径。
    expect(
      DownloadTaskStateMachine.canTransition(
        DownloadTaskPhase.failed,
        DownloadTaskPhase.waitingToStart,
      ),
      isTrue,
    );
  });
}
