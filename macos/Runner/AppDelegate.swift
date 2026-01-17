import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  var methodChannel: FlutterMethodChannel?
  var pendingFilePath: String?
  
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
  
  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
    
    methodChannel = FlutterMethodChannel(
      name: "com.substitcher/open_file",
      binaryMessenger: controller.engine.binaryMessenger
    )
    
    methodChannel?.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "getInitialFile" {
        result(self?.pendingFilePath)
        self?.pendingFilePath = nil
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    if let filePath = pendingFilePath {
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        self.methodChannel?.invokeMethod("openFile", arguments: filePath)
      }
    }
  }
  
  override func application(_ application: NSApplication, open urls: [URL]) {
    guard let url = urls.first, url.pathExtension == "opus" else { return }
    
    let filePath = url.path
    
    if methodChannel != nil {
      methodChannel?.invokeMethod("openFile", arguments: filePath)
    } else {
      pendingFilePath = filePath
    }
  }
}