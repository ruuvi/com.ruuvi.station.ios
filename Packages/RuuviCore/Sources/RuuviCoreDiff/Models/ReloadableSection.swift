import Foundation

public struct ReloadableSection<N: Equatable>: Equatable {
    public var key: String
    public var value: [ReloadableCell<N>]
    public var index: Int

    public static func == (lhs: ReloadableSection, rhs: ReloadableSection) -> Bool {
        lhs.key == rhs.key && lhs.value == rhs.value
    }
}
