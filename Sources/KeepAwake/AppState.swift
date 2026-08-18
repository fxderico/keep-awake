import Foundation
import Combine
import AppKit
import UserNotifications

/// Central coordinator: owns power management, battery safeguard, and persisted
/// preferences, and exposes everything the SwiftUI menu needs to render.
final class AppState: ObservableObject {

    // MARK: - Persisted preferences (AppStorage-backed via PreferencesStore)

    @Published var mode: SleepPreventionMode {
        didSet { PreferencesStore.mode = mode }
    }
    @Published var selectedPreset: DurationPreset {
        didSet { PreferencesStore.selectedPreset = selectedPreset }
    }
    @Published var customMinutes: Int {
        didSet { PreferencesStore.customMinutes = customMinutes }
    }
    @Published var batterySafeguardEnabled: Bool {
        didSet { PreferencesStore.batterySafeguardEnabled = batterySafeguardEnabled }
    }
    @Published var launchAtLoginEnabled: Bool {
        didSet {
            PreferencesStore.launchAtLoginEnabled = launchAtLoginEnabled
            LoginItemManager.setEnabled(launchAtLoginEnabled)
        }
    }

    // MARK: - Live state

    @Published private(set) var isActive: Bool = false
    @Published private(set) var remainingLabel: String?
    @Published private(set) var batteryLevel: Int?

    let powerManager = PowerManager()
    private let batteryMonitor = BatteryMonitor()
    private var countdownTimer: Timer?

    init() {
        mode = PreferencesStore.mode
        selectedPreset = PreferencesStore.selectedPreset
        customMinutes = PreferencesStore.customMinutes
        batterySafeguardEnabled = PreferencesStore.batterySafeguardEnabled
        launchAtLoginEnabled = LoginItemManager.isEnabled

        powerManager.onAutoStop = { [weak self] in
            DispatchQueue.main.async {
                self?.handleAutoStop(reason: "timer elapsed")
            }
        }

        batteryMonitor.onLowBattery = { [weak self] level in
            DispatchQueue.main.async {
                self?.handleLowBattery(level: level)
            }
        }

        batteryMonitor.startMonitoring(threshold: 20)

        // Release assertions cleanly on quit / logout / shutdown.
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleWillTerminate),
            name: NSApplication.willTerminateNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(handleWillTerminate),
            name: NSWorkspace.willPowerOffNotification, object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - Actions

    func toggle() {
        isActive ? stop() : start(preset: selectedPreset)
    }

    func start(preset: DurationPreset, customMinutesOverride: Int? = nil) {
        selectedPreset = preset

        let duration: TimeInterval?
        switch preset {
        case .indefinite:
            duration = nil
        case .custom:
            let minutes = customMinutesOverride ?? customMinutes
            duration = TimeInterval(max(1, minutes) * 60)
        default:
            duration = preset.seconds
        }

        powerManager.start(mode: mode, duration: duration)
        isActive = true
        startCountdownTicker()
    }

    func stop() {
        powerManager.stop()
        isActive = false
        remainingLabel = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    func changeMode(_ newMode: SleepPreventionMode) {
        mode = newMode
        // If currently active, restart under the new mode preserving remaining time.
        guard isActive else { return }
        let remaining = powerManager.remainingTime
        powerManager.start(mode: newMode, duration: remaining)
    }

    // MARK: - Private

    private func startCountdownTicker() {
        countdownTimer?.invalidate()
        updateRemainingLabel()
        guard powerManager.expiresAt != nil else {
            remainingLabel = nil
            return
        }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateRemainingLabel()
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    private func updateRemainingLabel() {
        guard let remaining = powerManager.remainingTime else {
            remainingLabel = nil
            return
        }
        if remaining <= 0 {
            remainingLabel = nil
            return
        }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        if hours > 0 {
            remainingLabel = String(format: "%d:%02d:%02d remaining", hours, minutes, seconds)
        } else {
            remainingLabel = String(format: "%d:%02d remaining", minutes, seconds)
        }
    }

    private func handleAutoStop(reason: String) {
        isActive = false
        remainingLabel = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        NSLog("KeepAwake: auto-stopped (\(reason))")
    }

    private func handleLowBattery(level: Int) {
        batteryLevel = level
        guard batterySafeguardEnabled, isActive else { return }
        stop()
        NSLog("KeepAwake: battery safeguard triggered at \(level)%")
        notifyLowBatteryDisabled(level: level)
    }

    @objc private func handleWillTerminate() {
        powerManager.stop()
    }

    private func notifyLowBatteryDisabled(level: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Keep Awake Disabled"
        content.body = "Battery dropped to \(level)% — Keep Awake was turned off to protect your battery."
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
