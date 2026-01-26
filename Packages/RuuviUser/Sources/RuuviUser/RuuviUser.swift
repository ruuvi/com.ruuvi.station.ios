import Foundation

public extension Notification.Name {
    static let RuuviUserDidAuthorized = Notification.Name("RuuviUser.AuthorizationSuccessful")
}

public protocol RuuviUser: Sendable {
    var apiKey: String? { get }
    var email: String? { get set }
    var isAuthorized: Bool { get }

    func login(apiKey: String)
    func logout()
}

public protocol RuuviUserFactory {
    func createUser() -> RuuviUser
}
