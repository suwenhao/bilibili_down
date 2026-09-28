# GitHub Actions 构建与上传

通过 `.github/workflows/build.yml` 的 `workflow_dispatch` 手动构建各平台包。

## Android 签名

在 GitHub 仓库的 Settings → Secrets and variables → Actions 中配置：

- `ANDROID_KEYSTORE_BASE64`：签名证书的 Base64 内容。
- `ANDROID_STORE_PASSWORD`：证书库密码。
- `ANDROID_KEY_ALIAS`：签名别名。
- `ANDROID_KEY_PASSWORD`：签名密码。

工作流只在运行时还原证书。不要提交 `release.jks`、`key.properties` 或
`github-actions-secrets*.txt`。本地忽略规则不会移除已经跟踪的文件，复制项目时也不会生效；
上传前使用 `git status` 和 `git ls-files` 检查。

如果真实签名材料曾被提交，删除当前文件不会清除 Git 历史，需要另行处理历史及凭据暴露。
不要直接替换已有应用的签名证书，否则可能无法覆盖安装原版本。

## Workmanager 注册类找不到

AGP 9 下，Flutter 项目使用 `android.builtInKotlin=false`。部分 Workmanager Android
版本只检查 AGP 主版本，跳过传统 Kotlin 插件，导致 Kotlin 源码没有编译，最终在
`GeneratedPluginRegistrant.java` 中报 `WorkmanagerPlugin` 找不到。

`android/build.gradle.kts` 对 Workmanager 单独补齐 Kotlin 插件，并使 Kotlin 和 Java
都使用 JVM 1.8 目标；不修改生成的注册文件，也不全局启用内置 Kotlin。
本地锁文件使用镜像源，CI 使用其他源时可能重新解析依赖，因此不能仅凭本地缓存版本
判断 CI 实际使用的版本。相关上游问题：[Workmanager #722](https://github.com/fluttercommunity/flutter_workmanager/issues/722)。

## Artifact 存储额度用满

`Artifact storage quota has been hit` 表示上传额度不足。若前面的构建、打包步骤成功，
无需将这个错误当作平台编译错误处理；`punycode` 弃用警告也不是上传失败原因。

1. 先保存仍需使用的构建产物。
2. 打开仓库 Actions → 旧运行记录，在 Artifacts 区域删除不再需要的产物；账户共享额度
   可能还包含其他仓库的产物，需要一并检查。
3. 等待 GitHub 更新存储用量，再重新运行工作流。官方说明用量通常每 6–12 小时重新计算。

工作流的新产物保留 7 天。修改保留期不会立即删除已有产物，也不能立即恢复耗尽的额度。
本地删除 `build/` 或清理 Git 源码不会释放远端 Artifact 存储。
参考：[upload-artifact 限制](https://github.com/actions/upload-artifact#limitations)。

## 上传目录

保留源码、`pubspec.lock`、平台工程、`native_bins`、`third_party`、资源、测试和文档。
本地缓存、生成目录、机器路径配置和签名材料不需要复制到上传目录；这些内容由忽略规则排除。
其中 `native_bins` 和 `third_party` 是构建输入，不能当作普通缓存删除。
