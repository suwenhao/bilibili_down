# BiliDown 发布身份与商店元数据

## 固定身份

- 产品名：`BiliDown`
- Android applicationId / namespace：`com.bilidown.app`
- iOS、macOS bundle identifier：`com.bilidown.app`
- Linux application ID：`com.bilidown.app`
- Windows 应用支持目录标识：`com.bilidown.app`
- Windows 展示名 / 文件描述：`BiliDown`
- 默认分类：工具 / Utilities
- 默认语言：简体中文

应用 ID 属于升级链路的一部分，首次正式发布后不得修改。Dart 包名与桌面可执行文件名继续使用 `bilibili_down`，避免破坏源码导入和打包脚本；应用支持目录统一交给 `path_provider`，桌面可见目录标识使用 `com.bilidown.app`。

## 图标

正式图标使用深色圆角背景、蓝绿渐变电视轮廓和白色下载箭头，源文件为 `assets/images/app_icon.png`。图标不使用哔哩哔哩吉祥物、文字或受保护的既有商标造型。Android 和 iOS 使用不透明方形资源并由系统应用圆角遮罩；macOS、Windows、Linux 和托盘资源使用约 22% 半径的透明圆角，避免桌面环境显示成方块。

生成提示词摘要：为跨平台视频下载器生成原创、扁平、无文字的电视与下载箭头组合图标，使用 `#FB7299`、白色和 `#14181A`，保证 16 像素可识别。

## 商店文案

### 简短说明

解析并管理个人有权保存的哔哩哔哩视频下载任务。

### 完整说明

BiliDown 是一款跨平台下载任务管理工具，可解析哔哩哔哩视频链接，选择清晰度、音质、字幕、弹幕和封面，并在本地完成下载、合并、恢复与文件管理。应用支持批量任务、并发控制、断网恢复、系统通知、诊断日志导出和亮暗主题。

用户必须仅下载自己拥有权利或已获得授权的内容，并遵守平台服务条款、著作权法及所在地法律。BiliDown 不提供、托管或破解受保护内容，也不绕过会员、地区或数字版权限制。

### 关键词

`BiliDown`、`视频下载`、`任务管理`、`字幕`、`弹幕`、`批量下载`

### 隐私与支持材料

- 隐私声明：`docs/privacy.md`
- 第三方许可证：`docs/third-party-licenses.md`
- 版权与使用说明：`docs/copyright-and-usage.md`
- 下载校验与误报说明：`docs/security-and-verification.md`
- 支持渠道：发布仓库的 Issue 页面

商店提交前，发布负责人必须把上述文档部署到公开 HTTPS 地址，并在商店后台填写该仓库的支持 URL；仓库不虚构尚未确定的域名或联系邮箱。

## 签名策略

### Android

正式包只能使用独立上传证书签名。开发机复制 `android/key.properties.example` 为 `android/key.properties`，CI 则注入 `BILIDOWN_STORE_FILE`、`BILIDOWN_STORE_PASSWORD`、`BILIDOWN_KEY_ALIAS`、`BILIDOWN_KEY_PASSWORD`。真实配置和证书已加入忽略规则；缺少任意字段时 release 任务必须失败，禁止回退到 debug 签名。

### Apple 平台

iOS 与 macOS 使用同一 Apple Developer Team 的 Distribution 证书和商店 provisioning profile。证书、私钥、Team ID 和 profile 只保存在开发者钥匙串或 CI Secret，构建时由 Xcode/CI 注入，不进入仓库。

### Windows 与 Linux

Windows 若取得受信任代码签名证书，应优先对 Runner、随包原生工具和安装包签名，证书私钥只由本地安全存储或 CI Secret 管理。开源发布在暂未签名时仍可发布，但必须固定官方下载来源、提供 `SHA256SUMS.txt`、保留源码和许可证链接，并在发布页引用 `docs/security-and-verification.md`；未签名产物不得伪装为已签名或诱导用户关闭安全软件。Linux 发布产物同时提供仓库签名或 SHA-256 校验值。

## 发布门禁

- 应用 ID、版本号、产品名和图标与本文件一致。
- 正式构建使用发布证书，且证书仍在有效期内。
- 隐私、许可证和版权页面已部署为公开 HTTPS 页面。
- 商店截图来自对应版本，并覆盖桌面和手机主要流程。
- 发布产物、符号文件、SBOM 和 SHA-256 清单一并归档。
- Windows 未签名发布必须附 `SHA256SUMS.txt`、源码链接、第三方组件说明和安全软件误报说明。
