import CompanionCore
import Foundation
import WatchConnectivity

/// Mirrors the chosen city, the location switch and personal anniversaries from iPhone to Watch.
/// Bond, journal and energy stay on each device, like two separate yards visited by the same 阿晴.
@MainActor
final class WatchSync: NSObject, WCSessionDelegate {
    private let model: CompanionModel
    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    init(model: CompanionModel) {
        self.model = model
        super.init()
        guard let session else { return }
        session.delegate = self
        session.activate()
        #if os(iOS)
        model.onSyncableChange = { [weak self] in self?.push() }
        #endif
    }

    #if os(iOS)
    func push() {
        guard let session, session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        try? session.updateApplicationContext(model.syncPayload())
    }
    #endif

    func apply(_ data: Data) {
        guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any], !payload.isEmpty else { return }
        model.applySync(payload)
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        let received = (try? JSONSerialization.data(withJSONObject: session.receivedApplicationContext)) ?? Data()
        Task { @MainActor in
            #if os(iOS)
            self.push()
            #else
            self.apply(received)
            #endif
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: context) else { return }
        Task { @MainActor in self.apply(data) }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.push() }
    }
    #endif
}

/// Launch arguments for simulator checks and screenshots, e.g. `-demo rain -sheet weather`.
/// Any of them starts the app in a demo that never writes the save file.
struct LaunchOptions {
    let defaults = UserDefaults.standard
    var demo: String? { defaults.string(forKey: "demo") }
    var sheet: String? { defaults.string(forKey: "sheet") }
    var previewDate: String? { defaults.string(forKey: "previewDate") }
    var festival: String? { defaults.string(forKey: "festival") }
    var effect: String? { defaults.string(forKey: "effect") }
    var quiet: Bool { defaults.bool(forKey: "quiet") }
    var active: Bool { demo != nil || previewDate != nil || festival != nil || effect != nil }

    @MainActor
    func apply(to model: CompanionModel) {
        model.startDemo(demo ?? "clear")
        if let date = previewDate { model.previewDate(date) }
        if let id = festival, let event = model.catalog.events.first(where: { $0.id == id }) { model.previewFestival(event) }
        if let id = effect { model.previewEffect(id) }
        if quiet { model.setQuietMode(true) }
        if let sheet { model.sheet = CompanionModel.Sheet(rawValue: sheet) }
    }
}
