@testable import RuuviCore
import UIKit
import XCTest

final class RuuviCoreTests: XCTestCase {
    func testMovingUpAndDownSwapsOnlyAdjacentMatches() {
        XCTAssertEqual([1, 2, 3].movingUp(2), [2, 1, 3])
        XCTAssertEqual([1, 2, 3].movingDown(2), [1, 3, 2])
        XCTAssertEqual([1, 2, 3].movingUp(1), [1, 2, 3])
        XCTAssertEqual([1, 2, 3].movingDown(3), [1, 2, 3])
    }

    func testArrayUtilitiesCoverDuplicateFilteringSafeAccessAndVersionComparison() {
        XCTAssertEqual([1, 2, 2, 3, 1].filterDuplicates(), [1, 2, 3])
        XCTAssertEqual("abcdef"[safe: NSRange(location: 2, length: 2)], "cd")
        XCTAssertEqual("abcdef"[safe: NSRange(location: 4, length: 10)], "ef")
        XCTAssertNil("abcdef"[safe: NSRange(location: 10, length: 1)])
        XCTAssertEqual([10, 20, 30][safe: 1], 20)
        XCTAssertNil([10, 20, 30][safe: 3])
        XCTAssertEqual([Int].compareVersions([1, 2, 0], [1, 2]), .orderedSame)
        XCTAssertEqual([Int].compareVersions([1, 2, 1], [1, 2, 9]), .orderedAscending)
        XCTAssertEqual([Int].compareVersions([2], [1, 9, 9]), .orderedDescending)
    }

    func testDiffCalculatorReportsSectionAndCellMutations() {
        let sut = DiffCalculatorImpl()
        let oldItems = [
            ReloadableSection(
                key: "section-1",
                value: [
                    ReloadableCell(key: "cell-1", value: "A", index: 0),
                    ReloadableCell(key: "cell-2", value: "B", index: 1),
                ],
                index: 0
            ),
        ]
        let newItems = [
            ReloadableSection(
                key: "section-1",
                value: [
                    ReloadableCell(key: "cell-1", value: "A*", index: 0),
                    ReloadableCell(key: "cell-3", value: "C", index: 1),
                ],
                index: 0
            ),
            ReloadableSection(key: "section-2", value: [], index: 1),
        ]

        let changes = sut.calculate(oldItems: oldItems, newItems: newItems)

        XCTAssertEqual(changes.insertsInts, [1])
        XCTAssertEqual(changes.deletesInts, [])
        XCTAssertEqual(changes.updates.reloads, [IndexPath(row: 0, section: 0)])
        XCTAssertEqual(changes.updates.deletes, [IndexPath(row: 1, section: 0)])
        XCTAssertEqual(changes.updates.inserts, [IndexPath(row: 1, section: 0)])
    }

    func testDiffCalculatorReportsDeletedSections() {
        let sut = DiffCalculatorImpl()
        let oldItems: [ReloadableSection<String>] = [
            ReloadableSection(key: "section-1", value: [], index: 0),
            ReloadableSection(key: "section-2", value: [], index: 1),
        ]
        let newItems: [ReloadableSection<String>] = [
            ReloadableSection(key: "section-1", value: [], index: 0),
        ]

        let changes = sut.calculate(oldItems: oldItems, newItems: newItems)

        XCTAssertEqual(changes.deletesInts, [1])
        XCTAssertEqual(changes.insertsInts, [])
        XCTAssertTrue(changes.updates.reloads.isEmpty)
        XCTAssertTrue(changes.updates.deletes.isEmpty)
        XCTAssertTrue(changes.updates.inserts.isEmpty)
    }

    func testReloadableModelsIgnoreIndexWhenComparingEquality() {
        let lhsCell = ReloadableCell(key: "cell", value: "value", index: 0)
        let rhsCell = ReloadableCell(key: "cell", value: "value", index: 5)
        let lhsSection = ReloadableSection(key: "section", value: [lhsCell], index: 0)
        let rhsSection = ReloadableSection(key: "section", value: [rhsCell], index: 3)

        XCTAssertEqual(lhsCell, rhsCell)
        XCTAssertEqual(lhsSection, rhsSection)
    }

    func testReloadableDataLookupsSupportBothKeysAndIndexes() {
        let cells = [
            ReloadableCell(key: "cell-1", value: "A", index: 0),
            ReloadableCell(key: "cell-2", value: "B", index: 1),
        ]
        let sections = [
            ReloadableSection(key: "section-1", value: cells, index: 0),
            ReloadableSection(key: "section-2", value: [], index: 1),
        ]
        let cellData = ReloadableCellData(items: cells)
        let sectionData = ReloadableSectionData(items: sections)

        XCTAssertEqual(cellData["cell-2"]?.value, "B")
        XCTAssertEqual(cellData[0]?.key, "cell-1")
        XCTAssertNil(cellData["missing"])
        XCTAssertNil(cellData[99])
        XCTAssertEqual(sectionData["section-2"]?.index, 1)
        XCTAssertEqual(sectionData[0]?.key, "section-1")
        XCTAssertNil(sectionData["missing"])
        XCTAssertNil(sectionData[99])
    }

    func testReloadableDataDefaultsToEmptyCollections() {
        let cellData = ReloadableCellData<String>()
        let sectionData = ReloadableSectionData<String>()

        XCTAssertTrue(cellData.items.isEmpty)
        XCTAssertNil(cellData["missing"])
        XCTAssertNil(cellData[0])
        XCTAssertTrue(sectionData.items.isEmpty)
        XCTAssertNil(sectionData["missing"])
        XCTAssertNil(sectionData[0])
    }

    func testDiffCalculatorCellAPIHandlesReloadDeleteInsertAndNoop() {
        let sut = DiffCalculatorImpl()
        let oldItems = [
            ReloadableCell(key: "cell-1", value: "A", index: 0),
            ReloadableCell(key: "cell-2", value: "B", index: 1),
        ]
        let newItems = [
            ReloadableCell(key: "cell-1", value: "A*", index: 0),
            ReloadableCell(key: "cell-3", value: "C", index: 1),
        ]

        let changes = sut.calculate(oldItems: oldItems, newItems: newItems, in: 2)
        let unchanged = sut.calculate(oldItems: oldItems, newItems: oldItems, in: 1)

        XCTAssertEqual(changes.reloads, [IndexPath(row: 0, section: 2)])
        XCTAssertEqual(changes.deletes, [IndexPath(row: 1, section: 2)])
        XCTAssertEqual(changes.inserts, [IndexPath(row: 1, section: 2)])
        XCTAssertTrue(unchanged.reloads.isEmpty)
        XCTAssertTrue(unchanged.deletes.isEmpty)
        XCTAssertTrue(unchanged.inserts.isEmpty)
    }

    func testSectionChangesExposeIndexSetsAndMutableCellUpdates() {
        let updates = CellChanges(
            inserts: [IndexPath(row: 1, section: 0)],
            deletes: [IndexPath(row: 2, section: 0)],
            reloads: [IndexPath(row: 0, section: 0)]
        )
        let sut = SectionChanges(inserts: [0, 2], deletes: [1], updates: updates)

        XCTAssertEqual(sut.inserts, IndexSet([0, 2]))
        XCTAssertEqual(sut.deletes, IndexSet([1]))
        XCTAssertEqual(sut.updates.inserts, [IndexPath(row: 1, section: 0)])
        XCTAssertEqual(sut.updates.deletes, [IndexPath(row: 2, section: 0)])
        XCTAssertEqual(sut.updates.reloads, [IndexPath(row: 0, section: 0)])
    }
}
