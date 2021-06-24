import Foundation

public protocol DiffCalculator: AnyObject {
    func calculate<N>(
        oldItems: [ReloadableSection<N>],
        newItems: [ReloadableSection<N>]
    ) -> SectionChanges

    func calculate<N>(
        oldItems: [ReloadableCell<N>],
        newItems: [ReloadableCell<N>],
        in sectionIndex: Int
    ) -> CellChanges
}
