# 项目级构建配置。
cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# 设置最终生成的应用可执行文件名。
set(BINARY_NAME "bilibili_down")
# 设置 GTK 应用唯一标识，发布前需要替换为正式标识。
set(APPLICATION_ID "com.bilidown.app")

# 显式启用现代符号可见性策略，避免新版本 CMake 警告。
cmake_policy(SET CMP0063 NEW)

# 运行时从可执行文件同级的 lib 目录加载随包动态库。
set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")

# 交叉编译时使用 Flutter 提供的目标系统根目录。
if(FLUTTER_TARGET_PLATFORM_SYSROOT)
  # 限制包、库和头文件在目标 sysroot 中查找，构建工具仍使用宿主环境。
  set(CMAKE_SYSROOT ${FLUTTER_TARGET_PLATFORM_SYSROOT})
  set(CMAKE_FIND_ROOT_PATH ${CMAKE_SYSROOT})
  set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
  set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
endif()

# 未指定构建类型时默认使用 Debug，并声明可选模式。
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE "Debug" CACHE
    STRING "Flutter build mode" FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
    "Debug" "Profile" "Release")
endif()

# 定义 Runner 与插件共用的标准编译设置。
# 插件默认也会调用此函数，新增参数时需要确认第三方插件兼容性。
function(APPLY_STANDARD_SETTINGS TARGET)
  # 使用 C++14、严格警告，并在非 Debug 模式启用优化和 NDEBUG。
  target_compile_features(${TARGET} PUBLIC cxx_std_14)
  target_compile_options(${TARGET} PRIVATE -Wall -Werror)
  target_compile_options(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:-O3>")
  target_compile_definitions(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:NDEBUG>")
endfunction()

# 引入 Flutter 管理的库与工具构建规则。
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# 查找 Linux Runner 所需的 PkgConfig 与 GTK3 系统依赖。
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)

# 引入 Linux Runner 应用目标。
add_subdirectory("runner")

# Runner 构建前必须执行 Flutter 资源与代码组装步骤。
add_dependencies(${BINARY_NAME} flutter_assemble)

# 未安装的 Runner 缺少正确相对资源路径，因此放入不可直接运行的中间目录。
set_target_properties(${BINARY_NAME}
  PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/intermediates_do_not_run"
)


# 引入自动生成的插件构建与链接规则。
include(flutter/generated_plugins.cmake)

# tray_manager 0.5.3 的 Linux 插件仍调用 libayatana-appindicator 的弃用构造接口。
# Release 构建需要保留项目自身 -Werror，但第三方弃用告警不能阻断打包。
if(TARGET tray_manager_plugin)
  target_compile_options(tray_manager_plugin PRIVATE
    -Wno-error=deprecated-declarations)
endif()

# === 安装与打包 ===
# 默认在构建目录生成可移动的 bundle。
set(BUILD_BUNDLE_DIR "${PROJECT_BINARY_DIR}/bundle")
# Flutter release 构建可能把默认前缀初始化为 /usr/local/<app>，普通用户没有写入权限。
# 应用只需要生成可移动 bundle，因此始终把安装前缀固定到构建目录。
set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)

# 每次安装前清空旧 bundle，避免其他架构或旧资源残留。
install(CODE "
  file(REMOVE_RECURSE \"${BUILD_BUNDLE_DIR}/\")
  " COMPONENT Runtime)

# 设置 Flutter 数据和动态库的 bundle 安装目录。
set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}/lib")

# 只打包当前 Linux 架构需要的原生工具，避免所有平台二进制进入同一安装包。
set(BILIDOWN_NATIVE_BINS_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../native_bins")
# 合并系统处理器与 Flutter 目标平台并转为小写，供架构判断。
string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR};${FLUTTER_TARGET_PLATFORM}"
  BILIDOWN_LINUX_ARCH)
# Linux ARM64 同时需要 aria2c 和独立 FFmpeg。
if(BILIDOWN_LINUX_ARCH MATCHES "aarch64|arm64")
  set(BILIDOWN_ARIA2_SOURCE
    "${BILIDOWN_NATIVE_BINS_ROOT}/aria2/linux-arm64/aria2c")
  set(BILIDOWN_FFMPEG_SOURCE
    "${BILIDOWN_NATIVE_BINS_ROOT}/ffmpeg/linux-arm64/ffmpeg")
# Linux x64 只需要 aria2c，媒体合并由 FFmpegKit 提供。
elseif(BILIDOWN_LINUX_ARCH MATCHES "x86_64|amd64")
  set(BILIDOWN_ARIA2_SOURCE
    "${BILIDOWN_NATIVE_BINS_ROOT}/aria2/linux-x86_x64/aria2c")
# 其他 Linux 架构尚未提供匹配原生工具，构建必须终止。
else()
  message(FATAL_ERROR
    "Unsupported Linux architecture: ${BILIDOWN_LINUX_ARCH}")
endif()

# aria2c 是桌面下载核心，源文件缺失时直接报告路径。
if(NOT EXISTS "${BILIDOWN_ARIA2_SOURCE}")
  message(FATAL_ERROR "Missing aria2 binary: ${BILIDOWN_ARIA2_SOURCE}")
endif()
# 仅在当前架构声明独立 FFmpeg 时检查文件。
if(DEFINED BILIDOWN_FFMPEG_SOURCE AND
   NOT EXISTS "${BILIDOWN_FFMPEG_SOURCE}")
  message(FATAL_ERROR "Missing FFmpeg binary: ${BILIDOWN_FFMPEG_SOURCE}")
endif()

# 安装 Runner 可执行文件及 Flutter 运行时数据。
install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

# 将当前架构的 aria2c 安装到 bundle/native_bins。
install(PROGRAMS "${BILIDOWN_ARIA2_SOURCE}"
  DESTINATION "${CMAKE_INSTALL_PREFIX}/native_bins"
  COMPONENT Runtime)
# ARM64 构建额外安装独立 FFmpeg，x64 不进入该分支。
if(DEFINED BILIDOWN_FFMPEG_SOURCE)
  install(PROGRAMS "${BILIDOWN_FFMPEG_SOURCE}"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/native_bins"
    COMPONENT Runtime)
endif()

# 逐个安装插件声明的动态库依赖。
foreach(bundled_library ${PLUGIN_BUNDLED_LIBRARIES})
  install(FILES "${bundled_library}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endforeach(bundled_library)

# 复制各 Dart 包 build.dart 生成的 Linux 原生资源。
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/linux/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# 每次构建完整重复制 Flutter 资源目录，避免上次安装残留旧文件。
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# 仅非 Debug 模式安装 AOT 库。
if(NOT CMAKE_BUILD_TYPE MATCHES "Debug")
  install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()
