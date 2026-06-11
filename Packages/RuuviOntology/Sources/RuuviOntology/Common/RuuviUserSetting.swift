import Foundation

public protocol RuuviUserSetting {
    var key: String { get }
    /// Raw setting payload stored by cloud/user-setting key.
    /// Enum parsing stays in the app-settings layer so storage preserves API values.
    var value: String { get }
    var lastUpdated: Date? { get }
}

public struct RuuviUserSettingStruct: RuuviUserSetting, Equatable {
    public var key: String
    public var value: String
    public var lastUpdated: Date?

    public init(
        key: String,
        value: String,
        lastUpdated: Date? = nil
    ) {
        self.key = key
        self.value = value
        self.lastUpdated = lastUpdated
    }
}
