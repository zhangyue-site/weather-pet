import CompanionCore
import SwiftUI

@main
struct WeatherPetWatchApp: App {
    @State private var model: CompanionModel
    @State private var sync: WatchSync
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let model = CompanionModel(storage: CompanionModel.defaultStorage(), location: DeviceLocation())
        let launch = LaunchOptions()
        if launch.active {
            launch.apply(to: model)
        } else {
            model.start()
        }
        _model = State(initialValue: model)
        _sync = State(initialValue: WatchSync(model: model))
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView(model: model)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.resume()
            case .background: model.suspend()
            default: break
            }
        }
    }
}
