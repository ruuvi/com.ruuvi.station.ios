import Foundation

class DiffCalculatorImpl: DiffCalculator {
    func calculate<N>(oldItems: [ReloadableSection<N>], newItems: [ReloadableSection<N>]) -> SectionChanges {
        let sectionChanges = SectionChanges()
        let uniqueSectionKeys = (oldItems + newItems)
            .map { $0.key }
            .filterDuplicates()

        let cellChanges = CellChanges()

        for sectionKey in uniqueSectionKeys {
            let oldSectionItem = ReloadableSectionData(items: oldItems)[sectionKey]
            let newSectionItem = ReloadableSectionData(items: newItems)[sectionKey]
            if let oldSectionItem = oldSectionItem, let newSectionItem = newSectionItem {
                if oldSectionItem != newSectionItem {
                    let oldCellIData = ReloadableCellData(items: oldSectionItem.value)
                    let newCellData = ReloadableCellData(items: newSectionItem.value)

                    let uniqueCellKeys = (oldCellIData.items + newCellData.items)
                        .map { $0.key }
                        .filterDuplicates()

                    for cellKey in uniqueCellKeys {
                        let oldCellItem = oldCellIData[cellKey]
                        let newCellItem = newCellData[cellKey]
                        if let oldCellItem = oldCellItem, let newCelItem = newCellItem {
                            if oldCellItem != newCelItem {
                                let indexPath: IndexPath = IndexPath(row: oldCellItem.index,
                                                                     section: oldSectionItem.index)
                                cellChanges.reloads
                                    .append(indexPath)
                            }
                        } else if let oldCellItem = oldCellItem {
                            cellChanges.deletes.append(IndexPath(row: oldCellItem.index, section: oldSectionItem.index))
                        } else if let newCellItem = newCellItem {
                            cellChanges.inserts.append(IndexPath(row: newCellItem.index, section: newSectionItem.index))
                        }
                    }
                }
            } else if let oldSectionItem = oldSectionItem {
                sectionChanges.deletesInts.append(oldSectionItem.index)
            } else if let newSectionItem = newSectionItem {
                sectionChanges.insertsInts.append(newSectionItem.index)
            }
        }

        sectionChanges.updates = cellChanges

        return sectionChanges
    }

    func calculate<N>(oldItems: [ReloadableCell<N>],
                      newItems: [ReloadableCell<N>],
                      in sectionIndex: Int) -> CellChanges {
        let cellChanges = CellChanges()

        let oldCellIData = ReloadableCellData(items: oldItems)
        let newCellData = ReloadableCellData(items: newItems)

        let uniqueCellKeys = (oldCellIData.items + newCellData.items)
            .map { $0.key }
            .filterDuplicates()
        for cellKey in uniqueCellKeys {
            let oldCellItem = oldCellIData[cellKey]
            let newCellItem = newCellData[cellKey]
            if let oldCellItem = oldCellItem, let newCelItem = newCellItem {
                if oldCellItem != newCelItem {
                    cellChanges.reloads.append(IndexPath(row: oldCellItem.index, section: sectionIndex))
                }
            } else if let oldCellItem = oldCellItem {
                cellChanges.deletes.append(IndexPath(row: oldCellItem.index, section: sectionIndex))
            } else if let newCellItem = newCellItem {
                cellChanges.inserts.append(IndexPath(row: newCellItem.index, section: sectionIndex))
            }
        }
        return cellChanges
    }
}
