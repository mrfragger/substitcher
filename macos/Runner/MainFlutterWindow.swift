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
        case load(String), noSubject, noCrop, noFace, unsupported, render(String)
        var description: String {
            switch self {
            case .load(let n): return "could not load \(n)"
            case .noSubject: return "Vision found no foreground subject"
            case .noCrop: return "no tighter crop found (the salient region fills the image)"
            case .noFace: return "Vision found no face"
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
                    case "instances":
                        let n = try SvgPaletteChannel.instanceCount(input)
                        DispatchQueue.main.async { result(n) }
                    case "faces":
                        let n = try SvgPaletteChannel.faceBoxes(try SvgPaletteChannel.load(input)).count
                        DispatchQueue.main.async { result(n) }
                    case "ocr":
                        let text = try SvgPaletteChannel.recognizeText(input)
                        DispatchQueue.main.async { result(text) }
                    case "render":
                        guard let output = args["output"] as? String,
                              let maxSide = args["maxSide"] as? Int,
                              let passes = args["smooth"] as? Int,
                              let wantCutout = args["cutout"] as? Bool
                        else { throw Failure.render("bad arguments") }
                        // mode: orig | bg | cut | crop | cropcut | face | facecut | mask   (instance is 1-based, face/facecut/mask only)
                        let mode = args["mode"] as? String ?? (wantCutout ? "cut" : "bg")
                        let instance = args["instance"] as? Int ?? 1
                        try SvgPaletteChannel.render(
                            input: input, output: output, maxSide: maxSide, passes: passes,
                            wantCutout: wantCutout, mode: mode, instance: instance)
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

    /// Scale so the longest side is at most `maxSide`; never enlarges.
    private static func fitDown(_ image: CIImage, maxSide: Int) -> CIImage {
        let e = image.extent
        let longest = max(e.width, e.height)
        guard longest > CGFloat(maxSide) else { return origin(image) }
        return fit(image, maxSide: maxSide)
    }

    private static func smooth(_ image: CIImage, passes: Int) -> CIImage {
        var out = image
        for _ in 0..<max(0, passes) { out = out.applyingFilter("CIMedianFilter") }
        return out.cropped(to: image.extent)
    }

    /// Same technology as Finder's "Remove Background". Also crops to the subject.
    /// With `instance` (1-based) only that one subject is kept; otherwise all subjects together.
    private static func cutout(_ image: CIImage, instance: Int? = nil) throws -> CIImage {
        guard #available(macOS 14.0, *) else { throw Failure.unsupported }
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        let request = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([request])
        guard let obs = request.results?.first, !obs.allInstances.isEmpty else {
            throw Failure.noSubject
        }
        var chosen = obs.allInstances
        if let n = instance {
            let ids = Array(obs.allInstances).sorted()
            guard n >= 1, n <= ids.count else { throw Failure.noSubject }
            chosen = IndexSet(integer: ids[n - 1])
        }
        let buffer = try obs.generateMaskedImage(
            ofInstances: chosen, from: handler, croppedToInstancesExtent: true)
        return origin(CIImage(cvPixelBuffer: buffer))
    }

    /// Smart crop: the union of Vision's salient regions (attention first, objectness as the
    /// fallback) plus 10% padding. Throws .noCrop when that would be almost the whole image.
    private static func smartCrop(_ image: CIImage) throws -> CIImage {
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        let attention = VNGenerateAttentionBasedSaliencyImageRequest()
        try handler.perform([attention])
        var boxes = (attention.results?.first?.salientObjects ?? []).map { $0.boundingBox }
        if boxes.isEmpty {
            let objectness = VNGenerateObjectnessBasedSaliencyImageRequest()
            try handler.perform([objectness])
            boxes = (objectness.results?.first?.salientObjects ?? []).map { $0.boundingBox }
        }
        guard var box = boxes.first else { throw Failure.noSubject }
        for b in boxes.dropFirst() { box = box.union(b) }

        let e = image.extent
        // Vision's normalized boxes and CoreImage both use a bottom-left origin.
        var r = CGRect(
            x: e.minX + box.minX * e.width, y: e.minY + box.minY * e.height,
            width: box.width * e.width, height: box.height * e.height)
        r = r.insetBy(dx: -r.width * 0.1, dy: -r.height * 0.1).intersection(e)
        if r.isNull || r.width * r.height > e.width * e.height * 0.9 { throw Failure.noCrop }
        return origin(image.cropped(to: r))
    }

    /// Faces Vision finds (normalized boxes, bottom-left origin), left to right. Tiny or unsure
    /// detections are dropped so background faces and false positives do not become cards.
    private static func faceBoxes(_ image: CIImage) throws -> [CGRect] {
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        let request = VNDetectFaceRectanglesRequest()
        try handler.perform([request])
        return (request.results ?? [])
            .filter { $0.boundingBox.width >= 0.04 && $0.confidence >= 0.5 }
            .map { $0.boundingBox }
            .sorted { $0.minX < $1.minX }
    }

    /// Pixel rectangle around a normalized face box with room for hair, ears and chin.
    private static func paddedFaceRect(_ box: CGRect, in e: CGRect) throws -> CGRect {
        var r = CGRect(
            x: e.minX + box.minX * e.width, y: e.minY + box.minY * e.height,
            width: box.width * e.width, height: box.height * e.height)
        r = r.insetBy(dx: -r.width * 0.5, dy: -r.height * 0.6).intersection(e)
        guard !r.isNull, r.width >= 8, r.height >= 8 else { throw Failure.noFace }
        return r
    }

    /// Crop around face number `instance` (1-based).
    private static func faceCrop(_ image: CIImage, instance: Int) throws -> CIImage {
        let boxes = try faceBoxes(image)
        guard instance >= 1, instance <= boxes.count else { throw Failure.noFace }
        return origin(image.cropped(to: try paddedFaceRect(boxes[instance - 1], in: image.extent)))
    }

    /// Which Vision subject (1-based label) this face belongs to: the most common non-zero label
    /// of the instance mask over a 5 x 5 grid inside the face box. nil when the face is on background.
    @available(macOS 14.0, *)
    private static func subjectLabel(_ obs: VNInstanceMaskObservation, at box: CGRect) -> Int? {
        let mask = obs.instanceMask
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return nil }
        let w = CVPixelBufferGetWidth(mask), h = CVPixelBufferGetHeight(mask)
        let stride = CVPixelBufferGetBytesPerRow(mask)
        var votes = [Int: Int]()
        for i in 1...5 {
            for j in 1...5 {
                let nx = box.minX + box.width * CGFloat(i) / 6
                let ny = box.minY + box.height * CGFloat(j) / 6   // bottom-left origin
                let x = min(w - 1, max(0, Int(nx * CGFloat(w))))
                let y = min(h - 1, max(0, Int((1 - ny) * CGFloat(h))))
                let v = Int(base.load(fromByteOffset: y * stride + x, as: UInt8.self))
                if v != 0 { votes[v, default: 0] += 1 }
            }
        }
        return votes.max { $0.value < $1.value }?.key
    }

    /// Face crop with the background removed: only the subject this face belongs to is kept, so
    /// neighbouring people inside the crop are cleared. Falls back to all subjects when the face
    /// is not part of one (e.g. a face on a poster in the background).
    private static func faceCut(_ image: CIImage, instance: Int) throws -> CIImage {
        guard #available(macOS 14.0, *) else { throw Failure.unsupported }
        let boxes = try faceBoxes(image)
        guard instance >= 1, instance <= boxes.count else { throw Failure.noFace }
        let box = boxes[instance - 1]
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        let request = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([request])
        guard let obs = request.results?.first, !obs.allInstances.isEmpty else {
            throw Failure.noSubject
        }
        var chosen = obs.allInstances
        if let label = subjectLabel(obs, at: box), obs.allInstances.contains(label) {
            chosen = IndexSet(integer: label)
        }
        let buffer = try obs.generateMaskedImage(
            ofInstances: chosen, from: handler, croppedToInstancesExtent: false)
        let masked = origin(CIImage(cvPixelBuffer: buffer))
        return origin(masked.cropped(to: try paddedFaceRect(box, in: masked.extent)))
    }

    // MARK: - Methods

    /// Text found in the image (Vision OCR), one line per recognised line, top to bottom.
    /// Empty string when there is no text. Low-confidence lines are dropped so photos
    /// without text do not produce noise.
    private static func recognizeText(_ path: String) throws -> String {
        var image = try load(path)
        let e = image.extent
        if max(e.width, e.height) > 3000 { image = fit(image, maxSide: 3000) }  // speed
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        if #available(macOS 13.0, *) { request.automaticallyDetectsLanguage = true }
        try handler.perform([request])
        let lines = (request.results ?? [])
            .filter { $0.confidence >= 0.5 }
            .sorted { a, b in
                // Vision's origin is bottom-left: higher maxY = nearer the top.
                abs(a.boundingBox.midY - b.boundingBox.midY) > 0.01
                    ? a.boundingBox.midY > b.boundingBox.midY
                    : a.boundingBox.minX < b.boundingBox.minX
            }
            .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.joined(separator: "\n")
    }

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

    /// Number of separate foreground subjects Vision finds (0 before macOS 14).
    private static func instanceCount(_ path: String) throws -> Int {
        guard #available(macOS 14.0, *) else { return 0 }
        let handler = VNImageRequestHandler(ciImage: try load(path), options: [:])
        let request = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([request])
        return request.results?.first?.allInstances.count ?? 0
    }

    private static func render(
        input: String, output: String, maxSide: Int, passes: Int, wantCutout: Bool,
        mode: String, instance: Int
    ) throws {
        var image = try load(input)
        if mode == "orig" {
            // Untouched look: only shrunk (never enlarged) to fit maxSide x maxSide, no smoothing.
            let small = fitDown(image, maxSide: maxSide)
            guard let cg = ctx.createCGImage(
                small, from: small.extent.integral, format: .RGBA8, colorSpace: srgb)
            else { throw Failure.render("bitmap") }
            try writePNG(cg, to: output)
            return
        }
        switch mode {
        case "crop":
            image = try smartCrop(image)
        case "cropcut":
            image = try smartCrop(image)
            if wantCutout { image = try cutout(image) }
        case "face":
            image = try faceCrop(image, instance: instance)
        case "facecut":
            image = try faceCut(image, instance: instance)
        case "mask":
            image = try cutout(image, instance: instance)
        default:  // "bg", "cut"
            if wantCutout { image = try cutout(image) }
        }
        image = smooth(fit(image, maxSide: maxSide), passes: passes)

        let rect = image.extent.integral
        guard let cg = ctx.createCGImage(image, from: rect, format: .RGBA8, colorSpace: srgb)
        else { throw Failure.render("bitmap") }
        try writePNG(cg, to: output)
    }

    private static func writePNG(_ cg: CGImage, to output: String) throws {
        guard let dest = CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: output) as CFURL, "public.png" as CFString, 1, nil)
        else { throw Failure.render("png destination") }
        CGImageDestinationAddImage(dest, cg, nil)
        guard CGImageDestinationFinalize(dest) else { throw Failure.render("png write") }
    }
}
