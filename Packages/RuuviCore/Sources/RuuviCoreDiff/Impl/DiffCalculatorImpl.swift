import Foundation
import UIKit

class DiffCalculatorImpl: DiffCalculator {
    func calculate<N>(oldItems: [ReloadableSection<N>], newItems: [ReloadableSection<N>]) -> SectionChanges {
        let sectionChanges = SectionChanges()
        let uniqueSectionKeys = (oldItems + newItems)
            .map(\.key)
            .filterDuplicates()

        let cellChanges = CellChanges()

        for sectionKey in uniqueSectionKeys {
            let oldSectionItem = ReloadableSectionData(items: oldItems)[sectionKey]
            let newSectionItem = ReloadableSectionData(items: newItems)[sectionKey]
            if let oldSectionItem, let newSectionItem {
                if oldSectionItem != newSectionItem {
                    let oldCellIData = ReloadableCellData(items: oldSectionItem.value)
                    let newCellData = ReloadableCellData(items: newSectionItem.value)

                    let uniqueCellKeys = (oldCellIData.items + newCellData.items)
                        .map(\.key)
                        .filterDuplicates()

                    for cellKey in uniqueCellKeys {
                        let oldCellItem = oldCellIData[cellKey]
                        let newCellItem = newCellData[cellKey]
                        if let oldCellItem, let newCelItem = newCellItem {
                            if oldCellItem != newCelItem {
                                let indexPath: IndexPath = .init(row: oldCellItem.index,
                                                                 section: oldSectionItem.index)
                                cellChanges.reloads
                                    .append(indexPath)
                            }
                        } else if let oldCellItem {
                            cellChanges.deletes.append(IndexPath(row: oldCellItem.index, section: oldSectionItem.index))
                        } else if let newCellItem {
                            cellChanges.inserts.append(IndexPath(row: newCellItem.index, section: newSectionItem.index))
                        }
                    }
                }
            } else if let oldSectionItem {
                sectionChanges.deletesInts.append(oldSectionItem.index)
            } else if let newSectionItem {
                sectionChanges.insertsInts.append(newSectionItem.index)
            }
        }

        sectionChanges.updates = cellChanges

        return sectionChanges
    }

    func calculate<N>(oldItems: [ReloadableCell<N>],
                      newItems: [ReloadableCell<N>],
                      in sectionIndex: Int) -> CellChanges
    {
        let cellChanges = CellChanges()

        let oldCellIData = ReloadableCellData(items: oldItems)
        let newCellData = ReloadableCellData(items: newItems)

        let uniqueCellKeys = (oldCellIData.items + newCellData.items)
            .map(\.key)
            .filterDuplicates()
        for cellKey in uniqueCellKeys {
            let oldCellItem = oldCellIData[cellKey]
            let newCellItem = newCellData[cellKey]
            if let oldCellItem, let newCelItem = newCellItem {
                if oldCellItem != newCelItem {
                    cellChanges.reloads.append(IndexPath(row: oldCellItem.index, section: sectionIndex))
                }
            } else if let oldCellItem {
                cellChanges.deletes.append(IndexPath(row: oldCellItem.index, section: sectionIndex))
            } else if let newCellItem {
                cellChanges.inserts.append(IndexPath(row: newCellItem.index, section: sectionIndex))
            }
        }
        return cellChanges
    }
}
