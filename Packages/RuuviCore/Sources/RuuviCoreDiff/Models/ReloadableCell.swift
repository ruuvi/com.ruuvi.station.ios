import Foundation

public struct ReloadableCell<N: Equatable>: Equatable {
    public var key: String
    public var value: N
    public var index: Int

    public static func == (lhs: ReloadableCell, rhs: ReloadableCell) -> Bool {
        lhs.key == rhs.key && lhs.value == rhs.value
    }
}
