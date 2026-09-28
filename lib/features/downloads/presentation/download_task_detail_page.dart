import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../core/platform/android_app_permissions.dart';
import '../../../core/widgets/app_action_button.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_icon_buttons.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../services/media_merge/media_merge_files.dart';
import '../application/resources/download_artifact_conversion_service.dart';
import '../data/download_task_draft.dart';
import '../domain/download_task_phase.dart';
import 'controllers/download_tasks_page_controller.dart';
import 'dialogs/download_artifact_conversion_dialog.dart';
import 'utils/download_output_directory_opener.dart';
import 'utils/download_task_formatters.dart';
import 'widgets/download_task_summary.dart';

/// 监听单条下载任务详情，删除记录后页面会收到 null。
final _downloadTaskDetailProvider = StreamProvider.autoDispose
    .family<DownloadTaskRecord?, String>((Ref ref, String taskId) {
      // 详情页只读取当前任务，不额外订阅任务列表，降低页面刷新范围。
      final repository = ref.watch(downloadTaskRepositoryProvider);
      return repository.watchTask(taskId);
    });

/// 监听已保留的本地文件产物，用于详情页展示视频和附加资源。
final _downloadTaskArtifactsProvider = StreamProvider.autoDispose
    .family<List<DownloadArtifactRecord>, String>((Ref ref, String taskId) {
      // 产物列表来自下载完成后的索引，旧任务会在页面侧回退到 outputPath。
      final repository = ref.watch(downloadTaskRepositoryProvider);
      return repository.watchRetainedArtifacts(taskId);
    });

/// 统计详情页当前任务正在进行的文件转换数量，用于禁用整条记录删除。
final _activeArtifactConversionsProvider =
    NotifierProvider<_ActiveArtifactConversionsController, Map<String, int>>(
      _ActiveArtifactConversionsController.new,
    );

/// 管理下载详情页内各任务的文件转换占用计数。
final class _ActiveArtifactConversionsController
    extends Notifier<Map<String, int>> {
  /// 初始没有任何任务处于文件转换流程。
  @override
  Map<String, int> build() => const <String, int>{};

  /// 增加指定任务的转换占用计数。
  void increment(String taskId) {
    // 新状态必须复制 Map，确保监听当前任务计数的按钮收到通知。
    final next = Map<String, int>.of(state);
    next[taskId] = (next[taskId] ?? 0) + 1;
    state = Map<String, int>.unmodifiable(next);
  }

  /// 减少指定任务的转换占用计数。
  void decrement(String taskId) {
    // 计数归零后移除 key，避免长时间保留已退出详情页的任务 ID。
    final current = state[taskId] ?? 0;
    if (current <= 0) return;
    final next = Map<String, int>.of(state);
    if (current == 1) {
      next.remove(taskId);
    } else {
      next[taskId] = current - 1;
    }
    state = Map<String, int>.unmodifiable(next);
  }
}

/// 已下载任务详情页。
final class DownloadTaskDetailPage extends ConsumerStatefulWidget {
  /// 创建指定任务 ID 的详情页。
  const DownloadTaskDetailPage({required this.taskId, super.key});

  /// 路由传入的业务任务 ID。
  final String taskId;

  /// 创建详情页状态对象。
  @override
  ConsumerState<DownloadTaskDetailPage> createState() =>
      _DownloadTaskDetailPageState();
}

/// 维护删除后自动返回的页面状态。
final class _DownloadTaskDetailPageState
    extends ConsumerState<DownloadTaskDetailPage> {
  /// 构建任务详情内容和删除后的返回监听。
  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<DownloadTaskRecord?>>(
      _downloadTaskDetailProvider(widget.taskId),
      (
        AsyncValue<DownloadTaskRecord?>? previous,
        AsyncValue<DownloadTaskRecord?> next,
      ) {
        // 只有详情页曾经拿到任务后再变成 null，才说明用户刚删除了当前记录。
        final hadTask = previous?.asData?.value != null;
        // 删除完成后数据库发出明确的 null，加载或错误过渡不能误判为删除。
        final removed =
            next is AsyncData<DownloadTaskRecord?> && next.value == null;
        if (!hadTask || !removed) return;
        // 等当前构建帧结束后再 pop，避免在 provider 通知期间改导航栈。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // 页面已释放时不再操作 Navigator。
          if (!mounted) return;
          // 详情页是任务分支二级页面，正常情况下可以直接返回任务列表。
          _leaveTaskDetail(context);
        });
      },
    );

    // 当前任务快照决定页面主体、空状态或错误状态。
    final taskValue = ref.watch(_downloadTaskDetailProvider(widget.taskId));
    // 详情页属于 Shell 内滚动内容区，背景使用 Scaffold 层而不是导航/头部 surface 层。
    final pageBackground = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        bottom: false,
        child: taskValue.when(
          data: (DownloadTaskRecord? task) {
            // 外部直达不存在的任务 ID 时展示友好空状态。
            if (task == null) {
              return const _TaskDetailMissingState();
            }
            return _TaskDetailContent(task: task);
          },
          loading: () {
            // 数据库首次读取期间保持详情页骨架简单稳定。
            return const _TaskDetailLoadingState();
          },
          error: (Object error, StackTrace stackTrace) {
            // 数据库读取异常需要保留错误文本，方便用户反馈日志。
            return _TaskDetailErrorState(message: '读取任务详情失败：$error');
          },
        ),
      ),
    );
  }
}

/// 任务详情主体。
final class _TaskDetailContent extends ConsumerWidget {
  /// 创建任务详情主体。
  const _TaskDetailContent({required this.task});

  /// 当前任务记录。
  final DownloadTaskRecord task;

  /// 构建响应式详情布局。
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 产物流用于展示最终文件和附加资源，加载中仍可先显示任务摘要。
    final artifactsValue = ref.watch(
      _downloadTaskArtifactsProvider(task.taskId),
    );
    // 任意本地文件正在转换时，整条下载记录不能被删除，避免文件处理和清理并发。
    final activeConversions = ref.watch(
      _activeArtifactConversionsProvider.select(
        (Map<String, int> counts) => counts[task.taskId] ?? 0,
      ),
    );
    // 当前宽度决定摘要卡使用桌面横排还是手机纵排。
    final width = MediaQuery.sizeOf(context).width;
    // 手机宽度下详情内容需要保留底部导航避让。
    final compact = width < AppBreakpoints.navigationRail;
    // 详情页正文最大宽度来自现有桌面设计，固定标题栏也沿用同一宽度。
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPersistentHeader(
              pinned: true,
              delegate: _TaskDetailHeaderDelegate(
                title: task.title,
                compact: compact,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                compact ? 18 : 32,
                8,
                compact ? 18 : 32,
                compact ? 112 : 32,
              ),
              sliver: SliverList.list(
                children: <Widget>[
                  _TaskOverviewCard(task: task, compact: compact),
                  const SizedBox(height: 14),
                  _TaskDescriptionCard(description: task.description),
                  const SizedBox(height: 14),
                  _TaskFilesSection(task: task, artifactsValue: artifactsValue),
                  const SizedBox(height: 18),
                  AppActionButton(
                    label: '删除下载记录',
                    icon: Icons.delete_outline_rounded,
                    variant: AppActionButtonVariant.filled,
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    borderColor: Colors.transparent,
                    onPressed: activeConversions > 0
                        ? null
                        : () {
                            // 删除流程沿用任务页控制器，保留确认弹窗和文件清理策略。
                            unawaited(
                              ref
                                  .read(
                                    downloadTasksPageControllerProvider
                                        .notifier,
                                  )
                                  .deleteTaskRecord(context, task),
                            );
                          },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 详情页固定顶部栏代理。
final class _TaskDetailHeaderDelegate extends SliverPersistentHeaderDelegate {
  /// 创建固定标题栏所需的布局状态。
  const _TaskDetailHeaderDelegate({
    required this.title,
    required this.compact,
    required this.backgroundColor,
  });

  /// 任务标题，来自当前详情任务快照。
  final String title;

  /// 是否使用窄屏边距，由当前视口宽度推导。
  final bool compact;

  /// 标题栏背景色，来自页面 Scaffold 背景。
  final Color backgroundColor;

  /// 固定标题栏最小高度，滚动后保持完整返回按钮和单行标题。
  @override
  double get minExtent => 68;

  /// 固定标题栏最大高度，初始状态与固定状态保持一致避免跳动。
  @override
  double get maxExtent => 68;

  /// 构建固定在滚动内容顶部的标题栏。
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // 横向边距跟随内容区，避免标题栏和下方卡片左右错位。
    final horizontalPadding = compact ? 18.0 : 32.0;
    // 滚动内容进入标题栏下方时显示分隔线，提示顶部栏已经固定。
    final dividerColor = overlapsContent
        ? Theme.of(context).dividerColor.withValues(alpha: 0.5)
        : Colors.transparent;
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(bottom: BorderSide(color: dividerColor)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            14,
            horizontalPadding,
            8,
          ),
          child: _TaskDetailHeader(title: title),
        ),
      ),
    );
  }

  /// 判断任务标题或响应式状态变化后是否需要重建固定栏。
  @override
  bool shouldRebuild(covariant _TaskDetailHeaderDelegate oldDelegate) {
    // 任务切换、宽度断点变化或主题背景变化时都需要刷新顶部栏。
    return oldDelegate.title != title ||
        oldDelegate.compact != compact ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

/// 详情页顶部栏。
final class _TaskDetailHeader extends StatelessWidget {
  /// 创建带返回按钮的详情页标题栏。
  const _TaskDetailHeader({required this.title});

  /// 任务标题。
  final String title;

  /// 构建返回按钮和标题。
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        AppCircleIconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: '返回任务列表',
          onPressed: () {
            // 返回任务分支上一层，通常是已下载任务列表。
            _leaveTaskDetail(context);
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

/// 任务封面和核心元数据。
final class _TaskOverviewCard extends StatelessWidget {
  /// 创建任务概览卡片。
  const _TaskOverviewCard({required this.task, required this.compact});

  /// 当前任务记录。
  final DownloadTaskRecord task;

  /// 是否使用手机布局。
  final bool compact;

  /// 构建封面、标题和基础信息。
  @override
  Widget build(BuildContext context) {
    // 卡片内容在不同宽度下共用同一组字段。
    final details = <_TaskInfoRow>[
      _TaskInfoRow(label: '发布者', value: task.publisherName ?? '未知'),
      _TaskInfoRow(
        label: '发布时间',
        value: task.publishedAt == null ? '未知' : dateLabel(task.publishedAt!),
      ),
      _TaskInfoRow(
        label: '完成时间',
        value: task.completedAt == null ? '未知' : dateLabel(task.completedAt!),
      ),
    ];
    return _DetailCard(
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AspectRatio(
                  aspectRatio: 14 / 9,
                  child: TaskCover(
                    task: task,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                const SizedBox(height: 14),
                _TaskMetadata(task: task, details: details),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TaskCover(task: task, width: 260, height: 167),
                const SizedBox(width: 20),
                Expanded(
                  child: _TaskMetadata(task: task, details: details),
                ),
              ],
            ),
    );
  }
}

/// 任务标题和键值信息列表。
final class _TaskMetadata extends StatelessWidget {
  /// 创建任务元数据块。
  const _TaskMetadata({required this.task, required this.details});

  /// 当前任务记录。
  final DownloadTaskRecord task;

  /// 展示用键值行。
  final List<_TaskInfoRow> details;

  /// 构建标题和元数据行。
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        for (final row in details) _TaskInfoLine(row: row),
      ],
    );
  }
}

/// 单条任务键值行。
final class _TaskInfoLine extends StatelessWidget {
  /// 创建信息行。
  const _TaskInfoLine({required this.row});

  /// 行数据。
  final _TaskInfoRow row;

  /// 构建左右对齐的元数据。
  @override
  Widget build(BuildContext context) {
    // 次级文本使用主题 outline，保持和现有任务卡一致。
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.outline,
      fontWeight: FontWeight.w700,
    );
    // 具体值使用更高字重，便于扫描。
    final valueStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: <Widget>[
              SizedBox(width: 82, child: Text(row.label, style: labelStyle)),
              Expanded(
                child: Text(
                  row.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: valueStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 简介卡片。
final class _TaskDescriptionCard extends StatelessWidget {
  /// 创建简介卡片。
  const _TaskDescriptionCard({required this.description});

  /// 任务简介原文。
  final String? description;

  /// 构建简介内容。
  @override
  Widget build(BuildContext context) {
    // 空简介使用友好占位，不让详情页出现空白卡。
    final text = description?.trim().isNotEmpty == true
        ? description!.trim()
        : '暂无简介';
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '简介',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// 本地文件列表。
final class _TaskFilesSection extends StatelessWidget {
  /// 创建文件列表区域。
  const _TaskFilesSection({required this.task, required this.artifactsValue});

  /// 当前任务记录。
  final DownloadTaskRecord task;

  /// 产物流当前状态。
  final AsyncValue<List<DownloadArtifactRecord>> artifactsValue;

  /// 构建本地视频和附加资源列表。
  @override
  Widget build(BuildContext context) {
    // 已读取到的产物用于合并旧版 outputPath 回退。
    final artifacts = artifactsValue.value ?? const <DownloadArtifactRecord>[];
    // 展示条目需要去重，避免旧任务迁移后重复显示最终视频。
    final entries = _fileEntriesForTask(task, artifacts);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '本地文件',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 10),
            if (artifactsValue.isLoading)
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (artifactsValue.hasError)
          _DetailMessageCard(message: '文件记录读取失败：${artifactsValue.error}')
        else if (entries.isEmpty)
          const _DetailMessageCard(message: '暂无可展示的本地文件记录')
        else
          for (final entry in entries) ...<Widget>[
            _TaskFileCard(taskId: task.taskId, entry: entry),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

/// 单个本地文件卡片。
final class _TaskFileCard extends ConsumerStatefulWidget {
  /// 创建文件卡片。
  const _TaskFileCard({required this.taskId, required this.entry});

  /// 当前任务 ID，用于转换成功后登记新产物。
  final String taskId;

  /// 文件展示条目。
  final _DownloadTaskFileEntry entry;

  /// 创建文件卡片状态。
  @override
  ConsumerState<_TaskFileCard> createState() => _TaskFileCardState();
}

/// 维护单个文件转换按钮的加载状态。
final class _TaskFileCardState extends ConsumerState<_TaskFileCard> {
  /// 当前文件是否正在转换。
  bool _converting = false;

  /// 当前转换派生文件是否正在删除。
  bool _deleting = false;

  /// 释放卡片时回收可能遗留的转换占用计数。
  @override
  void dispose() {
    // 转换期间页面被关闭时，要恢复父级删除按钮的可用性状态。
    if (_converting) _setConverting(false, refresh: false);
    super.dispose();
  }

  /// 构建文件类型、文件名和元数据。
  @override
  Widget build(BuildContext context) {
    // 当前条目的类型决定转换弹窗和按钮可用性。
    final entry = widget.entry;
    // 转换分类为空表示当前产物不适合在详情页直接转换。
    final category = _conversionCategoryForEntry(entry);
    // 文件类型决定图标和标题。
    final icon = _artifactIcon(entry.kind);
    // 文件名只展示 basename，长路径放在次行 tooltip 中避免撑宽。
    final fileName = p.basename(entry.path);
    // 当前卡片已有异步文件操作时禁用其它操作，避免同一路径并发读写。
    final busy = _converting || _deleting;
    return _DetailCard(
      child: _buildFileContent(
        context: context,
        entry: entry,
        icon: icon,
        fileName: fileName,
        category: category,
        busy: busy,
      ),
    );
  }

  /// 构建本地文件卡片，按图标、文本、元信息和操作四块排布。
  Widget _buildFileContent({
    required BuildContext context,
    required _DownloadTaskFileEntry entry,
    required IconData icon,
    required String fileName,
    required DownloadArtifactConversionCategory? category,
    required bool busy,
  }) {
    // 当前可用操作按钮固定放在底部右侧，避免压缩文件标题和文件名。
    final actionButtons = _buildFileActionButtons(
      category: category,
      busy: busy,
    );
    // 文件创建时间来自产物索引，缺失时显示稳定占位。
    final createdAtLabel = entry.createdAt == null
        ? '时间未知'
        : dateLabel(entry.createdAt!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 34,
              child: Center(
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TaskFileTextBlock(
                entry: entry,
                fileName: fileName,
                onOpenDirectory: () {
                  // 点击本地文件名打开该文件所在目录，便于用户在系统文件管理器里操作成品。
                  unawaited(
                    openDownloadOutputDirectory(context, p.dirname(entry.path)),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _FileMetaText(
                    icon: Icons.schedule_rounded,
                    value: createdAtLabel,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _FileMetaText(
                        icon: Icons.insert_drive_file_outlined,
                        value: entry.extensionLabel,
                      ),
                      const SizedBox(width: 14),
                      _FileMetaText(
                        icon: Icons.sd_storage_outlined,
                        value: fileSizeLabel(entry.sizeBytes),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (actionButtons.isNotEmpty) ...<Widget>[
              const SizedBox(width: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actionButtons),
            ],
          ],
        ),
      ],
    );
  }

  /// 构建文件卡片右侧操作按钮。
  List<Widget> _buildFileActionButtons({
    required DownloadArtifactConversionCategory? category,
    required bool busy,
  }) {
    // 按钮列表由当前产物能力决定，返回给底部操作区展示。
    final buttons = <Widget>[];
    if (category != null) {
      buttons.add(
        AppActionButton(
          label: '转换',
          loadingLabel: '转换中',
          icon: Icons.sync_alt_rounded,
          size: AppActionButtonSize.small,
          variant: AppActionButtonVariant.plain,
          loading: _converting,
          onPressed: busy
              ? null
              : () {
                  // 转换动作需要弹窗确认目标格式，避免误触直接启动耗时任务。
                  unawaited(_convert(category));
                },
        ),
      );
    }
    if (widget.entry.canDelete) {
      buttons.add(
        AppActionButton(
          label: '删除',
          loadingLabel: '删除中',
          icon: Icons.delete_outline_rounded,
          size: AppActionButtonSize.small,
          variant: AppActionButtonVariant.destructiveOutlined,
          loading: _deleting,
          onPressed: busy
              ? null
              : () {
                  // 只有转换派生文件允许单独移除，原始下载本体交给整条任务删除流程。
                  unawaited(_deleteConvertedFile());
                },
        ),
      );
    }
    return buttons;
  }

  /// 打开参数弹窗并执行一次本地文件转换。
  Future<void> _convert(DownloadArtifactConversionCategory category) async {
    // Android 转换会读写公共下载目录或转换产物目录，需要完整文件管理授权。
    if (!await _ensureAndroidFileManagementPermission('转换文件')) return;
    _setConverting(true);
    late final DownloadArtifactConversionService service;
    late final DownloadArtifactConversionCapabilities capabilities;
    try {
      // 转换服务按平台选择 FFmpegKit 或随包 FFmpeg。
      service = await ref.read(
        downloadArtifactConversionServiceProvider.future,
      );
      // 文本类资源不依赖 FFmpeg 编码器，视频和音频才需要按包型过滤选项。
      capabilities = switch (category) {
        DownloadArtifactConversionCategory.subtitle ||
        DownloadArtifactConversionCategory.danmaku =>
          DownloadArtifactConversionCapabilities.optimistic,
        _ => await service.conversionCapabilities(),
      };
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: '读取转换能力失败：${_conversionErrorMessage(error)}',
        type: AppSnackBarType.error,
      );
      return;
    } finally {
      // 能力探测结束后恢复按钮状态，再交给弹窗继续交互。
      _setConverting(false);
    }
    if (!mounted) return;
    // 用户选择输出参数后才真正访问 FFmpeg 或文本转换器。
    final options = await showDownloadArtifactConversionDialog(
      context: context,
      category: category,
      sourceExtension: widget.entry.extensionLabel,
      capabilities: capabilities,
    );
    // 弹窗关闭后页面可能已经被退出，此时不能再更新按钮状态。
    if (!mounted) return;
    // 取消弹窗不改变当前文件状态。
    if (options == null) return;
    _setConverting(true);
    try {
      // 当前文件路径来自下载产物索引，转换输出与源文件放在同目录。
      final result = await service.convert(
        sourcePath: widget.entry.path,
        category: category,
        options: options,
      );
      // 转换结果登记为新的保留产物，让详情页和后续清理都能追踪。
      await ref
          .read(downloadTaskRepositoryProvider)
          .upsertArtifact(
            DownloadArtifactDraft(
              taskId: widget.taskId,
              kind: _convertedArtifactKind(widget.entry.kind, category),
              path: result.path,
              sizeBytes: result.sizeBytes,
              retained: true,
            ),
          );
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: '转换完成：${p.basename(result.path)}',
        type: AppSnackBarType.success,
      );
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: '转换失败：${_conversionErrorMessage(error)}',
        type: AppSnackBarType.error,
      );
    } finally {
      // 页面仍存在时才恢复按钮状态。
      _setConverting(false);
    }
  }

  /// 同步卡片转换状态和页面级转换占用计数。
  void _setConverting(bool value, {bool refresh = true}) {
    // 相同状态不重复写入，避免转换计数被多次增减。
    if (_converting == value) return;
    _converting = value;
    // 页面仍在树上时刷新当前卡片按钮的 loading 状态。
    if (refresh && mounted) setState(() {});
    // 转换计数按当前任务 ID 分组，父级删除按钮只关心本任务。
    final controller = ref.read(_activeArtifactConversionsProvider.notifier);
    if (value) {
      controller.increment(widget.taskId);
    } else {
      controller.decrement(widget.taskId);
    }
  }

  /// 删除当前转换派生文件和对应产物索引。
  Future<void> _deleteConvertedFile() async {
    final fileName = p.basename(widget.entry.path);
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: const Text('删除转换文件'),
      content: Text('将删除“$fileName”和对应记录，原始下载文件不会受影响。'),
      confirmLabel: '删除',
    );
    if (!mounted || !confirmed) return;
    // Android 删除转换文件需要访问真实文件路径，权限被关闭时先让用户恢复授权。
    if (!await _ensureAndroidFileManagementPermission('删除转换文件')) return;
    setState(() => _deleting = true);
    try {
      // 文件存在时先删除实体文件，不存在则只清理数据库索引，修复外部手动删除后的残留记录。
      final file = File(widget.entry.path);
      if (await file.exists()) await file.delete();
      await ref
          .read(downloadTaskRepositoryProvider)
          .deleteArtifactByPath(
            taskId: widget.taskId,
            kind: widget.entry.kind,
            path: widget.entry.path,
          );
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: '已删除转换文件：$fileName',
        type: AppSnackBarType.success,
      );
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: '删除转换文件失败：$error',
        type: AppSnackBarType.error,
      );
    } finally {
      // 页面仍存在时才恢复按钮状态。
      if (mounted) setState(() => _deleting = false);
    }
  }

  /// 确保 Android 文件管理授权可用，非 Android 平台直接允许继续。
  Future<bool> _ensureAndroidFileManagementPermission(String actionName) async {
    final granted = await AndroidAppPermissions.ensureAllFilesAccess();
    if (granted) return true;
    if (!mounted) return false;
    AppSnackBar.show(
      context,
      message: '请开启文件管理授权后再$actionName。',
      type: AppSnackBarType.error,
    );
    return false;
  }
}

/// 文件卡片的标题、文件名和元信息文本块。
final class _TaskFileTextBlock extends StatelessWidget {
  /// 创建可在宽窄布局复用的文件文本块。
  const _TaskFileTextBlock({
    required this.entry,
    required this.fileName,
    required this.onOpenDirectory,
  });

  /// 当前本地文件条目，提供类型、时间、格式和大小。
  final _DownloadTaskFileEntry entry;

  /// 已清理为 basename 的文件名，空值时回退完整路径。
  final String fileName;

  /// 点击文件名时打开所在目录。
  final VoidCallback onOpenDirectory;

  /// 构建文件类型标题和文件名两行文本。
  @override
  Widget build(BuildContext context) {
    // 文件名展示值优先使用 basename，避免把完整路径直接挤进卡片。
    final displayName = fileName.isEmpty ? entry.path : fileName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _artifactKindLabel(entry.kind),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Tooltip(
          message: entry.path,
          child: InkWell(
            onTap: onOpenDirectory,
            mouseCursor: SystemMouseCursors.click,
            borderRadius: BorderRadius.circular(4),
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}

/// 返回适合直接展示给用户的转换错误文案。
String _conversionErrorMessage(Object error) {
  // 业务异常已经提供中文 message，去掉 Exception 类型名前缀让提示更像产品文案。
  if (error is MediaMergeException) return error.message;
  return error.toString();
}

/// 文件元数据短文本。
final class _FileMetaText extends StatelessWidget {
  /// 创建带图标的元数据。
  const _FileMetaText({required this.icon, required this.value});

  /// 元数据图标。
  final IconData icon;

  /// 元数据文本。
  final String value;

  /// 构建紧凑元数据。
  @override
  Widget build(BuildContext context) {
    // 文件元信息使用弱化颜色，突出主标题和文件名。
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.outline,
      fontWeight: FontWeight.w700,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 15, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 5),
        Text(value, style: style),
      ],
    );
  }
}

/// 详情页通用卡片。
final class _DetailCard extends StatelessWidget {
  /// 创建详情页卡片。
  const _DetailCard({required this.child});

  /// 卡片内容。
  final Widget child;

  /// 构建与任务列表一致的描边卡。
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

/// 详情页提示卡片。
final class _DetailMessageCard extends StatelessWidget {
  /// 创建提示卡片。
  const _DetailMessageCard({required this.message});

  /// 提示文案。
  final String message;

  /// 构建居中提示。
  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.outline,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// 任务不存在状态。
final class _TaskDetailMissingState extends StatelessWidget {
  /// 创建任务不存在状态。
  const _TaskDetailMissingState();

  /// 构建空状态。
  @override
  Widget build(BuildContext context) {
    return const _CenteredTaskDetailState(
      icon: Icons.search_off_rounded,
      title: '任务不存在',
      message: '这条下载记录可能已经被删除。',
    );
  }
}

/// 任务详情加载状态。
final class _TaskDetailLoadingState extends StatelessWidget {
  /// 创建加载状态。
  const _TaskDetailLoadingState();

  /// 构建加载状态。
  @override
  Widget build(BuildContext context) {
    return const _CenteredTaskDetailState(
      loading: true,
      title: '正在读取任务详情',
      message: '稍等一下，正在打开本地下载记录。',
    );
  }
}

/// 任务详情错误状态。
final class _TaskDetailErrorState extends StatelessWidget {
  /// 创建错误状态。
  const _TaskDetailErrorState({required this.message});

  /// 错误文案。
  final String message;

  /// 构建错误状态。
  @override
  Widget build(BuildContext context) {
    return _CenteredTaskDetailState(
      icon: Icons.error_outline_rounded,
      title: '打开详情失败',
      message: message,
    );
  }
}

/// 详情页居中状态。
final class _CenteredTaskDetailState extends StatelessWidget {
  /// 创建居中状态。
  const _CenteredTaskDetailState({
    required this.title,
    required this.message,
    this.icon,
    this.loading = false,
  });

  /// 状态标题。
  final String title;

  /// 状态说明。
  final String message;

  /// 非加载状态图标。
  final IconData? icon;

  /// 是否显示加载圈。
  final bool loading;

  /// 构建居中状态和返回按钮。
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (loading)
              const CircularProgressIndicator()
            else
              Icon(
                icon ?? Icons.info_outline_rounded,
                size: 54,
                color: Theme.of(context).colorScheme.outline,
              ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            AppActionButton(
              label: '返回任务列表',
              icon: Icons.arrow_back_rounded,
              onPressed: () {
                // 用户从异常状态返回任务列表。
                _leaveTaskDetail(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 任务键值行数据。
final class _TaskInfoRow {
  /// 创建键值行数据。
  const _TaskInfoRow({required this.label, required this.value});

  /// 字段名。
  final String label;

  /// 字段值。
  final String value;
}

/// 本地文件展示数据。
final class _DownloadTaskFileEntry {
  /// 创建本地文件展示数据。
  const _DownloadTaskFileEntry({
    required this.kind,
    required this.path,
    required this.sizeBytes,
    required this.createdAt,
    required this.canDelete,
  });

  /// 产物类型。
  final DownloadArtifactKind kind;

  /// 文件绝对路径。
  final String path;

  /// 文件大小，旧任务或检测失败时为空。
  final int? sizeBytes;

  /// 产物创建时间。
  final DateTime? createdAt;

  /// 是否允许从详情页单独删除实体文件和产物记录。
  final bool canDelete;

  /// 从路径后缀推导的文件类型。
  String get extensionLabel {
    // 后缀为空时回退为文件，避免显示空字符串。
    final extension = p.extension(path).replaceFirst('.', '').toUpperCase();
    return extension.isEmpty ? '文件' : extension;
  }
}

/// 合并任务产物和旧版 outputPath 回退。
List<_DownloadTaskFileEntry> _fileEntriesForTask(
  DownloadTaskRecord task,
  List<DownloadArtifactRecord> artifacts,
) {
  // 使用集合按类型和路径去重，避免补齐旧数据时重复展示同一文件。
  final seen = <String>{};
  // 页面最终展示的文件条目。
  final entries = <_DownloadTaskFileEntry>[];
  for (final artifact in artifacts) {
    // 封面已经在详情头图展示，本地文件区不再重复列出。
    if (artifact.kind == DownloadArtifactKind.cover) continue;
    // 详情页只展示真实文件路径，非文件系统标识不能参与打开、删除或转换。
    final path = _artifactDisplayPath(artifact);
    if (path == null) continue;
    // 同一任务可能因迁移或重试留下重复产物记录。
    final key = '${artifact.kind.name}|${p.normalize(path)}';
    if (!seen.add(key)) continue;
    // 原始输出文件属于任务本体，只有转换标记命中的派生文件允许单独删除。
    final isPrimaryOutput = _samePath(path, task.outputPath?.trim());
    entries.add(
      _DownloadTaskFileEntry(
        kind: artifact.kind,
        path: path,
        sizeBytes: artifact.sizeBytes,
        createdAt: artifact.createdAt,
        canDelete: !isPrimaryOutput && _isConvertedArtifactPath(path),
      ),
    );
  }
  // 旧版任务可能只有 outputPath，没有 download_artifacts.output 记录。
  final outputPath = task.outputPath?.trim();
  final hasOutput = entries.any(
    (_DownloadTaskFileEntry entry) => entry.kind == DownloadArtifactKind.output,
  );
  if (!hasOutput && outputPath != null && _isAbsoluteFilePath(outputPath)) {
    // 旧记录没有真实大小时使用解析阶段估算大小作为兜底。
    final estimatedBytes =
        (task.estimatedVideoSizeBytes ?? 0) +
        (task.estimatedAudioSizeBytes ?? 0);
    entries.insert(
      0,
      _DownloadTaskFileEntry(
        kind: DownloadArtifactKind.output,
        path: outputPath,
        sizeBytes: estimatedBytes > 0 ? estimatedBytes : null,
        createdAt: task.completedAt,
        canDelete: false,
      ),
    );
  }
  // 详情页固定最终视频优先，附加资源按常见查看顺序排在后面。
  entries.sort(
    (_DownloadTaskFileEntry left, _DownloadTaskFileEntry right) =>
        _artifactKindOrder(left.kind).compareTo(_artifactKindOrder(right.kind)),
  );
  return entries;
}

/// 把产物记录转换成当前页面可操作的真实文件路径。
String? _artifactDisplayPath(DownloadArtifactRecord artifact) {
  // 空路径和非绝对路径都无法作为详情页本地文件。
  final artifactPath = artifact.path.trim();
  if (artifactPath.isEmpty) return null;
  if (!_isAbsoluteFilePath(artifactPath)) return null;
  return artifactPath;
}

/// 判断路径是否为可直接访问的绝对文件路径。
bool _isAbsoluteFilePath(String storageIdentifier) {
  // 转换服务只能接收普通文件路径，不能把 URI 或相对路径传给 FFmpeg。
  final path = storageIdentifier.trim();
  return path.isNotEmpty && p.isAbsolute(path);
}

/// 判断两个本地路径是否指向同一个任务本体文件。
bool _samePath(String path, String? otherPath) {
  // 空路径不能作为本体路径比较，防止误把所有文件都识别为原始输出。
  if (otherPath == null || otherPath.isEmpty) return false;
  return p.equals(p.normalize(path), p.normalize(otherPath));
}

/// 判断路径是否符合转换派生文件命名。
bool _isConvertedArtifactPath(String path) {
  // 新版转换文件使用 [MP4_H264_AAC]，旧版临时产物可能仍是 [转换]。
  final baseName = p.basenameWithoutExtension(path);
  final markerMatch = RegExp(
    r'\[([A-Za-z0-9_]+|转换\d*)\]$',
  ).firstMatch(baseName);
  if (markerMatch == null) return false;
  final marker = markerMatch.group(1) ?? '';
  if (marker.startsWith('转换')) return true;
  final format = marker.split('_').first.toUpperCase();
  return _knownConversionOutputFormats.contains(format);
}

/// 详情页允许识别为转换派生文件的目标格式。
const Set<String> _knownConversionOutputFormats = <String>{
  'AAC',
  'AC3',
  'ASS',
  'AVI',
  'FLAC',
  'FLV',
  'M4A',
  'MKV',
  'MOV',
  'MP3',
  'MP4',
  'OGG',
  'OPUS',
  'SRT',
  'VTT',
  'WAV',
  'WEBM',
};

/// 将产物类型转换为详情页标题。
String _artifactKindLabel(DownloadArtifactKind kind) {
  // 面向用户展示的文件类型文案。
  return switch (kind) {
    DownloadArtifactKind.output => '有声视频',
    DownloadArtifactKind.standaloneAudio => '音频文件',
    DownloadArtifactKind.videoStream => '无声视频',
    DownloadArtifactKind.audioStream => '音频文件',
    DownloadArtifactKind.cover => '封面',
    DownloadArtifactKind.subtitle => '字幕',
    DownloadArtifactKind.danmaku => '弹幕',
    DownloadArtifactKind.resource => '附加资源',
  };
}

/// 推导本地文件可用的转换分类。
DownloadArtifactConversionCategory? _conversionCategoryForEntry(
  _DownloadTaskFileEntry entry,
) {
  // 产物类型优先于文件后缀，避免普通资源误判核心音视频分流。
  return switch (entry.kind) {
    DownloadArtifactKind.output =>
      DownloadArtifactConversionCategory.voicedVideo,
    DownloadArtifactKind.standaloneAudio =>
      DownloadArtifactConversionCategory.audio,
    DownloadArtifactKind.videoStream =>
      DownloadArtifactConversionCategory.silentVideo,
    DownloadArtifactKind.audioStream =>
      DownloadArtifactConversionCategory.audio,
    DownloadArtifactKind.subtitle =>
      DownloadArtifactConversionCategory.subtitle,
    DownloadArtifactKind.danmaku => DownloadArtifactConversionCategory.danmaku,
    DownloadArtifactKind.resource => _conversionCategoryForPath(entry.path),
    DownloadArtifactKind.cover => null,
  };
}

/// 从普通附加资源路径后缀推导转换分类。
DownloadArtifactConversionCategory? _conversionCategoryForPath(String path) {
  // 附加资源来自外部下载结果，只能按扩展名保守识别可转换类型。
  final extension = p.extension(path).toLowerCase();
  if (_videoExtensions.contains(extension)) {
    return DownloadArtifactConversionCategory.voicedVideo;
  }
  if (_audioExtensions.contains(extension)) {
    return DownloadArtifactConversionCategory.audio;
  }
  if (_subtitleExtensions.contains(extension)) {
    return DownloadArtifactConversionCategory.subtitle;
  }
  if (_danmakuExtensions.contains(extension)) {
    return DownloadArtifactConversionCategory.danmaku;
  }
  return null;
}

/// 转换后的产物类型。
DownloadArtifactKind _convertedArtifactKind(
  DownloadArtifactKind sourceKind,
  DownloadArtifactConversionCategory category,
) {
  // 已有明确业务类型的产物转换后仍保持原类型，方便清理和展示沿用旧逻辑。
  if (sourceKind != DownloadArtifactKind.resource) return sourceKind;
  // 普通附加资源按转换分类登记为更准确的产物类型。
  return switch (category) {
    DownloadArtifactConversionCategory.voicedVideo =>
      DownloadArtifactKind.output,
    DownloadArtifactConversionCategory.silentVideo =>
      DownloadArtifactKind.videoStream,
    DownloadArtifactConversionCategory.audio =>
      DownloadArtifactKind.standaloneAudio,
    DownloadArtifactConversionCategory.subtitle =>
      DownloadArtifactKind.subtitle,
    DownloadArtifactConversionCategory.danmaku => DownloadArtifactKind.danmaku,
  };
}

/// 可按视频封装处理的扩展名。
const Set<String> _videoExtensions = <String>{
  '.avi',
  '.flv',
  '.m4v',
  '.mkv',
  '.mov',
  '.mp4',
  '.ts',
  '.webm',
};

/// 可按音频文件处理的扩展名。
const Set<String> _audioExtensions = <String>{
  '.aac',
  '.flac',
  '.m4a',
  '.mp3',
  '.ogg',
  '.opus',
  '.wav',
};

/// 可按字幕文件处理的扩展名。
const Set<String> _subtitleExtensions = <String>{
  '.ass',
  '.json',
  '.srt',
  '.vtt',
};

/// 可按弹幕文件处理的扩展名。
const Set<String> _danmakuExtensions = <String>{'.xml'};

/// 将产物类型转换为详情页图标。
IconData _artifactIcon(DownloadArtifactKind kind) {
  // 图标只表达文件大类，不承载业务状态。
  return switch (kind) {
    DownloadArtifactKind.output ||
    DownloadArtifactKind.videoStream => Icons.movie_outlined,
    DownloadArtifactKind.standaloneAudio ||
    DownloadArtifactKind.audioStream => Icons.music_note_rounded,
    DownloadArtifactKind.cover => Icons.image_outlined,
    DownloadArtifactKind.subtitle => Icons.subtitles_outlined,
    DownloadArtifactKind.danmaku => Icons.chat_bubble_outline_rounded,
    DownloadArtifactKind.resource => Icons.attach_file_rounded,
  };
}

/// 详情页返回任务列表。
void _leaveTaskDetail(BuildContext context) {
  // 普通 push 进入时弹回上一页，外部直达时回到任务列表根路由。
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  // 深链或刷新直达详情页时没有上一页，显式回到任务页。
  context.go('/tasks');
}

/// 产物类型展示顺序。
int _artifactKindOrder(DownloadArtifactKind kind) {
  // 按用户关注度排序，最终视频优先，诊断价值较低的资源靠后。
  return switch (kind) {
    DownloadArtifactKind.output => 0,
    DownloadArtifactKind.standaloneAudio => 1,
    DownloadArtifactKind.cover => 2,
    DownloadArtifactKind.subtitle => 3,
    DownloadArtifactKind.danmaku => 4,
    DownloadArtifactKind.resource => 5,
    DownloadArtifactKind.videoStream => 6,
    DownloadArtifactKind.audioStream => 7,
  };
}
