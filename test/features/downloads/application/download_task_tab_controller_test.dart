import 'package:bilibili_down/features/downloads/application/ui_state/download_task_tab_controller.dart';
import 'package:bilibili_down/features/downloads/domain/download_task_phase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 验证跨页面页签请求与本轮任务完成判断。
void main() {
  test('重复请求同一页签仍递增导航序号', () {
    // 独立容器模拟解析页和任务页共享同一个应用级控制器。
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(
      downloadTaskTabControllerProvider.notifier,
    );

    controller.select(DownloadTaskTab.pending);
    final firstRevision = container
        .read(downloadTaskTabControllerProvider)
        .revision;
    controller.select(DownloadTaskTab.pending);
    final secondRequest = container.read(downloadTaskTabControllerProvider);

    expect(secondRequest.tab, DownloadTaskTab.pending);
    expect(secondRequest.revision, firstRevision + 1);
  });

  test('只有跟踪任务全部成功完成才返回真', () {
    // 暂停、失败和仍在下载都不能触发自动跳到已下载页签。
    expect(
      areTrackedDownloadTasksCompleted(
        taskIds: <String>{'a', 'b'},
        snapshots: const <({String taskId, DownloadTaskPhase phase})>[
          (taskId: 'a', phase: DownloadTaskPhase.completed),
          (taskId: 'b', phase: DownloadTaskPhase.downloading),
        ],
      ),
      isFalse,
    );
    // 两条本轮任务都进入 completed 后才满足产品语义。
    expect(
      areTrackedDownloadTasksCompleted(
        taskIds: <String>{'a', 'b'},
        snapshots: const <({String taskId, DownloadTaskPhase phase})>[
          (taskId: 'a', phase: DownloadTaskPhase.completed),
          (taskId: 'b', phase: DownloadTaskPhase.completed),
        ],
      ),
      isTrue,
    );
  });
}
