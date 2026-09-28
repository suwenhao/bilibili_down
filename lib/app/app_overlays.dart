import 'package:flutter/material.dart';

import '../core/widgets/app_action_button.dart';
import '../core/logging/crash_recovery_service.dart';
import '../features/downloads/application/lifecycle/automatic_shutdown_controller.dart';
import 'desktop_runtime_access_service.dart';

/// 桌面首次启动与能力不足时展示的不可跳过全屏门禁。
final class DesktopRuntimeAccessGate extends StatelessWidget {
  /// 创建覆盖整个应用且只能通过能力检查进入主界面的门禁。
  const DesktopRuntimeAccessGate({
    required this.state,
    required this.onConfirmOrRetry,
    required this.onChooseDirectory,
    super.key,
  });

  /// 当前目录、下载服务检查阶段与错误信息。
  final DesktopRuntimeAccessState state;

  /// 用户确认说明或修复环境后重新检查的回调。
  final VoidCallback onConfirmOrRetry;

  /// 打开系统目录选择器并保存新目录的回调。
  final VoidCallback onChooseDirectory;

  /// 构建不可通过返回键关闭的全屏说明与修复入口。
  @override
  Widget build(BuildContext context) {
    // 检查阶段禁用操作，避免并发创建目录或重复启动 aria2。
    final isBusy =
        state.phase == DesktopRuntimeAccessPhase.checking ||
        state.phase == DesktopRuntimeAccessPhase.verifying;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: _RuntimeAccessGateBody(
          state: state,
          isBusy: isBusy,
          onConfirmOrRetry: onConfirmOrRetry,
          onChooseDirectory: onChooseDirectory,
        ),
      ),
    );
  }
}

/// 启动门禁的滚动与居中外壳，避免页面 build 出现过深布局层级。
final class _RuntimeAccessGateBody extends StatelessWidget {
  /// 创建桌面启动能力门禁正文。
  const _RuntimeAccessGateBody({
    required this.state,
    required this.isBusy,
    required this.onConfirmOrRetry,
    required this.onChooseDirectory,
  });

  /// 当前能力检查状态，用于展示目录、错误和检查结果。
  final DesktopRuntimeAccessState state;

  /// 当前是否正在检查能力，忙碌时禁用所有入口。
  final bool isBusy;

  /// 用户确认或重新检查的入口。
  final VoidCallback onConfirmOrRetry;

  /// 用户重新选择下载目录的入口。
  final VoidCallback onChooseDirectory;

  /// 构建全屏居中的滚动卡片。
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: _RuntimeAccessCard(
              state: state,
              isBusy: isBusy,
              onConfirmOrRetry: onConfirmOrRetry,
              onChooseDirectory: onChooseDirectory,
            ),
          ),
        ),
      ),
    );
  }
}

/// 启动门禁卡片内容，集中展示检查项和修复入口。
final class _RuntimeAccessCard extends StatelessWidget {
  /// 创建启动门禁说明卡片。
  const _RuntimeAccessCard({
    required this.state,
    required this.isBusy,
    required this.onConfirmOrRetry,
    required this.onChooseDirectory,
  });

  /// 当前能力检查状态，用于渲染卡片文案和检查项。
  final DesktopRuntimeAccessState state;

  /// 当前是否正在执行检查，控制检查项和按钮状态。
  final bool isBusy;

  /// 用户确认或重试检查的回调。
  final VoidCallback onConfirmOrRetry;

  /// 用户改选下载目录的回调。
  final VoidCallback onChooseDirectory;

  /// 首次确认与失败状态使用不同标题，让用户快速理解当前需要做什么。
  String get _title {
    if (state.phase == DesktopRuntimeAccessPhase.blocked) {
      return '需要处理一个问题';
    }
    return '开始使用前检查';
  }

  /// 构建带图标、检查项和操作按钮的门禁卡片。
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Icon(
              Icons.admin_panel_settings_outlined,
              size: 48,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              _title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              '为了正常下载，BiliDown 需要使用网络，并能够在你选择的文件夹中保存文件。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '如果安全软件弹出提示，请确认操作来自 BiliDown 后选择允许。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            _RuntimeAccessItem(
              icon: Icons.public_rounded,
              title: '下载功能',
              description: '确认应用可以正常启动下载。',
              available: state.downloadServiceAvailable,
              checking: isBusy,
            ),
            const SizedBox(height: 12),
            _RuntimeAccessItem(
              icon: Icons.folder_outlined,
              title: '保存位置',
              description: state.directoryPath ?? '正在解析下载目录…',
              available: state.storageAvailable,
              checking: isBusy,
            ),
            if (state.errorMessage != null) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                state.errorMessage!,
                style: TextStyle(color: colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            _RuntimeAccessActions(
              state: state,
              isBusy: isBusy,
              onConfirmOrRetry: onConfirmOrRetry,
              onChooseDirectory: onChooseDirectory,
            ),
          ],
        ),
      ),
    );
  }
}

/// 启动门禁底部动作区，负责切换忙碌态和主按钮文案。
final class _RuntimeAccessActions extends StatelessWidget {
  /// 创建启动门禁动作区。
  const _RuntimeAccessActions({
    required this.state,
    required this.isBusy,
    required this.onConfirmOrRetry,
    required this.onChooseDirectory,
  });

  /// 当前能力检查状态，用于决定主按钮文案。
  final DesktopRuntimeAccessState state;

  /// 当前是否正在检查，忙碌时按钮不可重复触发。
  final bool isBusy;

  /// 用户确认或重新检查的回调。
  final VoidCallback onConfirmOrRetry;

  /// 用户改选下载目录的回调。
  final VoidCallback onChooseDirectory;

  /// 首次确认与失败重试使用不同按钮文案，避免把能力检查伪装成系统授权。
  String get _primaryLabel {
    return switch (state.phase) {
      DesktopRuntimeAccessPhase.needsConfirmation => '确认并检查',
      DesktopRuntimeAccessPhase.blocked => '重新检查',
      _ => '正在检查…',
    };
  }

  /// 构建右对齐的目录选择和确认按钮。
  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        AppActionButton(
          variant: AppActionButtonVariant.outlined,
          onPressed: isBusy ? null : onChooseDirectory,
          icon: Icons.drive_folder_upload_outlined,
          label: '选择其他文件夹',
        ),
        AppActionButton(
          variant: AppActionButtonVariant.filled,
          onPressed: isBusy ? null : onConfirmOrRetry,
          loading: isBusy,
          icon: Icons.verified_user_outlined,
          label: _primaryLabel,
        ),
      ],
    );
  }
}

/// 展示单项桌面运行能力及其当前检查状态。
final class _RuntimeAccessItem extends StatelessWidget {
  /// 创建包含图标、说明和状态标记的能力条目。
  const _RuntimeAccessItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.available,
    required this.checking,
  });

  /// 能力条目前导图标。
  final IconData icon;

  /// 能力名称。
  final String title;

  /// 能力用途或当前目录说明。
  final String description;

  /// 本次检查是否已经确认能力可用。
  final bool available;

  /// 当前是否正在执行异步检查。
  final bool checking;

  /// 构建响应主题颜色的能力状态行。
  @override
  Widget build(BuildContext context) {
    // 已通过时使用主题色，未通过时保持中性以免在检查前误报失败。
    final statusColor = available
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outline;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Icon(icon, color: statusColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (checking && !available)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                available ? Icons.check_circle_rounded : Icons.pending_outlined,
                color: statusColor,
              ),
          ],
        ),
      ),
    );
  }
}

/// 下次启动显示的未处理异常恢复提示。
final class CrashRecoveryOverlay extends StatelessWidget {
  /// 创建包含异常时间、导出和继续入口的模态卡片。
  const CrashRecoveryOverlay({
    required this.report,
    required this.onDismiss,
    required this.onExport,
    super.key,
  });

  /// 已脱敏的上次异常摘要。
  final CrashRecoveryReport report;

  /// 用户确认并继续使用应用的回调。
  final VoidCallback onDismiss;

  /// 导出本次诊断日志的回调。
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Icon(Icons.healing_rounded, size: 42),
                    const SizedBox(height: 14),
                    Text(
                      '检测到上次异常退出',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '时间：${report.occurredAt.toLocal()}\n'
                      '应用已恢复启动。你可以导出脱敏日志帮助定位问题。',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        AppActionButton(
                          variant: AppActionButtonVariant.outlined,
                          onPressed: onExport,
                          icon: Icons.file_download_outlined,
                          label: '导出日志',
                        ),
                        AppActionButton(
                          variant: AppActionButtonVariant.filled,
                          onPressed: onDismiss,
                          label: '继续使用',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 下载整轮完成后展示的可取消自动关机倒计时。
final class AutomaticShutdownOverlay extends StatelessWidget {
  /// 创建根级倒计时遮罩。
  const AutomaticShutdownOverlay({
    required this.state,
    required this.onCancel,
    super.key,
  });

  /// 当前剩余秒数、执行或错误状态。
  final AutomaticShutdownState state;

  /// 用户取消倒计时或确认错误后的回调。
  final VoidCallback onCancel;

  /// 构建不可点击背景但提供明确取消入口的居中弹窗。
  @override
  Widget build(BuildContext context) {
    // 错误优先于执行状态显示，确保系统命令失败不会被加载动画掩盖。
    final hasError = state.errorMessage != null;
    // 正文根据倒计时生命周期给出准确且可操作的信息。
    final message = _automaticShutdownMessage(state);
    return PopScope(
      canPop: false,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const ModalBarrier(dismissible: false, color: Color(0x8A000000)),
          Dialog(
            insetPadding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _AutomaticShutdownHeader(hasError: hasError),
                    const SizedBox(height: 14),
                    Text(message),
                    if (!state.executing || hasError) ...<Widget>[
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: AppActionButton(
                          variant: AppActionButtonVariant.filled,
                          onPressed: onCancel,
                          label: hasError ? '知道了' : '取消关机',
                        ),
                      ),
                    ] else ...<Widget>[
                      const SizedBox(height: 18),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 根据倒计时生命周期返回当前应展示的说明文案。
  String _automaticShutdownMessage(AutomaticShutdownState state) {
    // 错误优先于执行状态显示，确保系统命令失败不会被加载动画掩盖。
    if (state.errorMessage != null) {
      return '系统关机命令启动失败：${state.errorMessage}';
    }
    // 系统命令已经发出时显示执行态，不再展示过期倒计时。
    if (state.executing) return '正在请求系统关机…';
    // 普通倒计时态展示剩余秒数，方便用户判断是否取消。
    return '全部下载已完成，将在 ${state.remainingSeconds} 秒后关机。';
  }
}

/// 自动关机弹窗顶部状态标题。
final class _AutomaticShutdownHeader extends StatelessWidget {
  /// 创建自动关机状态标题。
  const _AutomaticShutdownHeader({required this.hasError});

  /// 当前关机命令是否失败。
  final bool hasError;

  /// 根据执行结果展示错误或普通关机图标。
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(_icon, color: hasError ? colorScheme.error : colorScheme.primary),
        const SizedBox(width: 12),
        Text(_title, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }

  /// 当前状态使用的图标。
  IconData get _icon {
    if (hasError) return Icons.error_outline_rounded;
    return Icons.power_settings_new_rounded;
  }

  /// 当前状态使用的标题。
  String get _title {
    if (hasError) return '自动关机失败';
    return '自动关机';
  }
}

/// 覆盖整个应用且不可主动关闭的桌面退出提示。
final class ApplicationClosingOverlay extends StatelessWidget {
  /// 创建只展示加载状态的全局退出遮罩。
  const ApplicationClosingOverlay({required this.detail, super.key});

  /// 当前正在执行的资源清理步骤说明。
  final String detail;

  /// 构建居中弹窗、模态遮罩和返回键拦截。
  @override
  Widget build(BuildContext context) {
    // PopScope 阻止键盘返回，ModalBarrier 阻止鼠标和触摸穿透。
    return PopScope(
      canPop: false,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const ModalBarrier(dismissible: false, color: Color(0x8A000000)),
          Dialog(
            insetPadding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints.tightFor(width: 320),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 22,
                ),
                child: Row(
                  children: <Widget>[
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text('正在退出'),
                          const SizedBox(height: 4),
                          Text(detail),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 数据库启动失败时展示的阻断错误页。
final class DatabaseStartupError extends StatelessWidget {
  /// 创建错误说明与重试操作。
  const DatabaseStartupError({
    required this.error,
    required this.onRetry,
    super.key,
  });

  /// Drift 打开或迁移过程返回的原始错误。
  final Object error;

  /// 销毁失败连接并重新初始化的回调。
  final VoidCallback onRetry;

  /// 构建不会依赖数据库的最小错误界面。
  @override
  Widget build(BuildContext context) {
    // 限制错误内容宽度，避免桌面窗口中说明横向过长。
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.storage_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text('数据库启动失败', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                AppActionButton(
                  variant: AppActionButtonVariant.filled,
                  onPressed: onRetry,
                  icon: Icons.refresh_rounded,
                  label: '重试',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
