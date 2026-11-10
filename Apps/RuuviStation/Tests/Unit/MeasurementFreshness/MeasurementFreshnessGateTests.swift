@testable import station
import XCTest
import RuuviLocal
import RuuviService
import RuuviOntology

@MainActor
final class MeasurementFreshnessGateTests: XCTestCase {
    private var uptime: TimeInterval = 0
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var center: NotificationCenter!
    private var gate: MeasurementFreshnessGate!

    override func setUp() {
        super.setUp()
        center = NotificationCenter()
        gate = MeasurementFreshnessGate(notificationCenter: center, uptime: { [unowned self] in self.uptime })
    }

    override func tearDown() {
        gate = nil
        center = nil
        super.tearDown()
    }

    func testLocalReadingsGetExactlyThirtySecondsForDiscovery() {
        gate.beginForegroundSession(expectingCloudSync: false)
        let local = snapshot()
        uptime = 29.999
        XCTAssertFalse(warns(local))
        uptime = 30
        XCTAssertTrue(warns(local))
        local.lastUpdated = now
        XCTAssertFalse(warns(local))
    }

    func testLocalGraceDoesNotWaitForCloudSync() {
        gate.beginForegroundSession(expectingCloudSync: true)
        _ = start()
        uptime = 30
        XCTAssertTrue(warns(snapshot()))
        XCTAssertFalse(warns(snapshot(cloud: true)))
    }

    func testClaimedSensorsAlsoGetBluetoothDiscoveryGraceAfterQuickCloudSync() {
        gate.beginForegroundSession(expectingCloudSync: true)
        let id = start()
        uptime = 2
        finish(id)
        XCTAssertFalse(warns(snapshot(cloud: true)))
        uptime = 29.999
        XCTAssertFalse(warns(snapshot(cloud: true)))
        uptime = 30
        XCTAssertTrue(warns(snapshot(cloud: true)))
    }

    func testMissingCloudStartHasABoundedFallback() {
        gate.beginForegroundSession(expectingCloudSync: true)
        uptime = 59.999
        XCTAssertFalse(warns(snapshot(cloud: true)))
        uptime = 60
        XCTAssertTrue(warns(snapshot(cloud: true)))
    }

    func testAStuckSyncCannotHideOldCloudDataIndefinitely() {
        gate.beginForegroundSession(expectingCloudSync: true)
        _ = start()
        uptime = 60
        XCTAssertTrue(warns(snapshot(cloud: true)))
    }

    func testOverlappingSyncsFinishByIdentityAndDuplicatesDoNotReleaseTheWait() {
        gate.beginForegroundSession(expectingCloudSync: true)
        let first = start()
        let second = start()
        uptime = 30
        finish(second)
        finish(second)
        finish(UUID())
        XCTAssertFalse(warns(snapshot(cloud: true)))
        finish(first)
        XCTAssertTrue(warns(snapshot(cloud: true)))
    }

    func testSuccessOrFailureReleasesInitialWaitAfterGrace() {
        gate.beginForegroundSession(expectingCloudSync: true)
        let id = start()
        uptime = 30
        finish(id)
        XCTAssertTrue(warns(snapshot(cloud: true)))
    }

    func testCommittedFreshRecordWaitsForSnapshotEvenWhenCompletionArrivesFirst() {
        gate.beginForegroundSession(expectingCloudSync: true)
        let cloud = snapshot(cloud: true)
        let id = start()
        post(.recordsSaved(["AA:BB:CC:DD:EE:FF": now]))
        finish(id)
        uptime = 30
        XCTAssertFalse(warns(cloud))
        cloud.lastUpdated = now
        XCTAssertFalse(warns(cloud))
    }

    func testSnapshotMayArriveBeforeSyncCompletion() {
        gate.beginForegroundSession(expectingCloudSync: true)
        let cloud = snapshot(cloud: true)
        let id = start()
        cloud.lastUpdated = now
        post(.recordsSaved(["aa:bb:cc:dd:ee:ff": now]))
        finish(id)
        uptime = 30
        XCTAssertFalse(warns(cloud))
    }

    func testCommittedOldRecordOnlyWarnsOnceSnapshotCatchesUp() {
        gate.beginForegroundSession(expectingCloudSync: true)
        let cloud = snapshot(cloud: true)
        let id = start()
        let committed = now.addingTimeInterval(-4000)
        post(.recordsSaved(["AA:BB:CC:DD:EE:FF": committed]))
        finish(id)
        uptime = 30
        XCTAssertFalse(warns(cloud))
        cloud.lastUpdated = committed
        XCTAssertTrue(warns(cloud))
    }

    func testLostSnapshotUpdateAlsoHasABoundedFallback() {
        gate.beginForegroundSession(expectingCloudSync: true)
        let id = start()
        post(.recordsSaved(["AA:BB:CC:DD:EE:FF": now]))
        finish(id)
        uptime = 60
        XCTAssertTrue(warns(snapshot(cloud: true)))
    }

    func testResumingRestartsGraceButAnInFlightAttemptCanFinish() {
        gate.beginForegroundSession(expectingCloudSync: true)
        let id = start()
        uptime = 10
        gate.beginForegroundSession(expectingCloudSync: true)
        finish(id)
        uptime = 39
        XCTAssertFalse(warns(snapshot(cloud: true)))
        uptime = 40
        XCTAssertTrue(warns(snapshot(cloud: true)))
    }

    func testExpiredOperationCannotCompleteAnotherSessionsWait() {
        gate.beginForegroundSession(expectingCloudSync: true)
        let old = start()
        uptime = 90
        gate.beginForegroundSession(expectingCloudSync: true)
        let current = start()
        uptime = 120
        finish(old)
        XCTAssertFalse(warns(snapshot(cloud: true)))
        finish(current)
        XCTAssertTrue(warns(snapshot(cloud: true)))
    }

    func testRoutinePollsDoNotBlinkAnAlreadyConfirmedWarning() {
        gate.beginForegroundSession(expectingCloudSync: true)
        finish(start())
        uptime = 30
        _ = start()
        XCTAssertTrue(warns(snapshot(cloud: true)))
    }

    func testCloudSourceOnLocallyAddedSensorsAlsoWaitsForSync() {
        gate.beginForegroundSession(expectingCloudSync: true)
        let local = snapshot()
        local.displayData.source = .ruuviNetwork
        uptime = 30
        XCTAssertFalse(warns(local))
        finish(start())
        XCTAssertTrue(warns(local))
    }

    func testLogoutReleasesCloudWaitAndConfiguredTimeoutIsStillApplied() {
        gate.beginForegroundSession(expectingCloudSync: true)
        _ = start()
        uptime = 30
        center.post(name: .RuuviAuthServiceDidLogout, object: nil)
        XCTAssertTrue(warns(snapshot(cloud: true)))
        let local = snapshot()
        local.lastUpdated = now.addingTimeInterval(-10)
        XCTAssertTrue(warns(local, timeout: 1))
        XCTAssertFalse(warns(local, timeout: 3600))
        XCTAssertFalse(gate.shouldShowWarning(for: nil, timeoutSeconds: 1, now: now))
    }

    private func post(_ event: RuuviCloudSyncEvent) {
        center.post(name: RuuviCloudSyncEvent.notification, object: nil,
                    userInfo: [RuuviCloudSyncEvent.userInfoKey: event])
    }

    private func start() -> UUID {
        let id = UUID()
        post(.started(id))
        return id
    }

    private func finish(_ id: UUID) { post(.finished(id)) }

    private func snapshot(cloud: Bool = false) -> RuuviTagCardSnapshot {
        let snapshot = RuuviTagCardSnapshot(
            id: "sensor", identifierData: .init(mac: "AA:BB:CC:DD:EE:FF".mac),
            lastUpdated: now.addingTimeInterval(-7200)
        )
        snapshot.metadata.isCloud = cloud
        return snapshot
    }

    private func warns(_ snapshot: RuuviTagCardSnapshot, timeout: Int = 3600) -> Bool {
        gate.shouldShowWarning(for: snapshot, timeoutSeconds: timeout, now: now)
    }
}
