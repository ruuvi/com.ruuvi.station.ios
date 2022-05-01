import Foundation

extension Notification.Name {
    public static let RuuviUserDidAuthorized = Notification.Name("RuuviUser.AuthorizationSuccessful")
}

public protocol RuuviUser {
    var apiKey: String? { get }
    var email: String? { get set }
    var isAuthorized: Bool { get }

    func login(apiKey: String)
    func logout()
}

public protocol RuuviUserFactory {
    func createUser() -> RuuviUser
}
