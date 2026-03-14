import Cocoa
import Vision
import AVFoundation
import FlutterMacOS

class VisionTracker: NSObject {

  static func trackRegion(
    videoPath: String,
    normX: Double, normY: Double,
    normW: Double, normH: Double,
    result: @escaping FlutterResult
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let coords = try Self._track(
          videoPath: videoPath,
          normX: normX, normY: normY,
          normW: normW, normH: normH
        )
        DispatchQueue.main.async { result(coords) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "TRACK_ERROR",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }

  private static func _track(
    videoPath: String,
    normX: Double, normY: Double,
    normW: Double, normH: Double
  ) throws -> [[Double]] {

    let url = URL(fileURLWithPath: videoPath)
    let asset = AVAsset(url: url)

    guard let videoTrack = asset.tracks(withMediaType: .video).first else {
      throw NSError(domain: "VisionTracker", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "No video track found"])
    }

    let visionX = normX
    let visionY = 1.0 - normY - normH
    let visionW = normW
    let visionH = normH

    let boundingBox = CGRect(x: visionX, y: visionY, width: visionW, height: visionH)

    let initialObservation = VNDetectedObjectObservation(boundingBox: boundingBox)
    let request = VNTrackObjectRequest(detectedObjectObservation: initialObservation)
    request.trackingLevel = VNRequestTrackingLevel.accurate

    let generator = AVAssetImageGenerator(asset: asset)
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter  = .zero
    generator.appliesPreferredTrackTransform = true

    let duration   = asset.duration
    let totalSecs  = CMTimeGetSeconds(duration)
    let nominalFPS = videoTrack.nominalFrameRate
    let frameCount = Int(totalSecs * Double(nominalFPS))
    let frameDur   = 1.0 / Double(nominalFPS)

    var results: [[Double]] = []
    let sequenceHandler = VNSequenceRequestHandler()

    for frameIdx in 0 ..< frameCount {
      let timeSecs = Double(frameIdx) * frameDur
      let cmTime   = CMTime(seconds: timeSecs, preferredTimescale: 600)

      let cgImage: CGImage
      do {
        cgImage = try generator.copyCGImage(at: cmTime, actualTime: nil)
      } catch {
        continue
      }

      do {
        try sequenceHandler.perform([request], on: cgImage)
      } catch {
        continue
      }

      guard let observation = request.results?.first as? VNDetectedObjectObservation
      else { continue }

      let bb = observation.boundingBox

      let outX = bb.origin.x
      let outY = 1.0 - bb.origin.y - bb.height
      let outW = bb.width
      let outH = bb.height

      results.append([Double(frameIdx), outX, outY, outW, outH])
    }

    return results
  }
}