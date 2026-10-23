import Foundation
import Testing
@testable import CompanionCore

/// Port of `tests/test_companion.gd`.
@Suite struct WorldTests {
    func tick(_ w: CompanionWorld, _ seconds: Double) {
        for _ in 0..<Int((seconds * 20).rounded()) { w.step(0.05) }
    }

    @Test func weatherChainsCareSleepAndPersistence() {
        let w = CompanionWorld(seed: 1)
        w.setEnvironment(Catalog.preset("rain"))
        #expect(w.activity == "notice", "rain starts with notice")
        tick(w, 2.0)
        #expect(w.activity == "take_umbrella", "notice then take umbrella")
        tick(w, 2.0)
        #expect(w.activity == "umbrella", "opening completes")
        let wet = w.wetness
        tick(w, 10)
        #expect(w.wetness - wet < 0.04, "umbrella mitigates wetting")
        w.interact("drink")
        #expect(w.activity == "umbrella", "care cannot drop umbrella")
        w.setEnvironment(Catalog.preset("clear"))
        #expect(w.wetness > 0, "rain stop preserves wetness")
        tick(w, 2.1)
        #expect(w.activity == "shake", "rain stop closes and shakes umbrella")
        tick(w, 20)
        #expect(w.wetness < wet, "wetness gradually dries")
        w.setEnvironment(Catalog.preset("rain"))
        w.setEnvironment(Catalog.preset("night"))
        tick(w, 8)
        #expect(w.activity == "sleep", "weather interruption cancels stale rain queue")
        let energy = w.energy
        tick(w, 10)
        #expect(w.energy > energy, "sleep restores energy")
        w.interact("pet")
        #expect(w.activity == "blink", "sleep touch is gentle wake")
        tick(w, 2)
        #expect(w.activity == "sleep", "returns to sleep")
        #expect(!w.interact("pet"), "care cooldown prevents spam")
        for id in Catalog.ids {
            w.setEnvironment(Catalog.preset(id))
            tick(w, 20)
            #expect(w.activity != "", "activity for \(id)")
            #expect(w.wetness >= 0 && w.wetness <= 1, "wetness bounds \(id)")
        }
        #expect(w.discovered.count == 16, "all scenarios discovered once")
        let restored = CompanionWorld()
        restored.restore(w.saveData())
        #expect(restored.bond == w.bond && restored.discovered.count == 16, "persistence round trip")
    }

    @Test func wmoMapping() {
        #expect(Catalog.fromWMO(code: 95, temp: 36, wind: 40) == "thunderstorm", "storm priority over heat and wind")
        #expect(Catalog.fromWMO(code: 75, temp: -4, wind: 30) == "heavy_snow", "WMO snow")
        #expect(Catalog.fromWMO(code: 61, temp: 5, wind: 10) == "rain", "WMO rain")
        #expect(Catalog.fromWMO(code: 0, temp: 35, wind: 3) == "hot", "thermal heat fallback")
        #expect(Catalog.fromWMO(code: 45, temp: 10, wind: 2) == "fog", "WMO fog")
    }

    @Test func localSolarClock() {
        let midnight = Double(CivilDate("2026-09-05")!.daysSinceEpoch * 86400 - 28800)
        func state(_ seconds: Double) -> ClockState {
            WeatherClock.state(utcOffset: 28800, sunrise: "2026-09-05T05:35", sunset: "2026-09-05T18:20", now: Date(timeIntervalSince1970: midnight + seconds))
        }
        #expect(state(23 * 3600).phase == "night", "actual local late night")
        #expect(state(5 * 3600 + 35 * 60).phase == "dawn", "actual local sunrise")
        #expect(state(12 * 3600).phase == "day", "actual local noon")
        #expect(state(18 * 3600 + 20 * 60).phase == "dusk", "actual local sunset")
        #expect(state(20 * 3600).hour == 20, "timezone clock conversion")
    }

    @Test func journalStampsAndDailyGreeting() {
        let fixed = Date(timeIntervalSince1970: 1_790_000_000)
        let w = CompanionWorld(seed: 3, now: { fixed })
        w.restore(CompanionWorld.Saved(day: "2000-01-01"))
        #expect(w.journal.first?.text == "新的一天，小院里等到你了")
        #expect(w.journal.first?.time.count == 11)
        w.addNote("新的一天，小院里等到你了")
        #expect(w.journal.count == 1, "duplicate note collapses")
    }

    @Test func openMeteoParsing() throws {
        let body = """
        {"utc_offset_seconds":28800,"current":{"time":"2026-10-23T21:45","temperature_2m":12.6,"relative_humidity_2m":81,"apparent_temperature":10.9,"is_day":0,"precipitation":0.4,"weather_code":61,"wind_speed_10m":9.4},"daily":{"sunrise":["2026-10-23T06:18"],"sunset":["2026-10-23T17:22"]}}
        """
        let data = try #require(OpenMeteo.parse(Data(body.utf8), city: "上海"))
        #expect(data.environment.id == "rain")
        #expect(data.environment.temperature == 12.6 && data.environment.feels == 10.9)
        #expect(!data.environment.isDay && data.environment.hour == 21)
        #expect(data.sunset == "2026-10-23T17:22" && data.utcOffset == 28800)
        #expect(OpenMeteo.parse(Data(#"{"current":{"time":"x"}}"#.utf8), city: "") == nil, "missing fields rejected")
        #expect(OpenMeteo.parse(Data(#"{"current":{"time":"2026-10-23T21:45","temperature_2m":null,"relative_humidity_2m":81,"apparent_temperature":10.9,"is_day":0,"weather_code":61,"wind_speed_10m":9.4}}"#.utf8), city: "") == nil, "null field rejected")
    }

    @Test func civilDates() {
        #expect(CivilDate("2028-02-29") != nil && CivilDate("2026-02-29") == nil)
        #expect(CivilDate("2026-1-01") == nil && CivilDate("1969-12-31") == nil)
        #expect(CivilDate("2026-12-31")!.adding(days: 1).description == "2027-01-01")
        #expect(CivilDate("2026-03-01")!.adding(days: -1).description == "2026-02-28")
        #expect(CivilDate("2026-05-10")!.weekday == 0, "2026-05-10 is a Sunday")
        #expect(CivilDate.at(Date(timeIntervalSince1970: 0), utcOffset: -3600).description == "1969-12-31")
    }
}
