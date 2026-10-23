import Foundation
import Testing
@testable import CompanionCore

/// Port of `tests/test_year_program.gd`.
@Suite struct YearProgramTests {
    let data = Events.catalog(bundledEventsJSON())!
    let calendar = CalendarData.shared

    func has(_ date: String, _ id: String) -> Bool {
        Events.matching(data, date: date).contains { $0.id == id }
    }

    @Test func contentShape() {
        #expect(data.schema == 2, "schema 2 validated")
        #expect(calendar.daily.count == 366, "366 daily slots includes leap day")
        #expect(calendar.effects.count == 200, "200 effect recipes")
        let families = Set(calendar.effects.values.map(\.family))
        let combinations = Set(calendar.effects.values.map { $0.family + ":" + $0.motion })
        #expect(families.count == 20 && combinations.count == 200, "200 geometry-motion combinations")
        #expect(calendar.lunarTable.count == 4383)
    }

    @Test(arguments: [2026, 2028]) func fullYear(year: Int) {
        var date = CivilDate(year: year, month: 1, day: 1)
        var count = 0
        while date.year == year {
            let program = Events.program(data, date: date.description)
            #expect(!program.title.isEmpty && !program.actions.isEmpty, "daily program \(date)")
            for id in program.effectIDs { #expect(calendar.effect(id) != nil, "effect resolves \(date)") }
            count += 1
            date = date.adding(days: 1)
        }
        #expect(count == (year == 2028 ? 366 : 365), "full Gregorian year \(year)")
    }

    @Test func movingFestivals() {
        #expect(has("2026-02-16", "new_year_eve"), "29-day lunar New Year eve")
        #expect(has("2026-02-17", "spring_festival"), "2026 Spring Festival")
        #expect(has("2027-02-06", "spring_festival"), "Spring Festival moves in 2027")
        #expect(has("2026-06-19", "dragon_boat"), "2026 Dragon Boat")
        #expect(has("2026-09-25", "mid_autumn"), "2026 Mid Autumn")
        #expect(has("2026-04-05", "term_6"), "Qingming is a calculated solar term")
        #expect(has("2026-05-10", "mother_day"), "second Sunday in May")
        #expect(has("2026-06-21", "father_day"), "third Sunday in June")
    }

    @Test func personalAnniversaries() throws {
        var normal = try #require(Events.event(["id": "birthday", "title": "生日", "caption": "一起记住", "lunar_day": "06-01", "days": 1, "actions": ["celebrate_wave"], "effect": "heart_garland", "priority": 100, "kind": "anniversary"]), "personal lunar anniversary")
        #expect(Events.program(data, date: "2025-06-25", personal: [normal]).matches.contains { $0.id == "birthday" }, "regular lunar month birthday")
        #expect(!Events.program(data, date: "2025-07-25", personal: [normal]).matches.contains { $0.id == "birthday" }, "leap month does not duplicate birthday")
        normal.rule = .lunarDay("06-01", leap: true)
        #expect(Events.program(data, date: "2025-07-25", personal: [normal]).matches.contains { $0.id == "birthday" }, "explicit leap month anniversary")
        let birthday = try #require(Events.event(["id": "birthday", "title": "生日", "caption": "记得今天", "month_day": "12-13", "days": 1, "actions": ["celebrate_cheer"], "effect": "heart_burst", "priority": 100, "kind": "anniversary"]))
        let solemn = Events.program(data, date: "2026-12-13", personal: [birthday])
        #expect(solemn.tone == "solemn" && solemn.actions == ["idle", "notice"], "memorial suppresses celebrations including birthdays")
        #expect(solemn.matches.count >= 2, "simultaneous events retained")
    }

    @Test func weatherAndDateCombine() {
        let w = CompanionWorld(seed: 2)
        w.setFestival(Events.program(data, date: "2026-10-01"))
        w.setEnvironment(Catalog.preset("rain"))
        for _ in 0..<100 { w.step(0.05) }
        #expect(w.activity == "umbrella" && !(w.festival?.effectIDs.isEmpty ?? true), "weather and date remain combined")
        let unsupported = Events.program(data, date: "2040-08-15")
        #expect(unsupported.lunar == nil && !unsupported.dailyTitle.isEmpty, "out-of-range calendar is explicit, daily content remains")
    }

    @Test func lunarSpotChecks() {
        #expect(calendar.lunar("2026-02-17")?.title == "正月初一")
        #expect(calendar.lunar("2026-04-05")?.term == "清明")
        let leap = calendar.lunar("2025-07-25")
        #expect(leap?.leap == true && leap?.month == 6 && leap?.title == "闰六月初一")
    }
}
