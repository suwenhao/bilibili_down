import 'package:flutter/material.dart';

import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/app_dialog.dart';

/// 展示当前安装包版本、1.0.2 更新内容和应用身份说明。
Future<void> showVersionInfoDialog({
  required BuildContext context,
  required String version,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AppAlertDialog(
      title: const Text('BiliDown 版本详情'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        // 更新说明较长时允许正文滚动，保证小屏和矮窗口仍可关闭弹窗。
        child: SingleChildScrollView(
          child: Text(
            '当前版本：$version\n\n'
            '1.0.2 新增：\n'
            '• 新增独立“AI 字幕”选项，与人工字幕分别选择，支持批量导出为 SRT。\n'
            '• 新增下载限速设置，可调整全局下载速度上限。\n'
            '• 开启剪贴板监听后，识别 B 站链接并自动进入解析。\n\n'
            '1.0.2 修复与优化：\n'
            '• 证书吊销服务器不可达时，自动切换备用下载线路，最多重试两次，并改善失败提示。\n'
            '• 修复账号弹窗中版权使用说明的页面跳转。\n'
            '• 完善多平台打包兼容性、原生组件校验与许可证说明。\n\n'
            'AI 字幕需视频已提供对应轨道，部分字幕需要先登录 B 站。\n\n'
            'BiliDown 是面向多平台的非官方第三方下载工具。许可证、隐私和版权说明可在设置页“法律与许可”中分别查看。',
          ),
        ),
      ),
      actions: <Widget>[
        AppActionButton(
          variant: AppActionButtonVariant.filled,
          onPressed: () {
            // 关闭详情弹窗回到设置页。
            Navigator.of(dialogContext).pop();
          },
          label: '知道了',
        ),
      ],
    ),
  );
}
