# 下载校验与安全软件误报说明

BiliDown 是开源软件，发布包应当可以从源码、许可证、第三方二进制来源和 SHA-256 摘要逐项追溯。未签名版本可能被 Windows SmartScreen 或部分安全软件提示风险；这不等于文件一定有问题，但用户必须能自行验证来源和完整性。

## 官方来源

正式发布只使用以下来源：

- 项目 GitHub Releases。
- 项目维护者在 README 或 Release Notes 中明确列出的 HTTPS 下载地址。

不要从网盘转载、第三方下载站、聊天群转发压缩包或改名文件安装。若文件名、大小、哈希与 Release 页面不一致，应当删除并重新从官方来源下载。

## SHA-256 校验

每次正式发布必须提供 `SHA256SUMS.txt`。Windows 用户可以在 PowerShell 中运行：

```powershell
Get-FileHash .\BiliDown-windows-x64.zip -Algorithm SHA256
```

把输出的 `Hash` 与 Release 页面或 `SHA256SUMS.txt` 中对应文件的 SHA-256 对比；完全一致才代表下载文件没有在传输或镜像过程中被改动。

维护者生成发布清单时运行：

```powershell
pwsh -File tool/create_release_checksums.ps1 -Path dist
```

## 安全软件误报

开源、未签名或下载量较小的软件容易触发启发式检测，尤其是包含下载器、FFmpeg、aria2、网络请求或缓存清理功能时。BiliDown 的正式发布应遵守以下原则，降低误报概率：

- 不使用加壳、加密打包、自解压壳或隐藏释放二进制。
- 不混淆 Dart、C++ Runner 或原生工具文件名。
- 保留稳定产品名、版本号、应用 ID 和 Windows 文件版本信息。
- 发布页同时提供源码、许可证、第三方组件说明和 SHA-256。
- 清理缓存只处理应用缓存目录内的文件，不删除数据库、登录凭据或用户下载内容。
- 误报时向对应安全厂商提交官方 Release 链接、SHA-256、源码仓库和许可证说明。

不要要求用户关闭安全软件。正确做法是让用户从官方来源重新下载、校验 SHA-256，并把误报样本提交给安全厂商复核。

## 原生组件来源

aria2、FFmpegKit 和 FFmpeg CLI 的版本、许可证、来源与哈希见：

- `docs/release-runtime-components.md`
- `docs/native-tool-supply-chain.md`
- `native_bins/manifest.json`

发布前必须运行：

```powershell
pwsh -File tool/verify_native_binaries.ps1
```

该检查用于确认随包原生二进制没有被替换、缺失或混入未登记文件。
