#include "flutter_window.h"

#include <flutter/standard_method_codec.h>
#include <shobjidl.h>

#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <system_error>
#include <thread>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

namespace {

// 回收站任务完成后投递到窗口线程的私有消息，避开 Shell 操作阻塞界面绘制。
constexpr UINT kSystemTrashCompletedMessage = WM_APP + 0x42;

// 保存后台 Shell 结果与尚未回复的 Flutter 方法调用。
struct SystemTrashCompletion {
  // Windows Shell 返回的 HRESULT，窗口线程据此回复成功或失败。
  HRESULT result;

  // 共享所有权覆盖线程创建与窗口投递生命周期，但业务仍只在窗口线程回复一次。
  std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>> method_result;
};

// 将 Flutter 传入的 UTF-8 路径转换为 Windows Shell 使用的 UTF-16。
std::wstring Utf16FromUtf8(const std::string& value) {
  if (value.empty()) {
    return std::wstring();
  }
  const int required_length = ::MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
      static_cast<int>(value.size()), nullptr, 0);
  if (required_length <= 0) {
    return std::wstring();
  }
  std::wstring converted(static_cast<size_t>(required_length), L'\0');
  const int converted_length = ::MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
      static_cast<int>(value.size()), converted.data(), required_length);
  return converted_length == required_length ? converted : std::wstring();
}

// 使用一次 IFileOperation 把全部用户成品移入 Windows 回收站。
HRESULT MovePathsToRecycleBin(const std::vector<std::string>& paths) {
  IFileOperation* operation = nullptr;
  HRESULT result = ::CoCreateInstance(CLSID_FileOperation, nullptr,
                                      CLSCTX_INPROC_SERVER,
                                      IID_PPV_ARGS(&operation));
  if (FAILED(result)) {
    return result;
  }

  // 关闭 Shell 二次确认与进度窗口，但明确要求删除进入回收站且可撤销。
  result = operation->SetOperationFlags(
      FOF_ALLOWUNDO | FOF_NOCONFIRMATION | FOF_SILENT |
      FOFX_RECYCLEONDELETE);
  if (SUCCEEDED(result)) {
    for (const auto& path : paths) {
      const std::wstring wide_path = Utf16FromUtf8(path);
      if (wide_path.empty()) {
        result = E_INVALIDARG;
        break;
      }
      IShellItem* item = nullptr;
      result = ::SHCreateItemFromParsingName(wide_path.c_str(), nullptr,
                                             IID_PPV_ARGS(&item));
      if (FAILED(result)) {
        break;
      }
      // 队列阶段只登记项目，PerformOperations 才会作为一个 Shell 批次执行。
      result = operation->DeleteItem(item, nullptr);
      item->Release();
      if (FAILED(result)) {
        break;
      }
    }
  }
  if (SUCCEEDED(result)) {
    result = operation->PerformOperations();
  }
  if (SUCCEEDED(result)) {
    BOOL aborted = FALSE;
    const HRESULT aborted_result = operation->GetAnyOperationsAborted(&aborted);
    if (FAILED(aborted_result)) {
      result = aborted_result;
    } else if (aborted) {
      result = HRESULT_FROM_WIN32(ERROR_CANCELLED);
    }
  }
  operation->Release();
  return result;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  // 注册用户成品回收站通道，Dart 层只在明确勾选删除文件后调用。
  system_trash_channel_ = std::make_unique<
      flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "bilidown/system_trash",
      &flutter::StandardMethodCodec::GetInstance());
  system_trash_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        // 通道只暴露批量移入回收站，不提供任意永久删除能力。
        if (call.method_name() != "movePathsToTrash") {
          result->NotImplemented();
          return;
        }
        const auto* arguments =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (arguments == nullptr) {
          result->Error("invalid_arguments", "缺少回收站参数。");
          return;
        }
        const auto path_iterator =
            arguments->find(flutter::EncodableValue("paths"));
        if (path_iterator == arguments->end()) {
          result->Error("invalid_arguments", "缺少文件路径列表。");
          return;
        }
        const auto* path_values =
            std::get_if<flutter::EncodableList>(&path_iterator->second);
        if (path_values == nullptr) {
          result->Error("invalid_arguments", "文件路径列表格式错误。");
          return;
        }
        std::vector<std::string> paths;
        paths.reserve(path_values->size());
        for (const auto& path_value : *path_values) {
          const auto* path = std::get_if<std::string>(&path_value);
          if (path == nullptr || path->empty()) {
            result->Error("invalid_arguments", "文件路径不能为空。");
            return;
          }
          paths.push_back(*path);
        }
        // 空批次无需访问 Shell，直接报告成功。
        if (paths.empty()) {
          result->Success();
          return;
        }
        // 固定当前原生窗口句柄，后台完成后通过私有消息切回窗口线程回复 Flutter。
        const HWND window = GetHandle();
        // 共享结果允许线程创建失败时仍在当前窗口线程返回明确错误。
        auto shared_result = std::shared_ptr<
            flutter::MethodResult<flutter::EncodableValue>>(std::move(result));
        try {
          std::thread(
              [window, paths = std::move(paths), shared_result]() mutable {
                // IFileOperation 依赖 COM，工作线程必须建立并成对释放自己的单元。
                const HRESULT initialize_result =
                    ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
                HRESULT recycle_result = initialize_result;
                if (SUCCEEDED(initialize_result)) {
                  // 全部路径仍作为一个 Shell 批次提交，不循环执行底层删除命令。
                  recycle_result = MovePathsToRecycleBin(paths);
                  ::CoUninitialize();
                }
                // 堆对象所有权随窗口消息转移，窗口线程处理后立即自动释放。
                auto* completion = new SystemTrashCompletion{
                    recycle_result, shared_result};
                if (!::PostMessage(window, kSystemTrashCompletedMessage, 0,
                                   reinterpret_cast<LPARAM>(completion))) {
                  // 应用退出导致窗口失效时释放结果，不能让后台线程泄漏内存。
                  delete completion;
                }
              })
              .detach();
        } catch (const std::system_error&) {
          // 系统无法创建工作线程时不执行文件操作，并让 Dart 安全保留记录。
          shared_result->Error("trash_worker_unavailable",
                               "Windows 无法启动后台回收站任务。");
        }
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  // 先销毁平台通道，再释放 Flutter 引擎和其二进制消息器。
  system_trash_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == kSystemTrashCompletedMessage) {
    // 私有完成消息必须先于插件分发处理，避免未知插件截获后遗失结果对象。
    std::unique_ptr<SystemTrashCompletion> completion(
        reinterpret_cast<SystemTrashCompletion*>(lparam));
    if (FAILED(completion->result)) {
      // 失败详情只返回 HRESULT，Dart 层会转换成用户可读提示并保留任务记录。
      completion->method_result->Error(
          "trash_failed", "Windows 无法把下载文件移入回收站。",
          flutter::EncodableValue(static_cast<int64_t>(completion->result)));
    } else {
      // Shell 全部完成后才允许 Dart 层继续删除数据库记录。
      completion->method_result->Success();
    }
    return 0;
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
