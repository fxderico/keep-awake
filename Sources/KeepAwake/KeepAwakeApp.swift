import SwiftUI

@main
struct KeepAwakeApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra(content: {
            MenuContentView()
                .environmentObject(appState)
        }, label: {
            StatusIconLabel()
                .environmentObject(appState)
        })
        .menuBarExtraStyle(.menu)

        Window("Custom Duration", id: "custom-duration") {
            CustomDurationView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)
    }
}
