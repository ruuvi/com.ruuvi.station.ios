import Foundation

struct ReloadableSection<N: Equatable>: Equatable {
    var key: String
    var value: [ReloadableCell<N>]
    var index: Int

    static func == (lhs: ReloadableSection, rhs: ReloadableSection) -> Bool {
        return lhs.key == rhs.key && lhs.value == rhs.value
    }
}
