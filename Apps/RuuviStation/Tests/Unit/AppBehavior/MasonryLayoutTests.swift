import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class MasonryLayoutTests: XCTestCase {
    func testVariableHeightCardsFillTheShortestColumnWithConfiguredInsetsAndSpacing() throws {
        let fixture = MasonryLayoutFixture(count: 4)
        fixture.delegate.heights = [100, 200, 50, 100]
        fixture.collection.contentInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 20)
        fixture.layout.invalidateLayout()
        fixture.layout.prepare()
        let expected = [
            CGRect(x: 16, y: 16, width: 164, height: 100),
            CGRect(x: 192, y: 16, width: 164, height: 200),
            CGRect(x: 16, y: 128, width: 164, height: 50),
            CGRect(x: 16, y: 190, width: 164, height: 100),
        ]
        for (index, frame) in expected.enumerated() {
            let attributes = try XCTUnwrap(
                fixture.layout.layoutAttributesForItem(at: IndexPath(item: index, section: 0)))
            XCTAssertEqual(attributes.frame, frame)
            XCTAssertEqual(attributes.alpha, 1)
        }
        XCTAssertEqual(fixture.layout.collectionViewContentSize, CGSize(width: 402, height: 318))
        XCTAssertEqual(
            fixture.layout.layoutAttributesForElements(in: CGRect(x: 0, y: 0, width: 180, height: 120))?.map(
                \.indexPath),
            [IndexPath(item: 0, section: 0)])
        XCTAssertTrue(
            fixture.layout.layoutAttributesForElements(in: CGRect(x: 0, y: 1000, width: 402, height: 100))?.isEmpty
                == true)
        XCTAssertNil(fixture.layout.layoutAttributesForItem(at: IndexPath(item: 99, section: 0)))
    }

    func testResizingAndChangingColumnCountInvalidateCachedGeometry() throws {
        let fixture = MasonryLayoutFixture(count: 6)
        XCTAssertFalse(
            fixture.layout.shouldInvalidateLayout(forBoundsChange: fixture.collection.bounds.offsetBy(dx: 0, dy: 100)))
        let resized = CGRect(x: 0, y: 0, width: 720, height: 650)
        XCTAssertTrue(fixture.layout.shouldInvalidateLayout(forBoundsChange: resized))
        fixture.collection.frame = resized
        fixture.delegate.columns = 3
        fixture.delegate.spacing = 20
        fixture.delegate.insets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        fixture.layout.invalidateLayout()
        fixture.layout.prepare()
        for index in 0..<6 {
            let frame = try XCTUnwrap(fixture.layout.layoutAttributesForItem(at: IndexPath(item: index, section: 0)))
                .frame
            XCTAssertEqual(frame.width, 220)
            XCTAssertEqual(frame.minX, CGFloat(index % 3) * 240 + 10)
            XCTAssertEqual(frame.minY, index < 3 ? 10 : 130)
        }
        XCTAssertEqual(fixture.layout.collectionViewContentSize, CGSize(width: 720, height: 260))
    }

    func testEmptyAndDetachedLayoutsHaveNoItemsAndUseTheDocumentedDefaults() {
        let detached = MasonryReorderableLayout()
        detached.prepare()
        detached.cancelDrag()
        detached.configureAutoScroll()
        XCTAssertEqual(detached.collectionViewContentSize, .zero)
        XCTAssertFalse(detached.shouldInvalidateLayout(forBoundsChange: CGRect(x: 0, y: 0, width: 100, height: 100)))
        XCTAssertFalse(detached.gestureRecognizerShouldBegin(UIPanGestureRecognizer()))
        let fixture = MasonryLayoutFixture(count: 0)
        XCTAssertEqual(fixture.layout.collectionViewContentSize, CGSize(width: 402, height: 32))
        XCTAssertEqual(fixture.layout.layoutAttributesForElements(in: fixture.collection.bounds)?.count, 0)
        fixture.layout.delegate = nil
        var snapshot = NSDiffableDataSourceSnapshot<MasonrySection, RuuviTagCardSnapshot>()
        snapshot.appendSections([.main])
        let items = MasonryLayoutFixture(count: 2).items
        snapshot.appendItems(items)
        fixture.dataSource.apply(snapshot, animatingDifferences: false)
        fixture.layout.invalidateLayout()
        fixture.layout.prepare()
        XCTAssertEqual(
            fixture.layout.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))?.frame,
            CGRect(x: 16, y: 16, width: 179, height: 100))
        XCTAssertEqual(
            fixture.layout.layoutAttributesForItem(at: IndexPath(item: 1, section: 0))?.frame,
            CGRect(x: 207, y: 16, width: 179, height: 100))
    }

    func testMissingSectionIsAnEmptyLayoutDuringDiffableSourceInitialization() {
        let fixture = MasonryLayoutFixture()
        let snapshot = NSDiffableDataSourceSnapshot<MasonrySection, RuuviTagCardSnapshot>()
        fixture.dataSource.apply(snapshot, animatingDifferences: false)
        fixture.layout.invalidateLayout()
        fixture.layout.prepare()
        XCTAssertEqual(fixture.layout.layoutAttributesForElements(in: fixture.collection.bounds)?.count, 0)
        XCTAssertEqual(fixture.layout.collectionViewContentSize.height, 32)
    }

    func testScrollAndReorderGesturesDoNotCompeteBeforeLongPressBegins() throws {
        let fixture = MasonryLayoutFixture()
        let gestures = fixture.collection.gestureRecognizers ?? []
        let longPress = try XCTUnwrap(
            gestures.first { $0 is UILongPressGestureRecognizer && $0.delegate === fixture.layout })
        let pan = try XCTUnwrap(gestures.first { $0 is UIPanGestureRecognizer && $0.delegate === fixture.layout })
        XCTAssertTrue(fixture.layout.gestureRecognizerShouldBegin(longPress))
        XCTAssertFalse(fixture.layout.gestureRecognizerShouldBegin(pan))
        XCTAssertTrue(fixture.layout.gestureRecognizer(pan, shouldRecognizeSimultaneouslyWith: longPress))
        XCTAssertFalse(
            fixture.layout.gestureRecognizer(
                pan, shouldRecognizeSimultaneouslyWith: fixture.collection.panGestureRecognizer))
        XCTAssertFalse(
            fixture.layout.gestureRecognizer(
                fixture.collection.panGestureRecognizer, shouldRecognizeSimultaneouslyWith: pan))
        let gesture = MasonryLongPress()
        gesture.point = CGPoint(x: 60, y: 60)
        fixture.delegate.allow = false
        XCTAssertFalse(fixture.layout.gestureRecognizerShouldBegin(gesture))
        fixture.delegate.allow = true
        XCTAssertTrue(fixture.layout.gestureRecognizerShouldBegin(gesture))
    }
}
