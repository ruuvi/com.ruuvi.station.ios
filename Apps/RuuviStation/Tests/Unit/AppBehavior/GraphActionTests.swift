import Foundation
import RuuviLocal
import RuuviOntology
import XCTest
@testable import station

@MainActor final class GraphActionTests: XCTestCase {
    func testHistoryAndDisplayPreferencesAreClampedAndAppliedToTheView() {
        let fixture = GraphFixture()
        defer { fixture.cleanup() }
        let settings = fixture.measurements.settings
        settings.dataPruningOffsetHours = 24
        settings.chartDurationHours = 12
        settings.chartStatsOn = true
        settings.chartShowAll = false
        settings.chartsPerScreen = 4
        settings.showAlertsRangeInGraph = true
        fixture.presenter.viewWillAppear()
        XCTAssertEqual(fixture.view.active?.id, fixture.measurements.sensor.id)
        XCTAssertEqual(fixture.view.historyLengthInHours, 12)
        XCTAssertTrue(fixture.view.showChartStat)
        XCTAssertTrue(fixture.view.showAlertRangeInGraph)
        XCTAssertEqual(fixture.view.chartsPerScreen, 4)
        for (input, expected) in [(-1, 1), (0, 1), (8, 8), (100, 24)] {
            fixture.presenter.viewDidSelectChartHistoryLength(hours: input)
            XCTAssertEqual(settings.chartDurationHours, expected)
            XCTAssertEqual(fixture.view.historyLengthInHours, expected)
            XCTAssertFalse(fixture.view.showChartAll)
        }
        fixture.presenter.viewDidSelectAllChartHistory()
        XCTAssertTrue(settings.chartShowAll)
        XCTAssertTrue(fixture.view.showChartAll)
        XCTAssertEqual(settings.chartDurationHours, 24)
        fixture.presenter.viewDidSelectTriggerChartStat(show: false)
        XCTAssertFalse(settings.chartStatsOn)
        XCTAssertFalse(fixture.view.showChartStat)
        XCTAssertEqual(fixture.interactor.statistics, [false])
        fixture.presenter.viewDidSelectChartsPerScreen(2)
        XCTAssertEqual(settings.chartsPerScreen, 2)
        XCTAssertEqual(fixture.view.chartsPerScreen, 2)
    }

    func testTutorialAndConfirmationChoicesRemainSpecificToTheCurrentSensor() {
        let fixture = GraphFixture()
        defer { fixture.cleanup() }
        fixture.measurements.settings.showGraphLongPressTutorial = true
        fixture.presenter.viewDidAskGraphLongPressTutorialDialog()
        fixture.presenter.viewDidTriggerDoNotShowGraphLongPressTutorialDialog()
        fixture.presenter.viewDidAskGraphLongPressTutorialDialog()
        XCTAssertEqual(fixture.view.tutorials, 1)
        fixture.presenter.viewDidSelectLongerHistory()
        XCTAssertEqual(fixture.view.longerHistory, 1)
        fixture.presenter.viewDidTriggerDoNotShowSyncDialog()
        XCTAssertTrue(fixture.measurements.settings.syncDialogHidden(for: fixture.measurements.sensor.luid!))
        XCTAssertFalse(fixture.measurements.settings.syncDialogHidden(for: "another-sensor".luid))
        fixture.presenter.viewDidTriggerClear(for: nil)
        fixture.presenter.viewDidTriggerClear(for: fixture.measurements.snapshot)
        XCTAssertEqual(fixture.view.clearDialogs, [fixture.measurements.sensor.id])
        fixture.presenter.viewDidTriggerStopSync(for: fixture.measurements.snapshot)
        fixture.presenter.showAbortSyncConfirmationDialog(for: fixture.measurements.snapshot, from: .rootBackButton)
        XCTAssertEqual(fixture.view.aborts.count, 2)
    }

    func testExportsUseTheCurrentSensorAndDismissActivityOnBothSuccessAndFailure() async {
        let fixture = GraphFixture()
        defer { fixture.cleanup() }
        fixture.presenter.viewDidTapOnExportCSV()
        await waitForAppState("CSV export") { fixture.activity.dismissed == 1 }
        XCTAssertEqual(fixture.view.exports, [fixture.export.url])
        fixture.presenter.viewDidTapOnExportXLSX()
        await waitForAppState("XLSX export") { fixture.activity.dismissed == 2 }
        XCTAssertEqual(fixture.view.exports.last, fixture.export.url.appendingPathExtension("xlsx"))
        fixture.export.failure = .failedToParseNetworkResponse
        fixture.presenter.viewDidTapOnExportCSV()
        fixture.presenter.viewDidTapOnExportXLSX()
        await waitForAppState("failed exports dismissed") { fixture.activity.dismissed == 4 }
        XCTAssertEqual(fixture.activity.shown, 4)
        XCTAssertEqual(fixture.errors.errors.count, 2)
        XCTAssertEqual(fixture.view.exports.count, 2)
        XCTAssertEqual(fixture.export.requests.map(\.format), ["csv", "xlsx", "csv", "xlsx"])
        XCTAssertTrue(
            fixture.export.requests.allSatisfy {
                $0.id == fixture.measurements.sensor.id && $0.version == 225 && $0.settings == nil
            })
    }

    func testClearDeletesOnlyTheSelectedSensorsHistoryAndReportsFailure() async {
        let fixture = GraphFixture()
        defer { fixture.cleanup() }
        fixture.presenter.viewDidConfirmToClear(for: fixture.measurements.snapshot)
        await waitForAppState("history deleted") { fixture.activity.dismissed == 1 }
        XCTAssertEqual(fixture.interactor.deleted, [fixture.measurements.sensor.id])
        fixture.interactor.failure = .bluetooth(.disconnected)
        fixture.presenter.viewDidConfirmToClear(for: fixture.measurements.snapshot)
        await waitForAppState("delete failure") { fixture.activity.dismissed == 2 }
        XCTAssertEqual(fixture.errors.errors.count, 1)
        XCTAssertEqual(fixture.activity.shown, 2)
    }

    func testMissingSensorDoesNotLeaveALoadingOverlayOrAttemptAnExport() async {
        let fixture = GraphFixture()
        defer { fixture.cleanup() }
        fixture.presenter.configure(with: fixture.measurements.snapshot, sensor: nil, settings: nil)
        fixture.presenter.viewDidConfirmToClear(for: fixture.measurements.snapshot)
        fixture.presenter.viewDidTapOnExportCSV()
        fixture.presenter.viewDidTapOnExportXLSX()
        await flushAppBindings()
        XCTAssertEqual(fixture.activity.shown, fixture.activity.dismissed)
        XCTAssertTrue(fixture.export.requests.isEmpty)
        XCTAssertTrue(fixture.interactor.deleted.isEmpty)
    }

    func testRepeatedStartAndLoadDoNotDuplicateSettingsOrCloudNotifications() async {
        let fixture = GraphFixture()
        defer { fixture.cleanup() }
        fixture.presenter.viewDidLoad()
        fixture.presenter.viewDidLoad()
        fixture.presenter.start(shouldSyncFromCloud: false)
        fixture.presenter.start(shouldSyncFromCloud: false)
        XCTAssertEqual(fixture.reactor.settings.count, 1)
        let before = fixture.interactor.dataStarts
        for name in [
            Notification.Name.TemperatureUnitDidChange, .HumidityUnitDidChange, .PressureUnitDidChange,
            .DownsampleOnDidChange, .ChartDurationHourDidChange,
        ] {
            fixture.notifications.post(name: name, object: nil)
        }
        XCTAssertEqual(fixture.interactor.dataStarts - before, 5)
        fixture.notifications.post(
            name: .NetworkSyncHistoryDidChangeStatus, object: nil,
            userInfo: [
                NetworkSyncStatusKey.mac: fixture.measurements.sensor.macId!,
                NetworkSyncStatusKey.status: NetworkSyncStatus.complete,
            ])
        XCTAssertEqual(fixture.interactor.dataStarts - before, 6)
        XCTAssertEqual(fixture.interactor.configurations.count, 2)
        XCTAssertTrue(fixture.interactor.configurations.allSatisfy { !$0.2 })
        fixture.presenter.scroll(to: 0, animated: false)
        let restarted = fixture.interactor.dataStarts
        fixture.notifications.post(
            name: .NetworkSyncHistoryDidChangeStatus, object: nil,
            userInfo: [
                NetworkSyncStatusKey.mac: fixture.measurements.sensor.macId!,
                NetworkSyncStatusKey.status: NetworkSyncStatus.complete,
            ])
        XCTAssertEqual(fixture.interactor.dataStarts - restarted, 1)
        await flushAppBindings()
    }
}
