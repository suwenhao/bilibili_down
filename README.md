# BiliDown

面向 Android、iOS、Windows、macOS 和 Linux 的 Flutter B 站视频下载工具。

当前仓库已实现解析、任务持久化、并发下载、媒体合并、后台恢复和跨平台响应式界面。

## 文档

- [版本更新记录](CHANGELOG.md)
- [技术架构与功能规划](docs/technical-architecture.md)
- [隐私声明](docs/privacy.md)
- [第三方许可证说明](docs/third-party-licenses.md)
- [版权与使用说明](docs/copyright-and-usage.md)
- [下载校验与安全软件误报说明](docs/security-and-verification.md)
- [原生运行时组件清单](docs/release-runtime-components.md)
- [原生工具供应链说明](docs/native-tool-supply-chain.md)

## 环境

- Flutter 3.44.5
- Dart 3.12.2
- Android 8.0（API 26）或更高版本
- iOS 14 或更高版本
- macOS 13 或更高版本
- Windows x64
- Linux x64，glibc 2.28 或更高版本

## 开发命令

```powershell
flutter pub get
flutter analyze
flutter run -d windows
```

各平台原生依赖、下载引擎差异和 FFmpeg 配置见技术架构文档。

## 构建命令

GitHub Actions 的签名配置、Workmanager 编译兼容和产物额度处理见
[GitHub Actions 构建与上传](docs/github-actions.md)。

Android release APK（按 ABI 拆包）：

```powershell
flutter build apk --release --split-per-abi
```

Android release App Bundle：

```powershell
flutter build appbundle --release
```

Windows x64：

```powershell
flutter config --enable-windows-desktop
flutter build windows --release
```

macOS：

```bash
flutter config --enable-macos-desktop
flutter build macos --release
```

iOS 无签名 app：

```bash
flutter build ios --release --no-codesign
```

iOS 正式签名 IPA：

```bash
flutter build ipa --release
```

正式 iOS 签名需要先在 Xcode 中配置 Bundle ID、Team、证书和描述文件。

Linux x64：

```bash
sudo apt-get update
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libsecret-1-dev libayatana-appindicator3-dev
flutter config --enable-linux-desktop
flutter build linux --release
```

Linux deb 包可参考 `.gitea/workflows/build.yml` 中的 `Package deb` 步骤，构建产物目录为 `build/linux/x64/release/bundle`。

## 下载校验

正式发布请只从项目 GitHub Releases 或项目维护者明确列出的 HTTPS 地址获取。发布包会随附 `SHA256SUMS.txt`，Windows 用户可用以下命令校验：

```powershell
Get-FileHash .\BiliDown-windows-x64.zip -Algorithm SHA256
```

若安全软件误报，请先确认下载来源和 SHA-256；误报申诉与校验说明见 [下载校验与安全软件误报说明](docs/security-and-verification.md)。
