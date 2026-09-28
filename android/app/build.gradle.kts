import java.io.File
import java.util.Properties

plugins {
    // 应用 Android 插件负责生成 APK 与 App Bundle。
    id("com.android.application")
    // Flutter Gradle 插件必须在 Android 与 Kotlin 插件之后应用。
    id("dev.flutter.flutter-gradle-plugin")
}

// 正式签名属性优先读取未入库的 key.properties，并允许 CI 通过环境变量注入。
val releaseSigningProperties = Properties().apply {
    // 本地签名配置只保存在开发机，不允许提交真实证书信息。
    val localPropertiesFile = rootProject.file("key.properties")
    // 文件存在时才读取，保证日常 debug 与静态检查不依赖发布密钥。
    if (localPropertiesFile.exists()) {
        // 输入流仅在配置阶段读取并立即关闭，避免锁住本地密钥配置文件。
        localPropertiesFile.inputStream().use { inputStream -> load(inputStream) }
    }
}

// 按本地配置、CI 环境变量的顺序解析单个签名字段。
fun releaseSigningValue(propertyName: String, environmentName: String): String? {
    // 解析结果只用于 Gradle 内存中的签名配置，不写入构建产物之外的文件。
    val configuredValue = releaseSigningProperties.getProperty(propertyName)
        ?: System.getenv(environmentName)
    return configuredValue?.takeIf { it.isNotBlank() }
}

// 证书路径允许绝对路径；相对路径统一按 android 根目录解析，避免 app 模块重复拼接 app/。
fun releaseSigningFile(path: String): File {
    // CI 会传入 app/release.jks，本地 key.properties 也通常相对 android 目录保存。
    val configuredFile = File(path)
    return if (configuredFile.isAbsolute) configuredFile else rootProject.file(path)
}

// 四个字段必须同时存在，避免 release 包意外回退到调试签名。
val releaseStoreFile = releaseSigningValue("storeFile", "BILIDOWN_STORE_FILE")
val releaseStorePassword = releaseSigningValue("storePassword", "BILIDOWN_STORE_PASSWORD")
val releaseKeyAlias = releaseSigningValue("keyAlias", "BILIDOWN_KEY_ALIAS")
val releaseKeyPassword = releaseSigningValue("keyPassword", "BILIDOWN_KEY_PASSWORD")
val hasReleaseSigning = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { it != null }

// local.properties 仅保存开发机本地开关，适合 VS Code 调试任务临时写入 ABI 选择。
val localBuildProperties = Properties().apply {
    // Flutter 与 Android 工具链会共同维护该文件，读取时必须保留已有 sdk.dir 等配置。
    val localPropertiesFile = rootProject.file("local.properties")
    // 文件不存在时保持空配置，避免 CI 或首次克隆环境被本地调试开关影响。
    if (localPropertiesFile.exists()) {
        // 配置阶段读取后立即关闭输入流，避免影响 IDE 或 Flutter 工具继续写入该文件。
        localPropertiesFile.inputStream().use { inputStream -> load(inputStream) }
    }
}

// Flutter 会通过 target-platform 告诉 Gradle 当前运行或构建目标，需要同步限制原生库 ABI。
val flutterTargetPlatforms = (project.findProperty("target-platform") as String?)
    ?.split(",")
    ?.map { it.trim() }
    ?.filter { it.isNotEmpty() }
    ?: emptyList()

// 本地 IDE 调试优先读取 local.properties，避免 Gradle Daemon 没有拿到 VS Code 环境变量。
val localAndroidAbiFilters = localBuildProperties.getProperty("bilidown.androidAbis")
    ?.split(",")
    ?.map { it.trim() }
    ?.filter { it.isNotEmpty() }
    ?: emptyList()

// CI 或命令行仍可通过环境变量强制 ABI，用于无需改写本地文件的自动化构建。
val forcedAndroidAbiFilters = System.getenv("BILIDOWN_ANDROID_ABIS")
    ?.split(",")
    ?.map { it.trim() }
    ?.filter { it.isNotEmpty() }
    ?: emptyList()

// 将 Flutter 平台名转换为 Android jniLibs ABI，避免模拟器安装时误选 arm64 原生库。
fun abiFiltersForFlutterTargets(targets: List<String>): List<String> {
    return targets.mapNotNull { target ->
        when (target) {
            "android-arm" -> "armeabi-v7a"
            "android-arm64" -> "arm64-v8a"
            "android-x64" -> "x86_64"
            else -> null
        }
    }.distinct()
}

// BiliDown 正式支持的 Android ABI；debug 模拟器可在本地临时收窄到其中一个 ABI。
val defaultAndroidAbiFilters = listOf("armeabi-v7a", "arm64-v8a", "x86_64")

// 第三方插件可能额外携带 x86 原生库，排除列表需要覆盖所有 Android 常见 JNI 目录。
val packageableAndroidAbiFilters = listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")

// 当前 Gradle 任务请求的 ABI：本地调试配置优先，其次 CI 环境变量，最后跟随 Flutter 目标平台。
val requestedAndroidAbiFilters = localAndroidAbiFilters.ifEmpty {
    forcedAndroidAbiFilters
}.ifEmpty {
    abiFiltersForFlutterTargets(flutterTargetPlatforms)
}

// 实际参与编译和打包的 ABI；没有显式请求时保留正式支持的三类架构。
val effectiveAndroidAbiFilters = requestedAndroidAbiFilters.ifEmpty {
    defaultAndroidAbiFilters
}

// 只有显式请求单一或部分 ABI 时才排除其他 JNI 目录，避免普通 release 包被错误裁剪。
val excludedAndroidAbiFilters = if (requestedAndroidAbiFilters.isEmpty()) {
    emptyList()
} else {
    packageableAndroidAbiFilters.filterNot { it in effectiveAndroidAbiFilters }
}

// 生成目录只保存当前 Android 架构需要打包的 aria2 JNI 文件。
val generatedAria2JniLibs = layout.buildDirectory.dir("generated/aria2JniLibs")
// 注册同步任务，把不同 ABI 的 aria2c 重命名为 Android 可提取的共享库。
val syncAria2NativeBins by tasks.registering(Sync::class) {
    // 原生 aria2 资源根目录位于 Flutter 项目的 native_bins 下。
    val nativeBinsRoot = rootProject.projectDir.parentFile.resolve("native_bins/aria2")

    // 32 位 ARM 包仅复制 armeabi-v7a 对应文件。
    from(nativeBinsRoot.resolve("android-armeabi_v7a/aria2c")) {
        into("armeabi-v7a")
        rename { "libaria2c.so" }
    }
    // 64 位 ARM 包仅复制 arm64-v8a 对应文件。
    from(nativeBinsRoot.resolve("android-arm64_v8a/aria2c")) {
        into("arm64-v8a")
        rename { "libaria2c.so" }
    }
    // x64 模拟器或设备仅复制 x86_64 对应文件。
    from(nativeBinsRoot.resolve("android-x86_x64/aria2c")) {
        into("x86_64")
        rename { "libaria2c.so" }
    }
    // 将三个 ABI 目录写入构建生成目录，不修改源码资源。
    into(generatedAria2JniLibs)
}

android {
    // namespace 与 Kotlin 包路径保持一致。
    namespace = "com.bilidown.app"
    // 编译 SDK 和 NDK 版本沿用 Flutter 工具链配置。
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // 后台插件使用的新 Java API 需要启用核心库脱糖。
        isCoreLibraryDesugaringEnabled = true
        // Android 与 Kotlin 均统一使用 Java 17 字节码目标。
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 五端统一使用正式应用 ID，发布后不得变更以免丢失升级关系。
        applicationId = "com.bilidown.app"
        // FFmpegKit Extended 最低要求 Android API 26。
        minSdk = 26
        // 目标 SDK、版本号和版本名由 Flutter 配置统一提供。
        targetSdk = flutter.targetSdkVersion
        // 插件依赖较多，启用 MultiDex 避免方法数上限问题。
        multiDexEnabled = true
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // split-per-abi 会由 Flutter 设置 splits.abi.filters，避免与 NDK 过滤器重复配置。
        if (!project.hasProperty("split-per-abi")) {
            ndk {
                // 普通 APK 按 Flutter 当前目标收窄 ABI，未传目标时保留正式支持的三类架构。
                abiFilters += effectiveAndroidAbiFilters
            }
        }
    }

    sourceSets {
        // 将同步任务生成的目录注册为主源码集 JNI 库来源。
        getByName("main").jniLibs.srcDir(generatedAria2JniLibs.get().asFile)
    }

    packaging {
        jniLibs {
            // aria2 从 applicationInfo.nativeLibraryDir 直接作为进程启动。
            useLegacyPackaging = true
            // MEmu 这类多 ABI 模拟器会优先挑 arm64，显式排除非目标 JNI 才能稳定使用 x86_64。
            excludes += excludedAndroidAbiFilters.map { "lib/$it/**" }
        }
    }

    signingConfigs {
        // 仅在全部字段齐备时创建正式签名，绝不复用 debug 证书。
        if (hasReleaseSigning) {
            create("release") {
                // 证书路径可为相对 android 目录的路径，也可为 CI 提供的绝对路径。
                storeFile = releaseSigningFile(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // 配置存在时绑定生产签名；缺失时由下方发布任务门禁给出明确错误。
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

// 只有真正执行 release 打包时才校验密钥，避免影响 debug、analyze 与测试。
tasks.configureEach {
    // Flutter/Android 的正式产物入口均包含 Release，需统一阻止无签名产物。
    if (name.contains("Release", ignoreCase = true)) {
        doFirst {
            // 缺失任意字段都停止构建，防止误发布未签名或调试签名包。
            check(hasReleaseSigning) {
                "BiliDown release 签名未配置，请复制 android/key.properties.example 或注入 BILIDOWN_* 环境变量。"
            }
        }
    }
}

// 所有 Android 构建开始前必须先准备对应 ABI 的 aria2 文件。
tasks.named("preBuild").configure {
    dependsOn(syncAria2NativeBins)
}

dependencies {
    // 为低版本 Android 提供 Java 新 API 的兼容实现。
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        // Kotlin 编译产物与 Java 17 目标保持一致。
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    // Flutter 工程根目录位于 android 上两级。
    source = "../.."
}
