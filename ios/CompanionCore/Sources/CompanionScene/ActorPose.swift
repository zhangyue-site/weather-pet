import CompanionCore
import Foundation

/// Which sprite 阿晴 shows and how it sways. Port of the pose logic in `actor.gd::_draw`.
public struct ActorPose: Equatable, Sendable {
    public var sheet: String
    public var index: Int
    public var normalHeight: Double
    public var lean: Double
    public var bounce: Double
    public var breath: Double
    public var flipped: Bool

    public var imageName: String { "\(sheet)_\(index)" }

    static let weatherPoses = ["take_umbrella", "open_umbrella", "umbrella", "shake", "cold", "hot", "wind", "snow"]
    static let weatherHeights: [Double] = [440, 410, 382, 410, 420, 430, 420, 420]

    public init(world: CompanionWorld) {
        let a = world.activity
        var sheet = "daily"
        var idx = 0
        var normal = 460.0
        switch a {
        case "blink", "pet": idx = 1
        case "wave", "celebrate_wave": idx = 2
        case "celebrate_cheer": idx = 3
        case "celebrate_dance": idx = Int(world.activityTime * 2) % 2 == 0 ? 2 : 3
        case "stretch": idx = 3
        case "notice": idx = 4
        case "scared": idx = 5
        case "drink": idx = 6
        case "sleep": idx = 7
        case _ where Self.weatherPoses.contains(a):
            sheet = "weather"
            idx = Self.weatherPoses.firstIndex(of: a)!
            normal = Self.weatherHeights[idx]
        case "walk":
            sheet = "walk"
            idx = Int(world.activityTime * 5.5) % 4
            if world.direction < 0 { idx += 4 }
        default: idx = 0
        }
        if a == "idle" && world.totalTime.truncatingRemainder(dividingBy: 4.7) < 0.16 { idx = 1 }
        let t = world.totalTime
        breath = sin(t * (a == "sleep" ? 1.5 : 2.6)) * (a == "sleep" ? 0.007 : 0.003)
        lean = 0
        bounce = 0
        if a == "cold" { lean = sin(t * 37) * 0.007 }
        if a == "wind" { lean = sin(t * 2) * 0.018 }
        if ["wave", "pet"].contains(a) { bounce = -abs(sin(world.activityTime * 3)) * 3 }
        if a.hasPrefix("celebrate_") {
            bounce = -abs(sin(world.activityTime * 3.5)) * (a == "celebrate_cheer" ? 9 : 4)
            lean = sin(world.activityTime * 3.5) * (a == "celebrate_dance" ? 0.045 : 0.012)
        }
        if world.lightning > 0 { bounce -= world.lightning * 8 }
        // The generated right-walk row faces left; orient it at draw time.
        flipped = a == "walk" && world.direction > 0
        self.sheet = sheet
        self.index = idx
        self.normalHeight = normal
    }
}

/// Frame sizes and foot anchors of the sprites, in source pixels (`sprites.json`).
public struct SpriteManifest: Sendable {
    public struct Frame: Decodable, Sendable {
        public let w: Double
        public let h: Double
        public let ax: Double
        public let ay: Double
    }

    public static let shared = SpriteManifest()
    public let sheets: [String: [Frame]]

    init() {
        let url = Bundle.module.url(forResource: "sprites", withExtension: "json")
        let data = url.flatMap { try? Data(contentsOf: $0) } ?? Data("{}".utf8)
        sheets = (try? JSONDecoder().decode([String: [Frame]].self, from: data)) ?? [:]
    }

    public func frame(_ pose: ActorPose) -> Frame? {
        guard let list = sheets[pose.sheet], pose.index < list.count else { return nil }
        return list[pose.index]
    }
}
