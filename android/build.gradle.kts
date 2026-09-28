allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Workmanager 部分版本只按 AGP 版本判断 Kotlin 支持，忽略 Flutter 关闭内置 Kotlin 的配置。
    // 仅在该插件走传统 Kotlin 编译路径时补齐编译器，确保生成的注册代码能找到 WorkmanagerPlugin。
    if (name == "workmanager_android" &&
        providers.gradleProperty("android.builtInKotlin").orNull == "false"
    ) {
        // 等待 Android 库插件就绪后再接入 Kotlin；重复应用同一插件不会重复注册任务。
        pluginManager.withPlugin("com.android.library") {
            pluginManager.apply("org.jetbrains.kotlin.android")
            // Workmanager 的 Java 目标为 1.8，Kotlin 必须匹配，避免补齐编译后出现 JVM 目标不一致。
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
