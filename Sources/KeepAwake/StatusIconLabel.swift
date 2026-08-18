import SwiftUI

/// The dynamic menu-bar glyph: solid/filled while an assertion is active, outlined/idle otherwise.
struct StatusIconLabel: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Image(systemName: iconName)
    }

    private var iconName: String {
        guard appState.isActive else { return "cup.and.saucer" }
        switch appState.mode {
        case .system: return "cup.and.saucer.fill"
        case .display: return "eye.fill"
        }
    }
}
