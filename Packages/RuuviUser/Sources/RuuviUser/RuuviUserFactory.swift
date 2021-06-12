import Foundation

public final class RuuviUserFactoryImpl: RuuviUserFactory {
    public init() {}

    public func createUser() -> RuuviUser {
        let keychainService = KeychainServiceImpl()
        return RuuviUserCoordinator(keychainService: keychainService)
    }
}
