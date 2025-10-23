import Foundation
import Future

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

public protocol RuuviServiceAuth {
    func logout() -> Future<Bool, RuuviServiceError>
}
