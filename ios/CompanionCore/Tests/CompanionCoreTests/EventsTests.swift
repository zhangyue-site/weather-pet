import Foundation
import Testing
@testable import CompanionCore

/// The JSON files bundled into CompanionCore (same files the module ships).
func contentURL(_ name: String) -> URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources/CompanionCore/Content/\(name).json")
}

func bundledEventsJSON() -> [String: Any] {
    try! JSONSerialization.jsonObject(with: Data(contentsOf: contentURL("events"))) as! [String: Any]
}

func mutated(_ data: [String: Any], _ change: (inout [String: Any]) -> Void) -> [String: Any] {
    var copy = data
    var events = copy["events"] as! [[String: Any]]
    var first = events[0]
    change(&first)
    events[0] = first
    copy["events"] = events
    return copy
}

/// Port of `tests/test_events.gd`.
@Suite struct EventsTests {
    @Test func datesValidationPriorityCooldownExpiry() throws {
        let raw = bundledEventsJSON()
        let data = try #require(Events.catalog(raw), "bundled content valid")
        let event = try #require(Events.current(data, date: "2026-10-01"))
        // Expiry tests isolate National Day; other real observances can share dates.
        let nationalOnly = EventCatalog(schema: 2, revision: 1, events: [data.events[0]])
        #expect(event.id == "national_day", "National Day October 1")
        #expect(Events.current(data, date: "2026-10-07")?.id == "national_day", "last celebration day")
        #expect(Events.current(nationalOnly, date: "2026-10-08") == nil, "event expires")
        #expect(Events.current(nationalOnly, date: "2026-09-30") == nil, "no early celebration")
        #expect(Events.catalog(mutated(raw) { $0["actions"] = ["execute_script"] }) == nil, "reject unshipped actions")
        #expect(Events.catalog(mutated(raw) { $0["month_day"] = "02-30" }) == nil, "reject impossible date")
        #expect(Events.catalog(mutated(raw) { $0["days"] = -1 }) == nil, "reject invalid duration")
        #expect(Events.catalog(mutated(raw) { $0["date"] = 20261001 }) == nil, "reject malformed date field")
        #expect(Events.catalog(mutated(raw) { $0["days"] = true }) == nil, "booleans are not numbers")
        #expect(Events.catalog(mutated(raw) { $0["id"] = String(repeating: "a", count: 121) }) == nil, "overlong text")
        var dated = data.events[0]
        dated.rule = .date("2026-12-31")
        dated.days = 2
        #expect(Events.event(Events.json(dated)) != nil, "specific-year event")
        let datedCatalog = EventCatalog(schema: 2, revision: 1, events: [dated])
        #expect(Events.current(datedCatalog, date: "2027-01-01") != nil, "cross-year event")
        #expect(Events.current(datedCatalog, date: "2027-12-31") == nil, "dated event not annual")

        let w = CompanionWorld(seed: 7)
        w.setFestival(Events.program(EventCatalog(schema: 2, revision: 1, events: [event]), date: "2026-10-01"))
        w.chooseActivity()
        #expect(w.activity.hasPrefix("celebrate_"), "auto celebration")
        for _ in 0..<140 { w.step(0.05) }
        #expect(!w.activity.hasPrefix("celebrate_"), "celebration cooldown")
        w.setEnvironment(Catalog.preset("rain"))
        #expect(w.activity == "notice", "rain interrupts celebration")
        #expect(!w.celebrate(), "cannot celebrate instead of umbrella")
        w.setEnvironment(Catalog.preset("night"))
        #expect(!w.celebrate(), "sleep takes priority")
        w.setEnvironment(Catalog.preset("clear"))
        w.celebrate()
        w.setFestival(nil)
        #expect(!w.activity.hasPrefix("celebrate_"), "midnight expires active celebration")
    }

    @Test func catalogLimits() throws {
        let raw = bundledEventsJSON()
        var duplicate = raw
        var list = raw["events"] as! [[String: Any]]
        list.append(list[0])
        duplicate["events"] = list
        #expect(Events.catalog(duplicate) == nil, "duplicate ids rejected")
        var bad = raw
        bad["revision"] = 0
        #expect(Events.catalog(bad) == nil, "revision must be positive")
        #expect(Events.catalog(from: Data(repeating: 32, count: Events.maxBytes + 1)) == nil, "size limit")
        #expect(Events.catalog(mutated(raw) { $0["effect"] = "not_an_effect" }) == nil, "unknown effect")
        #expect(Events.catalog(mutated(raw) { $0["solar_term"] = "清明" }) == nil, "two date rules")
    }
}
