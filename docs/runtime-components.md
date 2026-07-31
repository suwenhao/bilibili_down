# 随包运行组件说明

更新日期：2026-07-31

BiliDown 的安装包会随平台携带必要的下载和媒体处理组件。它们用于本地下载、合并、转换、字幕和弹幕等功能。

## 当前发布平台

当前只提供以下发布包：

- Android APK
- Windows x64
- Linux x64
- macOS arm64
- macOS x86_64
- iOS unsigned app

不提供 Windows ARM64 发布包。

## 关键组件

| 组件 | 使用平台 | 用途 | 许可证 |
| --- | --- | --- | --- |
| aria2 | Android、Windows x64、Linux x64、macOS | 下载媒体分流文件 | GPL-2.0-or-later；Android 分发包包含 Aria2Android GPL-3.0-only |
| FFmpegKit | Android、iOS、Windows x64、Linux x64、macOS | 合并音视频、转换格式、处理字幕和弹幕 | LGPL-3.0-or-later |
| Flutter / Dart | 全平台 | 应用界面与运行时 | BSD-3-Clause |
| SQLite / sqlite3 | 全平台 | 本地保存任务记录、设置和文件索引 | SQLite Public Domain 及相关包许可证 |

## 组件来源

| 组件 | 版本或来源说明 |
| --- | --- |
| Android aria2 | 来自 F-Droid 可复现构建的 Aria2Android 2.6.8 (76)，内含 aria2 1.36.0 |
| Windows x64 aria2 | aria2 1.37.0 official Windows 64-bit build1 |
| Linux x64 aria2 | aria2-zero v2025.04.06-release.1 |
| macOS aria2 | aria2-zero v2025.04.06-release.1 |
| FFmpegKit | ffmpeg-kit-builders 0.10.4 / ffmpeg_kit_extended_flutter 0.5.10 补丁包，使用 video + LGPL + shared 配置 |

## 文件完整性

发布页如果提供 `SHA256SUMS.txt`，你可以用它校验安装包或压缩包是否完整。具体方法见 [下载校验与安全软件提示说明](security-and-verification.md)。

## 相关链接

- [aria2 源码](https://github.com/aria2/aria2)
- [Aria2Android 源码与许可证](https://github.com/devgianlu/Aria2Android)
- [FFmpeg 法律说明](https://ffmpeg.org/legal.html)
- [FFmpeg 源码](https://git.ffmpeg.org/ffmpeg.git)
- [FFmpegKit builders](https://github.com/akashskypatel/ffmpeg-kit-builders)
