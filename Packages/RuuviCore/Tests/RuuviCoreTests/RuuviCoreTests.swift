import Foundation
import UIKit
import XCTest
@testable import RuuviCore
#if SWIFT_PACKAGE
    @testable import RuuviCoreDiff
    @testable import RuuviCoreImage
#endif

final class RuuviCoreTests: XCTestCase {
    func testFirmwareVersionsCompareNumericallyAndPadMissingComponents() {
        XCTAssertEqual([Int].compareVersions([3, 10], [3, 9, 9]), .orderedDescending)
        XCTAssertEqual([Int].compareVersions([3, 2], [3, 2, 0]), .orderedSame)
        XCTAssertEqual([Int].compareVersions([3], [3, 0, 1]), .orderedAscending)
        XCTAssertEqual([Int].compareVersions([], [0, 0]), .orderedSame)
        XCTAssertEqual([Int].compareVersions([1], []), .orderedDescending)
    }

    func testMovingItemsPreservesOtherItemsAndHandlesBounds() {
        XCTAssertEqual([1, 2, 3].movingUp(2), [2, 1, 3])
        XCTAssertEqual([1, 2, 3].movingDown(2), [1, 3, 2])
        XCTAssertEqual([1, 2, 3].movingUp(1), [1, 2, 3])
        XCTAssertEqual([1, 2, 3].movingDown(3), [1, 2, 3])
        XCTAssertEqual([1, 2, 3].movingUp(4), [1, 2, 3])
        XCTAssertEqual([Int]().movingDown(1), [])
        XCTAssertEqual([3, 1, 3, 2, 1].filterDuplicates(), [3, 1, 2])
    }

    func testSafeStringRangesUseUTF16AndRejectInvalidOffsets() {
        let string = "A🙂B"
        XCTAssertEqual(string[safe: NSRange(location: 1, length: 2)], "🙂")
        XCTAssertEqual(string[safe: NSRange(location: 3, length: Int.max)], "B")
        XCTAssertEqual(string[safe: NSRange(location: 4, length: 0)], "")
        XCTAssertNil(string[safe: NSRange(location: 2, length: 1)])
        XCTAssertNil(string[safe: NSRange(location: -1, length: 2)])
        XCTAssertNil(string[safe: NSRange(location: 0, length: -1)])
        XCTAssertNil(string[safe: NSRange(location: 100, length: 1)])
        XCTAssertEqual(""[safe: NSRange(location: 0, length: 0)], "")
        XCTAssertNil([1, 2][safe: -1])
        XCTAssertNil([1, 2][safe: 2])
        XCTAssertEqual([1, 2][safe: 1], 2)
    }

    func testCellDiffDistinguishesInsertDeleteAndChangedValues() {
        let before = [cell("same", 1, 0), cell("changed", 1, 1), cell("deleted", 1, 2)]
        let after = [cell("same", 1, 0), cell("changed", 2, 1), cell("inserted", 1, 2)]
        let changes = DiffCalculatorImpl().calculate(oldItems: before, newItems: after, in: 3)
        XCTAssertEqual(changes.inserts, [IndexPath(row: 2, section: 3)])
        XCTAssertEqual(changes.deletes, [IndexPath(row: 2, section: 3)])
        XCTAssertEqual(changes.reloads, [IndexPath(row: 1, section: 3)])
        let unchanged = DiffCalculatorImpl().calculate(oldItems: before, newItems: before, in: 3)
        XCTAssertTrue(unchanged.inserts.isEmpty && unchanged.deletes.isEmpty && unchanged.reloads.isEmpty)
    }

    func testSectionDiffReportsSectionAndCellChanges() {
        let before = [
            ReloadableSection(key: "kept", value: [cell("updated", 1, 0), cell("gone", 2, 1)], index: 0),
            ReloadableSection(key: "removed", value: [cell("x", 0, 0)], index: 1),
        ]
        let after = [
            ReloadableSection(key: "kept", value: [cell("updated", 2, 0), cell("new", 3, 1)], index: 0),
            ReloadableSection(key: "added", value: [cell("y", 0, 0)], index: 1),
        ]
        let changes = DiffCalculatorImpl().calculate(oldItems: before, newItems: after)
        XCTAssertEqual(changes.inserts, IndexSet(integer: 1))
        XCTAssertEqual(changes.deletes, IndexSet(integer: 1))
        XCTAssertEqual(changes.updates.reloads, [IndexPath(row: 0, section: 0)])
        XCTAssertEqual(changes.updates.deletes, [IndexPath(row: 1, section: 0)])
        XCTAssertEqual(changes.updates.inserts, [IndexPath(row: 1, section: 0)])
        let unchanged = DiffCalculatorImpl().calculate(oldItems: before, newItems: before)
        XCTAssertTrue(unchanged.inserts.isEmpty && unchanged.deletes.isEmpty && unchanged.updates.reloads.isEmpty)
    }

    @MainActor func testImageResizePreservesAspectRatioAndDoesNotUpscale() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 100)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        }
        let service = RuuviCoreImageImpl()
        let scaled = service.cropped(image: image, to: CGSize(width: 50, height: 50))
        XCTAssertEqual(scaled.size.width, 50, accuracy: 0.001)
        XCTAssertEqual(scaled.size.height, 25, accuracy: 0.001)
        XCTAssertNotNil(scaled.cgImage)
        XCTAssertTrue(service.cropped(image: image, to: CGSize(width: 400, height: 400)) === image)
        XCTAssertTrue(service.cropped(image: image, to: .zero) === image)
        XCTAssertTrue(service.cropped(image: image, to: CGSize(width: CGFloat.infinity, height: 10)) === image)
        let empty = UIImage()
        XCTAssertTrue(service.cropped(image: empty, to: CGSize(width: 10, height: 10)) === empty)
    }

    private func cell(_ key: String, _ value: Int, _ index: Int) -> ReloadableCell<Int> {
        .init(key: key, value: value, index: index)
    }
}
