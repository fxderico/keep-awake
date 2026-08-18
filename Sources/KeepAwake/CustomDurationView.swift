import SwiftUI

struct CustomDurationView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Int

    init() {
        _minutes = State(initialValue: PreferencesStore.customMinutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keep Awake for a custom duration")
                .font(.headline)

            Stepper(value: $minutes, in: 1...600, step: 5) {
                Text("\(minutes) minutes")
                    .monospacedDigit()
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Start") {
                    appState.customMinutes = minutes
                    appState.start(preset: .custom, customMinutesOverride: minutes)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 280)
    }
}
