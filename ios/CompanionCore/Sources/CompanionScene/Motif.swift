import SwiftUI

/// The 20 drawn motifs, in a unit space the caller scales (`calendar_effects.gd::_symbol`).
enum Motif {
    static func draw(_ family: String, color c: RGBA, t: Double, in g: inout GraphicsContext) {
        let fill = GraphicsContext.Shading.color(c.color)
        let bright = c.lightened(0.3)
        let dark = c.darkened(0.28)
        func line(_ a: CGPoint, _ b: CGPoint, _ color: RGBA, _ width: Double) {
            var p = Path()
            p.move(to: a)
            p.addLine(to: b)
            g.stroke(p, with: .color(color.color), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
        func circle(_ center: CGPoint, _ r: Double, _ color: RGBA) {
            g.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)), with: .color(color.color))
        }
        func arc(_ center: CGPoint, _ r: Double, _ from: Double, _ to: Double, _ color: RGBA, _ width: Double) {
            var p = Path()
            p.addArc(center: center, radius: r, startAngle: .radians(from), endAngle: .radians(to), clockwise: false)
            g.stroke(p, with: .color(color.color), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
        func polygon(_ points: [CGPoint], _ color: RGBA) {
            var p = Path()
            p.addLines(points)
            p.closeSubpath()
            g.fill(p, with: .color(color.color))
        }
        func polyline(_ points: [CGPoint], _ color: RGBA, _ width: Double) {
            var p = Path()
            p.addLines(points)
            g.stroke(p, with: .color(color.color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
        func ellipse(_ center: CGPoint, _ rx: Double, _ ry: Double, _ angle: Double, _ color: RGBA) {
            let points = (0..<24).map { i -> CGPoint in
                let a = 2 * Double.pi * Double(i) / 24
                let x = cos(a) * rx, y = sin(a) * ry
                return CGPoint(x: center.x + x * cos(angle) - y * sin(angle), y: center.y + x * sin(angle) + y * cos(angle))
            }
            polygon(points, color)
        }
        func fromAngle(_ a: Double) -> CGPoint { CGPoint(x: cos(a), y: sin(a)) }
        func scaled(_ v: CGPoint, _ k: Double) -> CGPoint { CGPoint(x: v.x * k, y: v.y * k) }

        switch family {
        case "lantern":
            ellipse(.zero, 1.25, 1.5, 0, c)
            arc(.zero, 0.9, -Double.pi / 2, Double.pi / 2, bright, 0.14)
            line(CGPoint(x: -0.6, y: -1.4), CGPoint(x: 0.6, y: -1.4), dark, 0.25)
            line(CGPoint(x: 0, y: 1.4), CGPoint(x: 0, y: 2.2), bright, 0.17)
        case "firework":
            for j in 0..<10 {
                let v = fromAngle(2 * .pi * Double(j) / 10)
                line(scaled(v, 0.6), scaled(v, 2.0), c, 0.18)
                circle(scaled(v, 2.3), 0.15, bright)
            }
        case "confetti":
            g.fill(Path(CGRect(x: -0.55, y: -1.3, width: 1.1, height: 2.6)), with: fill)
            line(CGPoint(x: -0.5, y: -0.6), CGPoint(x: 0.5, y: 0.1), bright, 0.16)
        case "ribbon":
            polyline((0..<14).map { j in CGPoint(x: Double(j) * 0.35 - 2.2, y: sin(Double(j) * 0.6 + t) * 0.6) }, c, 0.4)
        case "blossom":
            for j in 0..<5 {
                let a = 2 * Double.pi * Double(j) / 5
                ellipse(scaled(fromAngle(a), 0.85), 0.8, 0.45, a, c)
            }
            circle(.zero, 0.3, bright)
        case "leaf":
            ellipse(.zero, 0.65, 1.6, 0.4, c)
            line(CGPoint(x: 0.6, y: -1.4), CGPoint(x: -0.6, y: 1.4), dark, 0.12)
        case "snowflake":
            for j in 0..<6 {
                let v = fromAngle(2 * .pi * Double(j) / 6)
                line(.zero, scaled(v, 1.8), c, 0.15)
                for side in [-1.0, 1.0] {
                    let r = CGPoint(x: -v.y * side, y: v.x * side) // v rotated by side * 90 degrees
                    line(scaled(v, 1.1), CGPoint(x: v.x * 1.3 + r.x * 0.4, y: v.y * 1.3 + r.y * 0.4), c, 0.12)
                }
            }
        case "star":
            polygon((0..<10).map { i in scaled(fromAngle(-Double.pi / 2 + Double(i) * .pi / 5), i % 2 == 0 ? 1.65 : 1.65 * 0.42) }, c)
        case "heart":
            circle(CGPoint(x: -0.55, y: -0.35), 0.72, c)
            circle(CGPoint(x: 0.55, y: -0.35), 0.72, c)
            polygon([CGPoint(x: -1.16, y: 0), CGPoint(x: 1.16, y: 0), CGPoint(x: 0, y: 1.4)], c)
        case "butterfly":
            let wing = 0.45 + abs(sin(t * 3)) * 0.7
            ellipse(CGPoint(x: -0.7, y: 0), wing, 1.25, -0.3, c)
            ellipse(CGPoint(x: 0.7, y: 0), wing, 1.25, 0.3, c)
            line(CGPoint(x: 0, y: -0.7), CGPoint(x: 0, y: 0.8), dark, 0.18)
        case "bubble":
            arc(.zero, 1.5, 0, 2 * .pi, c, 0.16)
            arc(CGPoint(x: -0.12, y: -0.12), 1.05, .pi, .pi * 1.5, bright, 0.25)
        case "firefly":
            circle(.zero, 1.6, c.alpha(c.a * 0.14))
            circle(.zero, 0.8, c.alpha(c.a * 0.3))
            circle(.zero, 0.32, bright)
        case "raindrop":
            polygon([CGPoint(x: 0, y: -1.6), CGPoint(x: 0.7, y: 0.15), CGPoint(x: -0.7, y: 0.15)], c)
            circle(CGPoint(x: 0, y: 0.3), 0.7, c)
            circle(CGPoint(x: -0.2, y: 0.2), 0.16, bright)
        case "cloud":
            ellipse(CGPoint(x: 0, y: 0.4), 2.0, 0.6, 0, c)
            circle(CGPoint(x: -0.8, y: 0), 0.7, c)
            circle(CGPoint(x: 0.2, y: -0.3), 1.0, c)
            circle(CGPoint(x: 1.1, y: 0.1), 0.65, c)
        case "sun":
            circle(.zero, 0.85, c)
            for j in 0..<8 {
                let v = fromAngle(2 * .pi * Double(j) / 8 + t * 0.15)
                line(scaled(v, 1.15), scaled(v, 1.65), c, 0.17)
            }
        case "moon":
            // Crescent assembled as a non-self-intersecting outline.
            var points: [CGPoint] = []
            for j in 0..<25 {
                let a = Double.pi / 2 + Double.pi * Double(j) / 24
                points.append(CGPoint(x: cos(a) * 1.5, y: sin(a) * 1.5))
            }
            for j in 0..<25 {
                let a = -Double.pi / 2 - Double.pi * Double(j) / 24
                points.append(CGPoint(x: cos(a) * 0.65, y: sin(a) * 1.5))
            }
            polygon(points, c)
        case "kite":
            polygon([CGPoint(x: 0, y: -1.5), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1.5), CGPoint(x: -1, y: 0)], c)
            line(CGPoint(x: 0, y: -1.4), CGPoint(x: 0, y: 1.4), bright, 0.12)
            polyline([CGPoint(x: 0, y: 1.5), CGPoint(x: 0.5, y: 2.2), CGPoint(x: 0.1, y: 3)], c, 0.1)
        case "music":
            ellipse(CGPoint(x: -0.3, y: 0.7), 0.55, 0.35, -0.4, c)
            line(CGPoint(x: 0.2, y: 0.65), CGPoint(x: 0.2, y: -1.5), c, 0.18)
            line(CGPoint(x: 0.2, y: -1.5), CGPoint(x: 1.1, y: -1.0), c, 0.3)
        case "lotus":
            for j in 0..<5 { ellipse(CGPoint(x: Double(j - 2) * 0.4, y: 0), 0.4, 1.25, Double(j - 2) * 0.35, c) }
            ellipse(CGPoint(x: 0, y: 0.7), 1.8, 0.3, 0, dark)
        case "candle":
            g.fill(Path(CGRect(x: -0.45, y: -0.25, width: 0.9, height: 1.65)), with: fill)
            ellipse(CGPoint(x: 0, y: -0.95), 0.4, 0.7, 0, bright)
            line(CGPoint(x: -0.7, y: 1.4), CGPoint(x: 0.7, y: 1.4), dark, 0.2)
        default:
            break
        }
    }
}
