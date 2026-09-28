# BiliDown 原生运行时发布披露

更新日期：2026-07-31

本文件用于 Release 下载页、商店审查材料和随包 `THIRD_PARTY_NOTICES`。正式发布时必须与安装包、`SHA256SUMS.txt` 一起公开，避免只在源码仓库内部保留许可证信息。

## 发布页必须同时提供

1. 最终安装包或压缩包的 `SHA256SUMS.txt`。
2. 本文件或等价内容，包含 aria2、FFmpegKit、FFmpeg CLI 的版本、来源、构建配置、哈希和许可证。
3. 许可证全文或稳定链接：GPL-2.0、GPL-3.0、LGPL-3.0，以及对应上游项目许可证页面；应用包内同步保留 `assets/licenses/` 本地文本。
4. 项目源码仓库链接和 `native_bins/manifest.json`，用于核对随包原生二进制来源。

## 原生组件清单

| 组件 | 随包平台 | 版本 | 来源与构建来源 | 构建配置 | 许可证 | 校验 |
| --- | --- | --- | --- | --- | --- | --- |
| aria2 | Android arm64-v8a | aria2 1.36.0 / Aria2Android 2.6.8 (76) | F-Droid 可复现构建 `com.gianlu.aria2android_76`；源码见 F-Droid 与上游 aria2 | 使用 Aria2Android 发布产物中随附的 aria2 原生二进制 | Aria2Android 分发包 GPL-3.0-only；aria2 GPL-2.0-or-later | `646bd6564f2ea00ba6b4662b66852fd3fbb332d4ab60c0d7ee2e30a840cbb23c` |
| aria2 | Android armeabi-v7a | aria2 1.36.0 / Aria2Android 2.6.8 (76) | F-Droid 可复现构建 `com.gianlu.aria2android_76`；源码见 F-Droid 与上游 aria2 | 使用 Aria2Android 发布产物中随附的 aria2 原生二进制 | Aria2Android 分发包 GPL-3.0-only；aria2 GPL-2.0-or-later | `c7f83c321eb440466f839903bba8e479395ec444177a754d7def3271436e259f` |
| aria2 | Android x86_64 | aria2 1.36.0 / Aria2Android 2.6.8 (76) | F-Droid 可复现构建 `com.gianlu.aria2android_76`；源码见 F-Droid 与上游 aria2 | 使用 Aria2Android 发布产物中随附的 aria2 原生二进制 | Aria2Android 分发包 GPL-3.0-only；aria2 GPL-2.0-or-later | `9ff36caa58ac2395c83c613ed2d0c6ce782dda81e59bc88a88ea509782f90d75` |
| aria2 | Linux ARM64 | aria2-zero v2025.04.06-release.1 | `zeromake/aria2-zero` release asset `aria2-linux-arm64-v8a.zip` | 上游 release 预构建资产 | GPL-2.0-or-later | `6cdb4f2514ef9c2639db0668042b7bae7017c494aff3f7f9027170a30cc5469f` |
| aria2 | Linux x64 | aria2-zero v2025.04.06-release.1 | `zeromake/aria2-zero` release asset `aria2-linux-x86_64.zip` | 上游 release 预构建资产 | GPL-2.0-or-later | `e98c4626c8e4f26059226d70a1a69850b12f4406a0aca075a083784a90941e52` |
| aria2 | macOS ARM64 | aria2-zero v2025.04.06-release.1 | `zeromake/aria2-zero` release asset `aria2-macosx-arm64.zip` | 上游 release 预构建资产 | GPL-2.0-or-later | `eef5ef63ede878e69b9c70e3ae65640f8fa685bca0eee3a9807905334c7d6eef` |
| aria2 | macOS x64 | aria2-zero v2025.04.06-release.1 | `zeromake/aria2-zero` release asset `aria2-macosx-x86_64.zip` | 上游 release 预构建资产 | GPL-2.0-or-later | `54031312a4459cd33d36d70b8ad723d987a643fee92c4f222af23c8c15a9de83` |
| aria2 | Windows ARM64 | aria2 1.37.0 | 已批准仓库导入 `b054f085`；上游 aria2 `release-1.37.0` 源码 | 仓库固定预构建基线 | GPL-2.0-or-later | `33c775256f64123515f32a8252200ef2ab5ad72963981c694dff5e61d650f6be` |
| aria2 | Windows x64 | aria2 1.37.0 official build1 | aria2 official asset `aria2-1.37.0-win-64bit-build1.zip` | 上游官方 Windows 64-bit build1 | GPL-2.0-or-later | `be2099c214f63a3cb4954b09a0becd6e2e34660b886d4c898d260febfe9d70c2` |
| FFmpegKit | Android、iOS、macOS、Windows x64、Linux x64 | ffmpeg-kit-builders 0.10.4 / ffmpeg_kit_extended_flutter 0.5.10 补丁包 | `akashskypatel/ffmpeg-kit-builders` 固定归档 | `type: video`、`gpl: false`、`small: false`、shared、LGPL；对应归档 SHA-256 见 `docs/native-tool-supply-chain.md` | LGPL-3.0-or-later | Hook 按固定 SHA-256 校验归档 |
| FFmpeg CLI | Linux ARM64 | FFmpeg `n8.1.2-22-g94138f6973-20260710` | BtbN FFmpeg-Builds ARM64 static build；已批准仓库导入 `3bb92b6f` | AArch64 Linux static；`--enable-version3`；未启用 `--enable-gpl` 或 `--enable-nonfree`；`libav*` 自报 LGPL v3 or later | LGPL-3.0-or-later | `7c7a73b8ee7fbd16869089c004ca8391ea2feee396eb5c678b804a727a4584a2` |
| FFmpeg CLI | Windows ARM64 | FFmpeg `n8.1.2-22-g94138f6973-20260710` | BtbN FFmpeg-Builds ARM64 static build；已批准仓库导入 `3bb92b6f` | AArch64 Windows static；`--enable-version3`；未启用 `--enable-gpl` 或 `--enable-nonfree`；`libav*` 自报 LGPL v3 or later | LGPL-3.0-or-later | `a51a5f1b11c53ca58c244d12d2068fcd39e09ada8403a30417f7cf251ee42673` |

## 许可证文本链接

- Aria2Android LICENSE: `assets/licenses/aria2android-gpl-3.0.txt`，来源 https://github.com/devgianlu/Aria2Android/blob/master/LICENSE
- aria2 COPYING: `assets/licenses/aria2-gpl-2.0.txt`，来源 https://github.com/aria2/aria2/blob/master/COPYING
- FFmpegKit LICENSE: `assets/licenses/ffmpeg-kit-builders-license.txt`，来源 https://github.com/akashskypatel/ffmpeg-kit-builders/blob/master/LICENSE
- LGPL-3.0: `assets/licenses/lgpl-3.0.txt`，来源 https://www.gnu.org/licenses/lgpl-3.0.txt
- aria2 source: https://github.com/aria2/aria2
- FFmpeg source and legal notes: https://ffmpeg.org/legal.html
- FFmpeg source: https://git.ffmpeg.org/ffmpeg.git
- FFmpegKit builders source: https://github.com/akashskypatel/ffmpeg-kit-builders

## 发布前验证

```powershell
pwsh -File tool/verify_native_binaries.ps1
pwsh -File tool/create_release_checksums.ps1 -Path dist
```

替换任何原生二进制后，必须先更新 `native_bins/manifest.json`、本文件和发布页文案，再重新生成最终安装包哈希。
