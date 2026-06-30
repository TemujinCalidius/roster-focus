import Foundation
import ServiceManagement

/// Launch-at-login via SMAppService (macOS 13+). The app registers itself; the user
/// may need to approve it under System Settings › General › Login Items.
public enum LoginItem {
    @discardableResult
    public static func register() -> Bool {
        do { try SMAppService.mainApp.register(); return true }
        catch { return false }
    }

    @discardableResult
    public static func unregister() -> Bool {
        do { try SMAppService.mainApp.unregister(); return true }
        catch { return false }
    }

    public static var status: SMAppService.Status { SMAppService.mainApp.status }
    public static var isEnabled: Bool { status == .enabled }
}
