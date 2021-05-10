import Foundation

struct ReloadableCell<N: Equatable>: Equatable {
    var key: String
    var value: N
    var index: Int

    static func == (lhs: ReloadableCell, rhs: ReloadableCell) -> Bool {
        return lhs.key == rhs.key && lhs.value == rhs.value
    }
}
