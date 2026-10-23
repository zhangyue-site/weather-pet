import CoreGraphics
import Foundation
import Testing
@testable import CompanionCore

/// Ports of `tests/test_calendar_ui.gd` and `tests/test_companion_scene.gd` against the model
/// the SwiftUI views drive.
@MainActor
@Suite struct ModelTests {
    func makeModel(storage: URL? = nil) -> CompanionModel {
        CompanionModel(world: CompanionWorld(seed: 5), storage: storage, location: nil, weatherFetcher: offline, contentFetcher: offline)
    }

    @Test func birthdayCalendarAndEffectBrowsing() throws {
        let app = makeModel()
        #expect(app.addAnniversary(title: "生日", calendar: .lunarYearly, date: "08-15", solemn: false) == nil, "form saves lunar birthday")
        if case .lunarDay(let day, let leap) = app.anniversaries.first?.rule { #expect(day == "08-15" && !leap) } else { Issue.record("rule") }
        app.previewDate("2026-09-25")
        #expect((app.world.festival?.matches.count ?? 0) >= 2, "birthday overlays Mid Autumn")
        #expect(app.hud().calendar.contains("八月十五"), "lunar date shown on main view")
        app.effectPage = (app.effectPage + 1) % 10
        #expect(app.effectPage == 1, "effect pagination")
        app.previewEffect(app.calendar.effectOrder[20])
        #expect(!app.effectOverrideID.isEmpty && app.activeEffects.first?.id == app.calendar.effectOrder[20], "effect button renders chosen recipe")
        app.previewDate("2026-02-17")
        #expect(app.effectOverrideID.isEmpty, "date selection clears stale effect override")
        #expect(app.world.festival?.id == "spring_festival", "date selection resolves lunar festival")
        #expect(app.addAnniversary(title: "", calendar: .solarYearly, date: "08-15", solemn: false) != nil, "name required")
        #expect(app.addAnniversary(title: "x", calendar: .lunarYearly, date: "08-31", solemn: false) != nil, "lunar day max 30")
        #expect(!app.previewDate("2026-02-30"), "invalid preview date")
    }

    @Test func careWeatherScenesAndFestivalPreview() throws {
        let app = makeModel()
        app.setDemo("clear")
        app.advance(0, size: CGSize(width: 540, height: 1170))
        let before = app.world.bond
        app.world.careCooldown = 0
        app.sheet = .care
        app.care("pet")
        app.sheet = nil
        #expect(app.world.bond == before + 1, "care button reaches behavior")
        #expect(!app.scene.hearts.isEmpty, "care generates visible affection")
        app.setDemo("rain")
        for _ in 0..<100 { app.advance(0.05) }
        #expect(app.world.activity == "umbrella", "scene rain chain")
        #expect(app.scene.backgroundNow == "rain", "scene rain background")
        app.setDemo("night")
        for _ in 0..<160 { app.advance(0.05) }
        #expect(app.scene.backgroundNow == "night", "scene night background")
        #expect(app.world.activity == "sleep", "scene sleep")
        app.previewFestival(app.catalog.events[0])
        #expect(app.world.activity.hasPrefix("celebrate_"), "festival preview animates")
        #expect(app.hud().festival.contains("欢度国庆"), "festival title visible")
    }

    @Test func touchesPetWaveAndWalk() {
        let app = makeModel()
        app.setDemo("clear")
        app.advance(0, size: CGSize(width: 540, height: 1170))
        let layout = app.scene.layout
        let head = CGPoint(x: layout.foot.x, y: layout.foot.y - layout.bodyHeight)
        app.touch(start: head, end: head, duration: 0.1)
        #expect(app.world.activity == "pet", "touching the head pets")
        app.world.careCooldown = 0
        let body = CGPoint(x: layout.foot.x, y: layout.foot.y - layout.bodyHeight * 0.3)
        app.touch(start: body, end: body, duration: 0.1)
        #expect(app.world.activity == "wave", "tapping the body waves")
        let ground = CGPoint(x: 540 * 0.9, y: 1170 * 0.9)
        app.touch(start: ground, end: ground, duration: 0.1)
        #expect(app.world.activity == "walk" && app.world.targetX == 0.72, "tapping the ground walks within the yard")
    }

    @Test func demoHUDAndQuietMode() {
        let app = makeModel()
        app.setDemo("rain")
        let hud = app.hud()
        #expect(hud.temperature == "16°")
        #expect(hud.details == "下雨  ·  体感 16°  ·  风 10 km/h")
        #expect(hud.clock.hasSuffix("体验") && hud.source == "天气体验 · 可以切换不同天气")
        app.setQuietMode(true)
        #expect(app.hud().caption == "轻轻点一下阿晴，打个招呼")
    }

    @Test func liveWithoutNetworkShowsPlaceholder() {
        let app = makeModel()
        app.chooseCity(1)
        let hud = app.hud()
        #expect(hud.temperature == "--°" && hud.details == "天气连接中，小院里先歇一会儿")
        #expect(hud.clock.hasSuffix("北京"))
    }

    @Test func persistenceAndWatchSync() throws {
        let dir = temporaryDirectory()
        let app = makeModel(storage: dir)
        app.chooseCity(3)
        _ = app.addAnniversary(title: "纪念日", calendar: .solarDate, date: "2026-11-11", solemn: true)
        app.setReducedMotion(true)
        app.world.bond = 9
        app.save()
        let reopened = makeModel(storage: dir)
        #expect(reopened.cityIndex == 3 && !reopened.useLocation && reopened.reducedMotion)
        #expect(reopened.anniversaries.first?.title == "纪念日" && reopened.anniversaries.first?.tone == "solemn")
        #expect(reopened.world.bond == 9)

        let watch = makeModel()
        watch.applySync(app.syncPayload())
        #expect(watch.cityIndex == 3 && !watch.useLocation && watch.anniversaries.count == 1)
    }

    @Test func tourCyclesScenes() {
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        let app = CompanionModel(world: CompanionWorld(seed: 1), storage: nil, location: nil, weatherFetcher: offline, contentFetcher: offline, now: { clock })
        app.startTour()
        #expect(app.world.environment.id == "clear" && app.cinematic)
        clock += 18
        app.periodic()
        #expect(app.world.environment.id == "cloudy" && app.cinematic, "tour advances every 18 seconds")
        #expect(app.hud().source == "天气体验 · 自动漫游中")
    }
}

/// The iOS bundle must carry exactly the Android content.
@Suite struct ContentParityTests {
    @Test(arguments: ["daily", "effects", "events", "lunar_calendar", "server"]) func sameAsGodot(name: String) throws {
        let godot = contentURL(name).deletingLastPathComponent() // .../Sources/CompanionCore/Content
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() // ios/CompanionCore
            .deletingLastPathComponent().deletingLastPathComponent() // repo root
            .appendingPathComponent("godot_project/companion/content/\(name).json")
        #expect(try Data(contentsOf: godot) == Data(contentsOf: contentURL(name)), "\(name).json drifted from godot_project; run ios/tools/sync_content.sh")
    }
}
