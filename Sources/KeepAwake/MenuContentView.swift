import SwiftUI
import AppKit

struct MenuContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // Status header
        Text(appState.isActive ? "Keep Awake: On" : "Keep Awake: Off")
        if let remaining = appState.remainingLabel {
            Text(remaining)
        }

        Divider()

        Button(appState.isActive ? "Turn Off" : "Turn On") {
            appState.toggle()
        }

        Divider()

        Menu("Duration") {
            ForEach(DurationPreset.allCases) { preset in
                Button {
                    handleSelect(preset)
                } label: {
                    HStack {
                        Text(preset.title)
                        if appState.selectedPreset == preset {
                            Text("✓")
                        }
                    }
                }
            }
        }

        Menu("Prevent") {
            ForEach(SleepPreventionMode.allCases) { mode in
                Button {
                    appState.changeMode(mode)
                } label: {
                    HStack {
                        Text(mode.title)
                        if appState.mode == mode {
                            Text("✓")
                        }
                    }
                }
            }
        }

        Divider()

        Toggle("Battery Safeguard (auto-off below 20%)", isOn: $appState.batterySafeguardEnabled)
        Toggle("Launch at Login", isOn: $appState.launchAtLoginEnabled)

        Divider()

        Button("Quit Keep Awake") {
            NSApplication.shared.terminate(nil)
        }
    }

    private func handleSelect(_ preset: DurationPreset) {
        if preset == .custom {
            openWindow(id: "custom-duration")
            return
        }
        appState.selectedPreset = preset
        if appState.isActive {
            appState.start(preset: preset)
        }
    }
}
