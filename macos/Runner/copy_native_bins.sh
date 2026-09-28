#!/bin/sh
# 任一命令失败或使用未定义变量时立即终止构建。
set -eu

# aria2 源文件统一从 Flutter 工程的 native_bins 读取。
NATIVE_BINS_ROOT="${PROJECT_DIR}/../native_bins/aria2"
# 目标目录位于当前 .app 的 Resources/native_bins 下。
DESTINATION="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/native_bins"

# 每次构建先清理目标目录，避免残留其他架构文件。
rm -rf "${DESTINATION}"
# 重新创建空目标目录。
mkdir -p "${DESTINATION}"

# 逐个处理 Xcode 当前构建请求包含的架构。
for ARCH in ${ARCHS}; do
  # 将 Xcode 架构映射到仓库中的 aria2 源目录。
  case "${ARCH}" in
    arm64)
      # Apple Silicon 使用 macos-arm64 版本。
      SOURCE="${NATIVE_BINS_ROOT}/macos-arm64/aria2c"
      ;;
    x86_64)
      # Intel Mac 使用 macos-x86_64 版本。
      SOURCE="${NATIVE_BINS_ROOT}/macos-x86_64/aria2c"
      ;;
    *)
      # 未适配架构必须终止，防止生成缺少下载能力的安装包。
      echo "Unsupported macOS architecture: ${ARCH}" >&2
      exit 1
      ;;
  esac

  # 源文件缺失时立即报告具体路径并终止构建。
  if [ ! -f "${SOURCE}" ]; then
    echo "Missing aria2 binary: ${SOURCE}" >&2
    exit 1
  fi

  # 每个架构使用独立目标目录，运行时按 ABI 精确选择。
  ARCH_DESTINATION="${DESTINATION}/${ARCH}"
  # 创建架构目录并复制 aria2c。
  mkdir -p "${ARCH_DESTINATION}"
  cp "${SOURCE}" "${ARCH_DESTINATION}/aria2c"
  # 确保 .app 内 aria2c 保留可执行权限。
  chmod 755 "${ARCH_DESTINATION}/aria2c"
done
