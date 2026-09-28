import 'package:flutter/material.dart';

import '../../../core/widgets/app_icon_buttons.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/download_extra_resource.dart';
import 'dialogs/download_custom_batch_dialog.dart';
import 'models/download_custom_batch_result.dart';

/// 任务分支二级页打开自定义批量时携带的初始化参数。
final class DownloadCustomBatchPageArguments {
  /// 创建不可变页面参数，避免路由层直接读取设置控制器。
  const DownloadCustomBatchPageArguments({
    required this.taskCount,
    required this.availableResources,
    required this.initialAudioQuality,
    required this.initialVideoQuality,
  });

  /// 本次批量涉及的待下载主任务数量。
  final int taskCount;

  /// 设置中心允许展示的附加资源。
  final Set<DownloadExtraResource> availableResources;

  /// 页面初始音质选择。
  final DefaultAudioQuality initialAudioQuality;

  /// 页面初始画质选择。
  final DefaultVideoQuality initialVideoQuality;
}

/// 移动端自定义批量页面，作为任务页二级页面入栈。
final class DownloadCustomBatchPage extends StatelessWidget {
  /// 创建用于手机端的自定义批量页面。
  const DownloadCustomBatchPage({
    required this.taskCount,
    required this.availableResources,
    required this.initialAudioQuality,
    required this.initialVideoQuality,
    super.key,
  });

  /// 本次批量涉及的待下载主任务数量。
  final int taskCount;

  /// 设置中心允许展示的附加资源。
  final Set<DownloadExtraResource> availableResources;

  /// 页面初始音质选择。
  final DefaultAudioQuality initialAudioQuality;

  /// 页面初始画质选择。
  final DefaultVideoQuality initialVideoQuality;

  /// 构建移动端二级批量设置页。
  @override
  Widget build(BuildContext context) {
    // 批量直下只开放不依赖主下载流的小资源。
    final directResourceOptions = availableResources
        .where(
          (DownloadExtraResource resource) =>
              resource != DownloadExtraResource.audio,
        )
        .toList(growable: false);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: <Widget>[
                  AppCircleIconButton(
                    tooltip: '返回任务页',
                    onPressed: () {
                      // 返回按钮等同取消，不执行任何批量动作。
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '自定义批量',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: DownloadCustomBatchForm(
                  taskCount: taskCount,
                  availableResources: availableResources,
                  directResourceOptions: directResourceOptions,
                  activeTab: 0,
                  selectedAudioQuality: initialAudioQuality,
                  selectedVideoQuality: initialVideoQuality,
                  selectedMode: DownloadBatchMediaMode.audioVideo,
                  selectedSettingResources: <DownloadExtraResource>{
                    ...availableResources,
                  },
                  selectedDirectResources: <DownloadExtraResource>{
                    ...directResourceOptions,
                  },
                  compactActions: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
