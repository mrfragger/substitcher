import Cocoa
import FlutterMacOS
import CoreImage
import Vision

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    SvgPaletteChannel.register(with: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

final class SvgPaletteChannel {
    private static let ctx = CIContext()
    private static let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let queue = DispatchQueue(
        label: "substitcher.svgpalette", qos: .userInitiated, attributes: .concurrent)

    private enum Failure: Error, CustomStringConvertible {
        case load(String), noSubject, unsupported, render(String)
        var description: String {
            switch self {
            case .load(let n): return "could not load \(n)"
            case .noSubject: return "Vision found no foreground subject"
            case .unsupported: return "background removal needs macOS 14 or newer"
            case .render(let m): return "could not render \(m)"
            }
        }
    }

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "substitcher/svgpalette", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            guard let args = call.arguments as? [String: Any], let input = args["input"] as? String else {
                result(FlutterError(code: "args", message: "missing input", details: nil))
                return
            }
            SvgPaletteChannel.queue.async {
                do {
                    switch call.method {
                    case "probe":
                        let cut = try SvgPaletteChannel.alreadyCutOut(input)
                        DispatchQueue.main.async { result(cut) }
                    case "render":
                        guard let output = args["output"] as? String,
                              let maxSide = args["maxSide"] as? Int,
                              let passes = args["smooth"] as? Int,
                              let wantCutout = args["cutout"] as? Bool
                        else { throw Failure.render("bad arguments") }
                        try SvgPaletteChannel.render(
                            input: input, output: output, maxSide: maxSide, passes: passes,
                            wantCutout: wantCutout)
                        DispatchQueue.main.async { result(nil) }
                    default:
                        DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "svgpalette", message: "\(error)", details: nil))
                    }
                }
            }
        }
    }

    // MARK: - CoreImage helpers

    private static func load(_ path: String) throws -> CIImage {
        guard let img = CIImage(
            contentsOf: URL(fileURLWithPath: path), options: [.applyOrientationProperty: true])
        else { throw Failure.load((path as NSString).lastPathComponent) }
        return img
    }

    private static func origin(_ i: CIImage) -> CIImage {
        i.transformed(by: CGAffineTransform(translationX: -i.extent.minX, y: -i.extent.minY))
    }

    /// Scale so the longest side equals `maxSide` (up or down).
    private static func fit(_ image: CIImage, maxSide: Int) -> CIImage {
        let e = image.extent
        let scale = CGFloat(maxSide) / max(e.width, e.height)
        let out = image.applyingFilter(
            "CILanczosScaleTransform",
            parameters: [kCIInputScaleKey: scale, kCIInputAspectRatioKey: 1.0])
        return origin(out)
    }

    private static func smooth(_ image: CIImage, passes: Int) -> CIImage {
        var out = image
        for _ in 0..<max(0, passes) { out = out.applyingFilter("CIMedianFilter") }
        return out.cropped(to: image.extent)
    }

    /// Same technology as Finder's "Remove Background". Also crops to the subject.
    private static func cutout(_ image: CIImage) throws -> CIImage {
        guard #available(macOS 14.0, *) else { throw Failure.unsupported }
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        let request = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([request])
        guard let obs = request.results?.first, !obs.allInstances.isEmpty else {
            throw Failure.noSubject
        }
        let buffer = try obs.generateMaskedImage(
            ofInstances: obs.allInstances, from: handler, croppedToInstancesExtent: true)
        return origin(CIImage(cvPixelBuffer: buffer))
    }

    // MARK: - Methods

    /// True when more than 2% of the image (at 128 px) is transparent.
    private static func alreadyCutOut(_ path: String) throws -> Bool {
        let small = fit(try load(path), maxSide: 128)
        let rect = small.extent.integral
        let w = Int(rect.width), h = Int(rect.height)
        guard w > 0, h > 0 else { return false }
        var px = [UInt8](repeating: 0, count: w * h * 4)
        ctx.render(small, toBitmap: &px, rowBytes: w * 4, bounds: rect, format: .RGBA8, colorSpace: srgb)
        var transparent = 0
        var i = 3
        while i < px.count {
            if px[i] < 128 { transparent += 1 }
            i += 4
        }
        return Double(transparent) / Double(w * h) > 0.02
    }

    private static func render(
        input: String, output: String, maxSide: Int, passes: Int, wantCutout: Bool
    ) throws {
        var image = try load(input)
        if wantCutout { image = try cutout(image) }
        image = smooth(fit(image, maxSide: maxSide), passes: passes)

        let rect = image.extent.integral
        guard let cg = ctx.createCGImage(image, from: rect, format: .RGBA8, colorSpace: srgb) else {
            throw Failure.render("bitmap")
        }
        guard let dest = CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: output) as CFURL, "public.png" as CFString, 1, nil)
        else { throw Failure.render("png destination") }
        CGImageDestinationAddImage(dest, cg, nil)
        guard CGImageDestinationFinalize(dest) else { throw Failure.render("png write") }
    }
}
