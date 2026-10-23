// Converts the Android/Godot art into native asset catalogs.
//
//   xcrun swift ios/tools/prepare_assets.swift [repo-root]
//
// - Cuts the magenta-keyed sprite sheets into transparent per-frame PNGs, applying the same
//   key and spill suppression as `godot_project/companion/chroma.gdshader`, so no shader is
//   needed at runtime.
// - Re-encodes the 941x1672 backgrounds as JPEG (full size for iPhone, half size for Watch).
// - Writes the app icons and `sprites.json` (frame sizes and foot anchors, in source pixels).
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let art = root.appendingPathComponent("godot_project/companion/art")
let iosAssets = root.appendingPathComponent("ios/App/Assets.xcassets")
let watchAssets = root.appendingPathComponent("ios/Watch/Assets.xcassets")
let manifestURL = root.appendingPathComponent("ios/CompanionCore/Sources/CompanionScene/Resources/sprites.json")
let fm = FileManager.default

func load(_ name: String) -> CGImage {
    let url = art.appendingPathComponent(name)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("cannot read \(url.path)") }
    return image
}

func write(_ image: CGImage, to url: URL, type: UTType, quality: Double? = nil) {
    try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else { fatalError("cannot write \(url.path)") }
    var props: [CFString: Any] = [:]
    if let quality { props[kCGImageDestinationLossyCompressionQuality] = quality }
    CGImageDestinationAddImage(dest, image, props as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { fatalError("cannot finalize \(url.path)") }
}

func context(_ w: Int, _ h: Int, alpha: Bool) -> CGContext {
    CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
              space: CGColorSpace(name: CGColorSpace.sRGB)!,
              bitmapInfo: alpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue)!
}

func resized(_ image: CGImage, scale: Double, alpha: Bool) -> CGImage {
    if scale == 1 { return image }
    let w = max(1, Int((Double(image.width) * scale).rounded()))
    let h = max(1, Int((Double(image.height) * scale).rounded()))
    let ctx = context(w, h, alpha: alpha)
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    return ctx.makeImage()!
}

/// Crop + chroma key, identical math to chroma.gdshader.
func keyed(_ sheet: CGImage, rect: [Int]) -> CGImage {
    let (x, y, w, h) = (rect[0], rect[1], rect[2], rect[3])
    let ctx = context(w, h, alpha: true)
    // CG origin is bottom-left; place the sheet so the requested top-left region lands in the context.
    ctx.draw(sheet, in: CGRect(x: -x, y: h + y - sheet.height, width: sheet.width, height: sheet.height))
    let pixels = ctx.data!.bindMemory(to: UInt8.self, capacity: w * h * 4)
    func smoothstep(_ e0: Double, _ e1: Double, _ v: Double) -> Double {
        let t = min(max((v - e0) / (e1 - e0), 0), 1)
        return t * t * (3 - 2 * t)
    }
    for i in 0..<(w * h) {
        let p = i * 4
        var r = Double(pixels[p]) / 255, g = Double(pixels[p + 1]) / 255, b = Double(pixels[p + 2]) / 255
        let magenta = min(r, b) - g
        let a = 1 - smoothstep(0.18, 0.60, magenta)
        // Suppress key-color spill on antialiased edge pixels.
        if magenta > 0.12 {
            r = min(r, g + 0.12)
            b = min(b, g + 0.12)
        }
        pixels[p] = UInt8((r * a * 255).rounded())
        pixels[p + 1] = UInt8((g * a * 255).rounded())
        pixels[p + 2] = UInt8((b * a * 255).rounded())
        pixels[p + 3] = UInt8((a * 255).rounded())
    }
    return ctx.makeImage()!
}

func imageset(_ catalog: URL, folder: String, name: String, file: String, image: CGImage, type: UTType, quality: Double? = nil, extra: String = "") {
    let dir = catalog.appendingPathComponent(folder).appendingPathComponent("\(name).imageset")
    try? fm.removeItem(at: dir)
    write(image, to: dir.appendingPathComponent(file), type: type, quality: quality)
    let json = """
    {
      "images" : [
        {
          "filename" : "\(file)",
          "idiom" : "universal"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }\(extra)
    }

    """
    try! json.write(to: dir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}

func folder(_ catalog: URL, _ name: String) {
    let dir = catalog.appendingPathComponent(name)
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    try! "{\n  \"info\" : {\n    \"author\" : \"xcode\",\n    \"version\" : 1\n  }\n}\n".write(to: dir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}

func catalogRoot(_ catalog: URL) {
    try? fm.createDirectory(at: catalog, withIntermediateDirectories: true)
    try! "{\n  \"info\" : {\n    \"author\" : \"xcode\",\n    \"version\" : 1\n  }\n}\n".write(to: catalog.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}

func appIcon(_ catalog: URL, platform: String) {
    let dir = catalog.appendingPathComponent("AppIcon.appiconset")
    try? fm.removeItem(at: dir)
    let icon = resized(load("icon.png"), scale: 1024.0 / Double(load("icon.png").width), alpha: false)
    write(icon, to: dir.appendingPathComponent("icon-1024.png"), type: .png)
    let json = """
    {
      "images" : [
        {
          "filename" : "icon-1024.png",
          "idiom" : "universal",
          "platform" : "\(platform)",
          "size" : "1024x1024"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }

    """
    try! json.write(to: dir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}

func accentColor(_ catalog: URL) {
    let dir = catalog.appendingPathComponent("AccentColor.colorset")
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    let json = """
    {
      "colors" : [
        {
          "color" : {
            "color-space" : "srgb",
            "components" : { "alpha" : "1.000", "blue" : "0x7E", "green" : "0x7C", "red" : "0x34" }
          },
          "idiom" : "universal"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }

    """
    try! json.write(to: dir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}

// MARK: Sprites

let atlas = try! JSONSerialization.jsonObject(with: Data(contentsOf: art.appendingPathComponent("atlas.json"))) as! [String: [[String: Any]]]
var frames = atlas.mapValues { list in list.map { ($0["rect"] as! [NSNumber]).map(\.intValue) } }
var anchors = atlas.mapValues { list in list.map { ($0["anchor"] as! [NSNumber]).map(\.doubleValue) } }
// Atlas cell boundaries are not exact in generated source sheets; use verified regions (actor.gd).
frames["daily"]![6] = [838, 513, 174, 453]; anchors["daily"]![6] = [91, 453]
frames["daily"]![7] = [1138, 635, 270, 335]; anchors["daily"]![7] = [141, 335]
frames["weather"]![1] = [417, 50, 287, 446]; anchors["weather"]![1] = [179, 446]
frames["weather"]![2] = [763, 29, 325, 467]; anchors["weather"]![2] = [193, 467]

for catalog in [iosAssets, watchAssets] {
    catalogRoot(catalog)
    folder(catalog, "Sprites")
    folder(catalog, "Backgrounds")
    accentColor(catalog)
}
appIcon(iosAssets, platform: "ios")
appIcon(watchAssets, platform: "watchos")

var manifest: [String: [[String: Double]]] = [:]
for sheet in ["daily", "weather", "walk"] {
    let image = load("\(sheet).png")
    manifest[sheet] = []
    for (i, rect) in frames[sheet]!.enumerated() {
        let frame = keyed(image, rect: rect)
        let name = "\(sheet)_\(i)"
        imageset(iosAssets, folder: "Sprites", name: name, file: "\(name).png", image: frame, type: .png)
        imageset(watchAssets, folder: "Sprites", name: name, file: "\(name).png", image: resized(frame, scale: 0.5, alpha: true), type: .png)
        manifest[sheet]!.append(["w": Double(rect[2]), "h": Double(rect[3]), "ax": anchors[sheet]![i][0], "ay": anchors[sheet]![i][1]])
    }
}
let manifestData = try! JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys, .prettyPrinted])
try! manifestData.write(to: manifestURL)

// MARK: Backgrounds

for id in ["day", "rain", "snow", "night"] {
    let image = load("\(id).png")
    imageset(iosAssets, folder: "Backgrounds", name: "bg_\(id)", file: "bg_\(id).jpg", image: image, type: .jpeg, quality: 0.84)
    imageset(watchAssets, folder: "Backgrounds", name: "bg_\(id)", file: "bg_\(id).jpg", image: resized(image, scale: 0.5, alpha: false), type: .jpeg, quality: 0.8)
}

// Launch screen and in-app portrait.
imageset(iosAssets, folder: "", name: "Portrait", file: "portrait.jpg", image: resized(load("icon.png"), scale: 0.5, alpha: false), type: .jpeg, quality: 0.85)

print("assets written: \(iosAssets.path), \(watchAssets.path), \(manifestURL.path)")
