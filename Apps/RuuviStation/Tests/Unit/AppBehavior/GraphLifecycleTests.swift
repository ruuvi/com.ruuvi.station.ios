import BTKit
import Foundation
import RuuviLocal
import RuuviService
import XCTest
@testable import station

@MainActor final class GraphLifecycleTests: XCTestCase {
    func testAnExternalQueuedDownloadIsAdoptedWithoutStartingADuplicate() async {
        let fixture = GraphFixture()
        defer { fixture.cleanup() }
        fixture.interactor.syncing = true
        fixture.interactor.queued = true
        fixture.presenter.viewWillAppear()
        XCTAssertEqual(fixture.view.syncStates.last?.1, "queued")
        XCTAssertEqual(fixture.output.syncing.last, true)
        fixture.presenter.viewDidTriggerSync(for: fixture.measurements.snapshot)
        fixture.presenter.start(shouldSyncFromCloud: false)
        await flushAppBindings()
        XCTAssertEqual(fixture.interactor.syncs, 0)
        XCTAssertEqual(fixture.interactor.stops, 0, "Opening the graph must preserve an external download")
        XCTAssertTrue(fixture.view.syncConfirmations.isEmpty)
        fixture.interactor.syncing = false
        fixture.presenter.viewWillAppear()
        XCTAssertEqual(fixture.view.syncStates.last?.1, "idle")
        XCTAssertEqual(fixture.output.syncing.last, false)
    }

    func testExternalProgressNotificationsAreScopedToTheSensorAndRefreshFinishedHistory() async {
        let fixture = GraphFixture()
        defer { fixture.cleanup() }
        fixture.notifications.post(
            name: .RuuviTagReadLogsOperationDidStart, object: nil,
            userInfo: [
                RuuviTagReadLogsOperationDidStartKey.uuid: "different-sensor"
            ])
        XCTAssertEqual(fixture.output.syncing.last, false)
        fixture.interactor.syncing = true
        let luid = fixture.measurements.sensor.luid!.value
        fixture.notifications.post(
            name: .RuuviTagReadLogsOperationDidStart, object: nil,
            userInfo: [
                RuuviTagReadLogsOperationDidStartKey.uuid: luid
            ])
        XCTAssertEqual(fixture.view.syncStates.last?.1, "connecting")
        fixture.notifications.post(
            name: .RuuviTagReadLogsOperationProgress, object: nil,
            userInfo: [
                RuuviTagReadLogsOperationProgressKey.uuid: luid,
                RuuviTagReadLogsOperationProgressKey.progress: 12,
            ])
        XCTAssertEqual(fixture.view.syncStates.last?.1, "reading:12")
        fixture.notifications.post(
            name: .RuuviTagReadLogsOperationProgress, object: nil,
            userInfo: [
                RuuviTagReadLogsOperationProgressKey.uuid: luid,
                RuuviTagReadLogsOperationProgressKey.serviceProgress: BTServiceProgress.reading(45),
            ])
        XCTAssertEqual(fixture.view.syncStates.last?.1, "reading:45")
        fixture.notifications.post(
            name: .RuuviTagReadLogsOperationDidFinish, object: nil,
            userInfo: [
                RuuviTagReadLogsOperationDidFinishKey.uuid: luid
            ])
        fixture.interactor.syncing = false
        await waitForAppState("external download completed") { fixture.interactor.dataStarts == 1 }
        XCTAssertEqual(fixture.output.syncing.last, false)
        XCTAssertEqual(fixture.view.syncStates.last?.1, "idle")
        fixture.notifications.post(
            name: .RuuviTagReadLogsOperationDidFail, object: nil,
            userInfo: [
                RuuviTagReadLogsOperationDidFailKey.uuid: luid
            ])
        await waitForAppState("external failure refresh") { fixture.interactor.dataStarts == 2 }
        XCTAssertEqual(fixture.view.syncFailures, 0)
    }

    func testStoppingDetachesSettingsAndReactorUntilTheModuleStartsAgain() async {
        let fixture = GraphFixture()
        defer { fixture.cleanup() }
        fixture.presenter.viewDidLoad()
        fixture.presenter.start(shouldSyncFromCloud: false)
        XCTAssertEqual(fixture.reactor.settings.count, 1)
        fixture.presenter.stop()
        XCTAssertTrue(fixture.reactor.settings.isEmpty)
        let before = fixture.interactor.dataStarts
        fixture.notifications.post(name: .TemperatureUnitDidChange, object: nil)
        XCTAssertEqual(fixture.interactor.dataStarts, before)
        fixture.presenter.start(shouldSyncFromCloud: false)
        XCTAssertEqual(fixture.reactor.settings.count, 1)
        fixture.notifications.post(name: .TemperatureUnitDidChange, object: nil)
        XCTAssertEqual(fixture.interactor.dataStarts, before + 1)
        await flushAppBindings()
    }

    func testReleasingThePresenterDetachesItsSensorObservers() async {
        let fixture = GraphFixture()
        fixture.presenter.viewDidLoad()
        fixture.presenter.start(shouldSyncFromCloud: false)
        weak var presenter = fixture.presenter
        fixture.presenter = nil
        await flushAppBindings()
        XCTAssertNil(presenter)
        XCTAssertTrue(fixture.reactor.settings.isEmpty)
        fixture.measurements.cleanup()
    }
}
