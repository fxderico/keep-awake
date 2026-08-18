import Foundation
import IOKit.pwr_mgt

/// The two flavors of "keep awake" the app supports.
enum SleepPreventionMode: String, CaseIterable, Identifiable {
    case system  // Prevents idle system sleep; display may still sleep normally.
    case display // Prevents display sleep (and, as a consequence, system sleep).

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Prevent System Sleep"
        case .display: return "Prevent Display Sleep"
        }
    }
}

/// Owns the low-level power-management assertions that actually keep the Mac awake.
///
/// Two independent mechanisms are held simultaneously while active, matching the
/// requirement to use both `IOPMAssertionCreateWithName` and
/// `ProcessInfo.processInfo.beginActivity`:
///   1. An IOKit power assertion (fine-grained: system-only vs display+system).
///   2. A `ProcessInfo` activity token (a higher-level, Swift-native equivalent that
///      also communicates app intent to the system, e.g. for App Nap suppression).
final class PowerManager: ObservableObject {

    @Published private(set) var isActive: Bool = false
    @Published private(set) var activeMode: SleepPreventionMode?
    @Published private(set) var expiresAt: Date?

    private var assertionID: IOPMAssertionID = 0
    private var hasAssertion = false
    private var processActivity: NSObjectProtocol?
    private var timeoutTimer: Timer?

    /// Called whenever the manager auto-stops itself (timeout, battery safeguard, shutdown).
    var onAutoStop: (() -> Void)?

    // MARK: - Public API

    /// Begin preventing sleep. `duration == nil` means indefinite.
    func start(mode: SleepPreventionMode, duration: TimeInterval?, reason: String = "User requested Keep Awake") {
        stop() // Clear any existing assertion first.

        let assertionType: CFString = {
            switch mode {
            case .system:
                return kIOPMAssertionTypePreventUserIdleSystemSleep as CFString
            case .display:
                return kIOPMAssertionTypeNoDisplaySleep as CFString
            }
        }()

        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            assertionType,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &id
        )

        if result == kIOReturnSuccess {
            assertionID = id
            hasAssertion = true
        } else {
            hasAssertion = false
            NSLog("KeepAwake: IOPMAssertionCreateWithName failed with result \(result)")
        }

        let activityOptions: ProcessInfo.ActivityOptions = mode == .display
            ? [.idleSystemSleepDisabled, .idleDisplaySleepDisabled, .userInitiated]
            : [.idleSystemSleepDisabled, .userInitiated]

        processActivity = ProcessInfo.processInfo.beginActivity(options: activityOptions, reason: reason)

        isActive = true
        activeMode = mode

        if let duration {
            let fireDate = Date().addingTimeInterval(duration)
            expiresAt = fireDate
            let timer = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
                self?.stop()
                self?.onAutoStop?()
            }
            RunLoop.main.add(timer, forMode: .common)
            timeoutTimer = timer
        } else {
            expiresAt = nil
        }
    }

    /// Stop preventing sleep and release all held assertions/activities.
    func stop() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil

        if hasAssertion {
            IOPMAssertionRelease(assertionID)
            hasAssertion = false
            assertionID = 0
        }

        if let processActivity {
            ProcessInfo.processInfo.endActivity(processActivity)
        }
        processActivity = nil

        isActive = false
        activeMode = nil
        expiresAt = nil
    }

    /// Remaining time until the assertion auto-expires, or nil if indefinite/inactive.
    var remainingTime: TimeInterval? {
        guard let expiresAt else { return nil }
        return max(0, expiresAt.timeIntervalSinceNow)
    }
}
