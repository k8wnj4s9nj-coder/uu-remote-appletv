import SwiftUI
// Protocol sources are compiled into this target

@main
struct UURemoteTVApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
        }
    }
}
