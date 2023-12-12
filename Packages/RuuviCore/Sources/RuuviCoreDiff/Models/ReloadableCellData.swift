import Foundation

struct ReloadableCellData<N: Equatable> {
    var items = [ReloadableCell<N>]()

    subscript(key: String) -> ReloadableCell<N>? {
        items.filter { $0.key == key }.first
    }

    subscript(index: Int) -> ReloadableCell<N>? {
        items.filter { $0.index == index }.first
    }
}
