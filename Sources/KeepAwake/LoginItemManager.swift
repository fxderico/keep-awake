import Foundation
import ServiceManagement

/// Thin wrapper around `SMAppService` for "Launch at Login".
enum LoginItemManager {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled { return true }
                try SMAppService.mainApp.register()
            } else {
                if SMAppService.mainApp.status != .enabled { return true }
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("KeepAwake: LoginItemManager failed to set enabled=\(enabled): \(error)")
            return false
        }
    }
}
