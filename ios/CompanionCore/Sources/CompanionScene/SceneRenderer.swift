import CompanionCore
import SwiftUI

/// Draws one frame of the yard in Godot's logical space (540 units wide). Ports the `_draw`
/// methods of `main.gd` (background), `actor.gd`, `effects.gd` and `calendar_effects.gd`.
@MainActor
public struct SceneRenderer {
    public struct Options: Sendable {
        /// Fraction of weather particles to draw (the Watch draws fewer).
        public var particles: Double = 1
        /// Static, dimmed frame for the Watch's always-on display.
        public var lowPower = false
        /// Character size relative to the phone layout.
        public var bodyScale: Double = 1
        /// Thicker rain and snow where the logical space is scaled far down.
        public var lineScale: Double = 1

        public init(particles: Double = 1, lowPower: Bool = false, bodyScale: Double = 1, lineScale: Double = 1) {
            self.particles = particles
            self.lowPower = lowPower
            self.bodyScale = bodyScale
            self.lineScale = lineScale
        }
    }

    /// Source size of the background paintings.
    static let backgroundSize = CGSize(width: 941, height: 1672)

    let model: CompanionModel
    let options: Options

    public init(model: CompanionModel, options: Options = Options()) {
        self.model = model
        self.options = options
    }

    var world: CompanionWorld { model.world }
    var scene: SceneState { model.scene }
    var layout: SceneLayout { model.scene.layout }

    public func draw(in ctx: inout GraphicsContext) {
        drawBackground(&ctx)
        drawActor(&ctx)
        if !model.reducedMotion && !options.lowPower { drawWeather(&ctx) }
        drawCalendarEffects(&ctx)
    }

    // MARK: Background (main.gd::_draw)

    func backgroundRect() -> CGRect {
        let size = layout.size
        let factor = max(size.width / Self.backgroundSize.width, size.height / Self.backgroundSize.height)
        let scaled = CGSize(width: Self.backgroundSize.width * factor, height: Self.backgroundSize.height * factor)
        return CGRect(x: (size.width - scaled.width) / 2, y: (size.height - scaled.height) / 2, width: scaled.width, height: scaled.height)
    }

    func drawBackground(_ ctx: inout GraphicsContext) {
        let e = world.environment
        var tint = RGBA.white
        if e.id == "cloudy" { tint = RGBA(0.88, 0.93, 0.98) }
        if e.id == "dawn" { tint = RGBA(1, 0.91, 0.86) }
        if e.id == "dusk" { tint = RGBA(1, 0.77, 0.59) }
        if model.mode == .live && e.phase == "dawn" { tint = RGBA(1, 0.91, 0.86) }
        if model.mode == .live && e.phase == "dusk" { tint = RGBA(1, 0.77, 0.59) }
        if e.id == "hot" { tint = RGBA(1, 0.96, 0.82) }
        if !e.isDay && scene.backgroundNow != "night" { tint = RGBA(0.43, 0.50, 0.67) }
        let rect = backgroundRect()
        func paint(_ id: String, opacity: Double, tint: RGBA) {
            guard opacity > 0.001 else { return }
            var g = ctx
            g.opacity = opacity
            if tint.r < 1 || tint.g < 1 || tint.b < 1 { g.addFilter(.colorMultiply(tint.color)) }
            g.draw(Image("bg_" + id), in: rect)
        }
        if scene.backgroundMix < 1 { paint(scene.backgroundBefore, opacity: 1, tint: tint) }
        paint(scene.backgroundNow, opacity: scene.backgroundMix, tint: tint)
        // A little dampness lingers after rain rather than disappearing with the weather code.
        if scene.backgroundNow == "day" && world.puddle > 0.01 {
            paint("rain", opacity: world.puddle * 0.14, tint: .white)
        }
        // Readable quiet sky behind the HUD: Godot's 24 stepped bands as one smooth ramp.
        let shade = RGBA(0.05, 0.13, 0.20)
        ctx.fill(Path(CGRect(x: 0, y: 0, width: layout.size.width, height: 288)),
                 with: .linearGradient(Gradient(colors: [shade.alpha(0.25).color, shade.alpha(0).color]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: 288)))
        let r = layout.bodyHeight * 0.25
        ctx.fill(Path(ellipseIn: CGRect(x: layout.foot.x - r, y: layout.foot.y + 2 - r * 0.24, width: r * 2, height: r * 0.48)),
                 with: .color(RGBA(0.08, 0.12, 0.13, 0.20).color))
    }

    // MARK: Actor (actor.gd::_draw)

    func drawActor(_ ctx: inout GraphicsContext) {
        let pose = ActorPose(world: world)
        guard let frame = SpriteManifest.shared.frame(pose) else { return }
        var anchor = CGPoint(x: frame.ax, y: frame.ay)
        // Keep pelvis centered through stride rather than anchoring to the swinging toe.
        if pose.sheet == "walk" { anchor = CGPoint(x: frame.w * 0.5, y: frame.h) }
        let scale = layout.bodyHeight / pose.normalHeight
        var sx = scale * (1 - pose.breath * 0.3)
        if pose.flipped { sx = -sx }
        var tint = RGBA.white
        let e = world.environment
        if !e.isDay {
            tint = RGBA(0.72, 0.78, 0.92)
        } else if ["rain", "heavy_rain", "thunderstorm", "overcast"].contains(e.id) {
            tint = RGBA(0.88, 0.93, 1)
        }
        if world.wetness > 0.1 { tint = tint.lerp(RGBA(0.68, 0.74, 0.80), world.wetness * 0.22) }
        var g = ctx
        g.translateBy(x: layout.foot.x, y: layout.foot.y + pose.bounce)
        g.rotate(by: .radians(pose.lean))
        g.scaleBy(x: sx, y: scale * (1 + pose.breath))
        if tint.r < 1 || tint.g < 1 || tint.b < 1 { g.addFilter(.colorMultiply(tint.color)) }
        g.draw(Image(pose.imageName), in: CGRect(x: -anchor.x, y: -anchor.y, width: frame.w, height: frame.h))
    }

    // MARK: Weather particles (effects.gd::_draw)

    func drawWeather(_ ctx: inout GraphicsContext) {
        let size = layout.size
        let id = world.environment.id
        let rain = Catalog.isRain(id)
        let snow = Catalog.isSnow(id)
        let t = world.totalTime
        let dots = scene.dots
        let foot = layout.foot
        let bh = layout.bodyHeight
        func count(_ n: Int) -> Int { max(1, Int(Double(n) * options.particles)) }
        if rain || snow {
            let total = count(["heavy_rain", "heavy_snow", "thunderstorm"].contains(id) ? 135 : (id == "drizzle" ? 45 : 80))
            let protected = ["umbrella", "open_umbrella"].contains(world.activity)
            for i in 0..<total {
                let d = dots[i]
                var p = CGPoint(x: d.x * size.width, y: d.y * size.height)
                // Match the character umbrella coverage and the illustrated cottage roof.
                if protected && abs(p.x - foot.x) < bh * 0.44 && p.y > foot.y - bh * 1.12 && p.y < foot.y { continue }
                if p.x < size.width * 0.43 && p.y > size.height * 0.45 && p.y < size.height * 0.68 { continue }
                if rain {
                    var line = Path()
                    line.move(to: p)
                    line.addLine(to: CGPoint(x: p.x - 3 * d.s, y: p.y + 15 * d.s))
                    ctx.stroke(line, with: .color(RGBA(0.80, 0.90, 1, 0.42 * d.s).color), lineWidth: 1.1 * options.lineScale)
                } else {
                    p.x += sin(t + d.phase) * 12
                    let r = (1.4 + 2 * d.s) * options.lineScale
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.8)))
                }
            }
            if rain {
                for i in 0..<count(14) {
                    let d = dots[i]
                    let phase = (t * 1.5 + d.phase).truncatingRemainder(dividingBy: 1)
                    let r = 2 + phase * 10
                    let center = CGPoint(x: d.x * size.width, y: size.height * (0.70 + 0.18 * d.s))
                    var g = ctx
                    g.translateBy(x: center.x, y: center.y)
                    g.scaleBy(x: 1, y: 0.3)
                    g.stroke(Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)), with: .color(RGBA(0.8, 0.9, 1, (1 - phase) * 0.35).color), lineWidth: options.lineScale)
                }
            }
        }
        if id == "windy" {
            for i in 0..<count(24) {
                let d = dots[i]
                var g = ctx
                g.translateBy(x: d.x * size.width, y: (0.2 + d.y * 0.65) * size.height)
                g.rotate(by: .radians(sin(t + d.phase) * 0.8))
                g.scaleBy(x: 1, y: 0.35)
                let r = 4 * d.s
                g.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)), with: .color(RGBA(0.63, 0.69, 0.32, 0.75).color))
            }
        }
        if id == "fog" {
            for i in 0..<7 {
                let y = size.height * (0.30 + Double(i) * 0.10) + sin(t * 0.15 + Double(i)) * 18
                let x = size.width * 0.5 + sin(t * 0.10 + Double(i)) * 60
                let rx = 80 * size.width / 80
                let ry = 80 * 0.6
                ctx.fill(Path(ellipseIn: CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2)), with: .color(RGBA(0.85, 0.9, 0.92, 0.075).color))
            }
        }
        if !world.environment.isDay && !rain && !snow {
            for i in 0..<count(18) {
                let d = dots[i]
                let p = CGPoint(x: d.x * size.width, y: (0.60 + d.y * 0.20) * size.height)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)), with: .color(RGBA(1, 0.88, 0.42, 0.4 + sin(t * 1.3 + d.phase) * 0.3).color))
            }
        }
        if ["cold", "drink", "sleep"].contains(world.activity) {
            for i in 0..<4 {
                let phase = (t * 0.5 + Double(i) * 0.23).truncatingRemainder(dividingBy: 1)
                let p = CGPoint(x: foot.x + sin(t + Double(i)) * 5, y: foot.y - bh * 0.65 - phase * 30)
                let r = 2 + phase * 4
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity((1 - phase) * 0.22)))
            }
        }
        if world.wetness > 0.2 && !rain {
            for i in 0..<5 {
                let phase = (t * 0.7 + Double(i) * 0.2).truncatingRemainder(dividingBy: 1)
                let p = CGPoint(x: foot.x + Double(i - 2) * 12, y: foot.y - bh * 0.5 + phase * bh * 0.5)
                var line = Path()
                line.move(to: p)
                line.addLine(to: CGPoint(x: p.x, y: p.y + 3))
                ctx.stroke(line, with: .color(RGBA(0.7, 0.85, 1, world.wetness * 0.5).color), lineWidth: 1)
            }
        }
        for h in scene.hearts {
            let p = CGPoint(x: h.x + sin(t * 2 + h.phase) * 5, y: h.y)
            let c = GraphicsContext.Shading.color(RGBA(1, 0.59, 0.48, (1 - h.life / 2.8) * 0.9).color)
            var heart = Path(ellipseIn: CGRect(x: p.x - 7, y: p.y - 6, width: 8, height: 8))
            heart.addEllipse(in: CGRect(x: p.x - 1, y: p.y - 6, width: 8, height: 8))
            heart.move(to: CGPoint(x: p.x - 6, y: p.y))
            heart.addLine(to: CGPoint(x: p.x + 6, y: p.y))
            heart.addLine(to: CGPoint(x: p.x, y: p.y + 8))
            heart.closeSubpath()
            ctx.fill(heart, with: c)
        }
        if world.lightning > 0 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(RGBA(0.84, 0.91, 1, world.lightning * 0.55).color))
        }
    }

    // MARK: Calendar effects (calendar_effects.gd)

    func drawCalendarEffects(_ ctx: inout GraphicsContext) {
        for (layer, recipe) in model.activeEffects.enumerated() {
            drawRecipe(recipe, layer: layer, ctx: &ctx)
        }
    }

    func drawRecipe(_ recipe: EffectRecipe, layer: Int, ctx: inout GraphicsContext) {
        let screen = layout.size
        let center = CGPoint(x: layout.foot.x, y: layout.foot.y - layout.bodyHeight * 0.65)
        let still = model.reducedMotion || options.lowPower
        let t = still ? 0.8 : world.totalTime * recipe.speed
        var count = still ? 5 : recipe.count
        let raining = Catalog.isRain(world.environment.id)
        if raining { count = max(4, count / 2) }
        let quiet = world.festival?.tone == "solemn" || !world.environment.isDay
        if quiet { count = min(count, 8) }
        let unit = min(screen.width / 540, screen.height / 960)
        let colors = recipe.colors.map(RGBA.init(hex:))
        for i in 0..<count {
            let fi = Double(i)
            let seed = (fi * 0.6180339887 + Double(layer) * 0.17).truncatingRemainder(dividingBy: 1)
            let phase = (t * 0.13 + fi / Double(count)).truncatingRemainder(dividingBy: 1)
            let a = 2 * Double.pi * fi / Double(count)
            var p = CGPoint.zero
            var opacity = 0.8
            var rotation = sin(t + fi) * 0.3
            switch recipe.motion {
            case "drift":
                p = CGPoint(x: (0.08 + seed * 0.84) * screen.width + sin(t + fi) * 18, y: screen.height * (0.28 + phase * 0.47))
                opacity *= sin(phase * .pi)
            case "rise":
                p = CGPoint(x: (0.08 + seed * 0.84) * screen.width + sin(t + fi) * 12, y: screen.height * (0.78 - phase * 0.46))
                opacity *= sin(phase * .pi)
            case "orbit":
                p = CGPoint(x: center.x + cos(a + t * 0.4) * 125 * unit, y: center.y + sin(a + t * 0.4) * 90 * unit)
            case "spiral":
                p = CGPoint(x: center.x + cos(a + t) * 140 * phase * unit, y: center.y + (-170 * phase + 70) * unit)
                opacity *= 1 - phase * 0.6
            case "fountain":
                p = CGPoint(x: layout.foot.x + (seed - 0.5) * 310 * phase * unit, y: layout.foot.y + (-310 * phase + 235 * phase * phase) * unit)
                opacity *= 1 - phase
            case "burst":
                p = CGPoint(x: screen.width * (0.28 + Double(layer) * 0.4) + cos(a) * phase * 150 * unit, y: screen.height * 0.40 + sin(a) * phase * 150 * unit)
                opacity *= 1 - phase
            case "wave":
                p = CGPoint(x: screen.width * (0.08 + seed * 0.84), y: screen.height * (0.42 + 0.09 * sin(seed * 2 * .pi + t)))
                rotation = sin(seed * 2 * .pi + t) * 0.6
            case "cascade":
                p = CGPoint(x: screen.width * (0.1 + Double(i % 5) * 0.2), y: screen.height * (0.29 + phase * 0.48))
                opacity *= sin(phase * .pi)
            case "garland":
                let span = Double(max(count - 1, 1))
                p = CGPoint(x: screen.width * (0.07 + fi / span * 0.86), y: screen.height * 0.32 + sin(fi / span * .pi) * 42)
                rotation = sin(t * 0.5 + fi) * 0.15
            case "trail":
                p = CGPoint(x: screen.width * (0.1 + phase * 0.8), y: screen.height * (0.63 - phase * 0.27) + sin(phase * 2 * .pi + t) * 18)
                opacity *= sin(phase * .pi)
            default: break
            }
            // Keep weather legible and the character face clear.
            if raining { opacity *= 0.48 }
            if quiet { opacity *= 0.65 }
            if hypot(p.x - center.x, p.y - center.y) < 40 * unit { opacity *= 0.3 }
            let c = colors[i % max(colors.count, 1)].alpha(max(0, opacity))
            guard c.a > 0.004 else { continue }
            let size = recipe.size * unit * (0.7 + seed * 0.7)
            var g = ctx
            g.translateBy(x: p.x, y: p.y)
            g.rotate(by: .radians(rotation))
            g.scaleBy(x: size, y: size)
            Motif.draw(recipe.family, color: c, t: t + fi, in: &g)
        }
    }
}
