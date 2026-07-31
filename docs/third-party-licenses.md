# 第三方许可证说明

更新日期：2026-07-31

BiliDown 使用 Flutter、Dart 生态依赖，以及 aria2、FFmpegKit、FFmpeg 等原生组件来完成下载和媒体处理。应用内「设置 → 法律与许可」可以查看开源许可证和第三方许可说明。

## 主要组件

| 组件 | 用途 | 许可证 |
| --- | --- | --- |
| Flutter / Dart | 跨平台应用框架与运行时 | BSD-3-Clause |
| aria2 | 下载引擎 | GPL-2.0-or-later；Android 版本还包含 Aria2Android 的 GPL-3.0-only 许可证 |
| FFmpegKit | 音视频封装、合并和转换 | LGPL-3.0-or-later |
| FFmpeg CLI | 部分平台的媒体处理兜底组件 | LGPL-3.0-or-later |
| SQLite / sqlite3 | 本地任务数据库 | SQLite Public Domain 及相关 Dart 包许可证 |
| Dio、Drift、Riverpod、go_router 等 | 网络、数据库、状态管理和路由 | 以应用内许可证页展示为准 |

## 在哪里查看完整许可证

- 应用内「设置 → 法律与许可 → 开源许可证」展示 Flutter/Dart 依赖登记的许可证全文。
- 应用内「设置 → 法律与许可 → 第三方许可」展示 aria2、FFmpegKit、FFmpeg 等原生组件说明。
- 发布包和仓库文档中会保留关键原生组件的来源、许可证和校验信息。

## 许可证链接

- [aria2 源码](https://github.com/aria2/aria2)
- [aria2 COPYING](https://github.com/aria2/aria2/blob/master/COPYING)
- [Aria2Android LICENSE](https://github.com/devgianlu/Aria2Android/blob/master/LICENSE)
- [FFmpeg 法律说明](https://ffmpeg.org/legal.html)
- [FFmpeg 源码](https://git.ffmpeg.org/ffmpeg.git)
- [FFmpegKit builders LICENSE](https://github.com/akashskypatel/ffmpeg-kit-builders/blob/master/LICENSE)
- [LGPL-3.0 文本](https://www.gnu.org/licenses/lgpl-3.0.txt)

## 用户需要知道的事

这些许可证主要约束软件分发和组件使用方式，不会限制你正常使用 BiliDown 管理自己的下载文件。你仍需要确认下载内容本身具有合法保存和使用权限。
