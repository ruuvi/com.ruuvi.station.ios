@testable import station
import Combine
import XCTest

@MainActor
final class MeasurementFreshnessServiceTests: XCTestCase {
    func testOneTimeoutReadPerBatchAndOnlyChangedStatesArePublished() {
        var uptime: TimeInterval = 0
        let gate = MeasurementFreshnessGate(notificationCenter: NotificationCenter(), uptime: { uptime })
        uptime = 30
        let now = Date()
        var timeout = 3600
        var reads = 0
        let service = MeasurementFreshnessService(gate: gate, timeout: { reads += 1; return timeout }, now: { now })
        let snapshots = (0..<10).map { index in
            RuuviTagCardSnapshot(
                id: "sensor-\(index)", identifierData: .init(), lastUpdated: now.addingTimeInterval(-7200)
            )
        }
        snapshots.forEach { service.track($0) }
        var changes = 0
        let observation = snapshots[0].$isOutdated.dropFirst().sink { _ in changes += 1 }
        reads = 0
        service.refresh()
        XCTAssertEqual(reads, 1)
        XCTAssertEqual(changes, 0)
        XCTAssertTrue(snapshots.allSatisfy(\.isOutdated))
        snapshots[0].lastUpdated = now
        service.refresh()
        XCTAssertEqual(changes, 1)
        XCTAssertFalse(snapshots[0].isOutdated)
        timeout = 10000
        service.refresh()
        XCTAssertTrue(snapshots.allSatisfy { !$0.isOutdated })
        withExtendedLifetime(observation) {}
    }

    func testInitialSubscriptionDoesNotRecheckAndRecordChangesAreCoalesced() async {
        var uptime: TimeInterval = 0
        let gate = MeasurementFreshnessGate(notificationCenter: NotificationCenter(), uptime: { uptime })
        uptime = 30
        let now = Date()
        var reads = 0
        let service = MeasurementFreshnessService(gate: gate, timeout: { reads += 1; return 3600 }, now: { now })
        let snapshot = RuuviTagCardSnapshot(
            id: "sensor", identifierData: .init(), lastUpdated: now.addingTimeInterval(-7200)
        )
        service.track(snapshot)
        let subscriptionsDrained = expectation(description: "Initial publisher delivery drained")
        DispatchQueue.main.async { DispatchQueue.main.async { subscriptionsDrained.fulfill() } }
        await fulfillment(of: [subscriptionsDrained], timeout: 2)
        XCTAssertEqual(reads, 1)
        reads = 0
        let refreshed = expectation(description: "Fresh state published after record changes")
        let observation = snapshot.$isOutdated.dropFirst().filter { !$0 }.sink { _ in refreshed.fulfill() }
        snapshot.lastUpdated = now
        snapshot.metadata.isCloud = true
        snapshot.displayData.source = .ruuviNetwork
        await fulfillment(of: [refreshed], timeout: 2)
        XCTAssertEqual(reads, 1)
        XCTAssertFalse(snapshot.isOutdated)
        withExtendedLifetime(observation) {}
    }

    func testTrackingDoesNotRetainDiscardedSnapshot() {
        let service = MeasurementFreshnessService()
        weak var released: RuuviTagCardSnapshot?
        autoreleasepool {
            let snapshot = RuuviTagCardSnapshot(id: "temporary", identifierData: .init(), lastUpdated: nil)
            released = snapshot
            service.track(snapshot)
        }
        XCTAssertNil(released)
        service.refresh()
    }

    func testOneBindingUpdatesBothControlsAndNotifiesOnlyOnFreshTransitions() {
        var uptime: TimeInterval = 0
        let gate = MeasurementFreshnessGate(notificationCenter: NotificationCenter(), uptime: { uptime })
        uptime = 30
        let now = Date()
        let service = MeasurementFreshnessService(gate: gate, now: { now })
        let button = SensorDataSourceButton()
        let label = MeasurementTimestampLabel()
        let binding = MeasurementFreshnessBinding(button: button, timestamp: label)
        var callbacks = 0
        binding.onFresh = { _ in callbacks += 1 }
        let snapshot = RuuviTagCardSnapshot(
            id: "sensor", identifierData: .init(), lastUpdated: now.addingTimeInterval(-7200)
        )
        binding.bind(snapshot, service: service)
        XCTAssertTrue(button.isStale)
        XCTAssertTrue(label.isWarningVisible)
        for _ in 0..<5 { service.refresh(); binding.updateTimestampLabel() }
        XCTAssertEqual(callbacks, 0)
        snapshot.lastUpdated = now
        service.refresh()
        XCTAssertFalse(button.isStale)
        XCTAssertFalse(label.isWarningVisible)
        XCTAssertEqual(callbacks, 1)
        for _ in 0..<5 { service.refresh(); binding.updateTimestampLabel() }
        binding.bind(snapshot, service: service)
        XCTAssertEqual(callbacks, 1)
        binding.bind(nil, service: nil)
        XCTAssertFalse(button.isStale)
        XCTAssertFalse(label.isWarningVisible)
    }
}
