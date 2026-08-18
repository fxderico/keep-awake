import Foundation
import IOKit.ps

/// Polls the system power source (battery) so the app can auto-disable Keep Awake
/// when the battery drops below a safety threshold and the Mac is not on AC power.
final class BatteryMonitor: ObservableObject {

    @Published private(set) var currentCharge: Int? // 0...100, nil if no battery (desktop Mac)
    @Published private(set) var isOnACPower: Bool = true

    /// Fires when charge drops below `threshold` while unplugged.
    var onLowBattery: ((Int) -> Void)?

    private var threshold: Int = 20
    private var timer: Timer?
    private var lastAlertedBelowThreshold = false

    func startMonitoring(threshold: Int, interval: TimeInterval = 60) {
        self.threshold = threshold
        refresh()
        timer?.invalidate()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func updateThreshold(_ newThreshold: Int) {
        threshold = newThreshold
        lastAlertedBelowThreshold = false
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]
        else {
            // No battery present (desktop Mac) — treat as always on AC, no safeguard needed.
            currentCharge = nil
            isOnACPower = true
            return
        }

        let capacity = description[kIOPSCurrentCapacityKey] as? Int
        let powerState = description[kIOPSPowerSourceStateKey] as? String

        currentCharge = capacity
        isOnACPower = (powerState == kIOPSACPowerValue)

        if let capacity, !isOnACPower, capacity < threshold {
            if !lastAlertedBelowThreshold {
                lastAlertedBelowThreshold = true
                onLowBattery?(capacity)
            }
        } else {
            lastAlertedBelowThreshold = false
        }
    }
}
