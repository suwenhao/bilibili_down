# BiliDown 第三方许可证说明

更新日期：2026-07-31

BiliDown 使用 Flutter、Dart 生态依赖及随包原生工具。应用内“设置 → 法律与许可 → 开源许可证”通过 Flutter `LicenseRegistry` 展示随构建产物登记的 Dart/Flutter 许可证全文；“第三方许可”展示 aria2、FFmpegKit 与 FFmpeg CLI 摘要，并可进入随包 `assets/licenses/` 中的许可证全文页面。

## 关键运行时组件

| 组件 | 用途 | 许可证与发布要求 |
| --- | --- | --- |
| Flutter / Dart | 跨平台应用框架与运行时 | BSD-3-Clause；保留版权和许可证文本 |
| aria2 | 桌面及支持平台的下载引擎 | GPL-2.0-or-later；Android Aria2Android 分发包同时提供 GPL-3.0-only LICENSE；分发二进制时必须提供相应许可证、源码获取方式及构建来源 |
| FFmpegKit 扩展包 | 主流平台音视频流封装与合并 | 当前配置为 LGPL-3.0-or-later、小型共享构建且关闭 GPL；发布包保留 `assets/licenses/ffmpeg-kit-builders-license.txt`、源码获取方式及可替换共享库要求 |
| FFmpeg ARM64 静态 CLI | Windows ARM64、Linux ARM64 合并兜底 | 当前固定基线按 LGPL-3.0-or-later 分发；必须随包提供 `assets/licenses/lgpl-3.0.txt`、对应源码获取方式、构建配置和哈希，不得与 FFmpegKit 混写成同一项 |
| SQLite / sqlite3 | 本地任务数据库 | SQLite Public Domain；Dart 封装各自许可证由应用内许可证页展示 |
| Dio、Drift、Riverpod、go_router 等 | 网络、数据库和状态管理 | 以各包随构建登记的许可证为准，应用内许可证页展示全文 |
| PingFang-SC-Medium.ttf | 统一界面字体 | 发布前必须确认具有跨平台再分发授权；无法提供授权证明时必须更换为可再分发字体 |

## 发布检查

1. 不得仅依赖本文件替代依赖包的完整许可证文本。
2. 每次升级依赖或替换原生二进制后重新生成并人工检查应用内许可证清单。
3. 安装包或下载页需要同时提供 aria2、FFmpeg 的准确版本、源码地址、构建配置、哈希和许可证文本；发布页可直接引用 `docs/release-runtime-components.md`，应用内应保留 `assets/licenses/` 许可证全文入口。
4. 商店截图、描述和应用名称不得暗示获得哔哩哔哩官方授权。
5. 本项目自身源代码目前没有在仓库根目录声明开放源代码许可证；对外发布源代码前需由权利人明确选择许可证，不能默认套用第三方许可证。
