import Foundation

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
