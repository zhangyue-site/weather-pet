import CompanionCore
import CompanionScene
import SwiftUI

/// Main screen: the yard, the weather HUD on top and 阿晴's card at the bottom (`main.gd::_build_ui`).
struct ContentView: View {
    @Bindable var model: CompanionModel
    @State private var cardHeight: CGFloat = 170

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                CompanionSceneView(model: model, groundInset: cardHeight + geo.safeAreaInsets.bottom)
                TimelineView(.periodic(from: .now, by: 0.2)) { _ in
                    let hud = model.hud()
                    ZStack(alignment: .top) {
                        if !model.quietMode { TopHUD(hud: hud, model: model) }
                        VStack {
                            Spacer()
                            BottomCard(hud: hud, model: model)
                                .background(GeometryReader { card in
                                    Color.clear.preference(key: CardHeightKey.self, value: card.size.height)
                                })
                        }
                    }
                }
            }
        }
        .onPreferenceChange(CardHeightKey.self) { cardHeight = $0 + 12 }
        .background(Color.black)
        .sheet(item: $model.sheet) { sheet in
            SheetRoot(kind: sheet, model: model)
                .presentationDetents([.fraction(0.62), .large])
                .presentationBackground(Palette.cream)
                .presentationCornerRadius(26)
                .presentationDragIndicator(.visible)
        }
        .statusBarHidden(model.quietMode)
        // Light status bar over the painted sky; sheets switch back to light themselves.
        .preferredColorScheme(.dark)
    }
}

private struct CardHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 170
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct TopHUD: View {
    let hud: HUD
    let model: CompanionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("小院天气")
                    .font(.system(size: 20, weight: .medium))
                Spacer()
                Text(hud.clock)
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
            HStack(alignment: .top) {
                Text(hud.temperature)
                    .font(.system(size: 58, weight: .light).monospacedDigit())
                    .contentTransition(.numericText())
                Spacer()
                Button("设置") { model.sheet = .settings }
                    .buttonStyle(PillButtonStyle(compact: true))
                    .frame(width: 64)
                    .padding(.top, 10)
            }
            .padding(.top, 2)
            Text(hud.details)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.92))
            Text(hud.source)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.72))
                .padding(.top, 4)
            if !hud.festival.isEmpty {
                Text(hud.festival)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.festival)
                    .lineLimit(1)
                    .padding(.top, 14)
            }
            Text(hud.calendar)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.88))
                .padding(.top, 6)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        .padding(.horizontal, 22)
        .padding(.top, 4)
    }
}

private struct BottomCard: View {
    let hud: HUD
    let model: CompanionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("阿晴的小日子")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.teal)
                Spacer()
                Text(hud.bond)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
            }
            Text(hud.status)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            Text(hud.caption)
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
            HStack(spacing: 8) {
                Button("天气") { model.sheet = .weather }
                Button("陪伴") { model.sheet = .care }.buttonStyle(PillButtonStyle(active: true))
                Button("日历") { model.sheet = .festivals }
            }
            .buttonStyle(PillButtonStyle())
            .padding(.top, 2)
        }
        .padding(16)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }
}

/// Godot's flat rounded buttons: cream, or teal when active.
struct PillButtonStyle: ButtonStyle {
    var active = false
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 15 : 16))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(active || configuration.isPressed ? .white : Palette.ink)
            .frame(maxWidth: .infinity, minHeight: compact ? 34 : 44)
            .padding(.horizontal, 6)
            .background(configuration.isPressed ? Palette.tealPressed : (active ? Palette.teal : Palette.button),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
    }
}
