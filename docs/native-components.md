# 原生工具来源说明

BiliDown 为了完成下载和媒体处理，会在部分平台随包携带 aria2、FFmpegKit 或 FFmpeg 相关组件。这些工具只在本机运行，用于处理你主动创建的下载任务。

## 为什么需要这些组件

- aria2：负责稳定下载视频、音频等媒体分流文件。
- FFmpegKit / FFmpeg：负责把音频和视频合并为常见媒体文件，也用于本地格式转换。
- SQLite：负责在本机保存任务、进度、文件索引和设置。

## 来源原则

BiliDown 的发布包应尽量使用固定版本和可追溯来源的组件，避免随意混入未知二进制文件。用户可以通过发布页、许可证文档和校验文件了解组件来源。

## 当前组件来源

| 组件 | 来源 |
| --- | --- |
| Android aria2 | F-Droid 可复现构建的 Aria2Android |
| Windows x64 aria2 | aria2 官方 Windows x64 发布包 |
| Linux x64 / macOS aria2 | aria2-zero 发布包 |
| FFmpegKit | ffmpeg-kit-builders 的 LGPL shared video 构建 |
| FFmpeg | FFmpeg 官方项目及对应构建说明 |

## 用户可以怎么确认

1. 从官方发布页下载 BiliDown。
2. 使用 `SHA256SUMS.txt` 校验安装包或压缩包。
3. 查看 [随包运行组件说明](runtime-components.md) 和 [第三方许可证说明](third-party-licenses.md)。
4. 如果安全软件提示风险，先不要关闭防护，优先重新下载并校验哈希。

## 隐私边界

这些原生工具只用于本地下载和本地媒体处理。BiliDown 不会把你的下载历史、本地文件或诊断日志上传给 BiliDown 开发者。
