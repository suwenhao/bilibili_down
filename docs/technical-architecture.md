# BiliDown 技术架构与功能规划

## 1. 结论

项目不能在五个平台上强行使用完全相同的后台下载实现。统一的是 Dart 领域模型和任务状态机，平台下载能力通过接口适配：

| 平台 | 主下载引擎 | 后台策略 | 合并 |
| --- | --- | --- | --- |
| Android | aria2 原生适配器；系统下载器作为回退 | 前台服务通知 + WorkManager 恢复/清理 | FFmpegKit |
| iOS | `background_downloader` / `URLSession` | 系统后台传输 | FFmpegKit，在系统允许的执行窗口内处理 |
| Windows | aria2c 子进程 + JSON-RPC | 桌面进程、托盘 | FFmpegKit |
| macOS | aria2c 子进程 + JSON-RPC | 桌面进程、托盘 | FFmpegKit |
| Linux | aria2c 子进程 + JSON-RPC | 桌面进程、托盘 | FFmpegKit |

iOS 不运行常驻 aria2c 子进程。iOS 应将音视频流作为两个系统后台下载任务，完成后再进入合并阶段。

## 2. 已安装依赖

### 应用基础

| 能力 | 包 | 说明 |
| --- | --- | --- |
| 状态管理 | `flutter_riverpod`, `riverpod_annotation` | 统一异步状态、依赖注入和任务流 |
| 路由 | `go_router` | 响应式 Shell 路由、深链接 |
| API | `dio` | B 站 API、重定向、请求头和超时处理 |
| 模型 | `freezed_annotation`, `json_annotation` | 不可变模型和 JSON 序列化 |
| 代码生成 | `build_runner`, `riverpod_generator`, `freezed`, `json_serializable`, `drift_dev`, `go_router_builder` | 开发期生成器 |
| 日志与工具 | `logging`, `uuid`, `collection`, `crypto` | 日志、任务 ID、集合工具、WBI/摘要计算 |

没有安装 `provider`。它与 Riverpod 的职责重复，项目统一使用 `flutter_riverpod` 的 Provider 体系。

### 存储

| 数据 | 包 | 规则 |
| --- | --- | --- |
| 主题、并发数、通知开关等设置 | `shared_preferences` | 保存非敏感设置；后台任务只读取已经写入 Drift 的任务快照 |
| Cookie、刷新令牌等敏感信息 | `flutter_secure_storage` | 禁止写入普通设置或 Drift |
| 下载任务、分集、状态、错误、文件记录 | `drift`, `drift_flutter` | SQLite 持久化，支持应用重启恢复 |
| 应用目录 | `path`, `path_provider` | 临时文件、数据库、日志和工具路径 |

### 下载与平台能力

| 能力 | 包 | 说明 |
| --- | --- | --- |
| 系统后台下载 | `background_downloader` | iOS 主引擎，也是其他平台的回退方案 |
| 延迟任务 | `workmanager` | 恢复、校验、清理；不负责长时间持续下载 |
| Android 前台服务 | `flutter_foreground_task` | aria2 下载与 FFmpeg 合并期间维持通知 |
| 通知 | `flutter_local_notifications` | 完成、失败和桌面通知 |
| 音视频合并 | `ffmpeg_kit_extended_flutter` | 使用 video LGPL 共享库，避免 full 包引入 TensorFlow/OpenVINO |
| 文件/目录选择 | `file_selector` | 官方跨平台选择器 |
| 外部链接 | `url_launcher` | 打开 B 站、声明和帮助链接 |
| 权限 | `permission_handler` | 通知和平台权限 |
| 桌面窗口/托盘 | `window_manager`, `tray_manager` | Windows、macOS、Linux |
| 网络状态 | `connectivity_plus` | 只作为网络变化信号，不代替真实请求检测 |
| 二维码 | `qr_flutter` | 展示 B 站扫码登录二维码 |
| 版本信息 | `package_info_plus` | 设置页和诊断信息 |

## 3. 推荐目录结构

```text
lib/
  app/
    app.dart
    router.dart
    theme/
  core/
    database/
    logging/
    network/
    platform/
    storage/
  features/
    auth/
    parser/
    downloads/
    settings/
  services/
    bilibili/
    download_engine/
    media_merge/
```

平台差异必须封装在 `services/download_engine` 和 `core/platform`，页面和 Riverpod Provider 不直接判断操作系统。

## 4. 下载引擎接口

建议定义统一接口：

```dart
abstract interface class DownloadEngine {
  Stream<DownloadEvent> watchEvents();
  Future<void> enqueue(DownloadRequest request);
  Future<void> pause(String taskId);
  Future<void> resume(String taskId);
  Future<void> cancel(String taskId);
  Future<void> restore();
  Future<void> dispose();
}
```

实现类：

- `Aria2DownloadEngine`：Windows、macOS、Linux，以及后续 Android 原生适配。
- `SystemDownloadEngine`：封装 `background_downloader`，iOS 必选、其他平台回退。
- `DownloadEngineFactory`：只在组合根根据平台返回实现，业务层不分支。

### aria2 要求

- 通过随机本地端口启动 JSON-RPC，必须设置一次性 RPC secret。
- 只绑定 `127.0.0.1`，禁止对局域网开放。
- 进程 PID、RPC 端口和 session 文件保存在应用支持目录。
- 使用 `--continue=true`、session 定时保存、分片下载和最大并发配置。
- B 站媒体请求必须带正确的 `User-Agent`、`Referer`，必要时带 Cookie。
- 视频流和音频流分别下载到临时文件，两个任务都完成后才能进入合并。
- 媒体 URL 可能过期；遇到 `401/403` 时重新获取播放地址并更新任务，不盲目重试旧 URL。

Android 不能直接把 Windows/Linux 的 aria2c 可执行文件当 Flutter asset 执行，需要为各 ABI 提供原生构建和平台通道，并在前台服务内管理生命周期。

## 5. 任务状态机

```text
queued
  -> resolving
  -> downloadingVideo + downloadingAudio
  -> merging
  -> completed
```

所有活动状态都可以转到：

- `paused`
- `failed`
- `canceled`

数据库至少保存：任务 ID、BVID/CID、标题、封面、流类型、质量、编码、临时路径、最终路径、下载引擎 ID、状态、进度、重试次数、错误码、创建和更新时间。

应用启动后先从 Drift 恢复任务，再向下载引擎查询真实状态；数据库状态不能单方面作为下载是否仍在运行的依据。

## 6. 解析与登录

### 首期支持

- BV 号和标准视频链接
- EP / SS 番剧链接
- `b23.tv` 短链接重定向
- 普通多 P 视频
- UGC 合集中的分集
- 二维码登录、登录状态检查、退出登录
- WBI 签名、Cookie 请求头、登录过期处理

### 后续扩展

- AV / MD 兼容输入
- UP 主合集链接
- 收藏夹链接和批量解析
- 8K、HDR、杜比视界、AV1/HEVC 选择
- Hi-Res、杜比、FLAC、AI 翻译音轨
- 仅音频、保留音频、封面、字幕
- 弹幕 XML 下载和 ASS 转换

解析页只展示视频基础信息和分集选择。播放流、画质、音轨和编码选择属于选中分集后的下一步。

## 7. B 站 API 边界

参考项目中值得复用的思路：

- `BiliDownloader-main`：BV/AV/MD/EP 输入、DASH 音视频分流、高品质音频选择、FFmpeg stream copy、弹幕转换、二维码登录和 Cookie 加密。
- `bilidown-main`：BV/EP/SS/收藏夹/合集链接归一化、`b23.tv` 跳转、WBI、二维码轮询、SQLite 任务、并发下载和 FFmpeg 进度解析。

不能直接复制其网络代码。需要重新封装：

- 统一超时、取消、指数退避和 API 错误映射。
- 缓存并刷新 WBI key。
- 保存完整登录 Cookie，而不只保存 `SESSDATA`。
- API 与 CDN 请求使用不同的重试策略。
- 对 `-101` 未登录、`-403` 风控、`-404` 资源不存在等错误提供明确用户提示。
- 限制批量解析并发，避免触发风控。

## 8. FFmpeg 合并

首期仅做无损封装合并：

```text
ffmpeg -i video.m4s -i audio.m4s -map 0:v:0 -map 1:a:0 -c copy -movflags +faststart output.mp4
```

实现要求：

- 使用参数数组，不拼接 shell 字符串。
- 临时文件名只使用内部任务 ID，避免标题注入命令。
- 监听 FFmpeg 统计输出，单独展示合并进度。
- 成功后原子移动最终文件，再清理临时文件。
- 失败时保留可恢复的临时文件，并记录完整日志。
- 上线前确认 FFmpegKit 构建的 LGPL/GPL 许可证边界。

## 9. 平台限制

### Android

- 最低 API 26，由 FFmpegKit 决定。
- 下载使用 `dataSync` 前台服务；合并使用 `mediaProcessing` 类型。
- Android 13+ 需要通知权限。
- Android 15 对前台服务有时长限制，不能承诺无限后台保活。
- WorkManager 只做任务恢复、校验和清理，不自动从开机广播启动下载前台服务。

### iOS

- 最低 iOS 14，由 `background_downloader` 决定。
- 后台下载交给 `URLSession`；用户强制划掉应用后，任务可能被系统终止。
- 音视频下载完成不代表系统会立即给足够时间完成长时间合并，需要设计“等待合并，打开应用继续”的状态。
- 不实现 aria2c 常驻子进程。

### macOS

- FFmpegKit 当前要求 macOS 13 或更高版本。
- 已添加网络客户端和 Keychain entitlement。

### Linux

- FFmpegKit 当前仅考虑 x64/glibc 2.28+；ARM64 需要单独验证或自建库。
- 构建机需要 `libsecret`，托盘通常需要 AppIndicator/Ayatana 开发包。

### Windows

- 当前以 x64 为首期目标。
- 发布时需要把 aria2c、许可证和校验文件一起打包，或首次运行时安全下载并验签。

## 10. 仍需补充的工作

1. 确定正式应用 ID、产品名、图标、签名和商店发布方式。
2. 确定 aria2c 各平台二进制来源、版本、许可证、哈希和更新策略。
3. 在 macOS 或 CI 上完成 iOS/macOS Podfile、FFmpegKit 架构排除和签名验证。
4. 完善 Drift 后续版本迁移、任务清理和损坏数据库恢复策略。
5. 补齐 B 站 refresh token 自动换新和远端退出接口。
6. 扩展字幕、弹幕、封面和更多 PGC 边界内容解析。
7. 完成 aria2 与系统下载适配器的各平台真机恢复和异常矩阵验证。
8. 实现临时文件、磁盘空间、文件名、路径长度和重复文件策略。
9. 实现断网恢复、备用 CDN 切换和更细粒度的人工重试策略。
10. 实现日志导出、崩溃恢复、隐私声明和版权使用提示。
11. 建立 Windows、Linux、macOS、Android、iOS 的 CI 构建矩阵。
12. 为解析、任务状态机、数据库迁移、文件清理和下载恢复编写测试。

## 11. 当前依赖注意事项

- Riverpod 3.3.2 与当前 `riverpod_lint/custom_lint` 组合存在解析冲突，因此暂未安装这两个开发期 lint；不影响运行和代码生成。
- `shared_preferences` 只保存非关键设置，关键任务使用 Drift，登录凭据使用安全存储。
- `connectivity_plus` 只报告网络类型变化，实际可用性仍以 API 请求结果为准。
- `ffmpeg_kit_extended_flutter` 使用 `third_party` 中固定的 0.5.10 补丁版：应用 `pubspec.yaml` 纳入 Hook 缓存依赖，原生包下载支持重试并在输出完成后显式结束 Hook，避免配置变化沿用旧包或网络连接阻塞构建。
- `drift_dev 2.34.0` 与 `sqlparser 0.44.6` 存在生成器 API 不兼容，同时新版 `drift_dev` 又与当前 `go_router_builder` 的 Analyzer 范围冲突，因此开发依赖暂时固定 `sqlparser 0.44.0`。
- 当前 Windows 开发机可以找到系统 `ffmpeg` 和 `ffprobe`，但没有安装 `aria2c`。正式应用不能依赖开发机 PATH；aria2c 必须按平台和 CPU 架构随包发布，或通过带签名与哈希校验的安装流程获取。

## 12. 已落地的平台运行时核心

平台和 CPU 架构统一由 `lib/core/platform/runtime_platform.dart` 识别，页面与业务 Provider 不直接判断操作系统。`native_tool_resolver.dart` 负责返回当前构建实际可用的工具路径：

| 目标 | 下载引擎 | 合并引擎 | 随包文件 |
| --- | --- | --- | --- |
| Android ARMv7 | aria2 原生适配 | FFmpegKit | ARMv7 `aria2c` |
| Android ARM64 | aria2 原生适配 | FFmpegKit | ARM64 `aria2c` |
| Android x86_64 | aria2 原生适配 | FFmpegKit | x86_64 `aria2c` |
| iOS ARM64 | 系统后台下载 | FFmpegKit | 无 `native_bins` |
| Windows x64 | aria2c 子进程 | FFmpegKit | x64 `aria2c.exe` |
| Windows ARM64 | aria2c 子进程 | CLI FFmpeg 兜底 | ARM64 `aria2c.exe`、`ffmpeg.exe` |
| macOS x64/ARM64 | aria2c 子进程 | FFmpegKit | 当前架构 `aria2c` |
| Linux x64 | aria2c 子进程 | FFmpegKit | x64 `aria2c` |
| Linux ARM64 | aria2c 子进程 | CLI FFmpeg 兜底 | ARM64 `aria2c`、`ffmpeg` |

Android 未自定义存储路径时，aria2 分流与 FFmpeg 合并先在应用专属 `BiliDown/.temp/<taskId>` 完成，再由 `background_downloader` 的 MediaStore 接口把成品发布到公共 `Download/BiliDown`；设置页只展示 MediaStore 的逻辑目录，不依赖设备绝对挂载路径，也不向用户暴露工作目录。其他平台保持系统下载目录下的 `BiliDown` 子目录。

Android 自定义成品目录使用系统 SAF tree URI：设置页与任务页共用 DocMan 目录选择器并持久化授权，aria2 与 FFmpeg 仍只访问应用专属 `.temp`，合并完成后再通过 ContentResolver 移动到授权目录。恢复默认目录时释放旧 SAF 授权；桌面自定义目录继续保存普通绝对路径。

Android 已完成任务的“打开文件所在目录”会复用发布阶段的相对父目录计算，把任务 `outputPath` 在应用工作根目录下的高级规则与标题目录层级映射到当前 MediaStore 或 SAF 成品根目录；因此系统文件管理器直接打开该任务文件所在的具体目录。尚未发布的活动任务继续打开成品根目录，旧任务路径无法安全映射时也回退根目录。

Android 删除公共 MediaStore 成品时先尝试应用直接删除；应用重装、文件归属变化或厂商实现拒绝直接删除时，通过 `com.bilidown.app/media_store` 原生通道调用 Android 11+ `MediaStore.createDeleteRequest`，批量文件合并为一次系统确认，用户同意且复查文件已消失后才删除 Drift 记录。Android 10 使用 `RecoverableSecurityException` 的一次性授权后重试删除。该流程不申请“所有文件访问”；SAF 自定义目录授权在卸载或清除数据后仍需用户重新选择目录。

构建接入规则：

- Android Gradle 将三个受支持 ABI 的 aria2 复制为 `libaria2c.so`；AAB 由应用商店按设备 ABI 下发，独立 APK 必须使用 `flutter build apk --split-per-abi`。
- Android 三个 aria2 二进制取自 F-Droid 可复现构建 `Aria2Android 2.6.8 (76)`；该版本的 aria2 1.36.0 已在 ARM64 真机验证 `--version` 和 JSON-RPC。不要替换为需要外置 OpenSSL legacy provider 的构建，否则进程会在 RPC 监听前退出。
- Windows、Linux CMake 只复制当前目标架构对应的文件。
- macOS 构建脚本按 `ARCHS` 复制；单架构应用只带一个 aria2，Universal 应用带两个架构目录并在运行时选择。
- iOS 不引用 `native_bins`。
- `ffmpeg_kit_extended_flutter` 支持的平台不重复打包 CLI FFmpeg。

## 13. 已落地的 aria2 下载核心

`lib/services/download_engine/aria2` 已提供首版可运行实现：

- aria2 仅监听 `127.0.0.1`，每次新建进程使用随机空闲端口和 32 字节随机 RPC secret。
- JSON-RPC 的所有请求都携带 `token:<secret>`，统一处理 RPC 错误和启动超时；客户端显式兼容 aria2 `application/json-rpc` 被 Dio 保留为字符串的响应，解码后再校验协议对象。
- session、运行参数、日志和任务 GID 映射保存在应用支持目录；写入使用临时文件替换，避免半写入状态。
- aria2 启动参数启用断点续传、定时保存 session，并关闭远程监听和跨域访问。
- Android 启动 aria2 前会把 Conscrypt APEX 或 system 目录中的系统 PEM 根证书合并到应用私有运行目录，并通过 `--ca-certificate` 显式加载；HTTPS 校验保持开启，避免静态 OpenSSL 因找不到 Android CA 路径而握手失败。
- DASH 主地址和 B 站返回的备用 CDN 地址会作为同一 aria2 任务的有序 URI 列表提交；TLS 协议中断且所有地址均失败时，协调器最多两次重新解析最新地址并保留已有分段续传。
- `Aria2DownloadEngine` 已实现添加、暂停、继续、取消、状态轮询和重启恢复。
- 任务 GID 由内部任务 ID 的 SHA-256 前 16 位稳定生成，不使用标题或外部输入。
- Windows、macOS、Linux 由 Dart 持有子进程；Android 由 `flutter_foreground_task` 的前台服务 isolate 持有子进程。
- Android 13+ 在启动下载服务前检查通知权限，前台服务类型固定为 `dataSync`，不启用开机自动下载。
- 桌面关窗由应用根组件拦截，先展示不可关闭的全局退出提示，再依次停止协调器与合并器、保存 aria2 session、请求 RPC 正常退出、等待子进程回收并关闭 Drift/SQLite，全部结束后才销毁窗口。
- Android 前台服务启用 `stopWithTask`，用户从最近任务关闭应用时由服务 `onDestroy` 终止 aria2 进程。

当前恢复映射仍是轻量 JSON 缓存；接入 Drift 后应以数据库任务为准，并用 aria2 查询结果校准状态。

## 14. 已落地的媒体合并核心

`lib/services/media_merge` 已实现统一 `MediaMerger` 和两种后端：

- Android、iOS、macOS、Windows x64、Linux x64 使用 `FfmpegKitMediaMerger`。
- Windows ARM64、Linux ARM64 使用随包发布的 `CliMediaMerger`。
- 两种后端都通过参数数组传递输入输出路径，不拼接 shell 命令。
- 首期固定使用双输入、显式流映射、`-c copy` 和 `+faststart`，不重新编码媒体。
- 输出先写到目标目录中的隐藏临时文件，成功后在同一文件系统内原子改名；失败或取消会清理半成品，输入文件保持不变。
- 合并目标已存在时直接报错，不静默覆盖用户文件。
- FFmpegKit 通过 Statistics 回调输出进度；CLI 使用 `-progress pipe:1` 解析进度。
- Debug 构建使用 `[BiliDown][aria2]` 和 `[BiliDown][ffmpeg]` 输出进程、RPC、分流提交、合并后端、进度、返回码与错误阶段；统一清理 URL、RPC token 和 Cookie，Release 构建不输出这些诊断日志。
- 合并器支持取消和安全释放，Provider 销毁时会等待活动合并退出后再关闭进度流。
- Android 在合并阶段使用 `mediaProcessing` 前台服务；若下载前台服务仍在运行，则复用通知而不强制杀死 aria2。

Windows 开发机已使用一秒钟的独立视频流和音频流完成 stream-copy 合并烟测，并确认生成最终 MP4 和 `progress=end`。

## 15. 已落地的系统后台下载核心

`lib/services/download_engine/system` 已提供 `SystemDownloadEngine`，作为 iOS 必选下载后端以及 aria2 不可用平台的回退实现：

- 使用 `background_downloader` 的 `UriDownloadTask`，按业务层给出的绝对目录和文件名保存媒体分流文件。
- 业务任务 ID 直接作为系统下载任务 ID，状态事件可以无额外映射回到统一任务模型。
- 固定使用 `bilidown.system` 任务分组，避免接收应用内其他后台传输任务的事件。
- 下载任务开启状态和进度双更新，支持暂停、恢复、取消，并保留 B 站媒体请求头。
- 通过插件持久化数据库恢复后台期间的任务状态；监听先于恢复建立，避免遗漏原生层补发事件。
- 插件状态统一映射到 `DownloadStatus`，等待重试映射为排队，404 与其他异常映射为失败。
- 进度比例结合服务端文件大小转换为已下载字节；无法获得总大小时不伪造字节进度。
- HTTP 响应码与原生异常会进入错误信息，为后续识别 401/403 并重新解析播放地址保留依据。
- 释放 Dart 引擎只取消事件监听，不主动终止 iOS 已接管的后台任务。
- `downloadEngineProvider` 是业务层统一入口，通过 `DownloadEngineFactory` 异步选择 aria2 或系统下载实现，页面不判断操作系统。

当前系统下载恢复使用 `background_downloader` 自带持久化记录，并由 Drift 保存业务任务与视频分集信息、由协调器使用系统下载器真实状态校准活动任务。Android 和 iOS 已初始化 WorkManager 周期恢复任务；Android 前台发现断网时还会注册具有联网、电量和存储约束的一次性恢复任务。

应用级调度器已监听 `connectivity_plus` 网络接口变化：明确离线时不再认领 `waitingToStart` 任务，恢复任一网络接口后立即重新泵送持久化等待队列；网络类型只作为调度信号，真实互联网和 B 站可用性仍由 DASH 与下载请求判断，插件查询异常时回退允许请求而不会永久锁死队列。

WorkManager 回调在独立 isolate 中打开同一 Drift 数据库，等待首份真实任务快照后执行一次最多 20 秒的可等待调度泵，把当前并发槽位允许的任务提交给原生下载器后立即关闭订阅和数据库；它不承担长时间传输。Android 使用网络恢复一次性任务和一小时周期兜底，iOS 使用系统控制频率的 Background Fetch，并声明 `UIBackgroundModes=fetch`。

DASH 主地址和备用地址会去重保序传入 aria2；系统下载器或 aria2 返回 TLS protocol error、超时、DNS、断连、connection reset 等网络错误时，协调器会在两次有限自动刷新中依次把下一个备用 CDN 移到首位，401/403 则保持最新鉴权主地址。失败任务人工重试会弹出策略选择：推荐“排队重试”遵守全局并发与网络门控，用户也可明确选择“立即重试”；弹窗会按鉴权、网络/CDN 或普通错误解释本次处理。

任务启动在请求 DASH 或创建临时文件前使用 `disk_usage` 按最终输出路径查询目标卷可用字节。已知媒体大小时，双流合并预留两份音视频总大小并增加 10% 或最低 128 MiB 安全余量；单资源保留一份大小和余量；未知大小保守要求 256 MiB。空间不足或平台无法读取剩余空间时任务进入可见失败态，不会继续写入磁盘。独立音频任务会继承解析期预计音频大小。

## 16. 已落地的 Drift 任务持久化核心

`lib/core/database` 与 `lib/features/downloads` 已建立首版任务数据库和领域状态机：

- `download_tasks` 保存任务 ID、原始输入、BVID/CID/EPID、合集与分集元数据、不含临时 URL 的 DASH 候选、当前画质编码、预计大小、临时目录、最终路径、后端类型、总进度、重试与错误信息。
- `download_streams` 按任务拆分唯一的视频流和音频流，保存临时媒体 URL、本地路径、引擎任务 ID、字节进度和独立错误；引擎任务 ID 建立唯一索引。
- `download_artifacts` 统一记录最终视频、临时流、封面、字幕和弹幕文件，为后续清理、保留和完整性校验提供依据。
- 主任务删除时通过 SQLite 外键级联清理分流和产物记录；每次连接都会开启外键约束和五秒 busy timeout。
- 当前数据库版本为 6，版本一到版本二增加视频时长，版本三增加任务列表解析元数据，版本四增加实际音频质量代码，版本五增加解析阶段预计音视频大小，版本六增加不含临时 URL 的 DASH 候选清单及命名上下文；未来版本必须逐版本补充迁移，不允许通过删库重建丢失用户任务。
- 原生平台数据库固定保存到 `getApplicationSupportDirectory()` 返回的应用支持目录下；Windows、Linux、macOS 的可见目录标识统一为 `com.bilidown.app`，Android 与 iOS 使用各自应用沙箱。旧 Documents 目录数据由用户按需手动迁移。
- 任务状态机覆盖 `queued -> resolving -> downloading -> waitingForMerge/merging -> completed`，活动状态可以进入暂停、失败或取消。
- 暂停时保存原阶段，恢复时回到正确流程位置；完成与取消是终态，非法状态跳转会在写库前被拒绝。
- `DownloadTaskRepository` 提供任务创建、活动任务恢复查询、状态事务、媒体分流写入、引擎进度关联、URL 刷新和文件产物登记。
- 视频流和音频流按真实字节总量加权计算主任务下载进度；总大小未知时不伪造比例。
- `appDatabaseProvider` 与 `downloadTaskRepositoryProvider` 负责数据库连接和仓库生命周期，页面不直接执行 SQL。
- 应用根组件会在进入主路由前主动打开数据库并完成迁移；同一个 Drift 后台连接在整个 `ProviderScope` 生命周期内持续复用，退出时统一关闭，不按查询或进度事件反复开关。
- 原生 SQLite 使用 WAL 与 `synchronous=NORMAL`，任务列表读取可以与多任务进度写入更平滑地并行；所有业务写入仍通过仓库事务和状态机约束。

下一阶段需要实现双流任务协调器：解析完成后创建视频/音频分流，监听统一下载引擎事件写入 Drift，两条分流完成后进入等待合并或合并阶段，并在应用启动时用引擎真实状态校准数据库。

## 17. 已落地的双流任务协调核心

`lib/features/downloads/application` 已实现解析完成后的下载与合并编排：

- `ResolvedDownloadPlan` 强制包含且仅包含一条视频流和一条音频流，并拒绝两条分流使用相同临时路径。
- 分流 ID 使用内部任务 ID 加 `video/audio` 生成，同时作为下载引擎任务 ID，下载事件无需标题或外部输入即可关联 Drift。
- 提交下载前先保存两条分流和临时文件产物，避免原生下载器的早到事件找不到持久化记录。
- 视频流和音频流独立提交统一 `DownloadEngine`，任一提交失败时取消已提交分流并把主任务标记为失败。
- 下载状态与进度通过串行事件队列写入 Drift，防止两条分流的高频回调并发覆盖。
- 两条分流都完成后，桌面与 Android 自动进入串行 FFmpeg 队列；iOS 进入 `waitingForMerge`，由应用回到前台后显式继续。
- FFmpeg 合并进度写入主任务阶段进度；生成最终文件并登记产物后才进入 `completed`。
- 暂停任务会保存下载或合并前阶段，恢复后继续对应流程；取消任务先写入终态，迟到的失败或取消事件不会覆盖用户决定。
- 应用销毁导致的合并取消会回到 `waitingForMerge`，视频与音频临时流继续保留，供下次恢复重试。
- 协调器恢复时要求下载引擎重新发送真实状态，并自动续接允许立即执行的待合并任务。
- `downloadTaskCoordinatorProvider` 在组合根注入下载引擎、媒体合并器、任务仓库和平台自动合并策略。

下一阶段需要实现 B 站 API 与解析核心，为协调器提供真实的 BV/EP/SS 分集、DASH 视频流、音频流、时长和请求头；之后再接入 URL 过期刷新策略。

## 18. 已落地的 B 站解析核心

`lib/services/bilibili` 与 `lib/core/network` 已实现首版公开信息和 DASH 播放流解析：

- 输入归一化支持直接 BV、EP、SS、标准 `bilibili.com` 网页以及 `b23.tv` 短链接，并限制跳转协议、域名和最大次数。
- 普通 BV 使用 view 接口解析标题、简介、UP 主、封面、发布时间和普通多 P；存在 `ugc_season` 时按 section 展开 UGC 合集。
- EP/SS 使用 PGC season 接口解析季度标题、简介、封面、主分集和附加 section，并按 EP ID 去重。
- 解析结果只包含设计稿约定的基础信息和分集，不把画质、编码和音轨选择提前塞入解析页。
- UGC 播放流使用动态 WBI 签名；签名器从 nav 图片地址生成混合密钥并缓存十分钟，不硬编码短期密钥。
- DASH 模型同时兼容驼峰与下划线字段，解析普通音频、FLAC 和杜比扩展节点并按 URL 去重。
- 视频选择支持指定清晰度与 AVC、HEVC、AV1 偏好；目标画质不可用时先选择不高于目标的最高可用档位，例如默认 4K 而清单最高为 1080P 时实际选择 1080P，不会跳到 480P。
- 音频按 64K、132K、192K、杜比和 Hi-Res 的产品等级执行相同的确定性降级，并把实际音频质量 ID 写入任务，下载启动和地址刷新时不会重新变成最高码率。
- 选定视频流和音频流可以直接转换为 `ResolvedDownloadPlan`，自动携带 User-Agent、Referer、Origin 和安全存储中的完整 Cookie。
- 网络层对连接和 5xx 使用有限指数退避，不重试明确业务错误；`-101`、`-403/-412/-352`、`-404`、`-10403` 分别映射登录、权限风控、资源不存在和地区限制。
- Cookie 接口与 `flutter_secure_storage` 实现分离，纯解析核心不依赖 Flutter UI；Cookie 不写入 SharedPreferences 或 Drift。

已使用设计截图中的 `BV1nfj86AEAo` 执行只读烟测，Dart 解析得到 UGC 合集 6 个分集、6 条公开视频流和 3 条公开音频流；`ss28770` 可解析季度及分集结构。登录专享画质、受地区限制的 PGC 播放流仍需要账号和对应网络环境验证。

上述解析结果已经继续接入二维码登录和 401/403 媒体地址恢复，具体状态见下一节。

## 19. 已落地的登录与媒体地址失效恢复核心

`lib/services/bilibili`、`lib/core/network` 和下载协调器已经接通登录会话与短期 DASH 地址恢复：

- 网络层新增完整 JSON 响应对象，在保持原正文接口兼容的同时保留 HTTP 状态、最终地址和全部多值响应头。
- 二维码登录支持生成二维码内容与轮询键，并识别未扫码、已扫码待确认、过期和成功四种状态；轮询流成功或过期后自动结束，并设置三分钟本地总超时。
- 扫码成功后从全部 `Set-Cookie` 中提取浏览器请求需要的 `name=value`，与 `refresh_token` 一起写入 `flutter_secure_storage`，不进入 Drift 或 SharedPreferences。
- 登录状态通过 nav 接口校验，正常会话返回 UID、昵称、头像和大会员状态；本地无 Cookie 或接口返回 `-101` 时稳定返回未登录。
- 本地退出会同时删除 Cookie 和 refresh token；远端退出及 refresh token 自动换新仍待后续接入。
- 解析服务可以从最新 DASH 清单单独创建视频或音频分流，地址刷新不需要重建另一条正常下载。
- 过期地址刷新器从 Drift 中恢复 BVID、CID、EPID、清晰度、视频编码和临时路径，重新请求与原任务匹配的媒体地址和请求头。
- 下载协调器仅在分流返回 HTTP 401/403 时自动刷新；HTTP 404 和普通网络错误继续进入明确失败状态。
- 自动刷新保持业务任务 ID、分流 ID 和临时路径稳定，只取消并重新提交失败的单条分流，另一条分流继续运行。
- 每个业务任务最多自动刷新两次，重试次数持久化到 Drift；主动替换旧引擎任务产生的迟到取消事件不会误取消主任务。

已对真实二维码生成接口执行只读烟测，新二维码首次轮询返回 `waitingForScan`，空会话登录状态返回未登录。扫码成功后的真实 Cookie 写入、登录专享画质以及 iOS 原生后台任务的 401/403 恢复仍需在真机账号环境验证。

上述登录和解析服务已经接入首版响应式页面，具体范围见下一节。

## 20. 已落地的响应式应用与解析入队界面

`lib/app`、`lib/core/theme` 与 `lib/features` 已把占位计数器替换为首版可运行产品界面：

- Android 与 iOS 在数据库迁移和遗留活动任务暂停完成后、主路由和下载调度器创建前读取 `onboarding.completed.v1`：未完成时展示四步卡片式引导，说明链接解析、下载队列、平台保存位置、账号与通知权限边界；完成或跳过后写入 SharedPreferences，后续启动不再展示。设置中心仅在移动端提供“重新查看使用引导”，重看只改变当前会话状态，不清除磁盘完成标记；桌面端始终跳过该门禁。
- `go_router` 管理解析、任务、设置和账号路由；桌面与宽平板使用固定 `48dp` 的单层 Material 图标侧栏，入口由 `InkWell` 原生处理 Hover、焦点和按压状态，避免与 `NavigationRail` 默认状态层叠加；桌面侧栏顶部提供主题化账号头像入口，未登录显示“登录”、已登录加载缓存头像并统一打开账号中心；手机使用三项底部导航，账号入口固定在全局顶栏；桌面和手机的任务入口实时显示 `queued` 待下载数量角标，数量为零时隐藏。
- 全局字号集中在 `lib/core/theme/app_theme.dart` 的 `AppFontSizes`，完整 `TextTheme` 和按钮主题都引用这些令牌；业务页面只选择语义文本层级，不直接写 `fontSize`。
- 亮色和暗色主题使用 `AppColors` 中的表面、主色、分隔线和危险色色值，支持跟随系统、亮色、暗色三种模式并通过 SharedPreferences 持久化。
- 视频解析页真实调用 BV/EP/SS、标准链接和短链解析服务，加载期间禁止重复提交，错误紧邻输入框展示并提供重试。
- 解析结果按内容宽度切换桌面双栏和手机单栏，展示封面、标题、发布者、发布时间、分辨率、时长、集数和描述。
- 分集选择支持单选、全选、取消全选和选择数量统计；输入、解析结果和选择由 Riverpod 保存，切换一级页面不会丢失。
- “解析选中项目”会按原顺序检查重复 BVID/CID、请求 DASH 清单，并依据设置中心选择默认画质、音质和编码；同时处理多个视频时，页面顶部按真实 DASH 请求进度展示当前项和总数，单 P 或仅选一项时不展示；单集内容统一使用媒体主标题，多 P/合集保留分集标题，该标题同时用于任务卡、`%title%` 命名变量和高级目录变量；随后为每条任务生成 UUID、跨平台安全文件名、临时目录、输出路径和首选下载后端，写入 Drift `queued` 阶段后自动进入待下载页。
- 任务中心已经落地桌面长条任务行和手机纵向任务卡；支持默认全选、单项选择、批量启动、单项启动、失败重试，以及二次确认清空或移除未启动任务；批量启动会在单个 Drift 事务中把全部任务移入 `waitingToStart` 下载中队列，不再由页面逐项搬运；自定义批量支持多选视频、封面、音频、XML 弹幕、ASS 弹幕和字幕，附加类型复用卡片单项下载链路按“源视频 × 资源类型”派生独立任务后统一交给并发调度器，不包含 NFO 刮削或未实现的音频转码；已下载页支持批量清空记录，并由默认关闭的复选框决定是否同时删除桌面文件或 Android MediaStore/SAF 成品。
- 用户启动下载时会重新请求最新 DASH 地址，避免待下载期间 URL 过期，并把选定视频流和音频流交给现有协调器下载、持久化进度与 FFmpeg 合并。
- 账号页已经接入真实二维码生成和轮询，展示未扫码、待确认、过期、成功与错误状态；关闭页面会自动停止轮询。
- 已登录状态展示头像、昵称、UID 和大会员状态；退出操作必须二次确认，并明确只清除本机凭据。
- 软件声明可从未登录和扫码页面打开，长内容独立滚动，官网使用系统浏览器打开。
- 设置中心已重构为桌面横向设置行和手机纵向设置行；系统提示音、按钮提示音、退出行为、下载目录、下载内容、默认音质、默认画质、编码、命名模板、并发数和主题均进入统一 SharedPreferences 设置仓库。
- 下载入队服务会把解析时获得的 DASH 质量代码、编码、码率、分辨率和预计大小候选写入任务，临时媒体 URL 不持久化；默认音质、默认画质或编码变化时只在本地候选中重新选择并同步全部 `queued` 任务，真正启动和 401/403 刷新时才请求最新媒体 URL。应用级调度器监听 Drift 等待队列，按设置中的业务任务并发数启动 DASH 刷新和真实下载，任务离开网络下载阶段后自动为下一项释放槽位，并在重启后继续处理持久化等待任务。
- 自定义命名弹窗支持标题、UP 主、实际音画质、BV/CID、下载与发布日期、序号和补零变量；变量插入、随机模板、实时预览和真实输出共用同一渲染器，避免预览与最终文件名不一致。
- 存储高级弹窗支持按 UP 主、内容类型、实际音画质、标题和日期动态创建下载根目录下的多层子文件夹；模板为空时直接使用根目录，渲染结果会过滤绝对路径和父目录跳转，避免越出用户选择的下载位置。
- 任务中心待下载项支持勾选、真实音质与画质选择；质量字段使用锚定下拉菜单，直接同步解码当前 Drift 记录携带的本地候选，不产生额外查询、加载态或模态弹窗，用户改选后只把候选中真实存在的质量代码、编码和预计大小写回任务快照。
- 解析选中分集时会按实际命中的 DASH 流平均码率和时长计算音频、视频预计字节数并写入任务表；任务卡直接读取数据库展示，改选质量时同步更新对应预计大小。
- 任务中心的存储栏始终展示设置中心下载根目录；设置中心或任务页修改根目录、保存高级存储规则后，会按当前命名与文件夹模板重新计算全部 `queued` 任务的临时目录和输出路径。
- 两类提示音开关已接入运行时：按钮提示音独立控制可点击控件的 `assets/sounds/tap.wav`，系统提示音控制任务首次失败的 `error.wav` 和同一轮所有非暂停活动任务完成后仅播放一次的 `success.wav`；历史任务快照、滚动和空白区域不会触发声音。

桌面托盘已接入 Windows、macOS、Linux：关闭窗口会读取持久化退出行为，选择最小化到托盘时隐藏窗口，单击图标或菜单可恢复并聚焦；托盘“退出程序”会先显示主窗口，再复用退出遮罩以及 aria2、FFmpeg、Drift 安全清理链路。托盘初始化失败时不会隐藏唯一窗口，而是回退为安全退出。

默认下载内容中的封面、独立音频、XML/ASS 弹幕和字幕已经接入解析入队：每个视频及其自动附加资源会在同一 Drift 事务中写入，任何草稿失败都会回滚整组；任务随后与手动自定义批量任务共用待下载列表和业务并发调度器。自动关机和剪贴板监听属于独立应用运行时，不会被错误创建为下载任务。

字幕提供两个独立选项：`subtitles` 获取人工轨道，`aiSubtitles` 获取 B 站已有的 AI 轨道；设置、单任务、附加资源和批量导出共用该区分，最终均转换为 SRT。语言代码保留 `ai-*`，旧接口的 `ai_type` 标记也归入 AI 类型，避免同语言人工字幕覆盖 AI 字幕。元数据优先读取 `/x/player/wbi/v2`；普通投稿缺少 AI 轨道时通过 `/x/v2/subtitle/web/view` 补查 Protobuf 元数据，沿用应用登录态，并限制响应大小和字段边界。新接口异常不丢弃已有人工轨道，AI 专用任务则明确反馈失败；不会在没有轨道时自行语音转写。新版协议参考 [bilibili-ai-subtitle 的接口说明](https://github.com/ccBilly-aipm/bilibili-ai-subtitle/blob/main/docs/FLOW_CN.md)，尚需使用真实账号验证平台当前返回行为。

自动关机已经复用任务声音观察器的整轮成功去重判定：仅桌面端且用户启用时显示 30 秒根级模态倒计时，托盘隐藏状态会恢复窗口，用户可以取消；Windows、macOS、Linux 分别调用不经过 shell 的系统关机入口，非零退出码会保留错误提示。移动端不会尝试执行不受支持的系统关机。

剪贴板监听已经接入桌面运行时：只有用户开启设置后才每两秒读取一次纯文本，精确白名单识别 bilibili.com 与 b23.tv，并对相同候选去重；根界面仅显示可忽略的非模态提示，必须点击“立即解析”才会写入解析页、跳转并发起网络请求，不会静默解析或下载。移动端受系统剪贴板隐私限制，不启动后台轮询。

系统通知已接入 Android、iOS、macOS、Linux 和 Windows：Android 固定使用 `bilidown_download_status` 高重要性通道，iOS/macOS 在系统提示设置启用时请求提醒与声音权限，Windows 使用稳定 AppUserModelID 和 GUID；任务首次失败与整轮成功复用声音观察器的阶段去重，分别更新固定通知 ID。Android 下载及合并后台状态继续由前台服务常驻通知承载。系统提示设置关闭时不会初始化、请求或发送结果通知。
