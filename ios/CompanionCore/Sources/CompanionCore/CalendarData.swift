import Foundation

public struct LunarDay: Equatable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int
    public let leap: Bool
    /// e.g. `闰六月初一`.
    public let title: String
    /// Solar term name on its first day, otherwise empty.
    public let term: String
}

/// One entry of `daily.json`: the gentle theme every ordinary day carries.
public struct DailyEntry: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var caption: String
    public var actions: [String]
    public var effect: String
    public var kind: String
    public var tone: String
    public var priority: Int
}

/// 20 drawn motifs x 10 choreographies; see `calendar_effects.gd`.
public struct EffectRecipe: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let family: String
    public let motion: String
    public let colors: [String]
    public let count: Int
    public let size: Double
    public let speed: Double
}

/// Bundled lunar table (2025-2036, China standard time), 366 daily themes and 200 effect recipes.
/// Port of `calendar_data.gd`.
public final class CalendarData: Sendable {
    public static let shared = CalendarData(bundle: .module)

    public let lunarTable: [String: LunarDay]
    public let daily: [String: DailyEntry]
    public let effects: [String: EffectRecipe]
    public let effectOrder: [String]

    init(bundle: Bundle) {
        func load(_ name: String) -> Data {
            guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Content"),
                  let data = try? Data(contentsOf: url) else { fatalError("missing bundled content \(name).json") }
            return data
        }
        var lunar: [String: LunarDay] = [:]
        if let root = try? JSONSerialization.jsonObject(with: load("lunar_calendar")) as? [String: Any],
           let days = root["days"] as? [String: [Any]] {
            lunar.reserveCapacity(days.count)
            for (date, row) in days where row.count >= 5 {
                let month = (row[1] as? NSNumber)?.intValue ?? 0
                lunar[date] = LunarDay(year: (row[0] as? NSNumber)?.intValue ?? 0, month: abs(month),
                                       day: (row[2] as? NSNumber)?.intValue ?? 0, leap: month < 0,
                                       title: row[3] as? String ?? "", term: row[4] as? String ?? "")
            }
        }
        lunarTable = lunar
        struct DailyFile: Decodable { let days: [String: DailyEntry] }
        struct EffectsFile: Decodable { let effects: [EffectRecipe] }
        daily = (try? JSONDecoder().decode(DailyFile.self, from: load("daily")).days) ?? [:]
        let list = (try? JSONDecoder().decode(EffectsFile.self, from: load("effects")).effects) ?? []
        effects = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        effectOrder = list.map(\.id)
    }

    public func lunar(_ date: String) -> LunarDay? { lunarTable[date] }

    public func dailyProgram(_ date: String) -> DailyEntry {
        let key = String(date.dropFirst(5).prefix(5))
        var entry = daily[key] ?? daily["01-01"]!
        entry.id += "_" + date
        return entry
    }

    public func effect(_ id: String) -> EffectRecipe? { effects[id] }

    public static func shift(_ date: String, days: Int) -> String {
        guard let day = CivilDate(date) else { return date }
        return day.adding(days: days).description
    }
}
