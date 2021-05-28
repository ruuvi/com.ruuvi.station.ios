import Foundation

public protocol RuuviLocalFactory {
    func createLocalSettings() -> RuuviLocalSettings
}

public final class RuuviLocalFactoryImpl: RuuviLocalFactory {
    public init() {}

    public func createLocalSettings() -> RuuviLocalSettings {
        return RuuviLocalSettingsUserDefaults()
    }
}
