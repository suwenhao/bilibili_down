/// 业务下载任务从解析到完成的持久化阶段。
enum DownloadTaskPhase {
  /// 任务已经创建，等待解析视频信息。
  queued,

  /// 已进入下载中队列，等待应用并发调度器分配启动名额。
  waitingToStart,

  /// 正在解析分集和播放地址。
  resolving,

  /// 视频流与音频流正在下载。
  downloading,

  /// 两条媒体流已经完成，但当前平台暂时不能执行合并。
  waitingForMerge,

  /// 正在通过 FFmpeg 合并音视频。
  merging,

  /// 用户暂停了当前任务。
  paused,

  /// 最终文件已经生成。
  completed,

  /// 解析、下载或合并过程失败。
  failed,

  /// 用户取消任务，后续不再自动恢复。
  canceled,
}

/// 判断任务当前是否应向用户提供暂停或继续操作。
bool canToggleDownloadTaskPause(DownloadTaskPhase phase) {
  // 等待启动和解析阶段仍在下载中队列，批量暂停需要阻止它们继续占用并发启动。
  return switch (phase) {
    DownloadTaskPhase.waitingToStart ||
    DownloadTaskPhase.resolving ||
    DownloadTaskPhase.downloading ||
    DownloadTaskPhase.paused => true,
    _ => false,
  };
}

/// 单条媒体分流在下载引擎中的状态。
enum DownloadStreamPhase {
  /// 已创建分流记录，尚未提交下载引擎。
  pending,

  /// 已经提交下载引擎并等待执行。
  queued,

  /// 正在传输媒体数据。
  downloading,

  /// 下载引擎已经暂停该分流。
  paused,

  /// 分流文件已经完整下载。
  completed,

  /// 分流下载失败。
  failed,

  /// 分流下载已取消。
  canceled,
}

/// B 站 DASH 媒体分流类型。
enum DownloadStreamKind {
  /// 只包含画面的媒体流。
  video,

  /// 只包含声音的媒体流。
  audio,

  /// 封面、弹幕或字幕等无需媒体合并的附加资源。
  resource,
}

/// 持久化记录使用的下载后端类型。
enum PersistedDownloadBackend {
  /// 使用随包 aria2c 和本机 JSON-RPC。
  aria2,

  /// 使用系统后台传输 API。
  system,
}

/// 下载任务产生的本地文件类型。
enum DownloadArtifactKind {
  /// 合并完成的最终视频。
  output,

  /// 从主任务音频分流转封装得到的独立音频文件。
  standaloneAudio,

  /// 合并前的视频临时流。
  videoStream,

  /// 合并前的音频临时流。
  audioStream,

  /// 视频封面图片。
  cover,

  /// 原始字幕或转换后的字幕文件。
  subtitle,

  /// XML 或 ASS 弹幕文件。
  danmaku,

  /// 尚未发布的通用附加资源临时文件。
  resource,
}

/// 约束下载任务阶段转换，避免数据库出现不可能的状态跳跃。
final class DownloadTaskStateMachine {
  /// 状态机只提供静态规则，不允许实例化。
  const DownloadTaskStateMachine._();

  /// 每个阶段允许直接进入的下一阶段集合。
  static const Map<DownloadTaskPhase, Set<DownloadTaskPhase>>
  _allowedTransitions = <DownloadTaskPhase, Set<DownloadTaskPhase>>{
    DownloadTaskPhase.queued: <DownloadTaskPhase>{
      DownloadTaskPhase.waitingToStart,
      DownloadTaskPhase.resolving,
      DownloadTaskPhase.paused,
      DownloadTaskPhase.failed,
      DownloadTaskPhase.canceled,
    },
    DownloadTaskPhase.waitingToStart: <DownloadTaskPhase>{
      DownloadTaskPhase.queued,
      DownloadTaskPhase.resolving,
      DownloadTaskPhase.paused,
      DownloadTaskPhase.failed,
      DownloadTaskPhase.canceled,
    },
    DownloadTaskPhase.resolving: <DownloadTaskPhase>{
      DownloadTaskPhase.downloading,
      DownloadTaskPhase.paused,
      DownloadTaskPhase.failed,
      DownloadTaskPhase.canceled,
    },
    DownloadTaskPhase.downloading: <DownloadTaskPhase>{
      DownloadTaskPhase.waitingForMerge,
      DownloadTaskPhase.merging,
      DownloadTaskPhase.paused,
      DownloadTaskPhase.failed,
      DownloadTaskPhase.canceled,
    },
    DownloadTaskPhase.waitingForMerge: <DownloadTaskPhase>{
      DownloadTaskPhase.merging,
      DownloadTaskPhase.paused,
      DownloadTaskPhase.failed,
      DownloadTaskPhase.canceled,
    },
    DownloadTaskPhase.merging: <DownloadTaskPhase>{
      DownloadTaskPhase.waitingForMerge,
      DownloadTaskPhase.completed,
      DownloadTaskPhase.paused,
      DownloadTaskPhase.failed,
      DownloadTaskPhase.canceled,
    },
    DownloadTaskPhase.paused: <DownloadTaskPhase>{
      DownloadTaskPhase.queued,
      DownloadTaskPhase.waitingToStart,
      DownloadTaskPhase.resolving,
      DownloadTaskPhase.downloading,
      DownloadTaskPhase.waitingForMerge,
      DownloadTaskPhase.merging,
      DownloadTaskPhase.failed,
      DownloadTaskPhase.canceled,
    },
    DownloadTaskPhase.failed: <DownloadTaskPhase>{
      DownloadTaskPhase.queued,
      DownloadTaskPhase.waitingToStart,
      DownloadTaskPhase.resolving,
      DownloadTaskPhase.canceled,
    },
    DownloadTaskPhase.completed: <DownloadTaskPhase>{},
    DownloadTaskPhase.canceled: <DownloadTaskPhase>{},
  };

  /// 判断指定阶段转换是否有效；同阶段更新视为有效幂等操作。
  static bool canTransition(DownloadTaskPhase current, DownloadTaskPhase next) {
    // 同一阶段允许更新进度、错误或时间戳，不属于真正的状态跳转。
    if (current == next) return true;
    // 从映射中查询下一阶段是否被当前阶段允许。
    return _allowedTransitions[current]?.contains(next) ?? false;
  }

  /// 校验阶段转换，无效时抛出包含前后状态的异常。
  static void ensureCanTransition(
    DownloadTaskPhase current,
    DownloadTaskPhase next,
  ) {
    // 合法转换直接返回，让仓库继续执行数据库事务。
    if (canTransition(current, next)) return;
    // 非法跳转必须阻止写库，避免完成任务重新进入活动状态。
    throw DownloadTaskTransitionException(current: current, next: next);
  }
}

/// 下载任务发生非法阶段转换时使用的领域异常。
final class DownloadTaskTransitionException implements Exception {
  /// 保存当前阶段和请求进入的下一阶段。
  const DownloadTaskTransitionException({
    required this.current,
    required this.next,
  });

  /// 数据库中的当前阶段。
  final DownloadTaskPhase current;

  /// 业务代码请求写入的下一阶段。
  final DownloadTaskPhase next;

  /// 输出便于日志定位的阶段变化信息。
  @override
  String toString() =>
      'DownloadTaskTransitionException: ${current.name} -> ${next.name}';
}
