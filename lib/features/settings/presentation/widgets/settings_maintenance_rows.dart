import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/legal/legal_information_dialogs.dart';
import '../../../../core/logging/app_debug_log.dart';
import '../../../../core/widgets/app_selection_controls.dart';
import '../controllers/settings_page_controller.dart';
import '../dialogs/version_info_dialog.dart';
import '../legal_document_page.dart';
import '../models/settings_page_state.dart';
import '../models/settings_labels.dart';
import 'settings_row.dart';

/// 缓存、诊断、法律许可和版本相关设置行。
final class SettingsMaintenanceRows extends StatelessWidget {
  /// 创建设置页底部动作区。
  const SettingsMaintenanceRows({
    required this.compact,
    required this.version,
    required this.appCacheSize,
    required this.pageState,
    required this.pageController,
    super.key,
  });

  /// 当前是否使用手机紧凑排版。
  final bool compact;

  /// 当前应用版本号。
  final String version;

  /// 当前缓存大小异步快照。
  final AsyncValue<int> appCacheSize;

  /// 设置页页面动作忙碌状态。
  final SettingsPageState pageState;

  /// 设置页页面动作控制器。
  final SettingsPageController pageController;

  /// 构建底部维护动作设置行。
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingsRow(
          compact: compact,
          label: '缓存',
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                appCacheSize.hasValue
                    ? '缓存 ${formatCacheSize(appCacheSize.value!)}'
                    : '正在计算…',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              AppCompactOutlinedActionButton(
                compact: compact,
                onPressed: appCacheSize.isLoading || pageState.clearingCache
                    ? null
                    : () => pageController.clearAppCache(
                        context,
                        appCacheSize.value ?? 0,
                      ),
                icon: Icons.cleaning_services_outlined,
                label: '清除缓存',
              ),
            ],
          ),
        ),
        SettingsRow(
          compact: compact,
          label: '诊断',
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppCompactOutlinedActionButton(
              compact: compact,
              onPressed: pageState.exportingDiagnosticLog
                  ? null
                  : () {
                      // 系统保存对话框和文件写入异步执行，页面保持可响应。
                      unawaited(pageController.exportDiagnosticLog(context));
                    },
              icon: Icons.file_download_outlined,
              label: '导出脱敏日志',
            ),
          ),
        ),
        if (Platform.isAndroid || Platform.isIOS)
          SettingsRow(
            compact: compact,
            label: '使用帮助',
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppCompactOutlinedActionButton(
                compact: compact,
                onPressed: () {
                  // 当前会话切回移动端引导，磁盘完成标记保持不变。
                  pageController.showOnboardingAgain();
                },
                icon: Icons.auto_stories_outlined,
                label: '重新查看使用引导',
              ),
            ),
          ),
        SettingsRow(
          compact: compact,
          compactStacked: compact,
          label: '法律与许可',
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                AppCompactOutlinedActionButton(
                  compact: compact,
                  onPressed: () {
                    // 手机端必须覆盖外层设置页头部，桌面端保留原有内容区展示。
                    pageController.showOpenSourceLicensePage(
                      context,
                      version: version,
                      compact: compact,
                    );
                  },
                  icon: Icons.code_rounded,
                  label: '开源许可证',
                ),
                AppCompactOutlinedActionButton(
                  compact: compact,
                  onPressed: () {
                    // aria2 和 FFmpeg 等原生组件不依赖 Flutter 注册表，单独展示许可摘要。
                    _openLegalDocument(
                      context,
                      thirdPartyLicensesLegalDocument,
                    );
                  },
                  icon: Icons.extension_outlined,
                  label: '第三方许可',
                ),
                AppCompactOutlinedActionButton(
                  compact: compact,
                  onPressed: () {
                    // 展示本地存储、网络访问和数据删除边界。
                    _openLegalDocument(context, privacyStatementLegalDocument);
                  },
                  icon: Icons.privacy_tip_outlined,
                  label: '隐私声明',
                ),
                AppCompactOutlinedActionButton(
                  compact: compact,
                  onPressed: () {
                    // 设置页与登录页复用同一份版权和允许用途说明。
                    _openLegalDocument(context, copyrightUsageLegalDocument);
                  },
                  icon: Icons.copyright_rounded,
                  label: '版权使用说明',
                ),
              ],
            ),
          ),
        ),
        SettingsRow(
          compact: compact,
          label: '版本',
          showDivider: false,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppCompactOutlinedActionButton(
              compact: compact,
              onPressed: () {
                AppDebugLog.settings(
                  'Version info dialog opened version=$version',
                );
                // 版本详情展示新增与修复内容，法律全文仍由上一行的独立入口负责。
                unawaited(
                  showVersionInfoDialog(context: context, version: version),
                );
              },
              icon: Icons.info_outline_rounded,
              label: '$version  详情',
            ),
          ),
        ),
      ],
    );
  }

  /// 打开法律文档页面，桌面端保留 Shell 侧栏，手机端覆盖整个 Shell。
  void _openLegalDocument(BuildContext context, LegalDocumentData document) {
    AppDebugLog.settings(
      'Legal document opened title=${document.title} compact=$compact',
    );
    // PC 端使用当前分支导航，行为与开源许可证页面保持一致并保留左侧菜单。
    final navigator = Navigator.of(context, rootNavigator: compact);
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (BuildContext routeContext) =>
              SettingsLegalDocumentPage(document: document),
        ),
      ),
    );
  }
}
