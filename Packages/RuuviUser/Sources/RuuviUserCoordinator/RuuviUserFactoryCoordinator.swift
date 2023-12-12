public final class RuuviUserFactoryCoordinator: RuuviUserFactory {
    public init() {}

    public func createUser() -> RuuviUser {
        let keychainService = KeychainServiceImpl()
        return RuuviUserCoordinator(keychainService: keychainService)
    }
}
