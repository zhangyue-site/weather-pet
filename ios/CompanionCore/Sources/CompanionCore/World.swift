import Foundation

public struct JournalEntry: Codable, Equatable, Sendable, Identifiable {
    public var text: String
    /// `MM-DD HH:MM`, local time.
    public var time: String
    public var id: String { time + text }

    public init(text: String, time: String) {
        self.text = text
        self.time = time
    }
}

/// Small deterministic generator so tests can seed behaviour (SplitMix64).
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64 = UInt64.random(in: 0...UInt64.max)) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    public mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    public mutating func range(_ low: Double, _ high: Double) -> Double { low + (high - low) * unit() }
    public mutating func int(_ low: Int, _ high: Int) -> Int { Int.random(in: low...high, using: &self) }
}

/// One simulation clock for 阿晴, driven only by the scene. Port of `companion/world.gd`.
public final class CompanionWorld {
    public struct Step: Equatable, Sendable {
        public var name: String
        public var duration: Double
    }

    public var environment = Catalog.preset("clear")
    public private(set) var activity = "idle"
    public var activityTime = 0.0
    public var activityDuration = 5.0
    public var queue: [Step] = []
    public var wetness = 0.0
    public var energy = 78.0
    public var joy = 75.0
    public var bond = 0
    public var x = 0.57
    public var targetX = 0.57
    public var direction = 1.0
    public private(set) var totalTime = 0.0
    public var thunderIn = 5.0
    public var lightning = 0.0
    public var journal: [JournalEntry] = []
    public var discovered: [String] = []
    public var careCooldown = 0.0
    public var puddle = 0.0
    public var rng: SeededRandom
    public var status = "在小院里等你"
    public var lastDay = ""
    public private(set) var festival: DayProgram?
    public var festivalCooldown = 0.0
    public var festivalIndex = 0
    /// Injected clock for journal timestamps and the daily greeting.
    public var now: () -> Date

    static let statusText = ["idle": "发会儿呆，也很好", "blink": "眯起眼睛笑了", "wave": "看到你就开心", "stretch": "伸个懒腰，慢慢来", "notice": "咦，好像下雨了", "take_umbrella": "把小伞拿出来", "open_umbrella": "撑开伞，别淋湿啦", "umbrella": "伞下的小小世界", "shake": "雨停啦，甩掉水珠", "cold": "围巾裹紧一点", "hot": "扇扇风，慢一点", "wind": "呼——抓紧衣角", "snow": "雪花落在手心里", "scared": "刚才的雷有点响", "drink": "捧着杯子暖暖手", "sleep": "呼吸慢下来，睡一会儿", "walk": "在小院里散散步", "pet": "喜欢你轻轻摸我的头", "water": "看看小植物长大了没有"]
    static let careNotes = ["pet": "被你轻轻摸了摸头", "wave": "和你打了个招呼", "drink": "一起喝了一杯热饮", "sleep": "你陪我安静休息", "water": "一起看了看小植物"]

    public init(seed: UInt64? = nil, now: @escaping () -> Date = Date.init) {
        rng = seed.map { SeededRandom(seed: $0) } ?? SeededRandom()
        self.now = now
    }

    public func setFestival(_ event: DayProgram?) {
        if (event?.id ?? "") == (festival?.id ?? "") {
            festival = event
            return
        }
        festival = event
        festivalCooldown = 0
        festivalIndex = 0
        if activity.hasPrefix("celebrate_") {
            queue.removeAll()
            chooseActivity()
        }
        if let f = festival { addNote(f.title + (f.kind == "daily" ? "，又是一起的一天" : "，今天一起记住")) }
    }

    @discardableResult
    public func celebrate() -> Bool {
        guard let festival, !festival.actions.isEmpty else { return false }
        let id = environment.id
        if Catalog.isRain(id) || !environment.isDay || energy < 18 || environment.feels < 0 || environment.feels > 32 || ["windy", "snow", "heavy_snow"].contains(id) { return false }
        var action = festival.actions[festivalIndex % festival.actions.count]
        if festival.tone == "solemn" { action = "idle" }
        if action == "walk" {
            targetX = rng.range(0.38, 0.70)
            direction = sign(targetX - x)
        }
        start(action, 6)
        festivalIndex += 1
        festivalCooldown = 40
        return true
    }

    public func addNote(_ note: String) {
        if journal.first?.text == note { return }
        journal.insert(JournalEntry(text: note, time: Self.stamp(now())), at: 0)
        if journal.count > 30 { journal.removeLast(journal.count - 30) }
    }

    static func stamp(_ date: Date) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.month, .day, .hour, .minute], from: date)
        return String(format: "%02d-%02d %02d:%02d", c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
    }

    public func setEnvironment(_ e: WeatherEnvironment) {
        let old = environment.id
        environment = e
        let id = e.id
        if !discovered.contains(id) {
            discovered.append(id)
            addNote("一起遇见了" + Catalog.title(id))
        }
        if old == id { return }
        queue.removeAll()
        if Catalog.isRain(id) && !Catalog.isRain(old) {
            sequence([("notice", 1.8), ("take_umbrella", 1.2), ("open_umbrella", 0.8), ("umbrella", 8.0)])
        } else if Catalog.isRain(old) && !Catalog.isRain(id) {
            sequence([("umbrella", 1.1), ("open_umbrella", 0.7), ("shake", 2.5)])
            addNote("雨停了，甩甩伞上的水")
        } else {
            chooseActivity()
        }
    }

    public func sequence(_ steps: [(String, Double)]) {
        queue = steps.map { Step(name: $0.0, duration: $0.1) }
        nextAction()
    }

    public func start(_ name: String, _ duration: Double) {
        activity = name
        activityTime = 0
        activityDuration = duration
        status = Self.statusText[name] ?? "和你待在一起"
        if name.hasPrefix("celebrate_") { status = festival?.title ?? "一起庆祝" }
    }

    public func nextAction() {
        if queue.isEmpty {
            chooseActivity()
        } else {
            let s = queue.removeFirst()
            start(s.name, s.duration)
        }
    }

    public func chooseActivity() {
        let id = environment.id
        if Catalog.isRain(id) {
            start("umbrella", rng.range(7, 12))
        } else if id == "cold" || environment.feels < 0 {
            start("cold", 8)
        } else if Catalog.isSnow(id) {
            start(rng.unit() > 0.4 ? "snow" : "cold", 7)
        } else if id == "hot" || environment.feels > 32 {
            start(rng.unit() > 0.3 ? "hot" : "drink", 8)
        } else if id == "windy" {
            start("wind", 8)
        } else if !environment.isDay || energy < 18 {
            start("sleep", 12)
        } else if festivalCooldown <= 0 && celebrate() {
            // celebrating
        } else {
            let options = ["idle", "idle", "stretch", "walk", "water", "drink"]
            let a = options[rng.int(0, options.count - 1)]
            if a == "walk" {
                targetX = rng.range(0.38, 0.70)
                direction = sign(targetX - x)
            }
            start(a, rng.range(5, 9))
        }
    }

    @discardableResult
    public func interact(_ kind: String) -> Bool {
        if careCooldown > 0 { return false }
        careCooldown = 4
        bond += 1
        joy = min(100, joy + 3)
        if Catalog.isRain(environment.id) {
            // Keep hands on the umbrella and preserve unfinished opening sequence.
            status = "握好伞，也想和你打个招呼"
            addNote("雨里也有你的陪伴")
            return true
        }
        queue.removeAll()
        if activity == "sleep" && kind == "pet" {
            start("blink", 1.8)
            queue.append(Step(name: "sleep", duration: 10))
        } else {
            start(kind, kind != "sleep" ? 5 : 25)
        }
        if kind == "drink" { energy = min(100, energy + 6) }
        addNote(Self.careNotes[kind] ?? "今天又多了一点陪伴")
        return true
    }

    /// Walk to a point the user tapped on the ground.
    public func walk(to target: Double) {
        targetX = min(max(target, 0.35), 0.72)
        direction = sign(targetX - x)
        queue.removeAll()
        start("walk", 12)
    }

    public func step(_ delta: Double) {
        let dt = min(max(delta, 0), 0.1)
        totalTime += dt
        festivalCooldown = max(0, festivalCooldown - dt)
        activityTime += dt
        careCooldown = max(0, careCooldown - dt)
        lightning = max(0, lightning - dt * 2.5)
        let raining = Catalog.isRain(environment.id)
        let protected = ["umbrella", "open_umbrella"].contains(activity)
        wetness = clamp(wetness + dt * (raining ? (protected ? 0.002 : 0.04) : -0.015), 0, 1)
        puddle = clamp(puddle + dt * (raining ? 0.045 : -0.008), 0, 1)
        energy = clamp(energy + dt * (activity == "sleep" ? 0.30 : -0.015), 0, 100)
        joy = max(45, joy - dt * 0.002)
        if activity == "walk" {
            x = moveToward(x, targetX, dt * 0.022)
            if abs(x - targetX) < 0.003 { start("idle", 4) }
        }
        if activityTime >= activityDuration { nextAction() }
        if environment.id == "thunderstorm" {
            thunderIn -= dt
            if thunderIn <= 0 {
                thunderIn = rng.range(9, 16)
                lightning = 0.65
                status = "有点怕雷，幸好你在"
                // Umbrella remains held during surprise.
            }
        } else {
            thunderIn = 5
        }
    }

    // MARK: Persistence

    public struct Saved: Codable, Equatable, Sendable {
        public var energy: Double
        public var joy: Double
        public var bond: Int
        public var journal: [JournalEntry]
        public var discovered: [String]
        public var day: String

        public init(energy: Double = 78, joy: Double = 75, bond: Int = 0, journal: [JournalEntry] = [], discovered: [String] = [], day: String = "") {
            self.energy = energy
            self.joy = joy
            self.bond = bond
            self.journal = journal
            self.discovered = discovered
            self.day = day
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            energy = (try? c.decode(Double.self, forKey: .energy)) ?? 78
            joy = (try? c.decode(Double.self, forKey: .joy)) ?? 75
            bond = (try? c.decode(Int.self, forKey: .bond)) ?? 0
            journal = (try? c.decode([JournalEntry].self, forKey: .journal)) ?? []
            discovered = (try? c.decode([String].self, forKey: .discovered)) ?? []
            day = (try? c.decode(String.self, forKey: .day)) ?? ""
        }
    }

    public func saveData() -> Saved {
        Saved(energy: energy, joy: joy, bond: bond, journal: journal, discovered: discovered, day: lastDay)
    }

    public func restore(_ d: Saved) {
        energy = clamp(d.energy, 0, 100)
        joy = clamp(d.joy, 0, 100)
        bond = max(0, d.bond)
        journal = Array(d.journal.prefix(30))
        for id in d.discovered where Catalog.ids.contains(id) && !discovered.contains(id) { discovered.append(id) }
        lastDay = d.day
        let today = CivilDate.local(now()).description
        if today != lastDay {
            lastDay = today
            addNote("新的一天，小院里等到你了")
        }
    }
}

@inline(__always) func clamp(_ v: Double, _ low: Double, _ high: Double) -> Double { min(max(v, low), high) }

@inline(__always) func sign(_ v: Double) -> Double { v > 0 ? 1 : (v < 0 ? -1 : 0) }

@inline(__always) func moveToward(_ from: Double, _ to: Double, _ delta: Double) -> Double {
    abs(to - from) <= delta ? to : from + (to > from ? delta : -delta)
}
