import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// 系统废纸篓通道与 Flutter 主窗口同生命周期。
  private var systemTrashChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // 使用主引擎注册回收站通道，确保消息器已经随窗口完成初始化。
    let registrar = flutterViewController.registrar(forPlugin: "SystemTrash")
    let channel = FlutterMethodChannel(
      name: "bilidown/system_trash",
      binaryMessenger: registrar.messenger
    )
    systemTrashChannel = channel
    channel.setMethodCallHandler { call, result in
      // 通道只接受批量移入废纸篓，其他方法交给 Flutter 报告未实现。
      guard call.method == "movePathsToTrash" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let paths = arguments["paths"] as? [String],
        !paths.isEmpty
      else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "文件路径列表不能为空。",
            details: nil
          )
        )
        return
      }
      // NSWorkspace 使用与 Finder 相同的废纸篓语义，并在全部完成后回调结果。
      let urls = paths.map { URL(fileURLWithPath: $0) }
      NSWorkspace.shared.recycle(urls) { movedURLs, error in
        // 明确切回主队列响应 Flutter，避免系统在后台队列回调时触碰平台编码器。
        DispatchQueue.main.async {
          // 任一文件失败时返回平台错误，Dart 层会保留对应任务记录供重试。
          if let error {
            result(
              FlutterError(
                code: "trash_failed",
                message: "macOS 无法把下载文件移入废纸篓。",
                details: error.localizedDescription
              )
            )
            return
          }
          // 映射数量必须与输入一致，防止部分成功被误判为整批成功。
          guard movedURLs.count == urls.count else {
            result(
              FlutterError(
                code: "trash_partial_failure",
                message: "部分下载文件未能移入废纸篓。",
                details: nil
              )
            )
            return
          }
          result(nil)
        }
      }
    }

    super.awakeFromNib()
  }
}
