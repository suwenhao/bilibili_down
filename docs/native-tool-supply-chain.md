# aria2 与 FFmpeg 供应链基线

## 发布基线

`native_bins/manifest.json` 是随仓库原生可执行文件的唯一基线，逐项固定路径、版本、许可证、来源页面、许可证全文 asset 和 SHA-256。运行以下命令可检查文件缺失、字节变化或未登记文件：

```powershell
pwsh -File tool/verify_native_binaries.ps1
```

当前 Android aria2 固定为 F-Droid 可复现构建 Aria2Android 2.6.8 (76) 内的 aria2 1.36.0；Linux 与 macOS 固定为 aria2-zero `v2025.04.06-release.1`；Windows x64 固定为 aria2 官方 1.37.0 build1；Windows ARM64 保持用户确认可用的 1.37.0 仓库基线。ARM64 的 Linux/Windows CLI FFmpeg 保持 BtbN FFmpeg 8.1 LGPL 仓库基线。现有二进制不因建立清单而被替换。

其余平台使用 `ffmpeg_kit_extended_flutter` 0.5.10 补丁包和 FFmpegKit 构建产物 0.10.4，固定为 `video + LGPL + shared`。该包型保留常用音视频封装与转码能力，同时避免 `full` 包携带 TensorFlow/OpenVINO 造成桌面产物异常膨胀：

| 平台归档 | SHA-256 |
| --- | --- |
| Android `bundle-video-shared-lgpl-0.10.4.aar` | `bd63dbe69abffb24c687f1cb63f3290367d5272cb6448881a89494126ed2de1c` |
| iOS `bundle-video-ios-universal-lgpl.xcframework.zip` | `c93cd309cc2e6bd07e77a6272389a092d33154954d8f2f672f609c9b0c494287` |
| macOS `bundle-video-macos-universal-lgpl.xcframework.zip` | `e6a4ffbc32bc7df95c75d02d33bc1c123a5e8ce5a952d71c2b4068e8566f5d51` |
| Windows x64 `bundle-video-windows-x86_64-shared-lgpl.zip` | `b14947999069f12cf5fe26c814642b76780ce2ed0a64ee52d0c7f5a471b83967` |
| Linux x64 `bundle-video-linux-x86_64-shared-lgpl.zip` | `dbd0b85ab8a9991d61e53182a0bc70b952bc3f8750affb170d50bcb998afd721` |

构建 Hook 直接使用上述固定值校验下载归档。改变包型、版本或平台后若未同步新增哈希，构建会失败，不再仅依赖远端 release 元数据。

## 许可证边界

- aria2：GPL-2.0-or-later；Android Aria2Android 分发包额外保留 GPL-3.0-only LICENSE；发布页同时提供对应源码、`assets/licenses/` 完整许可证和本清单。
- FFmpegKit video-lgpl 共享库：LGPL-3.0-or-later；保留可替换共享库、许可证和对应源码/构建脚本。
- `native_bins/ffmpeg` ARM64 静态 CLI：当前内嵌配置未启用 `--enable-gpl` 或 `--enable-nonfree`，`libav*` 自报 LGPL version 3 or later，按 LGPL-3.0-or-later 分发；对应平台产物必须附完整许可证与源码获取方式。
- 不得把 FFmpegKit 与 ARM64 CLI 混写成同一项，也不得把所有架构二进制塞进同一个平台包。

## 更新策略

1. 仅在安全修复、平台兼容问题或明确功能需求时升级，不跟随 `latest` 漂移。
2. 在独立变更中记录上游 tag、资产完整 URL、上游签名/摘要、许可证、本地 LICENSE asset 和构建配置，并同步 `docs/release-runtime-components.md`。
3. 下载到隔离目录，先验证上游签名或摘要，再提取目标架构；禁止在原文件上覆盖后补写哈希。
4. 更新 `manifest.json` 或 FFmpegKit 固定哈希，并执行供应链校验、`--version`、JSON-RPC 启动、短文件下载及无转码合并冒烟。
5. 每个平台只打包运行时需要的当前架构；升级失败可回滚整个二进制与清单提交，不允许混用不同版本。
6. 正式发布保存源归档、许可证、构建日志、SBOM 和最终安装包 SHA-256，保留至少两个发布周期。

## 发布校验清单

正式发布完成打包后，维护者必须为最终交付文件生成 SHA-256 清单：

```powershell
pwsh -File tool/create_release_checksums.ps1 -Path dist
```

`SHA256SUMS.txt`、`docs/release-runtime-components.md` 与安装包、压缩包一同上传到 Release 页面。该清单用于用户自助校验，也用于向安全软件厂商提交误报复核时证明文件来源和完整性。
