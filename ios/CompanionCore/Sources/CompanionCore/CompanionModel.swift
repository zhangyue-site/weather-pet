import CoreGraphics
import Foundation
import Observation

/// Everything the HUD shows, recomputed a few times per second (`main.gd::_refresh_labels`).
public struct HUD: Equatable, Sendable {
    public var temperature: String
    public var details: String
    public var clock: String
    public var source: String
    public var festival: String
    public var calendar: String
    public var status: String
    public var caption: String
    public var bond: String
}

/// The app controller shared by iPhone and Apple Watch. Port of `companion/main.gd` without the
/// Godot UI nodes: SwiftUI views read this model and call its actions.
@MainActor
@Observable
public final class CompanionModel {
    public enum Mode: String, Sendable { case live, demo }

    public enum Sheet: String, Identifiable, Sendable {
        case weather, care, festivals, settings
        public var id: String { rawValue }
    }

    public enum AnniversaryCalendar: Int, CaseIterable, Identifiable, Sendable {
        case solarYearly, lunarYearly, solarDate, lunarLeap
        public var id: Int { rawValue }
        public var title: String {
            ["公历 · 每年重复", "农历 · 每年（非闰月）", "公历 · 指定日期", "农历 · 只在闰月"][rawValue]
        }
    }

    public private(set) var mode: Mode = .live
    public private(set) var cityIndex = 0
    public private(set) var useLocation = true
    public private(set) var locationTitle = "正在定位…"
    public private(set) var networkStatus = "正在连接天气"
    public private(set) var liveData: LiveWeather?
    public private(set) var cinematic = false
    public private(set) var previewDate = ""
    public private(set) var festivalPreview = false
    public private(set) var quietMode = false
    public private(set) var reducedMotion = false
    public private(set) var anniversaries: [CalendarEvent] = []
    public private(set) var effectOverrideID = ""
    public private(set) var eventStatus = "本地节日日历"
    public var effectPage = 0
    public var sheet: Sheet?

    @ObservationIgnored public let world: CompanionWorld
    @ObservationIgnored public let scene = SceneState()
    @ObservationIgnored public let weather: WeatherService
    @ObservationIgnored public let events: EventSource
    @ObservationIgnored public let calendar = CalendarData.shared
    @ObservationIgnored let location: LocationProviding?
    @ObservationIgnored let saveURL: URL?
    @ObservationIgnored let now: () -> Date
    /// Called after a setting that the watch mirrors changes (city, location, anniversaries).
    @ObservationIgnored public var onSyncableChange: (() -> Void)?
    @ObservationIgnored var programKey = ""
    @ObservationIgnored var anniversaryVersion = 0
    @ObservationIgnored var lastFrame: Date?
    @ObservationIgnored var lastSave: Date
    @ObservationIgnored var cinematicStart = Date.distantPast
    @ObservationIgnored var cinematicIndex = -1
    @ObservationIgnored var timer: Timer?
    @ObservationIgnored var persist = true

    public var hasLocation: Bool { location != nil }
    public var catalog: EventCatalog { events.catalog }

    public init(world: CompanionWorld = CompanionWorld(), storage: URL?, location: LocationProviding?,
                weatherFetcher: @escaping DataFetcher = Networking.weather,
                contentFetcher: @escaping DataFetcher = Networking.content,
                now: @escaping () -> Date = Date.init) {
        self.world = world
        self.location = location
        self.now = now
        lastSave = now()
        saveURL = storage?.appendingPathComponent("companion_save.json")
        weather = WeatherService(cacheURL: storage?.appendingPathComponent("companion_weather.json"), fetcher: weatherFetcher, now: now)
        events = EventSource(cacheURL: storage?.appendingPathComponent("events_cache.json"), fetcher: contentFetcher, now: now)
        eventStatus = events.status
        weather.onUpdate = { [weak self] in self?.onLiveWeather($0) }
        weather.onStatus = { [weak self] in self?.networkStatus = $0 }
        events.onChange = { [weak self] in
            guard let self else { return }
            self.eventStatus = self.events.status
            self.updateFestival()
        }
        loadSaved()
    }

    /// The app's own documents directory for saves and caches.
    public static func defaultStorage() -> URL? {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let url { try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
        return url
    }

    // MARK: Lifecycle

    /// Starts live weather, the festival calendar and the periodic timer.
    public func start(persist: Bool = true) {
        self.persist = persist
        events.refresh()
        eventStatus = events.status
        useLive()
        startTimer()
    }

    /// A launch without live weather, for screenshots and simulator checks. Never writes the save.
    public func startDemo(_ id: String) {
        persist = false
        setDemo(id)
        startTimer()
    }

    func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.periodic() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        periodic()
    }

    /// App returned to the foreground: refresh what went stale while suspended.
    public func resume() {
        lastFrame = nil
        if mode == .live, weather.enabled, now().timeIntervalSince(weather.lastSuccess ?? .distantPast) >= WeatherService.refreshInterval {
            weather.refresh()
        }
        events.tick()
        periodic()
    }

    public func suspend() {
        save()
    }

    /// One rendered frame: advance the simulation by the wall-clock time since the last frame.
    public func frame(at date: Date, size: CGSize, groundLimit: Double? = nil, bodyScale: Double = 1) {
        let dt = lastFrame.map { max(0, date.timeIntervalSince($0)) } ?? 0
        lastFrame = date
        advance(dt, size: size, groundLimit: groundLimit, bodyScale: bodyScale)
    }

    public func advance(_ dt: Double, size: CGSize? = nil, groundLimit: Double? = nil, bodyScale: Double = 1) {
        world.step(dt)
        let size = size ?? scene.layout.size
        scene.layout = SceneLayout(size: size, worldX: world.x, groundLimit: groundLimit, bodyScale: bodyScale)
        scene.update(dt, world: world)
    }

    /// Slow work, 5 times a second: date changes, live clock, tour, saves and refreshes.
    public func periodic() {
        if let data = liveData, mode == .live {
            let clock = WeatherClock.state(data, now: now())
            world.environment.hour = clock.hour
            world.environment.minute = clock.minute
            world.environment.isDay = clock.isDay
            world.environment.phase = clock.phase
        }
        updateFestival()
        if cinematic {
            let slot = Int(now().timeIntervalSince(cinematicStart) / 18) % Catalog.ids.count
            if slot != cinematicIndex {
                cinematicIndex = slot
                setDemo(Catalog.ids[slot], stopTour: false)
            }
        }
        if now().timeIntervalSince(lastSave) >= 20 { save() }
        weather.tick()
        events.tick()
        if eventStatus != events.status { eventStatus = events.status }
    }

    // MARK: Calendar

    public func today() -> String {
        if !previewDate.isEmpty { return previewDate }
        if mode == .live, let data = liveData { return CivilDate.at(now(), utcOffset: data.utcOffset).description }
        return CivilDate.local(now()).description
    }

    public func todayProgram() -> DayProgram {
        Events.program(events.catalog, date: today(), personal: anniversaries)
    }

    public func updateFestival() {
        if festivalPreview { return }
        let date = today()
        let key = "\(date):\(events.catalog.revision):\(anniversaryVersion)"
        if key == programKey { return }
        programKey = key
        world.setFestival(Events.program(events.catalog, date: date, personal: anniversaries))
    }

    public func previewFestival(_ event: CalendarEvent) {
        setDemo("clear")
        festivalPreview = true
        world.setFestival(DayProgram(previewing: event))
        world.queue.removeAll()
        world.celebrate()
        sheet = nil
    }

    /// Shows the program of any day. Returns false for an invalid date.
    @discardableResult
    public func previewDate(_ date: String) -> Bool {
        guard Events.validDate(date) else { return false }
        setDemo("clear")
        previewDate = date
        programKey = ""
        updateFestival()
        world.queue.removeAll()
        world.celebrate()
        sheet = nil
        return true
    }

    public func previewEffect(_ id: String) {
        guard let recipe = calendar.effect(id) else { return }
        previewDate(today())
        effectOverrideID = id
        festivalPreview = true
        world.setFestival(DayProgram(id: "effect_preview", title: recipe.title, caption: "特效体验 · 回到今天即可恢复自动场景", tone: "gentle", actions: ["idle"]))
    }

    /// Effect recipes on screen, at most two layers (`calendar_effects.gd`).
    public var activeEffects: [EffectRecipe] {
        let ids = effectOverrideID.isEmpty ? (world.festival?.effectIDs ?? []) : [effectOverrideID]
        return ids.prefix(2).compactMap { calendar.effect($0) }
    }

    // MARK: Anniversaries

    /// Saves a personal anniversary; returns an error message when it is not valid.
    public func addAnniversary(title: String, calendar kind: AnniversaryCalendar, date: String, solemn: Bool) -> String? {
        if anniversaries.count >= 64 { return "最多保存 64 个个人纪念日" }
        var json: [String: Any] = [
            "id": "personal_\(Int(now().timeIntervalSince1970 * 1_000_000))",
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
            "caption": "这一天，阿晴也记得。", "kind": "anniversary", "days": 1, "priority": 100,
            "tone": solemn ? "solemn" : "joyful",
            "actions": solemn ? ["idle"] : ["celebrate_wave", "celebrate_cheer"],
            "effect": solemn ? "candle_garland" : "heart_garland",
        ]
        let key = kind == .solarDate ? "date" : ([.lunarYearly, .lunarLeap].contains(kind) ? "lunar_day" : "month_day")
        json[key] = date.trimmingCharacters(in: .whitespacesAndNewlines)
        if kind == .lunarLeap { json["leap_month"] = true }
        guard let event = Events.event(json) else { return "请填写名称和有效日期；农历日期最大三十" }
        anniversaries.append(event)
        anniversariesChanged()
        return nil
    }

    public func removeAnniversary(_ id: String) {
        anniversaries.removeAll { $0.id == id }
        anniversariesChanged()
    }

    func anniversariesChanged() {
        anniversaryVersion += 1
        programKey = ""
        save()
        updateFestival()
        onSyncableChange?()
    }

    // MARK: Weather and places

    public func setDemo(_ id: String, stopTour: Bool = true) {
        festivalPreview = false
        previewDate = ""
        programKey = ""
        effectOverrideID = ""
        if stopTour { cinematic = false }
        mode = .demo
        weather.stop()
        world.setEnvironment(Catalog.preset(id))
        save()
    }

    public func startTour() {
        cinematic = true
        cinematicStart = now()
        cinematicIndex = -1
        sheet = nil
        periodic()
    }

    public func useLive() {
        festivalPreview = false
        previewDate = ""
        programKey = ""
        effectOverrideID = ""
        mode = .live
        cinematic = false
        liveData = nil
        world.setEnvironment(Catalog.preset("clear"))
        world.environment.caption = "天气更新中，先陪你安静待一会儿。"
        if useLocation, let location {
            weather.stop()
            locationTitle = "正在定位…"
            networkStatus = "正在获取位置 · 也可在设置中选择城市"
            location.request { [weak self] in self?.onLocation($0) }
        } else {
            weather.fetch(cityIndex: cityIndex)
        }
        sheet = nil
        updateFestival()
    }

    public func chooseCity(_ index: Int) {
        cityIndex = min(max(index, 0), Catalog.cities.count - 1)
        useLocation = false
        save()
        onSyncableChange?()
        useLive()
    }

    public func useCurrentLocation() {
        useLocation = true
        save()
        onSyncableChange?()
        useLive()
    }

    func onLocation(_ event: LocationEvent) {
        guard mode == .live, useLocation else { return }
        switch event {
        case .coordinates(let lat, let lon):
            locationTitle = String(format: "%.3f°, %.3f°", lat, lon)
            weather.fetchCoordinates(lat: lat, lon: lon)
        case .placeName(let name):
            locationTitle = name
        case .failure(let message):
            locationTitle = "定位未成功"
            networkStatus = message
        }
    }

    func onLiveWeather(_ data: LiveWeather) {
        guard mode == .live else { return }
        liveData = data
        world.setEnvironment(data.environment)
        periodic()
        save()
    }

    // MARK: Care and touch

    public func care(_ kind: String) {
        if world.interact(kind) {
            scene.affection()
            save()
        }
    }

    /// A touch on the scene, in logical coordinates (`main.gd::_unhandled_input`).
    public func touch(start: CGPoint, end: CGPoint, duration: TimeInterval) {
        let layout = scene.layout
        if layout.actorRect.contains(start) {
            care(duration > 0.35 || start.y < layout.foot.y - layout.bodyHeight * 0.60 ? "pet" : "wave")
        } else if end.y > layout.size.height * 0.65, !Catalog.isRain(world.environment.id) {
            world.walk(to: end.x / layout.size.width)
        }
    }

    public func setReducedMotion(_ on: Bool) {
        reducedMotion = on
        save()
    }

    public func setQuietMode(_ on: Bool) {
        quietMode = on
        sheet = nil
    }

    // MARK: HUD

    public func hud() -> HUD {
        let e = world.environment
        let hasLive = mode == .live && liveData != nil
        let valid = mode == .demo || hasLive
        var hour: Int
        var minute: Int
        if let data = liveData, hasLive {
            let clock = WeatherClock.state(data, now: now())
            (hour, minute) = (clock.hour, clock.minute)
        } else {
            let c = Calendar.current.dateComponents([.hour, .minute], from: now())
            (hour, minute) = (c.hour ?? 0, c.minute ?? 0)
        }
        let place = mode == .demo ? "体验" : (useLocation && hasLocation ? locationTitle : Catalog.cities[cityIndex].name)
        var source = networkStatus
        if mode == .demo {
            source = "天气体验 · " + (cinematic ? "自动漫游中" : "可以切换不同天气")
        } else if let data = liveData, hasLive {
            let prefix = now().timeIntervalSince1970 - data.savedAt > 3600 ? "过期缓存" : data.source
            let observed = String(data.observed.replacingOccurrences(of: "T", with: " ").dropFirst(5).prefix(11))
            source = "\(prefix) · \(observed) 更新 · Open-Meteo"
        }
        let date = today()
        let lunar = calendar.lunar(date)
        var calendarText = date + "  ·  " + (lunar.map { "农历" + $0.title } ?? "农历数据待更新")
        if !previewDate.isEmpty { calendarText += " · 体验" }
        return HUD(
            temperature: valid ? "\(Int(e.temperature.rounded()))°" : "--°",
            details: valid ? "\(e.title)  ·  体感 \(Int(e.feels.rounded()))°  ·  风 \(Int(e.wind.rounded())) km/h" : "天气连接中，小院里先歇一会儿",
            clock: String(format: "%02d:%02d  ·  ", hour, minute) + place,
            source: source,
            festival: (festivalPreview ? "节日体验 · " : "") + (world.festival?.title ?? ""),
            calendar: calendarText,
            status: world.status,
            caption: quietMode ? "轻轻点一下阿晴，打个招呼" : (world.festival?.caption ?? e.caption),
            bond: "陪伴 \(world.bond) 次")
    }

    public var appVersion: String {
        let info = Bundle.main.infoDictionary
        let name = info?["CFBundleShortVersionString"] as? String ?? "1.2.1"
        let build = info?["CFBundleVersion"] as? String ?? "103"
        return "\(name)（\(build)）"
    }

    // MARK: Persistence

    func loadSaved() {
        guard let url = saveURL, let data = try? Data(contentsOf: url),
              let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            world.restore(CompanionWorld.Saved())
            return
        }
        apply(settings: d)
        reducedMotion = (d["reduced_motion"] as? Bool) ?? false
        if let w = d["world"], let raw = try? JSONSerialization.data(withJSONObject: w),
           let saved = try? JSONDecoder().decode(CompanionWorld.Saved.self, from: raw) {
            world.restore(saved)
        } else {
            world.restore(CompanionWorld.Saved())
        }
    }

    public func save() {
        lastSave = now()
        guard persist, let url = saveURL else { return }
        var d = syncPayload()
        d["reduced_motion"] = reducedMotion
        if let raw = try? JSONEncoder().encode(world.saveData()), let w = try? JSONSerialization.jsonObject(with: raw) {
            d["world"] = w
        }
        if let data = try? JSONSerialization.data(withJSONObject: d, options: [.sortedKeys]) {
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: iPhone -> Watch settings

    /// The settings both devices share: chosen city, location switch and personal anniversaries.
    public func syncPayload() -> [String: Any] {
        ["city": cityIndex, "use_location": useLocation, "anniversaries": anniversaries.map(Events.json)]
    }

    /// Applies settings received from the paired iPhone.
    public func applySync(_ payload: [String: Any]) {
        let oldCity = cityIndex
        let oldLocation = useLocation
        apply(settings: payload)
        anniversaryVersion += 1
        programKey = ""
        save()
        updateFestival()
        if mode == .live && (oldCity != cityIndex || oldLocation != useLocation) { useLive() }
    }

    func apply(settings d: [String: Any]) {
        if let list = d["anniversaries"] as? [Any] {
            anniversaries = list.prefix(64).compactMap(Events.event)
        }
        if let city = d["city"] as? NSNumber { cityIndex = min(max(city.intValue, 0), Catalog.cities.count - 1) }
        if let use = d["use_location"] as? Bool { useLocation = use }
    }
}
