/// 应用外壳和功能页面共用的响应式断点。
abstract final class AppBreakpoints {
  /// 该宽度以下把解析页底部操作拆成上下两行。
  static const double parserActionBarStack = 380;

  /// 该宽度以下只显示任务批量操作图标。
  static const double smallMobile = 420;

  /// 该宽度以下使用解析页紧凑底部操作栏。
  static const double parserActionBarCompact = 560;

  /// 该宽度以下把解析输入框和按钮改为上下排列。
  static const double parserInputStack = 600;

  /// 该宽度以下大型设置弹窗使用全屏页面形态。
  static const double dialogFullscreen = 600;

  /// 该宽度以下非手机弹窗最大宽度限制为 560dp。
  static const double dialogWide = 1024;

  /// 该宽度以下把设置弹窗的输入框和随机按钮改为上下排列。
  static const double settingsDialogFieldStack = 620;

  /// 该宽度及以上显示桌面侧边导航栏。
  static const double navigationRail = 720;
}
