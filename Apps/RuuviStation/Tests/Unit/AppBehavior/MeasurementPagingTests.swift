import UIKit
import XCTest
@testable import station

@MainActor final class MeasurementPagingTests: XCTestCase {
    func testProgrammaticAndInteractivePagingRespectBoundariesAndReportTheSelectedSensor() async throws {
        let fixture = try MeasurementPagingFixture()
        defer { fixture.close() }
        let view = fixture.view
        let pager = fixture.pager
        let first = try fixture.page()
        XCTAssertNil(view.pageViewController(pager, viewControllerBefore: first))
        let second = try XCTUnwrap(
            view.pageViewController(pager, viewControllerAfter: first) as? CardsMeasurementPageViewController)
        XCTAssertEqual(second.pageIndex, 1)
        XCTAssertNil(view.pageViewController(pager, viewControllerAfter: second))
        XCTAssertEqual(
            (view.pageViewController(pager, viewControllerBefore: second) as? CardsMeasurementPageViewController)?
                .pageIndex, 0)
        XCTAssertNil(view.pageViewController(pager, viewControllerAfter: UIViewController()))
        view.navigateToIndex(-1, animated: false)
        view.navigateToIndex(2, animated: false)
        view.navigateToIndex(0, animated: false)
        XCTAssertTrue(fixture.output.indices.isEmpty)
        view.navigateToIndex(1, animated: false)
        await waitForAppState("second measurement page") { fixture.output.indices == [1] }
        XCTAssertEqual(try fixture.page().pageIndex, 1)
        view.navigateToIndex(0, animated: false)
        await waitForAppState("first measurement page") { fixture.output.indices == [1, 0] }
        pager.setViewControllers([second], direction: .forward, animated: false)
        view.pageViewController(
            pager, didFinishAnimating: true, previousViewControllers: [first], transitionCompleted: false)
        XCTAssertEqual(fixture.output.indices, [1, 0])
        view.pageViewController(
            pager, didFinishAnimating: true, previousViewControllers: [first], transitionCompleted: true)
        XCTAssertEqual(fixture.output.indices, [1, 0, 1])
        view.cardsPageDidSelectMeasurementIndicator(fixture.first.indicator(.init(type: .temperature)), in: second)
        XCTAssertEqual(fixture.output.tapped, [fixture.second.snapshot.id])
    }

    func testRapidIndexUpdatesKeepThePageIdentityInSyncWithItsDisplayedSensor() throws {
        let fixture = try MeasurementPagingFixture()
        defer { fixture.close() }
        fixture.view.updateSnapshots(fixture.snapshots, currentIndex: 1)
        let page = try fixture.page()
        XCTAssertEqual(page.pageIndex, 1, "A throttled refresh must not retain the preceding sensor's page index")
        fixture.view.cardsPageDidSelectMeasurementIndicator(
            fixture.first.indicator(.init(type: .temperature)), in: page)
        XCTAssertEqual(fixture.output.tapped, [fixture.second.snapshot.id])
        XCTAssertNil(fixture.view.pageViewController(fixture.pager, viewControllerAfter: page))
        fixture.view.updateSnapshots([fixture.first.snapshot], currentIndex: 99)
        XCTAssertEqual(try fixture.page().pageIndex, 0)
        XCTAssertNil(fixture.view.pageViewController(fixture.pager, viewControllerBefore: try fixture.page()))
        fixture.view.updateSnapshots([fixture.first.snapshot], currentIndex: -4)
        XCTAssertEqual(try fixture.page().pageIndex, 0)
    }

    func testRemovedPagesCannotOpenMeasurementsAndEmptyDataCanBeRepopulated() throws {
        let fixture = try MeasurementPagingFixture()
        defer { fixture.close() }
        let stale = CardsMeasurementPageViewController()
        stale.pageIndex = 1
        fixture.view.updateSnapshots([fixture.first.snapshot], currentIndex: 0)
        fixture.view.cardsPageDidSelectMeasurementIndicator(
            fixture.first.indicator(.init(type: .temperature)), in: stale)
        XCTAssertTrue(fixture.output.tapped.isEmpty)
        fixture.view.updateSnapshots([], currentIndex: 0)
        XCTAssertFalse(fixture.pager.viewControllers?.first is CardsMeasurementPageViewController)
        XCTAssertTrue(fixture.pager.view.isHidden)
        fixture.view.updateSnapshots(fixture.snapshots, currentIndex: 1)
        XCTAssertEqual(try fixture.page().pageIndex, 1)
        XCTAssertFalse(fixture.pager.view.isHidden)
    }
}

@MainActor private final class MeasurementPagingFixture {
    let first = MeasurementFixture()
    let second = MeasurementFixture()
    let view = CardsMeasurementViewController()
    let output = MeasurementPagingOutputSpy()
    let host: AppViewHost
    let pager: UIPageViewController
    var snapshots: [RuuviTagCardSnapshot] { [first.snapshot, second.snapshot] }
    init() throws {
        view.output = output
        host = try AppViewHost(view)
        pager = try XCTUnwrap(view.children.compactMap { $0 as? UIPageViewController }.first)
        view.updateSnapshots([first.snapshot, second.snapshot], currentIndex: 0)
    }
    func page() throws -> CardsMeasurementPageViewController {
        try XCTUnwrap(pager.viewControllers?.first as? CardsMeasurementPageViewController)
    }
    func close() { host.close(); first.cleanup(); second.cleanup() }
}
private final class MeasurementPagingOutputSpy: CardsMeasurementViewOutput {
    var indices = [Int]()
    var tapped = [String]()
    func viewWillAppear(sender: CardsMeasurementViewController) {}
    func viewDidScroll(to index: Int, sender: CardsMeasurementViewController) { indices.append(index) }
    func viewDidTapMeasurement(for indicator: RuuviTagCardSnapshotIndicatorData, snapshot: RuuviTagCardSnapshot) {
        tapped.append(snapshot.id)
    }
}
