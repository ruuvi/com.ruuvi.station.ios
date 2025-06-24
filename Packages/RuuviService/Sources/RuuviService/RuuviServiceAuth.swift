import Foundation
import Future

public extension Notification.Name {
    static let RuuviAuthServiceDidLogout =
        Notification.Name("RuuviServiceAuth.RuuviAuthServiceDidLogout")
}

public protocol RuuviServiceAuth {
    func logout() -> Future<Bool, RuuviServiceError>
}
