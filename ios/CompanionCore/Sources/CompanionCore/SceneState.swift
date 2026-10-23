import CoreGraphics
import Foundation

/// Where things sit in the scene, in Godot's logical space: 540 units wide, height follows the screen.
public struct SceneLayout: Equatable, Sendable {
    public static let logicalWidth: Double = 540

    public var size: CGSize
    public var foot: CGPoint
    public var bodyHeight: Double

    /// - Parameter bodyScale: enlarges 阿晴 on small screens (the Watch).
    public init(size: CGSize = CGSize(width: 540, height: 960), worldX: Double = 0.57, groundLimit: Double? = nil, bodyScale: Double = 1) {
        self.size = size
        let ground = min(size.height * 0.80, groundLimit ?? .infinity)
        foot = CGPoint(x: worldX * size.width, y: ground)
        bodyHeight = min(size.height * 0.27, 265) * bodyScale
    }

    /// Touch target of the character (`actor.gd::current_rect`).
    public var actorRect: CGRect {
        CGRect(x: foot.x - bodyHeight * 0.45, y: foot.y - bodyHeight * 1.2, width: bodyHeight * 0.9, height: bodyHeight * 1.2)
    }
}

/// Per-frame visual state that is not behaviour: background crossfade, weather particles, hearts.
/// Ports the stateful parts of `main.gd::_draw` and `effects.gd`.
public final class SceneState {
    public struct Dot: Sendable {
        public var x: Double
        public var y: Double
        public var s: Double
        public var phase: Double
    }

    public struct Heart: Sendable {
        public var x: Double
        public var y: Double
        public var life: Double
        public var phase: Double
    }

    public private(set) var backgroundNow = "day"
    public private(set) var backgroundBefore = "day"
    public private(set) var backgroundMix = 1.0
    public private(set) var dots: [Dot] = []
    public private(set) var hearts: [Heart] = []
    public var layout = SceneLayout()
    var rng = SeededRandom(seed: 23091)

    public init() {
        for _ in 0..<150 {
            dots.append(Dot(x: rng.unit(), y: rng.unit(), s: rng.range(0.3, 1.0), phase: rng.range(0, .pi * 2)))
        }
    }

    public static func background(for env: WeatherEnvironment) -> String {
        let id = env.id
        if Catalog.isRain(id) || ["overcast", "fog"].contains(id) { return "rain" }
        if Catalog.isSnow(id) || id == "cold" { return "snow" }
        if !env.isDay { return "night" }
        return "day"
    }

    public func updateBackground(_ env: WeatherEnvironment) {
        let next = Self.background(for: env)
        if next != backgroundNow {
            backgroundBefore = backgroundNow
            backgroundNow = next
            backgroundMix = 0
        }
    }

    public func affection() {
        for _ in 0..<6 {
            hearts.append(Heart(x: layout.foot.x + rng.range(-45, 45), y: layout.foot.y - layout.bodyHeight * 0.75, life: 0, phase: rng.range(-1, 1)))
        }
    }

    public func update(_ delta: Double, world: CompanionWorld) {
        backgroundMix = min(1, backgroundMix + delta * 0.6)
        updateBackground(world.environment)
        let id = world.environment.id
        let fall = Catalog.isRain(id) ? 0.70 : 0.055
        let drift = id == "windy" ? 0.15 : 0.015
        for i in dots.indices {
            dots[i].y = (dots[i].y + delta * fall * dots[i].s).truncatingRemainder(dividingBy: 1)
            let x = (dots[i].x + delta * drift * dots[i].s).truncatingRemainder(dividingBy: 1)
            dots[i].x = x < 0 ? x + 1 : x
        }
        for i in hearts.indices {
            hearts[i].life += delta
            hearts[i].y -= delta * 25
        }
        hearts.removeAll { $0.life >= 2.8 }
    }
}
