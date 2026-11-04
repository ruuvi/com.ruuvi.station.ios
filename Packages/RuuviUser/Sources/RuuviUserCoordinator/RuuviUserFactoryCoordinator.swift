#if SWIFT_PACKAGE
    import RuuviUser
#endif
public final class RuuviUserFactoryCoordinator: RuuviUserFactory {
    public init() {}

    public func createUser() -> RuuviUser {
        let keychainService = KeychainServiceImpl()
        return RuuviUserCoordinator(keychainService: keychainService)
    }
}
