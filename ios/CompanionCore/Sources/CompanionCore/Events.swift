import Foundation

/// A festival, solar term, observance or personal anniversary. Port of the dictionaries validated
/// by `events.gd`; the server can only reference actions and effects the app already ships.
public struct CalendarEvent: Equatable, Sendable, Identifiable {
    public enum Rule: Equatable, Sendable {
        /// One-off Gregorian date `YYYY-MM-DD`.
        case date(String)
        /// Gregorian `MM-DD`, every year.
        case monthDay(String)
        /// Lunar `MM-DD`; `leap` selects the leap month only.
        case lunarDay(String, leap: Bool)
        /// The last day of the lunar year, whether the twelfth month has 29 or 30 days.
        case lunarEve
        /// Month, nth week, weekday (0 = Sunday), e.g. Mother's Day.
        case weekDay(month: Int, week: Int, weekday: Int)
        case solarTerm(String)
    }

    public var id: String
    public var title: String
    public var caption: String
    public var rule: Rule
    public var days: Int
    public var priority: Int?
    public var tone: String?
    public var kind: String?
    public var effect: String?
    public var actions: [String]
    /// Whether `leap_month` was written explicitly (kept for a faithful round trip).
    var leapMonthField: Bool?

    public init(id: String, title: String, caption: String, rule: Rule, days: Int = 1, priority: Int? = nil, tone: String? = nil, kind: String? = nil, effect: String? = nil, actions: [String]) {
        self.id = id
        self.title = title
        self.caption = caption
        self.rule = rule
        self.days = days
        self.priority = priority
        self.tone = tone
        self.kind = kind
        self.effect = effect
        self.actions = actions
        if case .lunarDay(_, let leap) = rule, leap { leapMonthField = true }
    }

    public var sortPriority: Int { priority ?? 70 }

    /// Human readable rule, as shown in the anniversary list.
    public var ruleText: String {
        switch rule {
        case .date(let d): return d
        case .monthDay(let md): return md
        case .lunarDay(let ld, let leap): return "农历 " + (leap ? "闰" : "") + ld
        case .lunarEve: return "除夕"
        case .weekDay(let m, let w, let d): return "\(m) 月第 \(w) 个星期\(["日", "一", "二", "三", "四", "五", "六"][d])"
        case .solarTerm(let t): return t
        }
    }
}

public struct EventCatalog: Equatable, Sendable {
    public var schema: Int
    public var revision: Int
    public var events: [CalendarEvent]

    public init(schema: Int, revision: Int, events: [CalendarEvent]) {
        self.schema = schema
        self.revision = revision
        self.events = events
    }
}

/// What the yard celebrates on a given day: the daily theme or the top event, plus all matches.
public struct DayProgram: Equatable, Sendable {
    public var id: String
    public var title: String
    public var caption: String
    public var kind: String
    public var tone: String
    public var actions: [String]
    public var effectIDs: [String]
    public var date: String
    public var dailyTitle: String
    public var matches: [CalendarEvent]
    public var lunar: LunarDay?

    public init(id: String, title: String, caption: String, kind: String = "", tone: String = "", actions: [String], effectIDs: [String] = [], date: String = "", dailyTitle: String = "", matches: [CalendarEvent] = [], lunar: LunarDay? = nil) {
        self.id = id
        self.title = title
        self.caption = caption
        self.kind = kind
        self.tone = tone
        self.actions = actions
        self.effectIDs = effectIDs
        self.date = date
        self.dailyTitle = dailyTitle
        self.matches = matches
        self.lunar = lunar
    }

    /// A single event previewed from the festival library.
    public init(previewing event: CalendarEvent) {
        self.init(id: event.id, title: event.title, caption: event.caption, kind: event.kind ?? "", tone: event.tone ?? "",
                  actions: event.actions, effectIDs: [event.effect ?? "confetti_burst"])
    }
}

/// Validation and day matching. Port of `events.gd`.
public enum Events {
    public static let actions = ["celebrate_wave", "celebrate_dance", "celebrate_cheer", "idle", "notice", "wave", "stretch", "drink", "water", "pet", "walk"]
    public static let maxBytes = 131072
    public static let terms = ["小寒", "大寒", "立春", "雨水", "惊蛰", "春分", "清明", "谷雨", "立夏", "小满", "芒种", "夏至", "小暑", "大暑", "立秋", "处暑", "白露", "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至"]
    static let ruleKeys = ["date", "month_day", "lunar_day", "lunar_eve", "week_day", "solar_term"]

    // MARK: Validation of untrusted JSON

    static func isBool(_ v: Any?) -> Bool {
        guard let n = v as? NSNumber else { return false }
        return CFGetTypeID(n) == CFBooleanGetTypeID()
    }

    /// Integral number within range; booleans are not numbers (as in GDScript).
    static func integer(_ v: Any?, _ low: Int, _ high: Int) -> Int? {
        guard let n = v as? NSNumber, !isBool(n) else { return nil }
        let d = n.doubleValue
        guard d.isFinite, d == d.rounded(.down), d >= Double(low), d <= Double(high) else { return nil }
        return Int(d)
    }

    public static func validDate(_ text: String) -> Bool { CivilDate(text) != nil }

    /// Parses a catalog from raw bytes; nil unless every rule is valid.
    public static func catalog(from data: Data) -> EventCatalog? {
        guard data.count <= maxBytes, let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { return nil }
        return catalog(json)
    }

    public static func catalog(_ value: Any) -> EventCatalog? {
        guard let data = value as? [String: Any],
              let schema = integer(data["schema"], 1, 2),
              let list = data["events"] as? [Any],
              let revision = integer(data["revision"], 1, 2147483647),
              list.count <= 128 else { return nil }
        var events: [CalendarEvent] = []
        var ids = Set<String>()
        for raw in list {
            guard let event = event(raw), !ids.contains(event.id) else { return nil }
            ids.insert(event.id)
            events.append(event)
        }
        return EventCatalog(schema: schema, revision: revision, events: events)
    }

    /// One event from untrusted JSON. Same checks as `valid_event`.
    public static func event(_ value: Any) -> CalendarEvent? {
        guard let e = value as? [String: Any] else { return nil }
        var text: [String: String] = [:]
        for key in ["id", "title", "caption"] {
            guard let s = e[key] as? String, !s.isEmpty, s.unicodeScalars.count <= 120 else { return nil }
            text[key] = s
        }
        guard ruleKeys.filter({ e[$0] != nil }).count == 1 else { return nil }
        var leapField: Bool?
        if let leap = e["leap_month"] {
            guard isBool(leap) else { return nil }
            leapField = (leap as? NSNumber)?.boolValue
        }
        let rule: CalendarEvent.Rule
        if let v = e["date"] {
            guard let s = v as? String, validDate(s) else { return nil }
            rule = .date(s)
        } else if let v = e["month_day"] {
            guard let s = v as? String, validDate("2000-" + s) else { return nil }
            rule = .monthDay(s)
        } else if let v = e["lunar_day"] {
            guard let s = v as? String, validDate("2000-" + s), let day = Int(s.suffix(2)), day <= 30 else { return nil }
            rule = .lunarDay(s, leap: leapField ?? false)
        } else if let v = e["lunar_eve"] {
            guard isBool(v), (v as? NSNumber)?.boolValue == true else { return nil }
            rule = .lunarEve
        } else if let v = e["week_day"] {
            guard let a = v as? [Any], a.count == 3,
                  let m = integer(a[0], 1, 12), let w = integer(a[1], 1, 5), let d = integer(a[2], 0, 6) else { return nil }
            rule = .weekDay(month: m, week: w, weekday: d)
        } else {
            guard let s = e["solar_term"] as? String, terms.contains(s) else { return nil }
            rule = .solarTerm(s)
        }
        guard let days = integer(e["days"], 1, 14) else { return nil }
        var priority: Int?
        if e["priority"] != nil {
            guard let p = integer(e["priority"], 0, 110) else { return nil }
            priority = p
        }
        var tone: String?
        if e["tone"] != nil {
            guard let t = e["tone"] as? String, ["gentle", "joyful", "solemn"].contains(t) else { return nil }
            tone = t
        }
        var kind: String?
        if e["kind"] != nil {
            guard let k = e["kind"] as? String, ["festival", "observance", "memorial", "anniversary", "solar_term", "daily"].contains(k) else { return nil }
            kind = k
        }
        var effect: String?
        if e["effect"] != nil {
            guard let f = e["effect"] as? String, CalendarData.shared.effect(f) != nil else { return nil }
            effect = f
        }
        guard let rawActions = e["actions"] as? [Any], !rawActions.isEmpty, rawActions.count <= 8 else { return nil }
        var actions: [String] = []
        for a in rawActions {
            guard let s = a as? String, Self.actions.contains(s) else { return nil }
            actions.append(s)
        }
        var event = CalendarEvent(id: text["id"]!, title: text["title"]!, caption: text["caption"]!, rule: rule, days: days,
                                  priority: priority, tone: tone, kind: kind, effect: effect, actions: actions)
        event.leapMonthField = leapField
        return event
    }

    /// JSON object for persistence; parses back through `event(_:)`.
    public static func json(_ event: CalendarEvent) -> [String: Any] {
        var out: [String: Any] = ["id": event.id, "title": event.title, "caption": event.caption, "days": event.days, "actions": event.actions]
        switch event.rule {
        case .date(let d): out["date"] = d
        case .monthDay(let md): out["month_day"] = md
        case .lunarDay(let ld, _): out["lunar_day"] = ld
        case .lunarEve: out["lunar_eve"] = true
        case .weekDay(let m, let w, let d): out["week_day"] = [m, w, d]
        case .solarTerm(let t): out["solar_term"] = t
        }
        if let leap = event.leapMonthField { out["leap_month"] = leap }
        if let p = event.priority { out["priority"] = p }
        if let t = event.tone { out["tone"] = t }
        if let k = event.kind { out["kind"] = k }
        if let f = event.effect { out["effect"] = f }
        return out
    }

    // MARK: Matching

    static func starts(_ event: CalendarEvent, on day: CivilDate, calendar: CalendarData) -> Bool {
        switch event.rule {
        case .date(let d): return d == day.description
        case .monthDay(let md): return md == day.monthDay
        case .weekDay(let m, let w, let d):
            return day.month == m && (day.day - 1) / 7 + 1 == w && day.weekday == d
        case .lunarDay(let ld, let leap):
            guard let lunar = calendar.lunar(day.description) else { return false }
            return String(format: "%02d-%02d", lunar.month, lunar.day) == ld && lunar.leap == leap
        case .solarTerm(let term):
            guard let lunar = calendar.lunar(day.description) else { return false }
            return lunar.term == term
        case .lunarEve:
            guard calendar.lunar(day.description) != nil, let next = calendar.lunar(day.adding(days: 1).description) else { return false }
            return next.month == 1 && next.day == 1 && !next.leap
        }
    }

    public static func matching(_ catalog: EventCatalog, date: String, personal: [CalendarEvent] = [], calendar: CalendarData = .shared) -> [CalendarEvent] {
        guard let day = CivilDate(date) else { return [] }
        var result: [CalendarEvent] = []
        for event in catalog.events + personal {
            for offset in 0..<event.days where starts(event, on: day.adding(days: -offset), calendar: calendar) {
                result.append(event)
                break
            }
        }
        // Stable: equal priorities keep catalog order.
        return result.enumerated().sorted { a, b in
            a.element.sortPriority != b.element.sortPriority ? a.element.sortPriority > b.element.sortPriority : a.offset < b.offset
        }.map(\.element)
    }

    public static func current(_ catalog: EventCatalog, date: String) -> CalendarEvent? {
        matching(catalog, date: date).first
    }

    public static func program(_ catalog: EventCatalog, date: String, personal: [CalendarEvent] = [], calendar: CalendarData = .shared) -> DayProgram {
        let base = calendar.dailyProgram(date)
        let matches = matching(catalog, date: date, personal: personal, calendar: calendar)
        var result: DayProgram
        if let top = matches.first {
            result = DayProgram(id: top.id, title: top.title, caption: top.caption, kind: top.kind ?? "", tone: top.tone ?? "",
                                actions: top.actions, effectIDs: [top.effect ?? base.effect])
        } else {
            result = DayProgram(id: base.id, title: base.title, caption: base.caption, kind: base.kind, tone: base.tone,
                                actions: base.actions, effectIDs: [base.effect])
        }
        result.date = date
        result.dailyTitle = base.title
        result.matches = matches
        result.lunar = calendar.lunar(date)
        // A memorial always keeps the whole scene quiet, even if it is also a birthday.
        if matches.contains(where: { ($0.tone ?? "joyful") == "solemn" }) {
            result.tone = "solemn"
            result.actions = ["idle", "notice"]
            result.effectIDs = ["candle_garland"]
        } else {
            for event in matches {
                let effect = event.effect ?? base.effect
                if !result.effectIDs.contains(effect) && result.effectIDs.count < 2 { result.effectIDs.append(effect) }
            }
        }
        return result
    }
}
