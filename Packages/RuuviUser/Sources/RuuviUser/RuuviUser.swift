import Foundation

public protocol RuuviUser {
    var apiKey: String? { get set }
    var email: String? { get set }
    var isAuthorized: Bool { get }

    func logout()
}

public protocol RuuviUserFactory {
    func createUser() -> RuuviUser
}
