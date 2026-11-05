import Foundation
import RuuviLocal
#if SWIFT_PACKAGE
    @testable import RuuviLocalUserDefaults
#else
    @testable import RuuviLocal
#endif
import RuuviOntology
import XCTest

@MainActor final class SyncPersistenceTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    private let first = "AA:BB:CC:DD:EE:01".mac
    private let second = "AA:BB:CC:DD:EE:02".mac

    override func setUp() {
        super.setUp()
        suite = "ruuvi-sync-tests-" + UUID().uuidString
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testEverySyncStatusPersistsAndNotifiesOnMainThreadWithSensorIdentity() async {
        let notifications = NotificationCenter()
        let state = RuuviLocalSyncStateUserDefaults(defaults: defaults, notifications: notifications)
        XCTAssertEqual(state.syncStatus, .none)
        XCTAssertEqual(state.getSyncStatusLatestRecord(for: first), .none)
        for status: NetworkSyncStatus in [.none, .syncing, .complete, .onError] {
            let completed = expectation(description: "All three status notifications")
            completed.expectedFulfillmentCount = 3
            let tokens = [
                Notification.Name.NetworkSyncLatestDataDidChangeStatus,
                .NetworkSyncHistoryDidChangeStatus, .NetworkSyncDidChangeCommonStatus,
            ].map { name in
                notifications.addObserver(forName: name, object: nil, queue: nil) { event in
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(event.userInfo?[NetworkSyncStatusKey.status] as? NetworkSyncStatus, status)
                    if name == .NetworkSyncDidChangeCommonStatus {
                        XCTAssertEqual(state.syncStatus, status)
                        XCTAssertTrue((event.object as? RuuviLocalSyncStateUserDefaults) === state)
                    } else {
                        XCTAssertEqual(
                            (event.userInfo?[NetworkSyncStatusKey.mac] as? MACIdentifier)?.value, self.first.value)
                    }
                    completed.fulfill()
                }
            }
            state.setSyncStatusLatestRecord(status, for: first)
            state.setSyncStatusHistory(status, for: first)
            state.setSyncStatus(status)
            await fulfillment(of: [completed], timeout: 2)
            tokens.forEach(notifications.removeObserver)
            let restored = RuuviLocalSyncStateUserDefaults(defaults: defaults)
            XCTAssertEqual(restored.getSyncStatusLatestRecord(for: first), status)
            XCTAssertEqual(restored.getSyncStatusLatestRecord(for: second), .none)
            XCTAssertEqual(restored.syncStatus, status)
        }
        defaults.set(99, forKey: "RuuviLocalSyncStateUserDefaults.syncStatus")
        defaults.set(99, forKey: "RuuviLocalSyncStateUserDefaults.syncState." + first.value)
        XCTAssertEqual(state.syncStatus, .none)
        XCTAssertEqual(state.getSyncStatusLatestRecord(for: first), .none)
        state.setSyncStatusHistory(.syncing, for: nil)
    }

    func testSyncDatesRoundTripIndependentlyAndMissingIdentifiersAreSafe() {
        let state = RuuviLocalSyncStateUserDefaults(defaults: defaults)
        let date = Date(timeIntervalSince1970: 1234)
        XCTAssertNil(state.getSyncDate(for: first))
        XCTAssertNil(state.getGattSyncDate(for: first))
        XCTAssertNil(state.getAutoGattSyncAttemptDate(for: first))
        state.setSyncDate(date, for: first)
        state.setGattSyncDate(date.addingTimeInterval(1), for: first)
        state.setAutoGattSyncAttemptDate(date.addingTimeInterval(2), for: first)
        let restored = RuuviLocalSyncStateUserDefaults(defaults: defaults)
        XCTAssertEqual(restored.getSyncDate(for: first), date)
        XCTAssertEqual(restored.getGattSyncDate(for: first), date.addingTimeInterval(1))
        XCTAssertEqual(restored.getAutoGattSyncAttemptDate(for: first), date.addingTimeInterval(2))
        XCTAssertNil(restored.getSyncDate(for: second))
        XCTAssertNil(restored.getGattSyncDate(for: second))
        XCTAssertNil(restored.getAutoGattSyncAttemptDate(for: second))
        state.setSyncDate(nil, for: first)
        state.setGattSyncDate(nil, for: first)
        state.setAutoGattSyncAttemptDate(nil, for: first)
        state.setSyncDate(date, for: nil)
        state.setGattSyncDate(date, for: nil)
        state.setAutoGattSyncAttemptDate(date, for: nil)
        XCTAssertNil(restored.getSyncDate(for: first))
        XCTAssertNil(restored.getGattSyncDate(for: first))
        XCTAssertNil(restored.getAutoGattSyncAttemptDate(for: first))
        XCTAssertNil(restored.getSyncDate(for: nil))
        XCTAssertNil(restored.getGattSyncDate(for: nil))
        XCTAssertNil(restored.getAutoGattSyncAttemptDate(for: nil))
    }

    func testSavingGlobalSyncDateResetsStatusAfterPersistenceAndCanBeCleared() async {
        let notifications = NotificationCenter()
        let state = RuuviLocalSyncStateUserDefaults(defaults: defaults, notifications: notifications)
        XCTAssertNil(state.getSyncDate())
        for date in [Date(timeIntervalSince1970: 100), nil] as [Date?] {
            state.syncStatus = .syncing
            let completed = expectation(description: "Sync complete status")
            let token = notifications.addObserver(forName: .NetworkSyncDidChangeCommonStatus, object: nil, queue: nil) {
                _ in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(state.syncStatus, .none)
                XCTAssertEqual(state.getSyncDate(), date)
                completed.fulfill()
            }
            state.setSyncDate(date)
            await fulfillment(of: [completed], timeout: 2)
            notifications.removeObserver(token)
            XCTAssertEqual(RuuviLocalSyncStateUserDefaults(defaults: defaults).getSyncDate(), date)
        }
    }

    func testFullHistoryAndFirstSyncFlagsDistinguishUnsetValuesAndRemainSensorSpecific() {
        let state = RuuviLocalSyncStateUserDefaults(defaults: defaults)
        XCTAssertNil(state.downloadFullHistory(for: first))
        XCTAssertFalse(state.hasLoggedFirstAutoSyncGattHistoryForRuuviAir(for: first))
        for flag in [true, false] {
            state.setDownloadFullHistory(for: first, downloadFull: flag)
            state.setHasLoggedFirstAutoSyncGattHistoryForRuuviAir(flag, for: first)
            let restored = RuuviLocalSyncStateUserDefaults(defaults: defaults)
            XCTAssertEqual(restored.downloadFullHistory(for: first), flag)
            XCTAssertEqual(restored.hasLoggedFirstAutoSyncGattHistoryForRuuviAir(for: first), flag)
            XCTAssertNil(restored.downloadFullHistory(for: second))
            XCTAssertFalse(restored.hasLoggedFirstAutoSyncGattHistoryForRuuviAir(for: second))
        }
        state.setDownloadFullHistory(for: first, downloadFull: nil)
        state.setDownloadFullHistory(for: nil, downloadFull: true)
        state.setHasLoggedFirstAutoSyncGattHistoryForRuuviAir(true, for: nil)
        state.setAutoGattSyncSuppressed(true, for: nil)
        XCTAssertNil(state.downloadFullHistory(for: first))
        XCTAssertNil(state.downloadFullHistory(for: nil))
        XCTAssertFalse(state.hasLoggedFirstAutoSyncGattHistoryForRuuviAir(for: nil))
        XCTAssertFalse(state.isAutoGattSyncSuppressed(for: nil))
    }
}
