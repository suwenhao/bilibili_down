import 'package:flutter/material.dart';

/// 四步产品说明的不可变内容，顺序与顶部进度保持一致。
const onboardingSteps = <OnboardingStep>[
  OnboardingStep(
    title: '欢迎使用 BiliDown',
    subtitle: '粘贴链接，轻松保存 B 站视频',
    visual: OnboardingVisual.welcome,
    items: <OnboardingItem>[
      OnboardingItem(
        icon: Icons.link_rounded,
        title: '支持链接粘贴',
        detail: '解析 B 站视频、番剧、合集等链接',
      ),
      OnboardingItem(
        icon: Icons.download_rounded,
        title: '多种清晰度可选',
        detail: '按账号权限选择画质并加入下载队列',
      ),
      OnboardingItem(
        icon: Icons.verified_user_outlined,
        title: '请合规使用',
        detail: '仅下载个人学习或已获授权的内容',
      ),
    ],
  ),
  OnboardingStep(
    title: '三步完成下载',
    subtitle: '粘贴链接，选择内容与画质，加入队列',
    visual: OnboardingVisual.download,
    items: <OnboardingItem>[
      OnboardingItem(
        icon: Icons.looks_one_outlined,
        title: '粘贴链接',
        detail: '支持 B 站链接或 BV / AV / EP / SS 号',
      ),
      OnboardingItem(
        icon: Icons.looks_two_outlined,
        title: '选择内容与画质',
        detail: '选择分集、视频与账号可用清晰度',
      ),
      OnboardingItem(
        icon: Icons.looks_3_outlined,
        title: '加入下载队列',
        detail: '解析完成后排队下载，重启不会自动续传',
      ),
    ],
  ),
  OnboardingStep(
    title: '保存位置',
    subtitle: '使用合理默认位置，也可稍后调整',
    visual: OnboardingVisual.storage,
    items: <OnboardingItem>[
      OnboardingItem(
        icon: Icons.android_rounded,
        title: 'Android',
        detail: '默认保存到系统公共下载目录',
      ),
      OnboardingItem(
        icon: Icons.apple_rounded,
        title: 'iOS',
        detail: '默认保存在 App 内部目录，可在“文件”中访问',
      ),
      OnboardingItem(
        icon: Icons.folder_outlined,
        title: '可随时调整',
        detail: 'Android 可稍后在设置中选择其他目录',
      ),
    ],
  ),
  OnboardingStep(
    title: '必要授权，稳定下载',
    subtitle: '首次使用前完成文件管理和通知授权',
    visual: OnboardingVisual.ready,
    items: <OnboardingItem>[
      OnboardingItem(
        icon: Icons.folder_copy_outlined,
        title: '文件管理授权',
        detail: '用于保存、转换和删除下载文件',
        permissionKind: OnboardingPermissionKind.fileManagement,
      ),
      OnboardingItem(
        icon: Icons.notifications_none_rounded,
        title: '通知权限',
        detail: '用于展示下载、合并和转换进度',
        permissionKind: OnboardingPermissionKind.notification,
      ),
      OnboardingItem(
        icon: Icons.shield_outlined,
        title: '隐私边界清晰',
        detail: '权限只服务本地下载和文件处理',
      ),
    ],
  ),
];

/// 单页引导所需的不可变产品内容。
final class OnboardingStep {
  /// 创建标题、说明、主视觉和功能项集合。
  const OnboardingStep({
    required this.title,
    required this.subtitle,
    required this.visual,
    required this.items,
  });

  /// 当前步骤主标题。
  final String title;

  /// 当前步骤的一句话说明。
  final String subtitle;

  /// 顶部主视觉类型。
  final OnboardingVisual visual;

  /// 功能卡片内按顺序展示的说明项。
  final List<OnboardingItem> items;
}

/// 功能卡片内单条不可变说明。
final class OnboardingItem {
  /// 创建图标、标题和详细说明。
  const OnboardingItem({
    required this.icon,
    required this.title,
    required this.detail,
    this.permissionKind,
  });

  /// Material 图标，表达当前说明的功能语义。
  final IconData icon;

  /// 说明行的主要标签。
  final String title;

  /// 说明行的补充信息或产品边界。
  final String detail;

  /// 需要在引导页内主动授权的系统能力；为空表示纯说明项。
  final OnboardingPermissionKind? permissionKind;
}

/// 引导最后一步需要用户主动确认的系统权限。
enum OnboardingPermissionKind {
  /// Android 文件管理授权，用于公共下载目录的真实路径写入、转换和删除。
  fileManagement,

  /// 系统通知权限，用于下载、合并和转换进度提示。
  notification,
}

/// 四种步骤主视觉类型。
enum OnboardingVisual {
  /// 使用真实应用图标建立品牌识别。
  welcome,

  /// 使用链接与下载按钮示意三步下载流程。
  download,

  /// 使用 Android、目录和 iOS 图标说明平台保存差异。
  storage,

  /// 使用安全图标说明按需授权和隐私边界。
  ready,
}
