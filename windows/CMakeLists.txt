# 项目级构建配置。
cmake_minimum_required(VERSION 3.14)
project(bilibili_down LANGUAGES CXX)

# 设置最终生成的应用可执行文件名。
set(BINARY_NAME "bilibili_down")

# 显式启用现代 CMake 行为，避免新版本产生兼容性警告。
cmake_policy(VERSION 3.14...3.25)

# 判断生成器是否支持多配置，并设置 Debug、Profile、Release 构建类型。
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  # Visual Studio 等多配置生成器一次声明全部构建类型。
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  # 单配置生成器没有显式类型时默认使用 Debug。
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Profile 模式复用 Release 的编译与链接优化参数。
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# 所有 Windows 目标统一使用 Unicode API。
# GitHub 的新 MSVC 会把 experimental coroutine 废弃提示升级为插件编译错误。
add_definitions(
  -DUNICODE
  -D_UNICODE
  -D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS
)

# 定义 Flutter Runner 与插件共用的标准编译设置。
# 插件默认也会调用此函数，新增参数时需要确认不会破坏第三方插件。
function(APPLY_STANDARD_SETTINGS TARGET)
  # 使用 C++17，并把高等级警告视为错误。
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# 引入 Flutter 管理的库与工具构建规则。
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# 引入 Windows Runner 应用目标。
add_subdirectory("runner")

# 引入自动生成的插件构建与链接规则。
include(flutter/generated_plugins.cmake)

# === 安装与打包 ===
# 将运行依赖复制到可执行文件旁，保证 Visual Studio 内可直接构建运行。
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Windows Runner 必须执行 install 步骤，因此将其加入默认构建。
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
# 默认安装前缀指向当前构建配置的可执行文件目录。
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

# 设置 Flutter 数据文件和动态库的安装位置。
set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

# 只打包当前 Windows 架构真正需要的原生工具，避免混入其他系统或架构文件。
set(BILIDOWN_NATIVE_BINS_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../native_bins")
# 合并生成器平台与系统处理器并转为小写，供架构正则判断。
string(TOLOWER "${CMAKE_GENERATOR_PLATFORM};${CMAKE_SYSTEM_PROCESSOR}"
  BILIDOWN_WINDOWS_ARCH)
# Windows ARM64 同时需要 aria2c 和独立 FFmpeg。
if(BILIDOWN_WINDOWS_ARCH MATCHES "arm64")
  set(BILIDOWN_ARIA2_SOURCE
    "${BILIDOWN_NATIVE_BINS_ROOT}/aria2/windows-arm64/aria2c.exe")
  set(BILIDOWN_FFMPEG_SOURCE
    "${BILIDOWN_NATIVE_BINS_ROOT}/ffmpeg/windows-arm64/ffmpeg.exe")
# Windows x64 只需要 aria2c，媒体合并由 FFmpegKit 提供。
elseif(BILIDOWN_WINDOWS_ARCH MATCHES "x64|amd64|x86_64")
  set(BILIDOWN_ARIA2_SOURCE
    "${BILIDOWN_NATIVE_BINS_ROOT}/aria2/windows-x86_x64/aria2c.exe")
# 其他 Windows 架构尚未提供匹配的原生工具，构建必须终止。
else()
  message(FATAL_ERROR
    "Unsupported Windows architecture: ${BILIDOWN_WINDOWS_ARCH}")
endif()

# aria2c 是桌面下载核心，源文件缺失时直接报告路径。
if(NOT EXISTS "${BILIDOWN_ARIA2_SOURCE}")
  message(FATAL_ERROR "Missing aria2 binary: ${BILIDOWN_ARIA2_SOURCE}")
endif()
# 仅在当前架构声明了独立 FFmpeg 时检查其文件。
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

# 将当前架构的 aria2c 复制到运行目录下的 native_bins。
install(PROGRAMS "${BILIDOWN_ARIA2_SOURCE}"
  DESTINATION "${CMAKE_INSTALL_PREFIX}/native_bins"
  COMPONENT Runtime)
# ARM64 构建额外安装独立 FFmpeg，x64 不进入该分支。
if(DEFINED BILIDOWN_FFMPEG_SOURCE)
  install(PROGRAMS "${BILIDOWN_FFMPEG_SOURCE}"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/native_bins"
    COMPONENT Runtime)
endif()

# 安装插件声明的动态库依赖。
if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# 复制各 Dart 包 build.dart 生成的 Windows 原生资源。
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
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

# 仅 Profile 与 Release 模式安装 AOT 库。
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)
