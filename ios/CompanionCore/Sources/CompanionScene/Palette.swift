import SwiftUI

/// Colors of the Godot UI (`main.gd` constants).
public enum Palette {
    public static let ink = Color(hex: 0x293E42)
    public static let muted = Color(hex: 0x738181)
    public static let cream = Color(hex: 0xFFFAF0)
    public static let teal = Color(hex: 0x347C7E)
    public static let tealPressed = Color(hex: 0x245E62)
    public static let button = Color(hex: 0xF0EEE6)
    public static let festival = Color(hex: 0xFFE1A1)
    public static let error = Color(hex: 0xAA5143)
    public static let card = Color(red: 1, green: 0.985, blue: 0.945).opacity(0.96)
}

public extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

/// Straight RGBA for Godot-style color math (`lightened`, `darkened`, `lerp`).
struct RGBA {
    var r: Double
    var g: Double
    var b: Double
    var a: Double = 1

    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    init(hex: String) {
        let v = UInt32(hex, radix: 16) ?? 0xFFFFFF
        self.init(Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
    }

    func lightened(_ amount: Double) -> RGBA { RGBA(r + (1 - r) * amount, g + (1 - g) * amount, b + (1 - b) * amount, a) }
    func darkened(_ amount: Double) -> RGBA { RGBA(r * (1 - amount), g * (1 - amount), b * (1 - amount), a) }
    func lerp(_ to: RGBA, _ t: Double) -> RGBA { RGBA(r + (to.r - r) * t, g + (to.g - g) * t, b + (to.b - b) * t, a + (to.a - a) * t) }
    func alpha(_ value: Double) -> RGBA { RGBA(r, g, b, value) }
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }

    static let white = RGBA(1, 1, 1)
}
