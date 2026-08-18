import Foundation

/// The duration options shown in the menu.
enum DurationPreset: String, CaseIterable, Identifiable {
    case indefinite
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case twoHours
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .indefinite: return "Indefinite"
        case .fifteenMinutes: return "15 Minutes"
        case .thirtyMinutes: return "30 Minutes"
        case .oneHour: return "1 Hour"
        case .twoHours: return "2 Hours"
        case .custom: return "Custom…"
        }
    }

    /// Fixed duration in seconds, or nil for `.indefinite` / `.custom`
    /// (custom's duration comes from user input, indefinite has none).
    var seconds: TimeInterval? {
        switch self {
        case .indefinite: return nil
        case .fifteenMinutes: return 15 * 60
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .twoHours: return 2 * 60 * 60
        case .custom: return nil
        }
    }
}
