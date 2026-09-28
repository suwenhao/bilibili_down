import 'package:bilibili_down/features/downloads/application/runtime/download_merge_policy.dart';
import 'package:bilibili_down/features/downloads/domain/download_task_phase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 验证视频和音频分流按类型生成 FFmpeg 输入。
  test('完成的视频和音频分流生成唯一输入', () {
    // 输入顺序不应影响最终视频与音频路径选择。
    final inputs = resolveCompletedMediaInputs(
      taskId: 'task-1',
      streams: const <DownloadMergeStream>[
        (
          kind: DownloadStreamKind.audio,
          phase: DownloadStreamPhase.completed,
          temporaryPath: 'audio.m4s',
        ),
        (
          kind: DownloadStreamKind.video,
          phase: DownloadStreamPhase.completed,
          temporaryPath: 'video.m4s',
        ),
      ],
    );
    expect(inputs.videoPath, 'video.m4s');
    expect(inputs.audioPath, 'audio.m4s');
  });

  /// 验证音频单流仍可进入无视频 remux 流程。
  test('完成的音频单流生成音频输入', () {
    final inputs = resolveCompletedMediaInputs(
      taskId: 'audio-task',
      streams: const <DownloadMergeStream>[
        (
          kind: DownloadStreamKind.audio,
          phase: DownloadStreamPhase.completed,
          temporaryPath: 'audio.m4s',
        ),
      ],
    );
    expect(inputs.videoPath, isNull);
    expect(inputs.audioPath, 'audio.m4s');
  });

  /// 验证未完成或重复类型不能进入 FFmpeg。
  test('拒绝未完成和重复类型分流', () {
    // 下载中分流保持原有 completed 校验错误。
    expect(
      () => resolveCompletedMediaInputs(
        taskId: 'active-task',
        streams: const <DownloadMergeStream>[
          (
            kind: DownloadStreamKind.video,
            phase: DownloadStreamPhase.downloading,
            temporaryPath: 'video.m4s',
          ),
        ],
      ),
      throwsStateError,
    );
    // 两条视频分流违反每种类型唯一约束。
    expect(
      () => resolveCompletedMediaInputs(
        taskId: 'duplicate-task',
        streams: const <DownloadMergeStream>[
          (
            kind: DownloadStreamKind.video,
            phase: DownloadStreamPhase.completed,
            temporaryPath: 'video-1.m4s',
          ),
          (
            kind: DownloadStreamKind.video,
            phase: DownloadStreamPhase.completed,
            temporaryPath: 'video-2.m4s',
          ),
        ],
      ),
      throwsStateError,
    );
  });
}
