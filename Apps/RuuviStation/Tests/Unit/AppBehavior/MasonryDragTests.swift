import UIKit
import XCTest
@testable import station

@MainActor final class MasonryDragTests: XCTestCase {
    func testDraggingReordersTheDiffableSourceAndRestoresTheDroppedCell() async throws {
        let fixture = MasonryLayoutFixture()
        try fixture.host()
        defer { fixture.layout.cancelDrag(); fixture.unhost() }
        let start = try fixture.begin(0)
        XCTAssertEqual(fixture.delegate.starts, [IndexPath(item: 0, section: 0)])
        XCTAssertFalse(fixture.collection.scrollsToTop)
        XCTAssertEqual(fixture.layout.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))?.alpha, 0)
        let target = try XCTUnwrap(fixture.layout.layoutAttributesForItem(at: IndexPath(item: 3, section: 0)))
        fixture.move(from: start, to: target.center)
        await waitForAppState("drag reorder") { fixture.delegate.didMoves.count == 1 }
        var expected = fixture.items.map(\.id)
        let first = expected.removeFirst()
        expected.insert(first, at: 3)
        XCTAssertEqual(fixture.dataSource.snapshot().itemIdentifiers.map(\.id), expected)
        XCTAssertEqual(fixture.delegate.orders.last, expected)
        XCTAssertEqual(fixture.delegate.willMoves.first?.0, IndexPath(item: 0, section: 0))
        XCTAssertEqual(fixture.delegate.didMoves.first?.1, IndexPath(item: 3, section: 0))
        fixture.layout.cancelDrag()
        await waitForAppState("drag ended") { fixture.delegate.ends.count == 1 }
        fixture.collection.layoutIfNeeded()
        XCTAssertEqual(fixture.delegate.ends, [IndexPath(item: 3, section: 0)])
        XCTAssertTrue(fixture.collection.scrollsToTop)
        XCTAssertEqual(fixture.layout.layoutAttributesForItem(at: IndexPath(item: 3, section: 0))?.alpha, 1)
    }

    func testMoveRestrictionsAndCancelledGesturesPreserveSensorOrder() async throws {
        let fixture = MasonryLayoutFixture()
        try fixture.host()
        defer { fixture.layout.cancelDrag(); fixture.unhost() }
        fixture.delegate.allow = false
        _ = try fixture.begin(0)
        XCTAssertTrue(fixture.delegate.starts.isEmpty)
        XCTAssertTrue(fixture.collection.scrollsToTop)
        fixture.delegate.allow = true
        fixture.delegate.allowDestination = false
        let start = try fixture.begin(0)
        let target = try XCTUnwrap(fixture.layout.layoutAttributesForItem(at: IndexPath(item: 2, section: 0))).center
        fixture.move(from: start, to: target)
        XCTAssertTrue(fixture.delegate.didMoves.isEmpty)
        XCTAssertEqual(fixture.dataSource.snapshot().itemIdentifiers.map(\.id), fixture.items.map(\.id))
        fixture.move(from: start, to: target, state: .cancelled)
        let end = MasonryLongPress()
        end.point = start
        end.state = .cancelled
        fixture.layout.handleLongPress(end)
        await waitForAppState("cancelled drag ended") { fixture.delegate.ends.count == 1 }
        XCTAssertTrue(fixture.collection.scrollsToTop)
        XCTAssertEqual(fixture.dataSource.snapshot().itemIdentifiers.map(\.id), fixture.items.map(\.id))
    }

    func testAutoscrollMovesWithinContentBoundsAndStopsWhenTheDragEnds() async throws {
        let fixture = MasonryLayoutFixture(count: 30, size: CGSize(width: 402, height: 400))
        try fixture.host()
        defer { fixture.layout.cancelDrag(); fixture.unhost() }
        fixture.delegate.allowDestination = false
        fixture.layout.configureAutoScroll(
            triggerInsets: UIEdgeInsets(top: 80, left: 0, bottom: 80, right: 0),
            triggerPadding: .zero, scrollSpeed: 15)
        let start = try fixture.begin(0)
        fixture.move(from: start, to: CGPoint(x: start.x, y: 390))
        await waitForAppState("scroll toward bottom") { fixture.collection.contentOffset.y > 20 }
        let bottomOffset = fixture.collection.contentOffset.y
        XCTAssertLessThanOrEqual(
            bottomOffset, fixture.layout.collectionViewContentSize.height - fixture.collection.bounds.height)
        fixture.move(from: start, to: CGPoint(x: start.x, y: -100))
        await waitForAppState("scroll toward top") { fixture.collection.contentOffset.y < bottomOffset }
        XCTAssertGreaterThanOrEqual(fixture.collection.contentOffset.y, -fixture.collection.contentInset.top)
        fixture.layout.cancelDrag()
        await waitForAppState("autoscroll drag ended") { fixture.delegate.ends.count == 1 }
        let stopped = fixture.collection.contentOffset.y
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(fixture.collection.contentOffset.y, stopped)
    }

    func testClosingCollectionDuringAutoscrollReleasesItsLayout() async throws {
        var fixture: MasonryLayoutFixture? = MasonryLayoutFixture(count: 30, size: CGSize(width: 402, height: 400))
        try fixture?.host()
        let start = try XCTUnwrap(fixture?.begin(0))
        fixture?.delegate.allowDestination = false
        fixture?.move(from: start, to: CGPoint(x: start.x, y: 390))
        await waitForAppState("active autoscroll") { (fixture?.collection.contentOffset.y ?? 0) > 0 }
        weak var layout = fixture?.layout
        fixture?.unhost()
        fixture = nil
        try? await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertNil(layout)
        layout?.cancelDrag()
    }
}
