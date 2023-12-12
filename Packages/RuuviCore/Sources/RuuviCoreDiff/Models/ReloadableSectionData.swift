import Foundation

struct ReloadableSectionData<N: Equatable> {
    var items = [ReloadableSection<N>]()

    subscript(key: String) -> ReloadableSection<N>? {
        items.filter { $0.key == key }.first
    }

    subscript(index: Int) -> ReloadableSection<N>? {
        items.filter { $0.index == index }.first
    }
}
