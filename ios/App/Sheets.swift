import CompanionCore
import CompanionScene
import SwiftUI

/// The bottom sheet and its sub pages (`main.gd::_open_sheet`).
struct SheetRoot: View {
    let kind: CompanionModel.Sheet
    let model: CompanionModel

    var body: some View {
        NavigationStack {
            Group {
                switch kind {
                case .weather: WeatherSheet(model: model)
                case .care: CareSheet(model: model)
                case .festivals: FestivalsSheet(model: model)
                case .settings: SettingsSheet(model: model)
                }
            }
            .navigationDestination(for: Page.self) { page in
                switch page {
                case .journal: JournalPage(model: model)
                case .anniversaries: AnniversaryPage(model: model)
                case .effects: EffectLibraryPage(model: model)
                case .festivalLibrary: FestivalLibraryPage(model: model)
                case .updates: UpdatesPage(model: model)
                }
            }
        }
        .tint(Palette.teal)
        .preferredColorScheme(.light)
    }
}

enum Page: Hashable {
    case journal, anniversaries, effects, festivalLibrary, updates
}

/// Scrollable sheet body with the Godot heading row: title, subtitle and a 收起 button.
struct SheetPage<Content: View>: View {
    let title: String
    let subtitle: String
    var showsClose = true
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    if showsClose {
                        Button("收起") { dismiss() }
                            .buttonStyle(PillButtonStyle(compact: true))
                            .frame(width: 76)
                    }
                }
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                content
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.cream)
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Sub page variant that keeps the navigation bar for going back.
struct SubPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                content
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .background(Palette.cream)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.cream, for: .navigationBar)
    }
}

let fourColumns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 4)

// MARK: Weather

struct WeatherSheet: View {
    let model: CompanionModel

    var body: some View {
        SheetPage(title: "小院的每一种天气", subtitle: "让阿晴陪你看看，不一样的天空。") {
            LazyVGrid(columns: fourColumns, spacing: 8) {
                ForEach(Catalog.ids, id: \.self) { id in
                    Button(Catalog.title(id)) {
                        model.setDemo(id)
                        model.sheet = nil
                    }
                    .buttonStyle(PillButtonStyle(active: model.mode == .demo && model.world.environment.id == id))
                }
            }
            Button("自动漫游  ·  依次看遍 16 种场景") { model.startTour() }
                .buttonStyle(PillButtonStyle())
            Button("回到真实天气") { model.useLive() }
                .buttonStyle(PillButtonStyle(active: true))
        }
    }
}

// MARK: Care

struct CareSheet: View {
    let model: CompanionModel
    static let entries = [("摸摸头", "pet"), ("打个招呼", "wave"), ("一起喝热饮", "drink"), ("休息一会儿", "sleep"), ("看看小植物", "water")]

    var body: some View {
        SheetPage(title: "陪阿晴待一会儿", subtitle: "一杯热饮，一次摸头，都是今天的小事。") {
            NavigationLink("陪伴日记", value: Page.journal)
                .buttonStyle(PillButtonStyle())
            if model.quietMode {
                Button("返回正常视图") { model.setQuietMode(false) }
                    .buttonStyle(PillButtonStyle())
            }
            ForEach(Self.entries, id: \.1) { entry in
                Button(entry.0) {
                    model.care(entry.1)
                    model.sheet = nil
                }
                .buttonStyle(PillButtonStyle())
            }
            Text("精力 \(Int(model.world.energy)) / 100     心情 \(Int(model.world.joy)) / 100")
                .font(.system(size: 14))
                .foregroundStyle(Palette.teal)
        }
    }
}

struct JournalPage: View {
    let model: CompanionModel

    var body: some View {
        SubPage(title: "一起的小日子", subtitle: "已经一起遇见 \(model.world.discovered.count) / 16 种天气与时刻。") {
            if model.world.journal.isEmpty {
                Text("今天会留下第一件小事。")
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.muted)
            }
            ForEach(model.world.journal) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.time)
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(Palette.muted)
                    Text(entry.text)
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Palette.button, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

// MARK: Calendar

struct FestivalsSheet: View {
    let model: CompanionModel
    @State private var date = Date()

    var body: some View {
        let program = model.todayProgram()
        SheetPage(title: "今天与每一天", subtitle: "全年每日主题，叠加农历、公历、节气和你的纪念日。") {
            Text(program.dailyTitle)
                .font(.system(size: 16))
                .foregroundStyle(Palette.teal)
            ForEach(program.matches) { event in
                Text("今天 · " + event.title)
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.ink)
            }
            if program.matches.isEmpty {
                Text("今天没有额外节日，也有日常小节目。")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.muted)
            }
            HStack {
                DatePicker("日期", selection: $date, in: DateBounds.range, displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "zh-Hans"))
                Button("看看这一天") { model.previewDate(DateBounds.string(date)) }
                    .buttonStyle(PillButtonStyle())
            }
            NavigationLink("我的纪念日", value: Page.anniversaries).buttonStyle(PillButtonStyle())
            NavigationLink("200 种特效图鉴", value: Page.effects).buttonStyle(PillButtonStyle())
            NavigationLink("节日与节气目录", value: Page.festivalLibrary).buttonStyle(PillButtonStyle())
            Button("回到今天 · 真实天气") { model.useLive() }
                .buttonStyle(PillButtonStyle(active: true))
            Text(model.eventStatus)
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
        }
        .onAppear {
            if let day = CivilDate(model.today()) { date = DateBounds.date(day) }
        }
    }
}

/// Bridges the date pickers (local dates) and `YYYY-MM-DD` strings.
enum DateBounds {
    static let range = date(CivilDate(year: 1970, month: 1, day: 1))...date(CivilDate(year: 2099, month: 12, day: 31))

    static func date(_ day: CivilDate) -> Date {
        Calendar.current.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12))!
    }

    static func string(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return CivilDate(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1).description
    }
}

struct FestivalLibraryPage: View {
    let model: CompanionModel

    var body: some View {
        SubPage(title: "节日、节气与纪念日", subtitle: "自动使用真实日期；这里可以提前看看。纪念日采用安静的演出。") {
            ForEach(model.catalog.events) { event in
                Button(event.title) { model.previewFestival(event) }
                    .buttonStyle(PillButtonStyle())
            }
        }
    }
}

struct EffectLibraryPage: View {
    @Bindable var model: CompanionModel

    var body: some View {
        let order = model.calendar.effectOrder
        SubPage(title: "特效图鉴 · \(model.effectPage + 1) / 10", subtitle: "20 类图形 × 10 种运动编排，共 200 套程序特效；不是 200 段角色动画。") {
            HStack(spacing: 8) {
                Button("上一页") { model.effectPage = (model.effectPage + 9) % 10 }
                Button("下一页") { model.effectPage = (model.effectPage + 1) % 10 }
            }
            .buttonStyle(PillButtonStyle())
            ForEach(order[(model.effectPage * 20)..<min(order.count, (model.effectPage + 1) * 20)], id: \.self) { id in
                Button(model.calendar.effect(id)?.title ?? id) {
                    model.previewEffect(id)
                    model.sheet = nil
                }
                .buttonStyle(PillButtonStyle())
            }
        }
    }
}

struct AnniversaryPage: View {
    let model: CompanionModel
    @State private var name = ""
    @State private var kind = CompanionModel.AnniversaryCalendar.solarYearly
    @State private var month = 1
    @State private var day = 1
    @State private var fullDate = Date()
    @State private var solemn = false
    @State private var error = ""

    static let lunarMonths = ["正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "冬月", "腊月"]
    static let lunarDays: [String] = {
        let digits = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
        return (1...30).map { d in
            if d <= 10 { return "初" + digits[d - 1] }
            if d < 20 { return "十" + digits[d - 11] }
            if d == 20 { return "二十" }
            if d < 30 { return "廿" + digits[d - 21] }
            return "三十"
        }
    }()

    var lunar: Bool { kind == .lunarYearly || kind == .lunarLeap }

    var body: some View {
        SubPage(title: "我的纪念日", subtitle: "只保存在本机，并同步到配对的 Apple Watch。支持公历、农历每年重复，以及指定日期；不上传私人日期。") {
            ForEach(model.anniversaries) { event in
                HStack {
                    Text(event.title + " · " + event.ruleText)
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Button("删除") { model.removeAnniversary(event.id) }
                        .buttonStyle(PillButtonStyle(compact: true))
                        .frame(width: 64)
                }
            }
            TextField("名称，例如生日、结婚纪念日", text: $name)
                .textFieldStyle(.plain)
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                .onChange(of: name) { _, value in if value.count > 24 { name = String(value.prefix(24)) } }
            Picker("日历", selection: $kind) {
                ForEach(CompanionModel.AnniversaryCalendar.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            if kind == .solarDate {
                DatePicker("日期", selection: $fullDate, in: DateBounds.range, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "zh-Hans"))
            } else {
                HStack {
                    Picker("月", selection: $month) {
                        ForEach(1...12, id: \.self) { m in Text(lunar ? Self.lunarMonths[m - 1] : "\(m) 月").tag(m) }
                    }
                    Picker("日", selection: $day) {
                        ForEach(1...(lunar ? 30 : 31), id: \.self) { d in Text(lunar ? Self.lunarDays[d - 1] : "\(d) 日").tag(d) }
                    }
                }
                .pickerStyle(.menu)
            }
            Picker("方式", selection: $solemn) {
                Text("温暖庆祝").tag(false)
                Text("安静纪念").tag(true)
            }
            .pickerStyle(.segmented)
            if !error.isEmpty {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.error)
            }
            Button("保存纪念日") { save() }
                .buttonStyle(PillButtonStyle(active: true))
        }
        .onChange(of: kind) { _, _ in if day > 30 && lunar { day = 30 } }
    }

    func save() {
        let date = kind == .solarDate ? DateBounds.string(fullDate) : String(format: "%02d-%02d", month, day)
        if let message = model.addAnniversary(title: name, calendar: kind, date: date, solemn: solemn) {
            error = message
        } else {
            error = ""
            name = ""
        }
    }
}

// MARK: Settings

struct SettingsSheet: View {
    let model: CompanionModel

    var body: some View {
        SheetPage(title: "小院设置", subtitle: "选择城市，阿晴就会感受那里的天气。") {
            if model.hasLocation {
                if model.useLocation {
                    Text("自动定位 · " + model.locationTitle)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.muted)
                }
                Button("使用当前位置") { model.useCurrentLocation() }
                    .buttonStyle(PillButtonStyle(active: model.useLocation))
            }
            LazyVGrid(columns: fourColumns, spacing: 8) {
                ForEach(Catalog.cities.indices, id: \.self) { i in
                    Button(Catalog.cities[i].name) { model.chooseCity(i) }
                        .buttonStyle(PillButtonStyle(active: i == model.cityIndex && !model.useLocation))
                }
            }
            NavigationLink("应用更新", value: Page.updates).buttonStyle(PillButtonStyle())
            Button("刷新真实天气") { model.useLive() }
                .buttonStyle(PillButtonStyle(active: true))
            Button("减少动态效果：" + (model.reducedMotion ? "开" : "关")) { model.setReducedMotion(!model.reducedMotion) }
                .buttonStyle(PillButtonStyle())
            Button("安静观赏：" + (model.quietMode ? "开" : "关")) { model.setQuietMode(!model.quietMode) }
                .buttonStyle(PillButtonStyle())
            Text("小院天气 \(model.appVersion) · 阿晴\n天气来自 Open-Meteo，每 15 分钟更新。\n昼夜跟随当地时间与日出日落。\n可使用当前位置，也可手动选择城市。\n体验场景使用示例数据；陪伴记录保存在本机。")
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// iOS updates come from the App Store or TestFlight; only the festival calendar updates itself.
struct UpdatesPage: View {
    let model: CompanionModel

    var body: some View {
        SubPage(title: "应用更新", subtitle: "节日日历会自动从服务器更新；新版应用通过 App Store 或 TestFlight 安装。") {
            Text("当前版本：" + model.appVersion)
                .font(.system(size: 16))
                .foregroundStyle(Palette.teal)
            Text("节日日历：\(model.eventStatus) · 第 \(model.catalog.revision) 版")
                .font(.system(size: 14))
                .foregroundStyle(Palette.ink)
            Button("检查节日日历更新") { model.events.refresh() }
                .buttonStyle(PillButtonStyle(active: true))
        }
    }
}
