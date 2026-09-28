import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/app_anchored_dropdown.dart';
import '../../../../core/widgets/app_icon_buttons.dart';
import '../../../../core/widgets/app_popup_menu_items.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/app_swipe_reveal_action.dart';
import '../../../../core/widgets/app_tooltip.dart';
import '../../domain/download_extra_resource.dart';
import '../../domain/download_task_phase.dart';
import '../../domain/stored_dash_options.dart';
import '../utils/download_task_formatters.dart';
import '../utils/download_output_directory_opener.dart';
import 'download_task_controls.dart';
import 'download_task_progress.dart';
import 'download_task_summary.dart';
import 'download_task_mobile_summaries.dart';

/// 按业务任务监听音频和视频分流的实时状态。
final _downloadStreamListProvider = StreamProvider.autoDispose
    .family<List<DownloadStreamRecord>, String>((Ref ref, taskId) {
      // 分流变化频率高于主任务，独立监听避免给非活动卡片附加状态字段；
      // 卡片离开懒加载列表后立即释放 Drift 订阅，历史任务不能按 ID 永久占用内存。
      return ref.watch(downloadTaskRepositoryProvider).watchStreams(taskId);
    });

/// 单条任务的桌面行或手机卡片。
final class DownloadTaskItem extends ConsumerWidget {
  /// 桌面三类任务统一使用参考图指定的固定封面宽度。
  static const double _desktopCoverWidth = 204;

  /// 桌面三类任务统一使用参考图指定的固定封面高度。
  static const double _desktopCoverHeight = 110;

  /// 桌面封面与右侧详情之间保留固定间距。
  static const double _desktopCoverGap = 16;

  /// 创建任务项。
  const DownloadTaskItem({
    required this.task,
    required this.compact,
    required this.storagePath,
    required this.starting,
    required this.togglingPause,
    required this.pauseControlDisabled,
    required this.onStart,
    required this.onTogglePause,
    required this.onDelete,
    required this.onSelectAudio,
    required this.onSelectVideo,
    required this.onClearAudio,
    required this.onClearVideo,
    required this.availableExtraResources,
    required this.onExtraResourcesChanged,
    this.onOpenDetails,
    super.key,
  });

  /// Drift 持久化任务快照。
  final DownloadTaskRecord task;

  /// 是否使用手机布局。
  final bool compact;

  /// Android 系统文件管理器用于定位当前成品根目录的逻辑或绝对路径。
  final String storagePath;

  /// 是否正在刷新播放地址。
  final bool starting;

  /// 暂停或继续操作是否仍在等待后端完整返回。
  final bool togglingPause;

  /// 是否因批量操作禁用暂停或继续按钮。
  final bool pauseControlDisabled;

  /// 下载或重试回调。
  final VoidCallback onStart;

  /// 暂停或恢复当前任务回调。
  final VoidCallback onTogglePause;

  /// 移除回调。
  final VoidCallback onDelete;

  /// 保存音频候选回调。
  final ValueChanged<StoredAudioOption> onSelectAudio;

  /// 保存视频候选回调。
  final ValueChanged<StoredVideoOption> onSelectVideo;

  /// 取消当前音频选择。
  final VoidCallback onClearAudio;

  /// 取消当前视频选择。
  final VoidCallback onClearVideo;

  /// 设置中心允许当前卡片展示的附加资源。
  final Set<DownloadExtraResource> availableExtraResources;

  /// 保存当前主任务的附加资源复选集合。
  final ValueChanged<Set<DownloadExtraResource>> onExtraResourcesChanged;

  /// 已下载任务进入详情页的回调，未传时卡片不承担页面跳转。
  final VoidCallback? onOpenDetails;

  /// 构建任务卡片内统一尺寸的圆形图标操作。
  Widget _buildTaskIconButton({
    required Widget icon,
    required String tooltip,
    required VoidCallback? onPressed,
    AppCircleIconButtonVariant variant = AppCircleIconButtonVariant.plain,
  }) {
    // 下载列表内的图标操作都使用 32dp 点击区，避免各处重复约束和原生按钮最小高度。
    return AppCircleIconButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      variant: variant,
      size: AppCircleIconButtonSize.small,
    );
  }

  /// 按断点构建任务项。
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 附加资源任务在排队、失败和完成阶段也需要读取真实资源大小。
    final extraResource = downloadExtraResourceFromCode(task.contentType);
    // 桌面活动任务或任意平台附加资源任务监听分流字节信息。
    final streams = (_usesDesktopProgressLayout() || extraResource != null)
        ? ref.watch(_downloadStreamListProvider(task.taskId)).value ??
              const <DownloadStreamRecord>[]
        : const <DownloadStreamRecord>[];
    // 手机使用纵向卡片，桌面使用图二的横向长条卡片。
    if (compact) return _buildMobile(context, streams);
    // 桌面任务使用完整边框卡片，不再使用会挤压标题的表格分栏。
    // 桌面端已下载任务整体可点击进入详情，其他阶段继续只响应行内按钮。
    final desktopCard = Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Stack(
          children: <Widget>[
            SizedBox(
              // 右侧详情严格跟随固定封面高度，任何任务阶段都不能继续撑高卡片。
              height: _desktopCoverHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // 左侧占位使用固定封面宽度和详情间距，不再预留复选框区域。
                  const SizedBox(width: _desktopCoverWidth + _desktopCoverGap),
                  Expanded(child: _buildDesktopDetails(context, streams)),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: _desktopCoverWidth,
              height: _desktopCoverHeight,
              // 桌面三类任务都固定为参考图尺寸，不再随卡片宽度或详情高度伸缩。
              child: _buildDesktopCover(context, extraResource: extraResource),
            ),
          ],
        ),
      ),
    );
    if (onOpenDetails == null) return desktopCard;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpenDetails,
        child: Semantics(button: true, child: desktopCard),
      ),
    );
  }

  /// 构建桌面封面，并在主视频上叠加 UP 名称。
  Widget _buildDesktopCover(
    BuildContext context, {
    required DownloadExtraResource? extraResource,
  }) {
    // PC 主视频三类长条卡片都把发布者压到封面左上，右侧留给阶段信息和简介。
    final shouldShowPublisher = extraResource == null;
    // 发布者名称来自解析任务快照，空值时不占用封面空间。
    final publisherName = task.publisherName?.trim();
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        TaskCover(
          task: task,
          width: _desktopCoverWidth,
          height: _desktopCoverHeight,
        ),
        if (shouldShowPublisher &&
            publisherName != null &&
            publisherName.isNotEmpty)
          Positioned(
            left: 8,
            top: 8,
            right: 8,
            child: Align(
              alignment: Alignment.topLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: AppTooltip(
                    message: publisherName,
                    child: Text(
                      publisherName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 构建图二右侧的标题、资源操作、质量选择和媒体说明。
  Widget _buildDesktopDetails(
    BuildContext context,
    List<DownloadStreamRecord> streams,
  ) {
    // 封面、弹幕和字幕使用独立资源卡片，不展示无意义的音质与画质字段。
    final extraResource = downloadExtraResourceFromCode(task.contentType);
    if (extraResource != null && !_usesDesktopProgressLayout()) {
      return _buildDesktopExtraResourceDetails(context, streams, extraResource);
    }
    // 已下载任务使用专用完成卡片，突出完成信息和常用文件操作。
    if (task.phase == DownloadTaskPhase.completed) {
      return _buildDesktopCompletedDetails(context);
    }
    // 下载中页签使用专用进度卡片结构，不继续展示待下载质量选择布局。
    if (_usesDesktopProgressLayout()) {
      return _buildDesktopProgressDetails(context, streams);
    }
    // 当前任务已经随 Drift 列表携带候选 JSON，这里同步解码且不再查询数据库。
    final storedOptions = storedDashOptionsForTask(task);
    // 缺少候选清单时返回空列表并禁用下拉。
    final audioOptions = storedOptions?.audios ?? const <StoredAudioOption>[];
    // 视频候选与音频候选使用同一份解析快照。
    final videoOptions = storedOptions?.videos ?? const <StoredVideoOption>[];
    // 只有尚未启动的待下载任务允许修改音视频质量；失败重试使用原解析快照避免状态漂移。
    final qualityEditable = task.phase == DownloadTaskPhase.queued;
    // 音质根据任务阶段切换为下拉字段或只读文字。
    final audioField = qualityEditable
        ? DesktopOptionField<StoredAudioOption>(
            label: '音质',
            value: audioLabel(task),
            options: audioOptions,
            labelBuilder: audioOptionLabel,
            selectedBuilder: (StoredAudioOption option) =>
                option.qualityId == task.audioQualityId,
            onSelected: onSelectAudio,
            onClear: onClearAudio,
            cleared: task.audioQualityId == null,
          )
        : DesktopReadOnlyOption(label: '音质', value: audioLabel(task));
    // 画质根据任务阶段切换为下拉字段或只读文字。
    final videoField = qualityEditable
        ? DesktopOptionField<StoredVideoOption>(
            label: '画质',
            value: videoLabel(task),
            options: videoOptions,
            labelBuilder: videoOptionLabel,
            selectedBuilder: (StoredVideoOption option) =>
                option.qualityId == task.qualityId &&
                option.codec.name == task.videoCodec,
            onSelected: onSelectVideo,
            onClear: onClearVideo,
            cleared: task.qualityId == null,
          )
        : DesktopReadOnlyOption(label: '画质', value: videoLabel(task));
    // 桌面详情正文统一降一级，缩小音视频、状态和底部操作文字。
    final detailsTextStyle = Theme.of(context).textTheme.bodySmall;
    // 标题始终保持单行，窄桌面由标题自身省略而不是把右侧内容堆叠。
    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(child: DesktopTaskTitle(task: task)),
        const SizedBox(width: 8),
        _buildDesktopTopAction(context),
      ],
    );
    // 中间行把质量控件宽度优先保留，文件大小区域只使用剩余空间。
    final mediaOptions = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 每个“标签 + 下拉框”控制组在宽屏下保持紧凑最大宽度。
        const maximumQualityControlWidth = 228.0;
        // 窄桌面允许质量控制组收缩，但仍保留当前值和箭头的基本空间。
        const minimumQualityControlWidth = 145.0;
        // audio/video 弹性区优先保留的最小可识别宽度。
        const preferredMinimumMetricsWidth = 120.0;
        // 弹性区与两个质量控制组之间使用两段固定间距。
        const totalGaps = 16.0;
        // 质量控制组只在空间不足时收缩，宽屏达到上限后不再分散拉伸。
        final qualityControlWidth =
            ((constraints.maxWidth - preferredMinimumMetricsWidth - totalGaps) /
                    2)
                .clamp(minimumQualityControlWidth, maximumQualityControlWidth)
                .toDouble();
        // audio/video 使用两个紧凑质量控制组之外的全部剩余空间。
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  DesktopMetric(
                    label: 'audio:',
                    value: fileSizeLabel(task.estimatedAudioSizeBytes),
                  ),
                  const SizedBox(height: 2),
                  DesktopMetric(
                    label: 'video:',
                    value: fileSizeLabel(task.estimatedVideoSizeBytes),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: qualityControlWidth, child: audioField),
            const SizedBox(width: 8),
            SizedBox(width: qualityControlWidth, child: videoField),
          ],
        );
      },
    );
    // 三层内容在固定封面高度内均匀分布，与左侧封面上下对齐。
    return DefaultTextStyle.merge(
      style: detailsTextStyle,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(height: 32, child: heading),
          SizedBox(height: 34, child: mediaOptions),
          SizedBox(height: 34, child: _buildDesktopMetadata(context)),
        ],
      ),
    );
  }

  /// 构建附加资源排队、失败或完成状态的专用桌面内容。
  Widget _buildDesktopExtraResourceDetails(
    BuildContext context,
    List<DownloadStreamRecord> streams,
    DownloadExtraResource resource,
  ) {
    // 资源分流优先使用服务端总大小，缺失时回退当前已下载字节。
    final resourceBytes = resourceSizeBytes(streams);
    // 失败状态显示真实原因，其余状态显示最终文件名或独立任务说明。
    final detailText = _extraResourceDetailText();
    final detailColor = task.phase == DownloadTaskPhase.failed
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;
    // 标题右侧同时保留阶段状态；排队和失败任务额外提供移除入口。
    final heading = Row(
      children: <Widget>[
        Expanded(child: DesktopTaskTitle(task: task)),
        Text(
          phaseLabel(task.phase),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: task.phase == DownloadTaskPhase.failed
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (task.phase == DownloadTaskPhase.queued ||
            task.phase == DownloadTaskPhase.failed) ...<Widget>[
          const SizedBox(width: 4),
          _buildTaskIconButton(
            onPressed: starting ? null : onDelete,
            icon: const Icon(Icons.close_rounded),
            tooltip: '移除任务',
          ),
        ],
      ],
    );
    // 中间只展示资源任务真正有意义的类型和大小。
    final resourceSummary = Row(
      children: <Widget>[
        Text(
          '任务类型：',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          downloadExtraResourceLabel(resource),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 24),
        Text(
          '资源大小：',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          resourceBytes > 0 ? fileSizeLabel(resourceBytes) : '未知',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
    // 底部错误或文件信息与重试、打开目录、删除记录操作保持同一行。
    final footer = Row(
      children: <Widget>[
        Expanded(
          child: Text(
            detailText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: detailColor),
          ),
        ),
        const SizedBox(width: 8),
        _buildDesktopBottomActions(context),
      ],
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(height: 32, child: heading),
        SizedBox(height: 30, child: resourceSummary),
        SizedBox(height: 34, child: footer),
      ],
    );
  }

  /// 返回下载摘要中应展示的已下载字节数。
  int _downloadedBytesForDisplay({
    required List<DownloadStreamRecord> streams,
    required int actualDownloadedBytes,
    required int displayTotalBytes,
    required double progress,
  }) {
    // 有分流记录时始终使用真实完成字节，避免估算覆盖实时状态。
    if (streams.isNotEmpty) return actualDownloadedBytes;
    // 无分流记录但总量已知时按主任务进度估算历史数据。
    if (displayTotalBytes > 0) return (displayTotalBytes * progress).round();
    // 总量和分流都不可用时只展示 0，避免出现负数或未知计算。
    return 0;
  }

  /// 返回附加资源任务在桌面详情区展示的说明文本。
  String _extraResourceDetailText() {
    // 失败状态优先展示真实错误，帮助用户判断是否重试。
    final errorMessage = task.errorMessage?.trim();
    if (errorMessage != null && errorMessage.isNotEmpty) {
      return '错误：$errorMessage';
    }
    // 已规划输出路径时展示最终文件名，避免泄露完整本地路径。
    final outputPath = task.outputPath?.trim();
    if (outputPath != null && outputPath.isNotEmpty) {
      return '文件：${p.basename(outputPath)}';
    }
    // 待下载或历史旧记录没有路径时使用通用说明。
    return '独立资源下载任务';
  }

  /// 构建与下载中卡片同一视觉体系的桌面已下载详情。
  Widget _buildDesktopCompletedDetails(BuildContext context) {
    // 完成时间优先使用任务终态时间，旧记录回退最近更新时间。
    final completedAt = task.completedAt ?? task.updatedAt;
    // BVID 存在时开放复制入口。
    final canCopyBvid = task.bvid?.trim().isNotEmpty == true;
    // 能构造 B 站页面地址时开放浏览器入口。
    final pageUri = _bilibiliPageUri();
    // 输出路径存在时开放文件夹入口，点击后仍会检查目录是否存在。
    final canOpenDirectory = task.outputPath?.trim().isNotEmpty == true;
    // 已下载总量沿用解析时保存的音视频大小，旧记录为空时显示未知。
    final totalBytes = <int?>[
      task.estimatedAudioSizeBytes,
      task.estimatedVideoSizeBytes,
    ].whereType<int>().fold<int>(0, (int total, int bytes) => total + bytes);
    // 已下载右侧第一行改展示简介，发布者已经移动到封面叠层。
    final descriptionText = task.description?.trim().isNotEmpty == true
        ? task.description!.trim()
        : '-';
    // 次级文字统一使用主题弱化色，保持和下载中卡片一致。
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return DefaultTextStyle.merge(
      style: Theme.of(context).textTheme.bodySmall,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 38,
            child: Row(
              children: <Widget>[
                Expanded(child: DesktopTaskTitle(task: task)),
                const SizedBox(width: 8),
                Text(
                  dateLabel(completedAt),
                  maxLines: 1,
                  style: TextStyle(
                    color: secondary,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _buildTaskIconButton(
                  onPressed: canCopyBvid ? () => _copyBvid(context) : null,
                  icon: const Icon(Icons.content_copy_rounded),
                  tooltip: '复制 BV',
                ),
                const SizedBox(width: 2),
                _buildTaskIconButton(
                  onPressed: pageUri == null
                      ? null
                      : () => _openBilibiliPage(context, pageUri),
                  icon: const Icon(Icons.link_rounded),
                  tooltip: '浏览器打开',
                ),
                const SizedBox(width: 2),
                _buildTaskIconButton(
                  onPressed: canOpenDirectory
                      ? () async {
                          // 已完成任务通过系统文件管理器打开成品所在目录。
                          await _openOutputDirectory(context);
                        }
                      : null,
                  icon: const Icon(Icons.folder_open_rounded),
                  tooltip: '打开文件所在目录',
                ),
                const SizedBox(width: 2),
                _buildTaskIconButton(
                  variant: AppCircleIconButtonVariant.destructivePlain,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: '删除记录',
                ),
              ],
            ),
          ),
          // 分隔线把标题操作与完成信息分成上下两层。
          Divider(height: 1, color: Theme.of(context).dividerColor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '简介  $descriptionText',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: secondary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        mediaTaskTypeLabel(task),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: secondary),
                      ),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '音质  ${audioLabel(task)}   ·   画质  ${videoLabel(task)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: secondary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        totalBytes > 0 ? fileSizeLabel(totalBytes) : '大小未知',
                        style: TextStyle(color: secondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 复制当前任务的 BVID 并提供顶部反馈。
  Future<void> _copyBvid(BuildContext context) async {
    // 已完成卡片只有 BVID 非空时才会开放此入口。
    final bvid = task.bvid?.trim();
    // 防御旧记录缺少视频标识的异常调用。
    if (bvid == null || bvid.isEmpty) return;
    try {
      // 系统剪贴板保存纯 BVID，方便用户继续粘贴解析或分享。
      await Clipboard.setData(ClipboardData(text: bvid));
      // 异步返回后只在卡片仍存在时展示成功提示。
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        message: '已复制 $bvid。',
        type: AppSnackBarType.success,
        position: AppSnackBarPosition.top,
      );
    } catch (error) {
      // 平台剪贴板不可用时保留卡片，并提供可见的失败原因。
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        message: '复制 BV 号失败：$error',
        type: AppSnackBarType.error,
        position: AppSnackBarPosition.top,
      );
    }
  }

  /// 根据任务身份构造可在浏览器打开的 B 站页面。
  Uri? _bilibiliPageUri() {
    // 普通视频优先使用稳定 BVID，并保留多 P 的集序号。
    final bvid = task.bvid?.trim();
    if (bvid != null && bvid.isNotEmpty) {
      // 第一 P 无需额外查询参数，其余分集带上对应序号。
      final query = task.partIndex > 1
          ? <String, String>{'p': '${task.partIndex}'}
          : null;
      // 使用官方 HTTPS 地址交给系统默认浏览器。
      return Uri.https('www.bilibili.com', '/video/$bvid', query);
    }
    // PGC 任务没有 BVID 时使用稳定 EP 地址。
    if (task.epid != null) {
      // EP ID 来自解析结果，不复用可能带追踪参数的原输入。
      return Uri.https('www.bilibili.com', '/bangumi/play/ep${task.epid}');
    }
    // 旧记录回退用户原始输入，但只接受 HTTP(S) 链接。
    final sourceUri = Uri.tryParse(task.sourceInput.trim());
    if (sourceUri != null &&
        (sourceUri.scheme == 'https' || sourceUri.scheme == 'http')) {
      // 合法网络链接可直接交给系统浏览器。
      return sourceUri;
    }
    // 无法确定页面时禁用浏览器按钮。
    return null;
  }

  /// 使用系统默认浏览器打开任务对应的 B 站页面。
  Future<void> _openBilibiliPage(BuildContext context, Uri uri) async {
    try {
      // 外部应用模式避免在 Flutter 窗口内创建不一致的网页容器。
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      // 系统没有可用处理程序时转为可见错误。
      if (!opened) throw StateError('系统未能打开浏览器。');
    } catch (error) {
      // 异步系统调用返回时先确认卡片仍在 Widget 树中。
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        message: '打开网页失败：$error',
        type: AppSnackBarType.error,
        position: AppSnackBarPosition.top,
      );
    }
  }

  /// 判断任务是否属于桌面下载进度专用布局。
  bool _usesDesktopProgressLayout() {
    // 下载中页签包含等待启动、解析、下载、等待合并、合并和暂停状态。
    return switch (task.phase) {
      DownloadTaskPhase.waitingToStart ||
      DownloadTaskPhase.resolving ||
      DownloadTaskPhase.downloading ||
      DownloadTaskPhase.waitingForMerge ||
      DownloadTaskPhase.merging ||
      DownloadTaskPhase.paused => true,
      _ => false,
    };
  }

  /// 构建符合本项目主题的桌面下载进度卡片详情。
  Widget _buildDesktopProgressDetails(
    BuildContext context,
    List<DownloadStreamRecord> streams,
  ) {
    // 进度值先限制到合法范围，防御旧数据或迟到事件产生异常值。
    final progress = task.progress.clamp(0.0, 1.0).toDouble();
    // 预计总量由解析阶段保存的音频和视频流大小相加得到。
    final estimatedTotalBytes =
        <int?>[task.estimatedAudioSizeBytes, task.estimatedVideoSizeBytes]
            .whereType<int>()
            .where((int bytes) => bytes > 0)
            .fold<int>(0, (int total, int bytes) => total + bytes);
    // 两条分流都提供总字节时使用下载引擎的真实总量，不继续依赖码率估算。
    final hasActualTotal =
        streams.isNotEmpty &&
        streams.every(
          (DownloadStreamRecord stream) => (stream.totalBytes ?? 0) > 0,
        );
    // 分流已下载字节来自 aria2 或系统下载后端的实时事件。
    final actualDownloadedBytes = streams.fold<int>(
      0,
      (int total, DownloadStreamRecord stream) =>
          total + stream.downloadedBytes,
    );
    // 分流总量完整时累加真实音视频大小。
    final actualTotalBytes = hasActualTotal
        ? streams.fold<int>(
            0,
            (int total, DownloadStreamRecord stream) =>
                total + (stream.totalBytes ?? 0),
          )
        : 0;
    // 真实总量不可用时回退解析阶段预计值，历史数据仍能展示摘要。
    final displayTotalBytes = hasActualTotal
        ? actualTotalBytes
        : estimatedTotalBytes;
    // 有分流记录时始终使用真实完成字节，否则再按主任务进度估算。
    final downloadedBytes = _downloadedBytesForDisplay(
      streams: streams,
      actualDownloadedBytes: actualDownloadedBytes,
      displayTotalBytes: displayTotalBytes,
      progress: progress,
    );
    // 零字节需要显示明确数值，不能复用“未知”占位。
    final downloadedLabel = downloadedBytes == 0
        ? '0 B'
        : fileSizeLabel(downloadedBytes);
    // 只有真实下载阶段且双流汇总速度有效时才展示网络速度。
    final speedLabel =
        task.phase == DownloadTaskPhase.downloading &&
            task.downloadSpeedBytesPerSecond > 0
        ? '${fileSizeLabel(task.downloadSpeedBytesPerSecond)}/s'
        : null;
    // 传输摘要按任务阶段展示真实业务含义，合并阶段不继续伪装成网络下载。
    final transferLabel = switch (task.phase) {
      DownloadTaskPhase.waitingToStart => '等待并发下载名额',
      DownloadTaskPhase.resolving => '正在获取音视频下载地址',
      DownloadTaskPhase.waitingForMerge => '音视频下载完成，正在等待合并',
      DownloadTaskPhase.merging => '音视频下载完成，正在生成最终文件',
      _ when displayTotalBytes > 0 =>
        '${hasActualTotal ? '已下载' : '约已下载'}： '
            '$downloadedLabel / ${fileSizeLabel(displayTotalBytes)}',
      _ => '已下载进度',
    };
    // 自动刷新 URL 后分流会短暂回到 queued，此时展示明确重试状态。
    final retrying =
        task.phase == DownloadTaskPhase.downloading &&
        task.retryCount > 0 &&
        streams.any(
          (DownloadStreamRecord stream) =>
              stream.phase == DownloadStreamPhase.queued,
        );
    // 当前处理对象根据真实分流状态映射为音频、视频、音视频或合并。
    final currentWorkLabel = mediaTaskTypeLabel(task);
    // 进入等待合并或合并阶段后立即隐藏暂停入口，避免向已结束的下载后端发出请求。
    final canTogglePause = canToggleDownloadTaskPause(task.phase);
    // 输出路径存在时允许打开最终文件所在目录，目录存在性由点击处理再次验证。
    final canOpenDirectory = task.outputPath?.trim().isNotEmpty == true;
    // 当前阶段使用品牌色强调，与应用页签和下载按钮保持一致。
    final primary = Theme.of(context).colorScheme.primary;
    // 暂停标签使用中性色，活动和重试标签继续使用主色。
    final activityColor = task.phase == DownloadTaskPhase.paused
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : primary;
    // 与下载后端常见状态名称保持一致，方便用户和日志对照。
    final activityLabel = task.phase == DownloadTaskPhase.paused
        ? 'paused'
        : 'active';
    // 解析和合并阶段没有可靠百分比，使用阶段标签代替误导性的 0% 或 100%。
    final progressLabel = switch (task.phase) {
      DownloadTaskPhase.waitingToStart => '等待中',
      DownloadTaskPhase.resolving => '解析中',
      DownloadTaskPhase.waitingForMerge => '等待合并',
      DownloadTaskPhase.merging => '合并中',
      _ => '${(progress * 100).round()}%',
    };
    return DefaultTextStyle.merge(
      style: Theme.of(context).textTheme.bodySmall,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 38,
            child: Row(
              children: <Widget>[
                Expanded(child: DesktopTaskTitle(task: task)),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: '当前任务： ',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        TextSpan(
                          text: currentWorkLabel,
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (canTogglePause) ...<Widget>[
                  const SizedBox(width: 4),
                  _buildTaskIconButton(
                    variant: AppCircleIconButtonVariant.primaryPlain,
                    onPressed: togglingPause || pauseControlDisabled
                        ? null
                        : onTogglePause,
                    icon: togglingPause
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_pauseToggleIcon, size: 20),
                    tooltip: _pauseToggleTooltip,
                  ),
                ],
                if (canOpenDirectory) ...<Widget>[
                  const SizedBox(width: 4),
                  _buildTaskIconButton(
                    onPressed: () async {
                      // 打开当前任务最终输出文件所在目录。
                      await _openOutputDirectory(context);
                    },
                    icon: const Icon(Icons.folder_open_rounded),
                    tooltip: '打开文件所在目录',
                  ),
                ],
                const SizedBox(width: 4),
                _buildTaskIconButton(
                  variant: AppCircleIconButtonVariant.destructivePlain,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: '停止并删除任务',
                ),
              ],
            ),
          ),
          // 分隔线把标题操作和传输进度明确分成上下两层。
          Divider(height: 1, color: Theme.of(context).dividerColor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          transferLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (retrying) ...<Widget>[
                        const SizedBox(width: 12),
                        SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(
                            '重试中，可能需要一些时间…',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ] else if (speedLabel != null) ...<Widget>[
                        const SizedBox(width: 12),
                        Text(
                          speedLabel,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(width: 10),
                      // 百分比和阶段使用胶囊标签，避免纯文字漂浮在卡片右侧。
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          progressLabel,
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 后端活动状态与参考图一致，暂停和运行可一眼区分。
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: activityColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          activityLabel,
                          style: TextStyle(
                            color: activityColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedTaskProgressBar(
                    progress: progress,
                    phase: task.phase,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建桌面端发布信息、简介和当前阶段操作区。
  Widget _buildDesktopMetadata(BuildContext context) {
    // 失败任务优先展示错误原因，其他阶段继续展示视频简介。
    final detailText = task.errorMessage?.trim().isNotEmpty == true
        ? '错误： ${task.errorMessage!.trim()}'
        : '简介： ${task.description?.trim().isNotEmpty == true ? task.description!.trim() : '-'}';
    // 错误详情使用语义错误色，其余元数据使用次级正文色。
    final detailColor = task.errorMessage?.trim().isNotEmpty == true
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;
    // 左侧两行文字自动占据阶段操作之外的全部宽度。
    final metadata = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '发布： ${dateLabel(task.publishedAt ?? task.createdAt)}   '
          '时长： ${durationLabel(task.durationMilliseconds)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          detailText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: detailColor, height: 1),
        ),
      ],
    );
    // 每个阶段都把元数据和对应操作放在同一行，避免追加第四层内容。
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(child: metadata),
        const SizedBox(width: 8),
        _buildDesktopBottomActions(context),
      ],
    );
  }

  /// 根据任务阶段构建底部紧凑操作或进度摘要。
  Widget _buildDesktopBottomActions(BuildContext context) {
    // 待下载任务保留附加内容菜单，并把文字下载胶囊改成图标按钮。
    if (task.phase == DownloadTaskPhase.queued) {
      return _buildDesktopQueuedActions(context);
    }
    // 失败任务在底部提供紧凑重试图标，不再占用标题行高度。
    if (task.phase == DownloadTaskPhase.failed) {
      return _buildTaskIconButton(
        variant: AppCircleIconButtonVariant.warningPlain,
        onPressed: starting ? null : onStart,
        icon: starting
            ? const SizedBox.square(
                dimension: 15,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh_rounded),
        tooltip: '重试下载',
      );
    }
    // 已完成任务保留打开目录和删除记录两个图标入口。
    if (task.phase == DownloadTaskPhase.completed) {
      // 输出路径存在时才允许打开目录，避免历史数据空路径触发无效系统调用。
      final canOpenDirectory = task.outputPath?.trim().isNotEmpty == true;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildTaskIconButton(
            onPressed: canOpenDirectory
                ? () async {
                    // 用户点击后打开最终文件所在目录。
                    await _openOutputDirectory(context);
                  }
                : null,
            icon: const Icon(Icons.folder_open_rounded),
            tooltip: '打开文件所在目录',
          ),
          const SizedBox(width: 4),
          _buildTaskIconButton(
            variant: AppCircleIconButtonVariant.destructivePlain,
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: '删除下载记录',
          ),
        ],
      );
    }
    // 下载中和暂停阶段由专用进度详情处理，其他不可见阶段不提供操作。
    return const SizedBox.shrink();
  }

  /// 调用系统文件管理器打开任务真实输出目录。
  Future<void> _openOutputDirectory(BuildContext context) async {
    // 已完成任务的最终输出路径用于推导父目录，未完成任务回退当前成品根目录。
    final outputPath = task.outputPath?.trim();
    final directoryPath =
        task.phase == DownloadTaskPhase.completed &&
            outputPath != null &&
            outputPath.isNotEmpty
        ? p.dirname(outputPath)
        : storagePath;
    // Android 和桌面都必须使用真实目录路径，避免旧 URI 或逻辑路径影响重试、删除和转换。
    await openDownloadOutputDirectory(context, directoryPath);
  }

  /// 构建手机端封面纵向卡片。
  Widget _buildMobile(
    BuildContext context,
    List<DownloadStreamRecord> streams,
  ) {
    // 待下载主视频在手机端使用长条卡片，删除移入侧滑，降低列表高度。
    if (task.phase == DownloadTaskPhase.queued ||
        task.phase == DownloadTaskPhase.failed) {
      return _buildMobileQueuedStrip(context);
    }
    // 已下载页使用横向长条卡片，减少重复媒体参数占用的垂直空间。
    if (task.phase == DownloadTaskPhase.completed) {
      return _buildMobileCompletedStrip(context, streams);
    }
    // 下载中页签同样使用长条，避免大封面在手机端占用过多空间。
    if (_usesDesktopProgressLayout()) {
      return _buildMobileProgressStrip(context, streams);
    }
    // 当前三个页签不会展示取消等隐藏阶段；兜底仍用下载中长条，避免旧大卡片回流。
    return _buildMobileProgressStrip(context, streams);
  }

  /// 构建手机已下载横向长条卡片。
  Widget _buildMobileCompletedStrip(
    BuildContext context,
    List<DownloadStreamRecord> streams,
  ) {
    // 长条卡片只保留标题、发布者、类型和大小，隐藏音画质与时间类低优先信息。
    final extraResource = downloadExtraResourceFromCode(task.contentType);
    // 文件大小用于辅助用户判断成品，缺失时不展示占位噪音。
    final totalBytes = _completedOutputBytes(streams);
    // 发布者名称保留但去掉 UP 前缀，减少右侧信息密度。
    final publisherName = task.publisherName?.trim().isNotEmpty == true
        ? task.publisherName!.trim()
        : '未知发布者';
    // 视频画质不再单独占行，跟在发布者后面，保留用户判断清晰度需要的信息。
    final publisherItems = <String>[publisherName];
    if (extraResource == null) {
      // 纯音频任务会返回“无”，这里不展示无意义的画质占位。
      final videoQualityText = videoLabel(task);
      if (videoQualityText != '无') publisherItems.add(videoQualityText);
    }
    // 任务类型和大小合并为一行，音质和完成时间不再显示，时长继续留在封面角标。
    final metaItems = <String>[
      extraResource == null
          ? mediaTaskTypeLabel(task)
          : downloadExtraResourceLabel(extraResource),
      if (totalBytes > 0) fileSizeLabel(totalBytes),
    ];
    // 长条卡片使用更小的内边距和封面宽度，让一屏容纳更多已下载项。
    final card = Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // 极窄屏缩小封面，普通手机保持接近 B 站长条列表的缩略图宽度。
            final coverWidth = constraints.maxWidth < 360 ? 118.0 : 138.0;
            // 固定内容区高度，让封面撑满整张长条并使用 cover 裁切。
            final stripHeight = constraints.maxWidth < 360 ? 81.0 : 89.0;
            return SizedBox(
              height: stripHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    width: coverWidth,
                    child: TaskCover(
                      task: task,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MobileCompletedMediaSummary(
                      title: task.title,
                      publisherLabel: publisherItems.join(' · '),
                      metaLabel: metaItems.join(' · '),
                      actions: _buildMobileCompletedMoreActions(context),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    return AppSwipeRevealActions(
      itemId: task.taskId,
      onTap: onOpenDetails,
      endActions: <AppSwipeAction>[
        AppSwipeAction(
          icon: Icons.delete_outline_rounded,
          label: '删除',
          onPressed: onDelete,
        ),
      ],
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
      child: card,
    );
  }

  /// 构建手机长条已下载卡片的更多操作菜单。
  Widget _buildMobileCompletedMoreActions(BuildContext context) {
    // 已下载操作与原卡片保持一致，只从横排按钮收纳为更多菜单以节省高度。
    final extraResource = downloadExtraResourceFromCode(task.contentType);
    final pageUri = _bilibiliPageUri();
    final canCopyBvid = task.bvid?.trim().isNotEmpty == true;
    final canOpenDirectory =
        task.outputPath?.trim().isNotEmpty == true &&
        (Platform.isAndroid ||
            Platform.isWindows ||
            Platform.isMacOS ||
            Platform.isLinux);
    // 三点入口复用公共圆形更多菜单按钮，确保 hover 裁剪和卡片按钮一致。
    return AppCircleMoreMenuButton<String>(
      constraints: const BoxConstraints(minWidth: 176, maxWidth: 176),
      maxMenuHeight: 240,
      onSelected: (String action) async {
        // 菜单项按能力分发到原有动作，确保长条改版不改变业务行为。
        switch (action) {
          case 'copy':
            await _copyBvid(context);
          case 'page':
            if (pageUri != null) await _openBilibiliPage(context, pageUri);
          case 'directory':
            await _openOutputDirectory(context);
        }
      },
      itemBuilder: (BuildContext context) {
        // 不可用动作不展示，删除已移到侧滑区域，避免菜单承担破坏性操作。
        return <PopupMenuEntry<String>>[
          if (extraResource == null && canCopyBvid)
            PopupMenuItem<String>(
              value: 'copy',
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AppPopupMenuItemRow(
                icon: Icons.content_copy_rounded,
                label: '复制 BV',
              ),
            ),
          if (extraResource == null && pageUri != null)
            PopupMenuItem<String>(
              value: 'page',
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AppPopupMenuItemRow(
                icon: Icons.link_rounded,
                label: '浏览器打开',
              ),
            ),
          if (canOpenDirectory)
            PopupMenuItem<String>(
              value: 'directory',
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AppPopupMenuItemRow(
                icon: Icons.folder_open_rounded,
                label: '打开目录',
              ),
            ),
        ];
      },
    );
  }

  /// 构建手机待下载主视频的横向长条卡片。
  Widget _buildMobileQueuedStrip(BuildContext context) {
    // 待下载长条直接读取解析时入库的音画质候选，点击底部字段仍可展开切换。
    final storedOptions = storedDashOptionsForTask(task);
    // 缺少候选信息时字段保留但禁用展开。
    final audioOptions = storedOptions?.audios ?? const <StoredAudioOption>[];
    // 视频候选同样来自任务快照，避免列表滚动时重新请求网络。
    final videoOptions = storedOptions?.videos ?? const <StoredVideoOption>[];
    // 只有未失败的待下载项允许切换质量，失败重试时保持已保存选择不再展开。
    final qualityEditable = task.phase == DownloadTaskPhase.queued;
    // 身份信息始终保留视频来源与分集，失败原因单独占一行避免挤掉上下文。
    final identityItems = <String>[
      if (task.publisherName?.trim().isNotEmpty == true)
        task.publisherName!.trim(),
      if (task.resolutionLabel?.trim().isNotEmpty == true)
        task.resolutionLabel!.trim(),
      if (task.partIndex > 0) '第 ${task.partIndex} 集',
    ];
    // 错误行只在有业务错误时显示，正常待下载卡片不额外占高度。
    final errorText = task.errorMessage?.trim();
    // 长条卡片本体保持与下载中、已下载一致的视觉密度。
    final card = Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // 封面宽度跟下载中长条一致，窄屏时自动收缩。
            final coverWidth = constraints.maxWidth < 360 ? 118.0 : 138.0;
            // 待下载标题和按钮区域与下载中第一行等高，保证三类卡片统一。
            final mediaRowHeight = constraints.maxWidth < 360 ? 81.0 : 89.0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  height: mediaRowHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        width: coverWidth,
                        child: TaskCover(
                          task: task,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MobileQueuedMediaSummary(
                          title: task.title,
                          identityLabel: _mobileQueuedIdentityLabel(
                            identityItems,
                          ),
                          actions: _buildMobileQueuedCompactActions(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                if (errorText?.isNotEmpty == true) ...<Widget>[
                  _buildMobileQueuedErrorLine(context, errorText!),
                  const SizedBox(height: 4),
                ],
                _buildMobileQueuedSizeLine(context),
                const SizedBox(height: 5),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _buildMobileQueuedQualityChip<StoredAudioOption>(
                        context,
                        label: '音质',
                        value: audioLabel(task),
                        options: audioOptions,
                        labelBuilder: audioOptionLabel,
                        selectedBuilder: (StoredAudioOption option) =>
                            option.qualityId == task.audioQualityId,
                        onSelected: onSelectAudio,
                        onClear: onClearAudio,
                        cleared: task.audioQualityId == null,
                        enabled: qualityEditable,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMobileQueuedQualityChip<StoredVideoOption>(
                        context,
                        label: '画质',
                        value: videoLabel(task),
                        options: videoOptions,
                        labelBuilder: videoOptionLabel,
                        selectedBuilder: (StoredVideoOption option) =>
                            option.qualityId == task.qualityId &&
                            option.codec.name == task.videoCodec,
                        onSelected: onSelectVideo,
                        onClear: onClearVideo,
                        cleared: task.qualityId == null,
                        enabled: qualityEditable,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
    return AppSwipeRevealActions(
      itemId: task.taskId,
      endActions: <AppSwipeAction>[
        AppSwipeAction(
          icon: Icons.delete_outline_rounded,
          label: '删除',
          onPressed: onDelete,
        ),
      ],
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
      child: card,
    );
  }

  /// 构建待下载失败原因行，放在媒体信息和大小信息之间便于用户快速定位。
  Widget _buildMobileQueuedErrorLine(BuildContext context, String message) {
    // 失败原因来自任务持久化错误文案，只在非空时由调用方插入这一行。
    return Text(
      '错误：$message',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.error,
        height: 1.05,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  /// 构建待下载长条右侧的下载与更多操作。
  Widget _buildMobileQueuedCompactActions(BuildContext context) {
    // 启动中只锁定下载按钮，更多菜单仍用于查看当前附加资源选择。
    final moreAction = _buildMobileQueuedMoreActions(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        AppActionButton(
          variant: AppActionButtonVariant.filled,
          size: AppActionButtonSize.small,
          minWidth: 78,
          onPressed: starting ? null : onStart,
          loading: starting,
          icon: Icons.download_rounded,
          label: _mobileQueuedActionLabel(),
        ),
        if (moreAction != null) ...<Widget>[
          const SizedBox(width: 8),
          moreAction,
        ],
      ],
    );
  }

  /// 返回手机待下载主按钮文案。
  String _mobileQueuedActionLabel() {
    // 启动中表示正在解析 DASH 和入队，不能显示普通下载。
    if (starting) return '解析中';
    // 失败任务再次点击是重试语义。
    if (task.phase == DownloadTaskPhase.failed) return '重试';
    // 普通待下载任务显示下载。
    return '下载';
  }

  /// 构建待下载封面下方的音视频大小紧凑行。
  Widget _buildMobileQueuedSizeLine(BuildContext context) {
    // 音视频预估大小放在封面和质量选择之间，避免遮挡封面内容。
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      height: 1.05,
      fontWeight: FontWeight.w800,
    );
    return SizedBox(
      height: 17,
      child: Row(
        children: <Widget>[
          _buildMobileQueuedSizeText(
            label: 'audio',
            value: fileSizeLabel(task.estimatedAudioSizeBytes),
            style: textStyle,
          ),
          const SizedBox(width: 12),
          _buildMobileQueuedSizeText(
            label: 'video',
            value: fileSizeLabel(task.estimatedVideoSizeBytes),
            style: textStyle,
          ),
        ],
      ),
    );
  }

  /// 构建待下载音频或视频大小的一段紧凑文本。
  Widget _buildMobileQueuedSizeText({
    required String label,
    required String value,
    required TextStyle? style,
  }) {
    // label 和数值使用同一行展示，防止待下载卡片高度回到大卡片密度。
    return Flexible(
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$label: ',
              style: style?.copyWith(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value, style: style),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// 构建待下载长条的更多下载项菜单。
  Widget? _buildMobileQueuedMoreActions(BuildContext context) {
    // 更多菜单承接原待下载卡片里的附加资源选择，删除不再放入菜单。
    if (availableExtraResources.isEmpty) {
      // 没有任何可切换的附加资源时不显示入口，避免出现空菜单按钮。
      return null;
    }
    final selectedResources = decodeDownloadExtraResources(
      task.extraResourcesJson,
    );
    return AppCircleMoreMenuButton<DownloadExtraResource>(
      constraints: const BoxConstraints(minWidth: 176, maxWidth: 176),
      maxMenuHeight: 320,
      onSelected: (DownloadExtraResource resource) {
        // 待下载更多只切换附加资源 JSON，真正下载仍由主下载按钮统一触发。
        final nextResources = <DownloadExtraResource>{...selectedResources};
        if (!nextResources.add(resource)) nextResources.remove(resource);
        onExtraResourcesChanged(
          Set<DownloadExtraResource>.unmodifiable(nextResources),
        );
      },
      itemBuilder: (BuildContext context) {
        // 仅展示设置中允许的附加资源，继续复用主任务内嵌资源选择逻辑。
        return availableExtraResources
            .map(
              (DownloadExtraResource resource) =>
                  PopupMenuItem<DownloadExtraResource>(
                    value: resource,
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AppCheckboxMenuItemRow(
                      selected: selectedResources.contains(resource),
                      label: downloadExtraResourceLabel(resource),
                    ),
                  ),
            )
            .toList(growable: false);
      },
    );
  }

  /// 构建待下载底部音质或画质紧凑下拉。
  Widget _buildMobileQueuedQualityChip<T>(
    BuildContext context, {
    required String label,
    required String value,
    required List<T> options,
    required String Function(T option) labelBuilder,
    required bool Function(T option) selectedBuilder,
    required ValueChanged<T> onSelected,
    required VoidCallback onClear,
    required bool cleared,
    required bool enabled,
  }) {
    // 缺少候选清单或失败待重试时禁用展开，但仍展示当前已保存质量。
    final colorScheme = Theme.of(context).colorScheme;
    // 触发器 hover 和按压反馈必须被限制在字段圆角内，避免浅色块溢出边框。
    final triggerRadius = BorderRadius.circular(9);
    return AppAnchoredSelectionMenu<T>(
      enabled: enabled,
      options: options,
      labelBuilder: labelBuilder,
      selectedBuilder: selectedBuilder,
      onSelected: onSelected,
      onClear: onClear,
      cleared: cleared,
      constraints: const BoxConstraints(minWidth: 176, maxWidth: 220),
      borderRadius: triggerRadius,
      splashRadius: 18,
      fieldLabel: label,
      fieldValue: value,
      fieldHeight: 34,
      fieldHorizontalPadding: 10,
      fieldLabelGap: 5,
      fieldBorderRadius: triggerRadius,
      fieldIconSize: 16,
      fieldFillColor: colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.32,
      ),
      fieldLabelStyle: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
      fieldValueStyle: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      fieldValueTextAlign: TextAlign.right,
    );
  }

  /// 构建手机下载中任务的横向长条卡片。
  Widget _buildMobileProgressStrip(
    BuildContext context,
    List<DownloadStreamRecord> streams,
  ) {
    // 进度和字节计算与 PC 卡片使用相同来源，避免桌面和手机显示不同步。
    final progress = task.progress.clamp(0.0, 1.0).toDouble();
    // 解析阶段保存的预计大小用于历史数据或 aria2 尚未返回总量时兜底。
    final estimatedTotal =
        <int?>[task.estimatedAudioSizeBytes, task.estimatedVideoSizeBytes]
            .whereType<int>()
            .where((int value) => value > 0)
            .fold<int>(0, (int total, int value) => total + value);
    // 所有分流都有真实总量时才使用实际总量，避免部分流为空导致百分比跳变。
    final hasActualTotal =
        streams.isNotEmpty &&
        streams.every(
          (DownloadStreamRecord stream) => (stream.totalBytes ?? 0) > 0,
        );
    // 已下载字节来自分流聚合，能覆盖暂停、恢复和多流下载状态。
    final downloadedBytes = streams.fold<int>(
      0,
      (int total, DownloadStreamRecord stream) =>
          total + stream.downloadedBytes,
    );
    // 实际总量同样聚合所有分流。
    final actualTotal = streams.fold<int>(
      0,
      (int total, DownloadStreamRecord stream) =>
          total + (stream.totalBytes ?? 0),
    );
    // 展示总量优先真实值，没有时回退预计值。
    final displayTotal = hasActualTotal ? actualTotal : estimatedTotal;
    // 下载进度文字根据阶段切换，合并阶段不再伪装成网络传输。
    final transferLabel = switch (task.phase) {
      DownloadTaskPhase.resolving => '正在获取下载地址',
      DownloadTaskPhase.waitingForMerge => '下载完成，等待生成文件',
      DownloadTaskPhase.merging => '正在生成最终文件',
      _ when displayTotal > 0 =>
        '已下载：${fileSizeLabel(downloadedBytes)} / ${fileSizeLabel(displayTotal)}',
      _ => '正在下载',
    };
    // 解析和合并没有稳定百分比，用阶段文案替代。
    final progressLabel = switch (task.phase) {
      DownloadTaskPhase.resolving => '解析中',
      DownloadTaskPhase.waitingForMerge => '等待处理',
      DownloadTaskPhase.merging => '处理中',
      _ => '${(progress * 100).round()}%',
    };
    // 当前处理对象保留在标题下方，用户能判断下载的是音频、视频还是有声视频。
    final workItems = <String>[
      mediaTaskTypeLabel(task),
      phaseLabel(task.phase),
    ];
    if (task.downloadSpeedBytesPerSecond > 0) {
      // 只有下载后端返回速度时才展示，暂停或后处理阶段不制造无意义占位。
      workItems.add('${fileSizeLabel(task.downloadSpeedBytesPerSecond)}/s');
    }
    final primary = Theme.of(context).colorScheme.primary;
    final card = Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // 下载中封面与已下载长条保持同一比例和宽度，列表视觉统一。
            final coverWidth = constraints.maxWidth < 360 ? 118.0 : 138.0;
            // 第一行只放封面、标题和操作按钮，进度信息单独放到下一行。
            final mediaRowHeight = constraints.maxWidth < 360 ? 81.0 : 89.0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildMobileProgressMediaRow(
                  context,
                  coverWidth: coverWidth,
                  mediaRowHeight: mediaRowHeight,
                  workLabel: workItems.join(' · '),
                  primary: primary,
                ),
                const SizedBox(height: 9),
                _buildMobileProgressTransferRow(
                  context,
                  transferLabel: transferLabel,
                  progressLabel: progressLabel,
                  primary: primary,
                ),
                const SizedBox(height: 6),
                AnimatedTaskProgressBar(progress: progress, phase: task.phase),
              ],
            );
          },
        ),
      ),
    );
    return AppSwipeRevealActions(
      itemId: task.taskId,
      endActions: <AppSwipeAction>[
        AppSwipeAction(
          icon: Icons.delete_outline_rounded,
          label: '删除',
          onPressed: onDelete,
        ),
      ],
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
      child: card,
    );
  }

  /// 构建手机下载中卡片的封面、标题和紧凑操作行。
  Widget _buildMobileProgressMediaRow(
    BuildContext context, {
    required double coverWidth,
    required double mediaRowHeight,
    required String workLabel,
    required Color primary,
  }) {
    return SizedBox(
      height: mediaRowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: coverWidth,
            child: TaskCover(
              task: task,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MobileProgressMediaSummary(
              title: task.title,
              workLabel: workLabel,
              workLabelColor: _mobileProgressWorkColor(context, primary),
              actions: _buildMobileProgressCompactActions(context),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建手机下载中卡片的字节进度和百分比行。
  Widget _buildMobileProgressTransferRow(
    BuildContext context, {
    required String transferLabel,
    required String progressLabel,
    required Color primary,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            transferLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        TaskStatusBadge(label: progressLabel, color: primary),
      ],
    );
  }

  /// 解析手机下载中卡片标题下方状态文字的颜色。
  Color _mobileProgressWorkColor(BuildContext context, Color primary) {
    if (task.phase == DownloadTaskPhase.paused) {
      return Theme.of(context).colorScheme.onSurfaceVariant;
    }
    return primary;
  }

  /// 当前暂停按钮应该展示的图标。
  IconData get _pauseToggleIcon {
    if (task.phase == DownloadTaskPhase.paused) return Icons.play_arrow_rounded;
    return Icons.pause_rounded;
  }

  /// 当前暂停按钮应该展示的提示文案。
  String get _pauseToggleTooltip {
    if (task.phase == DownloadTaskPhase.paused) return '继续任务';
    return '暂停任务';
  }

  /// 返回手机排队卡片的发布身份兜底文案。
  String _mobileQueuedIdentityLabel(List<String> identityItems) {
    if (identityItems.isEmpty) return 'Bilibili 视频';
    return identityItems.join(' · ');
  }

  /// 构建手机下载中长条卡片的紧凑操作按钮。
  Widget _buildMobileProgressCompactActions(BuildContext context) {
    // 手机端与桌面端使用同一阶段规则，合并开始后立即移除暂停和继续入口。
    final canTogglePause = canToggleDownloadTaskPause(task.phase);
    // 输出路径可用时允许直接打开目录，路径有效性由平台调用再次校验。
    final canOpenDirectory =
        task.outputPath?.trim().isNotEmpty == true &&
        (Platform.isAndroid ||
            Platform.isWindows ||
            Platform.isMacOS ||
            Platform.isLinux);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        if (canTogglePause) ...<Widget>[
          AppCircleIconButton(
            variant: AppCircleIconButtonVariant.primaryOutlined,
            onPressed: togglingPause || pauseControlDisabled
                ? null
                : onTogglePause,
            icon: togglingPause
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_pauseToggleIcon),
            tooltip: _pauseToggleTooltip,
            size: AppCircleIconButtonSize.small,
          ),
          const SizedBox(width: 6),
        ],
        if (canOpenDirectory) ...<Widget>[
          AppCircleIconButton(
            variant: AppCircleIconButtonVariant.outlined,
            onPressed: () => _openOutputDirectory(context),
            icon: const Icon(Icons.folder_open_rounded),
            tooltip: '打开文件所在目录',
            size: AppCircleIconButtonSize.small,
          ),
        ],
      ],
    );
  }

  /// 计算已下载卡片用于展示和封面叠层的总大小。
  int _completedOutputBytes(List<DownloadStreamRecord> streams) {
    // 附加资源没有音视频双流大小，必须回退实际分流字节。
    final extraResource = downloadExtraResourceFromCode(task.contentType);
    if (extraResource != null) return resourceSizeBytes(streams);
    // 普通视频沿用解析阶段保存的音频和视频大小。
    final mediaBytes = <int?>[
      task.estimatedAudioSizeBytes,
      task.estimatedVideoSizeBytes,
    ].whereType<int>().fold<int>(0, (int total, int value) => total + value);
    return mediaBytes;
  }

  /// 构建桌面长条卡片右上角的移除、重试或状态入口。
  Widget _buildDesktopTopAction(BuildContext context) {
    // 排队任务右上角只保留移除操作，资源和下载操作移动到卡片下方。
    if (task.phase == DownloadTaskPhase.queued) {
      return _buildTaskIconButton(
        onPressed: starting ? null : onDelete,
        icon: const Icon(Icons.close_rounded),
        tooltip: '移除任务',
      );
    }
    // 失败任务除状态外必须提供移除入口，避免无法重试的记录滞留列表。
    if (task.phase == DownloadTaskPhase.failed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            phaseLabel(task.phase),
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          _buildTaskIconButton(
            onPressed: starting ? null : onDelete,
            icon: const Icon(Icons.close_rounded),
            tooltip: '移除任务',
          ),
        ],
      );
    }
    // 其他阶段只在标题行显示短状态，具体操作或进度统一放到底部行。
    final statusColor = _taskStatusColor(context);
    return Text(
      phaseLabel(task.phase),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
    );
  }

  /// 返回标题右侧状态文本颜色。
  Color _taskStatusColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 失败状态使用错误色，提示用户需要处理。
    if (task.phase == DownloadTaskPhase.failed) return colorScheme.error;
    // 已完成状态使用主色，和已下载页签保持一致。
    if (task.phase == DownloadTaskPhase.completed) return colorScheme.primary;
    // 其他状态弱化为辅助文字色。
    return colorScheme.onSurfaceVariant;
  }

  /// 构建桌面排队任务底部的附加内容下拉和图标下载按钮。
  Widget _buildDesktopQueuedActions(BuildContext context) {
    // 紧凑 Row 只占菜单和图标按钮的实际宽度，不挤压左侧元数据。
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        DesktopResourceMenu(
          availableResources: availableExtraResources,
          selectedResources: decodeDownloadExtraResources(
            task.extraResourcesJson,
          ),
          onChanged: onExtraResourcesChanged,
        ),
        const SizedBox(width: 6),
        _buildTaskIconButton(
          variant: AppCircleIconButtonVariant.primaryOutlined,
          onPressed: starting ? null : onStart,
          icon: starting
              ? const SizedBox.square(
                  dimension: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_rounded),
          tooltip: starting ? '正在解析播放地址' : '下载视频',
        ),
      ],
    );
  }
}
