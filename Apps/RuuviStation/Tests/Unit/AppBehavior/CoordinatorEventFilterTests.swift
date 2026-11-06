import Foundation
import XCTest
@testable import station

@MainActor final class CoordinatorEventFilterTests: XCTestCase {
    func testCategoryFiltersDeliverOnlyTheirOwnEventsAndTheDefaultIncludesEveryCategory() {
        let fixture = MeasurementFixture()
        defer { fixture.cleanup() }
        let error = NSError(domain: "event-test", code: 1)
        let groups: [[RuuviTagServiceCoordinatorEvent]] = [
            [
                .snapshotsUpdated([fixture.snapshot], reason: .initial, withAnimation: false),
                .snapshotUpdated(fixture.snapshot, invalidateLayout: true),
                .newSensorAdded(fixture.sensor, newOrder: []),
                .dataServiceError(error),
            ],
            [
                .userLoginStateChanged(true), .userLogoutStateChanged(true), .cloudSyncStatusChanged(true),
                .cloudSyncCompleted, .historySyncInProgress(true, macId: "AA"), .authorizationFailed,
                .cloudModeChanged(true),
            ],
            [.alertSnapshotUpdated(fixture.snapshot), .alertsChanged],
            [
                .connectionSnapshotUpdated(fixture.snapshot),
                .bluetoothStateChanged(isEnabled: true, userDeclined: false),
                .connectionServiceError(error),
            ],
        ]
        XCTAssertEqual(Set(groups.flatMap { $0.map(\.eventType) }), Set(RuuviTagCoordinatorEventType.allCases))
        let all = RuuviTagServiceCoordinatorEventFilter()
        XCTAssertTrue(groups.flatMap { $0 }.allSatisfy(all.shouldInclude))
        for category in 0..<4 {
            let filter = RuuviTagServiceCoordinatorEventFilter(
                includeDataEvents: category == 0,
                includeCloudEvents: category == 1, includeAlertEvents: category == 2,
                includeConnectionEvents: category == 3)
            for (index, events) in groups.enumerated() {
                for event in events {
                    XCTAssertEqual(filter.shouldInclude(event), index == category, event.eventType.rawValue)
                }
            }
        }
        let explicit = RuuviTagServiceCoordinatorEventFilter(
            includeDataEvents: false, includeCloudEvents: false,
            includeAlertEvents: false, includeConnectionEvents: false,
            specificEvents: [.authorizationFailed, .alertsChanged])
        XCTAssertEqual(
            groups.flatMap { $0 }.filter(explicit.shouldInclude).map(\.eventType),
            [.authorizationFailed, .alertsChanged])
        let empty = RuuviTagServiceCoordinatorEventFilter(specificEvents: [])
        XCTAssertFalse(groups.flatMap { $0 }.contains(where: empty.shouldInclude))
    }
}
