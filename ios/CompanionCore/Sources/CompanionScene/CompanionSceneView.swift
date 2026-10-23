import CompanionCore
import SwiftUI

/// The animated yard. Maps the view to Godot's 540-unit logical width so every distance,
/// speed and size from the Android version carries over unchanged.
public struct CompanionSceneView: View {
    public enum Touch: Sendable {
        /// Press-and-release with duration (iPhone): long press or head touch pets, tap waves.
        case press
        /// Plain taps (Watch, where drags belong to page scrolling).
        case tap
    }

    let model: CompanionModel
    let groundInset: CGFloat
    let touch: Touch
    let options: SceneRenderer.Options
    let frameInterval: Double?
    @State private var pressStart: Date?

    /// - Parameter groundInset: height at the bottom covered by UI; 阿晴 stands above it.
    public init(model: CompanionModel, groundInset: CGFloat = 0, touch: Touch = .press,
                options: SceneRenderer.Options = .init(), frameInterval: Double? = nil) {
        self.model = model
        self.groundInset = groundInset
        self.touch = touch
        self.options = options
        self.frameInterval = frameInterval
    }

    public var body: some View {
        GeometryReader { geo in
            let k = max(geo.size.width, 1) / SceneLayout.logicalWidth
            let logical = CGSize(width: SceneLayout.logicalWidth, height: geo.size.height / k)
            let ground = (geo.size.height - groundInset - 8) / k
            TimelineView(.animation(minimumInterval: options.lowPower ? 1 : frameInterval, paused: false)) { timeline in
                Canvas { ctx, _ in
                    model.frame(at: timeline.date, size: logical, groundLimit: ground, bodyScale: options.bodyScale)
                    ctx.scaleBy(x: k, y: k)
                    SceneRenderer(model: model, options: options).draw(in: &ctx)
                }
            }
            .contentShape(Rectangle())
            .modifier(TouchModifier(touch: touch, scale: k, model: model, pressStart: $pressStart))
            .accessibilityElement()
            .accessibilityLabel("阿晴在小院里")
            .accessibilityHint("轻点打招呼，长按摸摸头")
            .accessibilityAddTraits(.allowsDirectInteraction)
        }
        .ignoresSafeArea()
    }
}

private struct TouchModifier: ViewModifier {
    let touch: CompanionSceneView.Touch
    let scale: CGFloat
    let model: CompanionModel
    @Binding var pressStart: Date?

    func body(content: Content) -> some View {
        switch touch {
        case .press:
            content.gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if pressStart == nil { pressStart = value.time }
                    }
                    .onEnded { value in
                        let duration = value.time.timeIntervalSince(pressStart ?? value.time)
                        pressStart = nil
                        model.touch(start: logical(value.startLocation), end: logical(value.location), duration: duration)
                    })
        case .tap:
            content.onTapGesture(coordinateSpace: .local) { location in
                model.touch(start: logical(location), end: logical(location), duration: 0)
            }
        }
    }

    func logical(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x / scale, y: p.y / scale) }
}
