package com.bilidown.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.Settings
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Flutter Android 主 Activity，并向 Dart 暴露原生工具运行时信息。 */
class MainActivity : FlutterActivity() {
    /** 等待 Android 13+ 通知权限授权结果的 Flutter 回调；避免重复弹出系统权限框。 */
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null

    /** 注册 Flutter 插件后创建原生运行时方法通道。 */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // 先执行 FlutterActivity 默认插件注册流程。
        super.configureFlutterEngine(flutterEngine)
        // 使用引擎消息器创建与 Dart 端名称一致的方法通道。
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NATIVE_RUNTIME_CHANNEL,
        ).setMethodCallHandler { call, result ->
            // 按 Dart 调用的方法名分派原生能力。
            when (call.method) {
                "getNativeRuntimeInfo" -> {
                    // 返回 Android 安装后真实的 aria2 路径和首选 ABI。
                    result.success(
                        mapOf(
                            "aria2Path" to "${applicationInfo.nativeLibraryDir}/libaria2c.so",
                            "primaryAbi" to Build.SUPPORTED_ABIS.firstOrNull(),
                        ),
                    )
                }

                // 未声明的方法交给 Flutter 返回 notImplemented。
                else -> result.notImplemented()
            }
        }
        // Android 系统级权限通道供引导页和文件操作入口统一检查授权状态。
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ANDROID_PERMISSION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            // 文件管理和通知权限由原生侧判断系统版本，Dart 侧只关心是否可继续。
            when (call.method) {
                "hasAllFilesAccess" -> result.success(hasAllFilesAccess())
                "openAllFilesAccessSettings" -> {
                    openAllFilesAccessSettings()
                    result.success(null)
                }

                "hasNotificationPermission" -> result.success(hasNotificationPermission())
                "requestNotificationPermission" -> requestNotificationPermission(result)
                // 未声明的方法交给 Flutter 返回 notImplemented。
                else -> result.notImplemented()
            }
        }
        // Android 文件管理器通道用于打开可操作目录，而不是 ACTION_OPEN_DOCUMENT 文件选择器。
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ANDROID_DIRECTORY_ACTION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openDirectory" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    result.success(openDirectoryInFileManager(path))
                }

                // 未声明的方法交给 Flutter 返回 notImplemented。
                else -> result.notImplemented()
            }
        }
    }

    /** 判断 Android 文件管理授权是否已经满足当前下载器的本地文件操作需求。 */
    private fun hasAllFilesAccess(): Boolean {
        // Android 11 起外部公共目录的直接文件管理需要系统级开关；旧系统沿用安装时权限模型。
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            true
        }
    }

    /** 打开当前应用的“管理所有文件”授权页，厂商系统不支持时回退到系统列表入口。 */
    private fun openAllFilesAccessSettings() {
        // Android 10 及以下没有这个设置页，直接返回让 Dart 继续旧存储权限流程。
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        val uri = Uri.parse("package:$packageName")
        val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, uri)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            // 优先打开本应用专属授权页，减少用户在系统列表里查找应用。
            startActivity(intent)
        } catch (_: Exception) {
            // 部分系统没有专属页面，只能回退到“所有文件访问权限”总列表。
            startActivity(
                Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    /** 使用系统文件管理器打开真实目录，保留文件播放、长按和移动等操作能力。 */
    private fun openDirectoryInFileManager(path: String): Boolean {
        // 目录路径来自 Dart 的下载输出父目录，必须转换成外部存储 DocumentsProvider 的目录 Uri。
        val documentId = documentIdForExternalStoragePath(path) ?: return false
        val uri = DocumentsContract.buildDocumentUri(
            EXTERNAL_STORAGE_DOCUMENT_AUTHORITY,
            documentId,
        )
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, DocumentsContract.Document.MIME_TYPE_DIR)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            .addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        return try {
            // ACTION_VIEW 进入文件管理器浏览态，不进入只读/选择文件流程。
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    /** 将 /storage/emulated/0/Download/BiliDown 转成 primary:Download/BiliDown。 */
    private fun documentIdForExternalStoragePath(path: String): String? {
        // 规范化路径，避免相对段影响 DocumentsProvider 解析。
        val canonicalPath = try {
            File(path).canonicalPath
        } catch (_: Exception) {
            File(path).absolutePath
        }
        val primaryRoot = Environment.getExternalStorageDirectory().absolutePath
        if (canonicalPath == primaryRoot) return "primary:"
        if (canonicalPath.startsWith("$primaryRoot/")) {
            return "primary:${canonicalPath.removePrefix("$primaryRoot/")}"
        }
        // 兼容 /storage/XXXX-XXXX/Movies 这类外置存储路径。
        val storagePrefix = "/storage/"
        if (!canonicalPath.startsWith(storagePrefix)) return null
        val parts = canonicalPath.removePrefix(storagePrefix).split("/", limit = 2)
        if (parts.isEmpty() || parts[0].isBlank()) return null
        val storageId = parts[0]
        val relativePath = parts.getOrNull(1).orEmpty()
        return if (relativePath.isBlank()) "$storageId:" else "$storageId:$relativePath"
    }

    /** 判断 Android 13+ 通知运行时权限是否已授予。 */
    private fun hasNotificationPermission(): Boolean {
        // Android 12 及以下通知权限跟随安装授权，业务侧无需额外拦截。
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    /** 请求 Android 13+ 通知权限，并通过 MethodChannel 把系统回调返回给 Dart。 */
    private fun requestNotificationPermission(result: MethodChannel.Result) {
        // 已授权或系统不需要运行时通知权限时，直接允许引导流程继续。
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || hasNotificationPermission()) {
            result.success(true)
            return
        }
        // 同一时间只能保留一个 Flutter 回调，防止快速点击覆盖前一次请求。
        if (pendingNotificationPermissionResult != null) {
            result.error("PERMISSION_BUSY", "已有 Android 通知权限请求正在进行。", null)
            return
        }
        pendingNotificationPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE,
        )
    }

    /** 接收 Android 13+ 通知权限请求结果，并完成等待中的 Flutter MethodChannel 调用。 */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        // Flutter 插件也可能请求权限，必须先交给父类分发。
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        // 非通知权限请求不读取或清理当前回调。
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST_CODE) return
        val result = pendingNotificationPermissionResult ?: return
        pendingNotificationPermissionResult = null
        // 使用实时权限状态作为最终结果，兼容厂商系统返回数组异常的情况。
        result.success(hasNotificationPermission())
    }

    private companion object {
        // 方法通道名称必须与 Dart NativeToolResolver 保持一致。
        const val NATIVE_RUNTIME_CHANNEL = "com.bilidown.app/native_runtime"

        // Android 权限通道由引导页和文件操作入口调用。
        const val ANDROID_PERMISSION_CHANNEL = "com.bilidown.app/android_permissions"

        // Android 文件管理器通道用于打开真实目录浏览态。
        const val ANDROID_DIRECTORY_ACTION_CHANNEL =
            "com.bilidown.app/android_directory_actions"

        // 系统外部存储 DocumentsProvider authority。
        const val EXTERNAL_STORAGE_DOCUMENT_AUTHORITY =
            "com.android.externalstorage.documents"

        // 通知权限请求码只在当前 Activity 内部使用，避开常见插件低位编号。
        const val NOTIFICATION_PERMISSION_REQUEST_CODE = 0x4E50
    }
}
