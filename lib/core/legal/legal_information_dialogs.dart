import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logging/app_debug_log.dart';
import '../widgets/app_action_button.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_snack_bar.dart';

/// 法律文档完整内容，供设置页移动端页面和桌面弹窗复用。
final class LegalDocumentData {
  /// 创建一份可展示的法律文档。
  const LegalDocumentData({
    required this.title,
    required this.introduction,
    required this.sections,
  });

  /// 文档标题。
  final String title;

  /// 文档开头说明。
  final String introduction;

  /// 分段正文列表。
  final List<LegalSectionData> sections;
}

/// 单个法律说明分段的数据。
final class LegalSectionData {
  /// 创建包含分段标题和正文的不可变数据。
  const LegalSectionData({
    required this.title,
    required this.body,
    this.links = const <LegalLinkData>[],
  });

  /// 分段标题。
  final String title;

  /// 分段正文。
  final String body;

  /// 与本段内容直接相关的可跳转来源或许可证链接。
  final List<LegalLinkData> links;
}

/// 法律说明中可点击的外部链接。
final class LegalLinkData {
  /// 创建一个外部链接条目。
  const LegalLinkData({
    required this.label,
    this.url,
    this.assetPath,
    this.sourceUrl,
  }) : assert(url != null || assetPath != null);

  /// 给用户看的链接名称。
  final String label;

  /// 实际打开的 HTTPS 地址，存在时走系统浏览器。
  final String? url;

  /// 随包许可证全文资源路径，存在时进入应用内详情页。
  final String? assetPath;

  /// 本地许可证对应的上游页面，详情页中作为可选外部跳转。
  final String? sourceUrl;
}

/// 应用对本地数据、网络访问和诊断日志的隐私处理说明。
const LegalDocumentData privacyStatementLegalDocument = LegalDocumentData(
  title: '隐私声明',
  introduction: 'BiliDown 以本地处理为主。以下说明用于明确应用会保存什么、何时联网以及如何删除数据。',
  sections: <LegalSectionData>[
    LegalSectionData(
      title: '本地保存的数据',
      body: '账号 Cookie 和刷新凭据保存在系统安全存储中；下载任务、历史记录、设置、封面缓存和临时文件只保存在当前设备。',
    ),
    LegalSectionData(
      title: '网络访问',
      body: '应用仅在解析、登录和下载时访问哔哩哔哩及其内容分发网络，不提供自建账号、统计或广告服务，也不会主动上传下载历史和本地文件。',
    ),
    LegalSectionData(
      title: '诊断与权限',
      body: '脱敏诊断日志仅在你主动点击导出后写入所选位置。通知、文件、后台运行和剪贴板权限只用于对应功能，可通过系统设置撤回。',
    ),
    LegalSectionData(
      title: '删除数据',
      body: '退出登录会清除本地账号凭据；清空缓存、任务或历史记录时，以确认弹窗中显示的删除范围为准。卸载应用可移除其应用目录内的数据。',
    ),
  ],
);

/// 原生下载和媒体组件的第三方许可摘要。
const LegalDocumentData thirdPartyLicensesLegalDocument = LegalDocumentData(
  title: '第三方许可',
  introduction: '以下为随应用使用的主要原生组件许可摘要。发布包和下载页还应同时提供 SHA-256、源码地址、构建配置和许可证全文。',
  sections: <LegalSectionData>[
    LegalSectionData(
      title: 'aria2',
      body:
          '桌面和 Android 原生下载引擎使用 aria2。当前随包基线包含 Android Aria2Android 2.6.8 (76) 中的 aria2 1.36.0、aria2-zero v2025.04.06-release.1，以及 Windows aria2 1.37.0。aria2 本体按 GPL-2.0-or-later 分发；Android Aria2Android 分发包按 GPL-3.0-only 处理。各平台文件哈希见发布页原生组件清单。',
      links: <LegalLinkData>[
        LegalLinkData(
          label: 'Aria2Android LICENSE',
          assetPath: 'assets/licenses/aria2android-gpl-3.0.txt',
          sourceUrl:
              'https://github.com/devgianlu/Aria2Android/blob/master/LICENSE',
        ),
        LegalLinkData(
          label: 'aria2 COPYING',
          assetPath: 'assets/licenses/aria2-gpl-2.0.txt',
          sourceUrl: 'https://github.com/aria2/aria2/blob/master/COPYING',
        ),
        LegalLinkData(label: 'aria2 源码', url: 'https://github.com/aria2/aria2'),
        LegalLinkData(
          label: 'Aria2Android / F-Droid',
          url: 'https://f-droid.org/packages/com.gianlu.aria2android/',
        ),
        LegalLinkData(
          label: 'aria2-zero 发布页',
          url: 'https://github.com/zeromake/aria2-zero/releases',
        ),
        LegalLinkData(
          label: 'GPL-2.0 文本',
          url: 'https://www.gnu.org/licenses/old-licenses/gpl-2.0.txt',
        ),
      ],
    ),
    LegalSectionData(
      title: 'FFmpegKit',
      body:
          'Android、iOS、macOS、Windows x64 和 Linux x64 使用 ffmpeg_kit_extended_flutter 0.5.10 补丁包与 ffmpeg-kit-builders 0.10.4 归档。当前配置固定为 type: video、gpl: false、small: false，使用 shared LGPL 构建并关闭 GPL 组件。发布时应保留 LGPL-3.0-or-later 许可证、源码获取方式和可替换共享库要求。',
      links: <LegalLinkData>[
        LegalLinkData(
          label: 'FFmpegKit LICENSE',
          assetPath: 'assets/licenses/ffmpeg-kit-builders-license.txt',
          sourceUrl:
              'https://github.com/akashskypatel/ffmpeg-kit-builders/blob/master/LICENSE',
        ),
        LegalLinkData(
          label: 'FFmpegKit Builders',
          url: 'https://github.com/akashskypatel/ffmpeg-kit-builders',
        ),
        LegalLinkData(
          label: 'FFmpeg 法律说明',
          url: 'https://ffmpeg.org/legal.html',
        ),
        LegalLinkData(
          label: 'LGPL-3.0 文本',
          url: 'https://www.gnu.org/licenses/lgpl-3.0.txt',
        ),
      ],
    ),
    LegalSectionData(
      title: 'FFmpeg 命令行组件',
      body:
          'Windows ARM64 和 Linux ARM64 使用独立 FFmpeg CLI 兜底合并。当前文件来自 BtbN FFmpeg-Builds，版本为 n8.1.2-22-g94138f6973-20260710；构建参数启用 --enable-version3，未启用 --enable-gpl 或 --enable-nonfree，libav* 自报 LGPL version 3 or later。当前按 LGPL-3.0-or-later 记录；替换二进制后必须重新检查 -L 输出、构建参数和 SHA-256。',
      links: <LegalLinkData>[
        LegalLinkData(
          label: 'LGPL-3.0 LICENSE',
          assetPath: 'assets/licenses/lgpl-3.0.txt',
          sourceUrl: 'https://www.gnu.org/licenses/lgpl-3.0.txt',
        ),
        LegalLinkData(
          label: 'BtbN FFmpeg-Builds',
          url: 'https://github.com/BtbN/FFmpeg-Builds',
        ),
        LegalLinkData(
          label: 'BtbN Latest 资产说明',
          url: 'https://github.com/BtbN/FFmpeg-Builds/wiki/Latest',
        ),
        LegalLinkData(
          label: 'FFmpeg 源码',
          url: 'https://git.ffmpeg.org/ffmpeg.git',
        ),
        LegalLinkData(
          label: 'LGPL-3.0 文本',
          url: 'https://www.gnu.org/licenses/lgpl-3.0.txt',
        ),
      ],
    ),
    LegalSectionData(
      title: 'SQLite 与 Dart / Flutter 依赖',
      body:
          'SQLite 核心为公共领域；Drift、Dio、Riverpod、go_router 等依赖分别遵循各自许可证，完整登记内容请查看“开源许可证”。',
    ),
  ],
);

/// 软件身份、内容版权边界和允许用途说明。
const LegalDocumentData copyrightUsageLegalDocument = LegalDocumentData(
  title: '版权与使用说明',
  introduction: '使用本软件前，请确认你对目标内容拥有合法处理权限。',
  sections: <LegalSectionData>[
    LegalSectionData(
      title: '软件身份',
      body: 'BiliDown 是非官方第三方工具，与哔哩哔哩及其关联主体不存在隶属、授权、合作或赞助关系。',
    ),
    LegalSectionData(
      title: '功能边界',
      body: '本软件只提供本地视频解析和下载管理能力，不提供资源上传、自建媒体服务器或云端内容存储服务。',
    ),
    LegalSectionData(
      title: '解析范围',
      body: '本软件用于解析哔哩哔哩中的普通视频、合集和分集等受支持内容；媒体数据来自平台接口及其内容分发网络，并非由 BiliDown 提供。',
    ),
    LegalSectionData(
      title: '内容权利',
      body: '视频、音频、封面、字幕和其他内容的权利仍归原作者或合法权利人所有。解析成功不代表获得复制、传播或商业使用授权。',
    ),
    LegalSectionData(
      title: '允许用途',
      body: '请只处理你本人拥有权利、已经取得明确授权，或法律法规允许保存的内容，并遵守平台条款和所在地法律。',
    ),
    LegalSectionData(
      title: '禁止用途',
      body: '不得用于侵权传播、商业倒卖、绕过付费或会员限制、规避地区或版权限制、滥用接口，以及其他损害平台或权利人权益的行为。',
    ),
    LegalSectionData(
      title: '技术边界',
      body: '应用不提供 DRM 破解、会员权限提升或地区限制绕过功能。使用者应自行确认下载、保存和后续使用行为具备合法依据。',
    ),
    LegalSectionData(
      title: '软件分发',
      body:
          '官方发布版本免费提供。禁止将原安装包以付费、捆绑、冒名、植入广告或恶意篡改等方式再次分发；从第三方渠道取得的软件请自行核验安全性和完整性。',
    ),
    LegalSectionData(
      title: '使用责任',
      body: '本软件不对第三方内容的合法性或后续用途作出授权和背书。使用者应对自己的下载、保存、传播和其他使用行为承担相应责任。',
    ),
  ],
);

/// 展示应用对本地数据、网络访问和诊断日志的隐私处理说明。
Future<void> showPrivacyStatementDialog(BuildContext context) {
  AppDebugLog.settings('Privacy statement dialog opened');
  return showLegalDocumentDialog(
    context,
    document: privacyStatementLegalDocument,
  );
}

/// 展示原生下载和媒体组件的第三方许可摘要。
Future<void> showThirdPartyLicensesDialog(BuildContext context) {
  AppDebugLog.settings('Third party licenses dialog opened');
  return showLegalDocumentDialog(
    context,
    document: thirdPartyLicensesLegalDocument,
  );
}

/// 展示软件身份、内容版权边界和允许用途，并供账号页与设置页复用。
Future<void> showCopyrightUsageDialog(BuildContext context) {
  AppDebugLog.settings('Copyright usage dialog opened');
  return showLegalDocumentDialog(
    context,
    document: copyrightUsageLegalDocument,
  );
}

/// 构建统一的可滚动法律文档弹窗。
Future<void> showLegalDocumentDialog(
  BuildContext context, {
  required LegalDocumentData document,
}) {
  // 法律正文可能超过窗口高度，内容区独立滚动且不扩大整个页面。
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AppAlertDialog(
      width: 620,
      title: Text(document.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520),
        child: SingleChildScrollView(
          child: LegalDocumentBody(document: document),
        ),
      ),
      actions: <Widget>[
        AppActionButton(
          variant: AppActionButtonVariant.filled,
          onPressed: () {
            // 用户读完后仅关闭当前文档，不改变任何设置或登录状态。
            Navigator.of(dialogContext).pop();
          },
          label: '已读',
        ),
      ],
    ),
  );
}

/// 法律文档正文，供弹窗和移动端页面复用。
final class LegalDocumentBody extends StatelessWidget {
  /// 创建统一正文内容。
  const LegalDocumentBody({required this.document, super.key});

  /// 当前要展示的文档内容。
  final LegalDocumentData document;

  /// 构建分段标题和正文。
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(document.introduction),
        const SizedBox(height: 16),
        for (final section in document.sections) ...<Widget>[
          // 每段以短标题标识主题，便于用户快速定位关键边界。
          Text(section.title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(section.body),
          if (section.links.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final link in section.links)
                  _LegalDocumentLink(link: link),
              ],
            ),
          ],
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

/// 法律文档中的外部来源链接。
final class _LegalDocumentLink extends StatelessWidget {
  /// 创建可点击的外部链接控件。
  const _LegalDocumentLink({required this.link});

  /// 当前链接数据。
  final LegalLinkData link;

  /// 构建紧凑的链接按钮。
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final opensLocalAsset = link.assetPath != null;
    return ActionChip(
      avatar: Icon(
        opensLocalAsset ? Icons.article_outlined : Icons.open_in_new_rounded,
        size: 16,
        color: colorScheme.primary,
      ),
      label: Text(link.label),
      labelStyle: TextStyle(color: colorScheme.primary),
      side: BorderSide(color: colorScheme.outlineVariant),
      backgroundColor: colorScheme.surface,
      mouseCursor: SystemMouseCursors.click,
      onPressed: () => _openLegalLink(context),
    );
  }

  /// 使用系统浏览器打开外部许可证或源码链接。
  Future<void> _openLegalLink(BuildContext context) async {
    final assetPath = link.assetPath;
    if (assetPath != null) {
      // 随包许可证需要在应用内展示全文，避免用户离线或外部页面变化时无法核对。
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext routeContext) => LegalLicenseAssetPage(
              title: link.label,
              assetPath: assetPath,
              sourceUrl: link.sourceUrl,
            ),
          ),
        ),
      );
      return;
    }
    final url = link.url;
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      // 链接数据来自静态法律说明，异常时只反馈给当前页面，不中断阅读。
      AppSnackBar.show(context, message: '链接地址无效。');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted || opened) return;
    AppSnackBar.show(context, message: '无法打开链接，请稍后重试。');
  }
}

/// 随包许可证全文页面。
final class LegalLicenseAssetPage extends StatelessWidget {
  /// 创建一个可以离线查看的许可证文本页面。
  const LegalLicenseAssetPage({
    required this.title,
    required this.assetPath,
    this.sourceUrl,
    super.key,
  });

  /// 许可证页面标题。
  final String title;

  /// Flutter assets 中的许可证文本路径。
  final String assetPath;

  /// 许可证原始来源页面。
  final String? sourceUrl;

  /// 构建可复制、可滚动的许可证全文页面。
  @override
  Widget build(BuildContext context) {
    final pageBackground = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: pageBackground,
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<String>(
          // 许可证文本来自随包 assets，发布后不依赖网络即可查看。
          future: DefaultAssetBundle.of(context).loadString(assetPath),
          builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Text(
                  '许可证文本加载失败。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (sourceUrl != null) ...<Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ActionChip(
                        avatar: Icon(
                          Icons.open_in_new_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        label: const Text('打开上游 LICENSE'),
                        labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        mouseCursor: SystemMouseCursors.click,
                        onPressed: () => _openSourceUrl(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SelectableText(
                    snapshot.data!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 打开许可证的上游来源页面。
  Future<void> _openSourceUrl(BuildContext context) async {
    final url = sourceUrl;
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      // 详情页来源链接只用于辅助核验，失败时不影响本地文本阅读。
      AppSnackBar.show(context, message: '链接地址无效。');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted || opened) return;
    AppSnackBar.show(context, message: '无法打开链接，请稍后重试。');
  }
}
