import Foundation

/// A real observation from Open-Meteo, as cached on disk.
public struct LiveWeather: Codable, Equatable, Sendable {
    public var environment: WeatherEnvironment
    /// Local observation time, `YYYY-MM-DDTHH:MM`.
    public var observed: String
    public var city: String
    /// `实时` or `缓存`.
    public var source: String
    public var savedAt: Double
    public var utcOffset: Int
    public var sunrise: String?
    public var sunset: String?
}

public struct ClockState: Equatable, Sendable {
    public var hour: Int
    public var minute: Int
    public var isDay: Bool
    /// `dawn`, `day`, `dusk` or `night`.
    public var phase: String
}

public enum WeatherClock {
    /// Local clock and solar phase of the weather city. Port of `weather_source.gd::clock_state`.
    public static func state(utcOffset: Int, sunrise: String?, sunset: String?, now: Date = Date()) -> ClockState {
        let local = Int(now.timeIntervalSince1970.rounded(.down)) + utcOffset
        let secondOfDay = ((local % 86400) + 86400) % 86400
        let hour = secondOfDay / 3600
        let minuteOfHour = secondOfDay % 3600 / 60
        let minute = hour * 60 + minuteOfHour
        // Cache may be from yesterday; use its local solar clock until refresh succeeds.
        let rise = minutes(sunrise) ?? 6 * 60
        let setting = minutes(sunset) ?? 18 * 60
        var phase = "day"
        if minute < rise - 25 || minute > setting + 30 {
            phase = "night"
        } else if minute <= rise + 25 {
            phase = "dawn"
        } else if minute >= setting - 25 {
            phase = "dusk"
        }
        return ClockState(hour: hour, minute: minuteOfHour, isDay: phase != "night", phase: phase)
    }

    public static func state(_ data: LiveWeather, now: Date = Date()) -> ClockState {
        state(utcOffset: data.utcOffset, sunrise: data.sunrise, sunset: data.sunset, now: now)
    }

    static func minutes(_ stamp: String?) -> Int? {
        guard let s = stamp, s.count >= 16 else { return nil }
        let chars = Array(s)
        guard let h = Int(String(chars[11...12])), let m = Int(String(chars[14...15])) else { return nil }
        return h * 60 + m
    }
}

public enum OpenMeteo {
    public static func url(lat: Double, lon: Double) -> URL {
        URL(string: String(format: "https://api.open-meteo.com/v1/forecast?latitude=%.4f&longitude=%.4f&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m&daily=sunrise,sunset&forecast_days=1&timezone=auto", lat, lon))!
    }

    /// Parses a forecast response; nil when any required current field is missing.
    public static func parse(_ data: Data, city: String, now: Date = Date()) -> LiveWeather? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let c = json["current"] as? [String: Any] else { return nil }
        func number(_ key: String) -> Double? {
            guard let n = c[key] as? NSNumber else { return nil }
            return n.doubleValue
        }
        guard let temp = number("temperature_2m"), let feels = number("apparent_temperature"),
              let code = number("weather_code"), let wind = number("wind_speed_10m"),
              let humidity = number("relative_humidity_2m"), let isDay = number("is_day"),
              let time = c["time"] as? String else { return nil }
        let id = Catalog.fromWMO(code: Int(code), temp: temp, wind: wind)
        var env = Catalog.preset(id)
        env.temperature = temp
        env.feels = feels
        env.wind = wind
        env.humidity = humidity
        env.isDay = isDay != 0
        let chars = Array(time)
        env.hour = chars.count >= 13 ? Int(String(chars[11...12])) ?? 0 : 0
        var sunrise: String?
        var sunset: String?
        if let daily = json["daily"] as? [String: Any] {
            sunrise = (daily["sunrise"] as? [Any])?.first as? String
            sunset = (daily["sunset"] as? [Any])?.first as? String
        }
        let offset = (json["utc_offset_seconds"] as? NSNumber)?.intValue ?? 28800
        return LiveWeather(environment: env, observed: time, city: city, source: "实时",
                           savedAt: now.timeIntervalSince1970, utcOffset: offset, sunrise: sunrise, sunset: sunset)
    }
}

/// Fetches bytes for a URL. Swapped for a fake in tests.
public typealias DataFetcher = @Sendable (URLRequest) async throws -> (Data, Int)

/// Live weather with an on-disk cache and a 15 minute refresh. Port of `weather_source.gd`.
@MainActor
public final class WeatherService {
    public var onUpdate: ((LiveWeather) -> Void)?
    public var onStatus: ((String) -> Void)?
    public private(set) var cache: [String: LiveWeather] = [:]
    public private(set) var enabled = false
    public private(set) var lastData: LiveWeather?
    public private(set) var lastSuccess: Date?
    var cityIndex = 0
    var customTarget: (lat: Double, lon: Double)?
    var pendingKey = "0"
    var pendingName = "上海"
    var lastRequest = Date.distantPast
    var generation = 0
    var task: Task<Void, Never>?
    let cacheURL: URL?
    let fetcher: DataFetcher
    let now: () -> Date
    public static let refreshInterval: TimeInterval = 900

    public init(cacheURL: URL?, fetcher: @escaping DataFetcher, now: @escaping () -> Date = Date.init) {
        self.cacheURL = cacheURL
        self.fetcher = fetcher
        self.now = now
        if let url = cacheURL, let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode([String: LiveWeather].self, from: data) {
            cache = saved
        }
    }

    public func stop() {
        enabled = false
        generation += 1
        task?.cancel()
        task = nil
    }

    public func fetch(cityIndex index: Int) {
        cityIndex = min(max(index, 0), Catalog.cities.count - 1)
        customTarget = nil
        let city = Catalog.cities[cityIndex]
        fetchTarget(lat: city.lat, lon: city.lon, name: city.name, key: String(cityIndex))
    }

    public func fetchCoordinates(lat: Double, lon: Double) {
        guard (-90...90).contains(lat), (-180...180).contains(lon) else { return }
        customTarget = (lat, lon)
        fetchTarget(lat: lat, lon: lon, name: "当前位置", key: String(format: "location_%.2f_%.2f", lat, lon))
    }

    /// Called from the app's periodic timer; refreshes every 15 minutes while enabled.
    public func tick() {
        guard enabled, now().timeIntervalSince(lastRequest) >= Self.refreshInterval else { return }
        refresh()
    }

    public func refresh() {
        if let t = customTarget {
            fetchTarget(lat: t.lat, lon: t.lon, name: "当前位置", key: pendingKey)
        } else {
            fetch(cityIndex: cityIndex)
        }
    }

    func fetchTarget(lat: Double, lon: Double, name: String, key: String) {
        enabled = true
        pendingKey = key
        pendingName = name
        generation += 1
        task?.cancel()
        lastData = nil
        lastRequest = now()
        if var saved = cache[key] {
            saved.source = "缓存"
            lastData = saved
            onUpdate?(saved)
        }
        onStatus?("正在更新天气…")
        let token = generation
        var request = URLRequest(url: OpenMeteo.url(lat: lat, lon: lon))
        request.timeoutInterval = 18
        let fetcher = self.fetcher
        task = Task { [weak self] in
            let result: (Data, Int)?
            do { result = try await fetcher(request) } catch { result = nil }
            self?.completed(result, token: token)
        }
    }

    func completed(_ result: (Data, Int)?, token: Int) {
        guard enabled, token == generation else { return }
        guard let (body, code) = result, code == 200,
              let data = OpenMeteo.parse(body, city: pendingName, now: now()) else {
            onStatus?(lastData != nil ? "网络暂不可用 · 使用缓存" : "暂无天气 · 请重试或体验场景")
            return
        }
        cache[pendingKey] = data
        if let url = cacheURL, let encoded = try? JSONEncoder().encode(cache) {
            try? encoded.write(to: url, options: .atomic)
        }
        lastData = data
        lastSuccess = now()
        lastRequest = now()
        onUpdate?(data)
        onStatus?("天气已更新")
    }
}
