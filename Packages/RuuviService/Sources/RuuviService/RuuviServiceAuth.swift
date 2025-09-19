import Foundation

public extension Notification.Name {
    static let RuuviAuthServiceDidLogout =
        Notification.Name("RuuviServiceAuth.RuuviAuthServiceDidLogout")
}

public protocol RuuviServiceAuth {
    func logout() async throws -> Bool
}
