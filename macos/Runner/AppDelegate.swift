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
    
    let visionChannel = FlutterMethodChannel(
      name: "com.substitcher/vision_tracker",
      binaryMessenger: controller.engine.binaryMessenger
    )
    
    visionChannel.setMethodCallHandler { (call, result) in
      guard call.method == "trackRegion" else {
        result(FlutterMethodNotImplemented)
        return
      }
      
      guard
        let args  = call.arguments as? [String: Any],
        let path  = args["videoPath"] as? String,
        let normX = args["x"] as? Double,
        let normY = args["y"] as? Double,
        let normW = args["w"] as? Double,
        let normH = args["h"] as? Double
      else {
        result(FlutterError(
          code: "BAD_ARGS",
          message: "Expected videoPath, x, y, w, h",
          details: nil
        ))
        return
      }
      
      VisionTracker.trackRegion(
        videoPath: path,
        normX: normX, normY: normY,
        normW: normW, normH: normH,
        result: result
      )
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