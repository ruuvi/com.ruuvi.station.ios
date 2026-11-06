import RuuviLocalization
import UIKit
import XCTest
@testable import station

@MainActor final class DashboardScreenUpdateTests: XCTestCase {
    func testSearchDebouncesAndSelectsTheFilteredSensorCaseInsensitively() async throws {
        let fixture = DashboardScreenFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        let field = try XCTUnwrap(fixture.descendants(fixture.view.view).compactMap { $0 as? UITextField }.first)
        field.text = "off"; field.sendActions(for: .editingChanged)
        field.text = "KITCH"; field.sendActions(for: .editingChanged)
        await waitForAppState("filtered dashboard") { fixture.collection.numberOfItems(inSection: 0) == 1 }
        fixture.view.collectionView(fixture.collection, didSelectItemAt: IndexPath(item: 0, section: 0))
        XCTAssertEqual(fixture.output.navigation.last?.1, fixture.snapshots[1].id)
        XCTAssertTrue(fixture.view.textFieldShouldReturn(field))
        field.text = "not a sensor"; field.sendActions(for: .editingChanged)
        await waitForAppState("empty search") { fixture.collection.numberOfItems(inSection: 0) == 0 }
        let cancel = try XCTUnwrap(
            fixture.descendants(fixture.view.view).compactMap { $0 as? UIButton }
                .first { $0.title(for: .normal) == RuuviLocalization.cancel })
        cancel.sendActions(for: .touchUpInside)
        await waitForAppState("search cancelled") { fixture.collection.numberOfItems(inSection: 0) == 3 }
        XCTAssertEqual(field.text, "")
    }

    func testRenamingASensorWhileSearchingUpdatesTheMatchingResults() async throws {
        let fixture = DashboardScreenFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        let field = try XCTUnwrap(fixture.descendants(fixture.view.view).compactMap { $0 as? UITextField }.first)
        field.text = "office"; field.sendActions(for: .editingChanged)
        await waitForAppState("initial name match") { fixture.collection.numberOfItems(inSection: 0) == 1 }
        let snapshot = fixture.snapshots[0]
        snapshot.displayData.name = "Garage"
        fixture.view.updateSnapshot(from: snapshot, invalidateLayout: true)
        await waitForAppState("renamed sensor leaves search") { fixture.collection.numberOfItems(inSection: 0) == 0 }
        snapshot.displayData.name = "Office upstairs"
        fixture.view.updateSnapshot(from: snapshot, invalidateLayout: false)
        await waitForAppState("renamed sensor enters search") { fixture.collection.numberOfItems(inSection: 0) == 1 }
    }

    func testEndingAnUnchangedDragDoesNotFreezeSubsequentSensorUpdates() async throws {
        let fixture = DashboardScreenFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        let collection = fixture.collection
        let layout = try XCTUnwrap(collection.collectionViewLayout as? MasonryReorderableLayout)
        let path = IndexPath(item: 0, section: 0)
        fixture.view.collectionView(collection, layout: layout, willBeginDraggingItemAt: path)
        fixture.view.collectionView(collection, layout: layout, didBeginDraggingItemAt: path)
        fixture.view.collectionView(collection, layout: layout, didEndDraggingItemTo: path)
        await flushAppBindings()
        XCTAssertTrue(fixture.output.orders.isEmpty)
        fixture.view.updateSnapshots(Array(fixture.snapshots.prefix(2)), withAnimation: true)
        await waitForAppState("dashboard updates after unchanged drag") { collection.numberOfItems(inSection: 0) == 2 }
    }

    func testUpdatesReceivedDuringADragAppearWhenTheDragEnds() async throws {
        let fixture = DashboardScreenFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        let collection = fixture.collection
        let layout = try XCTUnwrap(collection.collectionViewLayout as? MasonryReorderableLayout)
        let path = IndexPath(item: 0, section: 0)
        fixture.view.collectionView(collection, layout: layout, willBeginDraggingItemAt: path)
        fixture.view.updateSnapshots(Array(fixture.snapshots.prefix(2)), withAnimation: false)
        XCTAssertEqual(collection.numberOfItems(inSection: 0), 3)
        fixture.view.collectionView(collection, layout: layout, didEndDraggingItemTo: path)
        await waitForAppState("deferred sensor removal after drag") { collection.numberOfItems(inSection: 0) == 2 }
        XCTAssertTrue(fixture.output.orders.isEmpty)
    }

    func testClosingTheCardMenuAppliesDeferredSensorChanges() async throws {
        let fixture = DashboardScreenFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        let snapshot = fixture.snapshots[0]
        fixture.view.didChangeMoreButtonMenuPresentationState(for: snapshot, isPresented: true)
        fixture.view.updateSnapshots(Array(fixture.snapshots.prefix(1)), withAnimation: false)
        XCTAssertEqual(fixture.collection.numberOfItems(inSection: 0), 3)
        fixture.view.didChangeMoreButtonMenuPresentationState(for: snapshot, isPresented: false)
        await waitForAppState("deferred list after menu dismissal") {
            fixture.collection.numberOfItems(inSection: 0) == 1
        }
    }

    func testLayoutUsesPortraitAndLandscapeColumnsAndRefreshStateTracksTheRequest() async throws {
        let fixture = DashboardScreenFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        let portrait = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 400, height: 800),
            collectionViewLayout: UICollectionViewFlowLayout())
        let landscape = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 800, height: 400),
            collectionViewLayout: UICollectionViewFlowLayout())
        XCTAssertEqual(fixture.view.numberOfColumns(in: portrait), 1)
        XCTAssertEqual(fixture.view.numberOfColumns(in: landscape), 2)
        XCTAssertEqual(fixture.view.columnSpacing(in: portrait), 8)
        XCTAssertEqual(fixture.view.sectionInsets(in: portrait), UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8))
        XCTAssertGreaterThan(fixture.view.collectionView(portrait, heightForItemAt: IndexPath(item: 0, section: 0)), 0)
        XCTAssertEqual(fixture.view.collectionView(portrait, heightForItemAt: IndexPath(item: 20, section: 0)), 200)
        fixture.view.isRefreshing = true
        XCTAssertTrue(
            fixture.descendants(fixture.view.view).compactMap { $0 as? UIActivityIndicatorView }
                .contains(where: \.isAnimating))
        fixture.view.isRefreshing = false
        XCTAssertFalse(
            fixture.descendants(fixture.view.view).compactMap { $0 as? UIActivityIndicatorView }
                .contains(where: \.isAnimating))
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(fixture.collection.numberOfItems(inSection: 0), 3)
    }
}
