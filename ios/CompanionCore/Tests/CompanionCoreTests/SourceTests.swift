import Foundation
import Testing
@testable import CompanionCore

func temporaryDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("companion-tests-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

let offline: DataFetcher = { _ in throw URLError(.notConnectedToInternet) }

/// Port of `tests/test_event_source.gd`, plus the weather cache.
@MainActor
@Suite struct SourceTests {
    @Test func eventSourceFallbackCacheAndRevision() throws {
        let dir = temporaryDirectory()
        let cache = dir.appendingPathComponent("events_cache.json")
        let source = EventSource(cacheURL: cache, fetcher: offline)
        let original = source.catalog
        #expect(original.revision == 2, "local content loads without server")
        source.completed(nil)
        #expect(source.catalog == original && source.status == "活动暂未更新 · 继续已存日历", "network failure preserves local content")
        source.completed((Data("{}".utf8), 200))
        #expect(source.catalog == original, "invalid response preserves local content")
        let raw = bundledEventsJSON()
        let invalid = mutated(raw) { $0["actions"] = ["unknown"] }
        source.completed((try JSONSerialization.data(withJSONObject: invalid), 200))
        #expect(source.catalog == original, "invalid action preserves local content")
        var fresh = mutated(raw) { $0["title"] = "测试活动" }
        fresh["revision"] = original.revision + 1
        source.completed((try JSONSerialization.data(withJSONObject: fresh), 200))
        #expect(source.catalog.revision == original.revision + 1 && source.catalog.events[0].title == "测试活动", "valid revision accepted")
        let cached = try #require(Events.catalog(from: Data(contentsOf: cache)))
        #expect(cached.revision == original.revision + 1, "successful content cached")
        source.completed((try JSONSerialization.data(withJSONObject: raw), 200))
        #expect(source.catalog.revision == original.revision + 1, "older revision rejected")
        let reopened = EventSource(cacheURL: cache, fetcher: offline)
        #expect(reopened.catalog.revision == original.revision + 1 && reopened.status == "已缓存节日日历", "cache survives restart")
        source.completed((try JSONSerialization.data(withJSONObject: fresh), 500))
        #expect(source.status == "活动暂未更新 · 继续已存日历", "HTTP error")
    }

    @Test func weatherCacheFirstThenLive() async throws {
        let dir = temporaryDirectory()
        let body = Data("""
        {"utc_offset_seconds":28800,"current":{"time":"2026-10-23T09:00","temperature_2m":21,"relative_humidity_2m":50,"apparent_temperature":20,"is_day":1,"weather_code":2,"wind_speed_10m":5}}
        """.utf8)
        let service = WeatherService(cacheURL: dir.appendingPathComponent("w.json"), fetcher: { _ in (body, 200) })
        var updates: [LiveWeather] = []
        var statuses: [String] = []
        service.onUpdate = { updates.append($0) }
        service.onStatus = { statuses.append($0) }
        service.fetch(cityIndex: 1)
        try await waitUntil { statuses.last == "天气已更新" }
        #expect(updates.last?.environment.id == "cloudy" && updates.last?.city == "北京")

        let failing = WeatherService(cacheURL: dir.appendingPathComponent("w.json"), fetcher: offline)
        var cachedUpdates: [LiveWeather] = []
        var failStatus: [String] = []
        failing.onUpdate = { cachedUpdates.append($0) }
        failing.onStatus = { failStatus.append($0) }
        failing.fetch(cityIndex: 1)
        #expect(cachedUpdates.first?.source == "缓存", "cache shown immediately")
        try await waitUntil { failStatus.last == "网络暂不可用 · 使用缓存" }
        failing.fetch(cityIndex: 0)
        try await waitUntil { failStatus.last == "暂无天气 · 请重试或体验场景" }
    }
}

@MainActor
func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0..<200 {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("condition not reached")
}
