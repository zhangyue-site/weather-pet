import CompanionCore
import CompanionScene
import SwiftUI

/// Apple Watch: the yard first, then today, care and more, as vertical pages.
///
/// Trade-offs against the phone: no anniversary editor (they sync from iPhone), no date picker
/// or 200-effect gallery, fewer weather particles, and a still frame on the always-on display.
struct WatchContentView: View {
    let model: CompanionModel
    @State private var page = Tab.yard

    enum Tab: Hashable { case yard, today, care, more }

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                YardPage(model: model).tag(Tab.yard)
                TodayPage(model: model).tag(Tab.today)
                CarePage(model: model) { page = .yard }.tag(Tab.care)
                MorePage(model: model).tag(Tab.more)
            }
            .tabViewStyle(.verticalPage)
        }
    }
}

private struct YardPage: View {
    let model: CompanionModel
    @Environment(\.isLuminanceReduced) private var lowPower

    var body: some View {
        ZStack {
            CompanionSceneView(model: model, groundInset: 26, touch: .tap,
                               options: .init(particles: 0.5, lowPower: lowPower, bodyScale: 1.45, lineScale: 2.2), frameInterval: 1.0 / 30)
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                let hud = model.hud()
                VStack(alignment: .leading, spacing: 0) {
                    Text(hud.temperature)
                        .font(.system(size: 34, weight: .light).monospacedDigit())
                    Text(model.world.environment.title)
                        .font(.system(size: 13))
                        .opacity(0.9)
                    Spacer()
                    Text(hud.status)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.35), in: Capsule())
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                .padding(.horizontal, 8)
                .padding(.top, 2)
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .opacity(lowPower ? 0.6 : 1)
    }
}

private struct TodayPage: View {
    let model: CompanionModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let hud = model.hud()
            let program = model.todayProgram()
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Text(hud.temperature + "  " + model.world.environment.title)
                        .font(.system(size: 22, weight: .light))
                    Text(hud.details).font(.footnote).foregroundStyle(.secondary)
                    Text(hud.clock).font(.footnote)
                    Text(hud.source).font(.caption2).foregroundStyle(.secondary)
                    Divider()
                    if !hud.festival.isEmpty {
                        Text(hud.festival).font(.headline).foregroundStyle(Palette.festival)
                    }
                    Text(hud.calendar).font(.footnote)
                    Text(program.dailyTitle).font(.footnote).foregroundStyle(Palette.festival.opacity(0.8))
                    ForEach(program.matches) { event in
                        Text("今天 · " + event.title).font(.footnote)
                    }
                    Divider()
                    Text(hud.caption).font(.footnote).foregroundStyle(.secondary)
                    Text("\(hud.bond) · 精力 \(Int(model.world.energy)) · 心情 \(Int(model.world.joy))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("今天")
    }
}

private struct CarePage: View {
    let model: CompanionModel
    let done: () -> Void
    static let entries = [("摸摸头", "pet", "hand.raised"), ("打个招呼", "wave", "hand.wave"), ("一起喝热饮", "drink", "cup.and.saucer"), ("休息一会儿", "sleep", "moon.zzz"), ("看看小植物", "water", "leaf")]

    var body: some View {
        List {
            ForEach(Self.entries, id: \.1) { entry in
                Button {
                    model.care(entry.1)
                    done()
                } label: {
                    Label(entry.0, systemImage: entry.2)
                }
            }
            NavigationLink {
                JournalList(model: model)
            } label: {
                Label("陪伴日记", systemImage: "book")
            }
        }
        .navigationTitle("陪伴")
    }
}

private struct JournalList: View {
    let model: CompanionModel

    var body: some View {
        List {
            Text("已经一起遇见 \(model.world.discovered.count) / 16 种天气与时刻。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if model.world.journal.isEmpty { Text("今天会留下第一件小事。") }
            ForEach(model.world.journal) { entry in
                VStack(alignment: .leading) {
                    Text(entry.time).font(.caption2).foregroundStyle(.secondary)
                    Text(entry.text).font(.footnote)
                }
            }
        }
        .navigationTitle("一起的小日子")
    }
}

private struct MorePage: View {
    let model: CompanionModel

    var body: some View {
        List {
            NavigationLink { ScenePicker(model: model) } label: { Label("天气体验", systemImage: "cloud.sun") }
            NavigationLink { CityPicker(model: model) } label: { Label("城市", systemImage: "location") }
            NavigationLink { FestivalList(model: model) } label: { Label("节日目录", systemImage: "calendar") }
            Button { model.useLive() } label: { Label("回到真实天气", systemImage: "arrow.clockwise") }
            Toggle("减少动态效果", isOn: Binding(get: { model.reducedMotion }, set: { model.setReducedMotion($0) }))
            Section {
                Text("小院天气 \(model.appVersion)\n天气来自 Open-Meteo，每 15 分钟更新。纪念日在 iPhone 上设置后同步过来。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("更多")
    }
}

private struct ScenePicker: View {
    let model: CompanionModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Button("自动漫游 · 16 种场景") {
                model.startTour()
                dismiss()
            }
            ForEach(Catalog.ids, id: \.self) { id in
                Button {
                    model.setDemo(id)
                    dismiss()
                } label: {
                    HStack {
                        Text(Catalog.title(id))
                        Spacer()
                        if model.mode == .demo && model.world.environment.id == id { Image(systemName: "checkmark") }
                    }
                }
            }
        }
        .navigationTitle("天气体验")
    }
}

private struct CityPicker: View {
    let model: CompanionModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if model.hasLocation {
                Button {
                    model.useCurrentLocation()
                    dismiss()
                } label: {
                    HStack {
                        Label("当前位置", systemImage: "location.fill")
                        Spacer()
                        if model.useLocation { Image(systemName: "checkmark") }
                    }
                }
            }
            ForEach(Catalog.cities.indices, id: \.self) { i in
                Button {
                    model.chooseCity(i)
                    dismiss()
                } label: {
                    HStack {
                        Text(Catalog.cities[i].name)
                        Spacer()
                        if !model.useLocation && model.cityIndex == i { Image(systemName: "checkmark") }
                    }
                }
            }
        }
        .navigationTitle("城市")
    }
}

private struct FestivalList: View {
    let model: CompanionModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(model.catalog.events) { event in
                Button(event.title) {
                    model.previewFestival(event)
                    dismiss()
                }
            }
        }
        .navigationTitle("节日目录")
    }
}
