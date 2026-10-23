import CompanionCore
import SwiftUI

@main
struct WeatherPetApp: App {
    @State private var model: CompanionModel
    @State private var sync: WatchSync
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let model = CompanionModel(storage: CompanionModel.defaultStorage(), location: DeviceLocation())
        let launch = LaunchOptions()
        if launch.active || launch.sheet != nil || launch.quiet {
            launch.apply(to: model)
        } else {
            model.start()
        }
        _model = State(initialValue: model)
        _sync = State(initialValue: WatchSync(model: model))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
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
