import SwiftUI

@main
struct RuuviWatchApp: App {

    init() {
        WatchSessionManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                SensorListView()
            }
        }
    }
}
