import Foundation

/// Thin, testable wrapper around UserDefaults-backed preferences.
/// (The SwiftUI views themselves read/write these same keys via @AppStorage
/// so the menu stays in sync with zero extra glue.)
enum PreferencesStore {
    enum Keys {
        static let mode = "keepAwake.mode"
        static let selectedPreset = "keepAwake.selectedPreset"
        static let customMinutes = "keepAwake.customMinutes"
        static let batterySafeguardEnabled = "keepAwake.batterySafeguardEnabled"
        static let launchAtLoginEnabled = "keepAwake.launchAtLoginEnabled"
    }

    static var mode: SleepPreventionMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: Keys.mode),
                  let value = SleepPreventionMode(rawValue: raw) else { return .system }
            return value
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.mode) }
    }

    static var selectedPreset: DurationPreset {
        get {
            guard let raw = UserDefaults.standard.string(forKey: Keys.selectedPreset),
                  let value = DurationPreset(rawValue: raw) else { return .indefinite }
            return value
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.selectedPreset) }
    }

    static var customMinutes: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: Keys.customMinutes)
            return value > 0 ? value : 45
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.customMinutes) }
    }

    static var batterySafeguardEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.batterySafeguardEnabled) == nil { return true }
            return UserDefaults.standard.bool(forKey: Keys.batterySafeguardEnabled)
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.batterySafeguardEnabled) }
    }

    static var launchAtLoginEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.launchAtLoginEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.launchAtLoginEnabled) }
    }
}
