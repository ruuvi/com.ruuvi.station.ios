import Foundation

public extension Notification.Name {
    static let RuuviAuthServiceWillLogout =
        Notification.Name("RuuviServiceAuth.RuuviAuthServiceWillLogout")
    static let RuuviAuthServiceLogoutDidFinish =
        Notification.Name("RuuviServiceAuth.RuuviAuthServiceLogoutDidFinish")
    static let RuuviAuthServiceDidLogout =
        Notification.Name("RuuviServiceAuth.RuuviAuthServiceDidLogout")
}

public enum RuuviAuthServiceLogoutDidFinishKey: String {
    case success
}

// MIGRATE: 1 declaration audited for async/await migration.
public protocol RuuviServiceAuth {
    func logout() async throws -> Bool
}
