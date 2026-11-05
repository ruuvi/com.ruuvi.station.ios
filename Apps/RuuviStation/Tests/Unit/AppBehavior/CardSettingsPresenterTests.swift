import RuuviCloud
import RuuviLocalization
import RuuviOntology
import RuuviService
import XCTest
@testable import station

@MainActor final class CardSettingsPresenterTests: XCTestCase {
    func testStartShowsSortingVisibilityNotesAndSavedBrightness() {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        fixture.calibration = SensorSettingsStruct(
            luid: fixture.sensor.luid, macId: fixture.sensor.macId,
            temperatureOffset: 2, humidityOffset: nil, pressureOffset: nil, description: "Living room")
        fixture.measurements.settings.dashboardSensorOrder = [fixture.sensor.id]
        let brightness = RuuviLedBrightnessLevel.allCases.last!
        fixture.measurements.settings.setLedBrightnessSelection(brightness, for: fixture.sensor.macId)
        fixture.configure()
        fixture.presenter.start()
        XCTAssertTrue(fixture.view.snapshots.last === fixture.snapshot)
        XCTAssertEqual(fixture.view.sorting.last!, .manual)
        XCTAssertEqual(fixture.view.visible.last?.0, "2/3")
        XCTAssertEqual(fixture.view.visible.last?.1, true)
        XCTAssertEqual(fixture.view.notes.last?.0, "Living room")
        XCTAssertEqual(fixture.view.notes.last?.1, true)
        XCTAssertEqual(fixture.view.brightness.last, brightness)
        XCTAssertFalse(fixture.view.sections.isEmpty)
        fixture.snapshot.displayData.measurementVisibility?.usesDefaultOrder = true
        fixture.measurements.settings.dashboardSensorOrder = []
        fixture.presenter.start()
        XCTAssertEqual(fixture.view.sorting.last!, .alphabetical)
        XCTAssertEqual(fixture.view.visible.last?.0, RuuviLocalization.visibleMeasurementsUseDefault)
        fixture.snapshot.metadata.isCloud = true
        fixture.snapshot.metadata.isOwner = false
        fixture.presenter.start()
        XCTAssertEqual(fixture.view.visible.last?.1, false)
        XCTAssertEqual(fixture.view.notes.last?.1, false)
    }

    func testNavigationActionsUseTheConfiguredSensorAndOwnershipState() {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        fixture.presenter.viewDidConfirmClaimTag()
        fixture.presenter.viewDidTriggerChangeBackground()
        fixture.presenter.viewDidAskToRemoveRuuviTag()
        fixture.presenter.viewDidTapShareButton()
        fixture.presenter.viewDidTapTemperatureOffsetCorrection()
        fixture.presenter.viewDidTapHumidityOffsetCorrection()
        fixture.presenter.viewDidTapOnPressureOffsetCorrection()
        fixture.presenter.viewDidTapOnUpdateFirmware()
        fixture.presenter.viewDidTapVisibleMeasurements()
        XCTAssertEqual(
            fixture.router.paths.map(\.0),
            ["owner", "background", "removal", "share", "offset", "offset", "offset", "firmware", "visibility"])
        XCTAssertTrue(fixture.router.paths.allSatisfy { $0.1 == fixture.sensor.id })
        XCTAssertEqual(fixture.router.offsets, [.temperature, .humidity, .pressure])
        fixture.presenter.viewDidTapOnOwner()
        fixture.snapshot.ownership.isClaimedTag = true
        fixture.snapshot.metadata.isOwner = true
        fixture.presenter.viewDidTapOnOwner()
        fixture.snapshot.metadata.isOwner = false
        fixture.presenter.viewDidTapOnOwner()
        XCTAssertEqual(fixture.router.owners, [.claim, .claim, .unclaim])
        XCTAssertEqual(fixture.router.paths.last?.0, "contest")
        fixture.presenter.viewDidTapAlertsShortcut()
        fixture.presenter.viewDidAskToDismiss()
        XCTAssertEqual(fixture.output.alerts, 1)
        XCTAssertEqual(fixture.output.dismissals, 1)
    }

    func testSensorAndPermissionGuardsPreventUnavailableSettingsRoutes() {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        fixture.configure(withSensor: false)
        fixture.presenter.viewDidConfirmClaimTag()
        fixture.presenter.viewDidTriggerChangeBackground()
        fixture.presenter.viewDidAskToRemoveRuuviTag()
        fixture.presenter.viewDidTapShareButton()
        fixture.presenter.viewDidTapOnOwner()
        fixture.presenter.viewDidTapVisibleMeasurements()
        fixture.presenter.viewDidTapTemperatureOffsetCorrection()
        fixture.presenter.viewDidTapHumidityOffsetCorrection()
        fixture.presenter.viewDidTapOnPressureOffsetCorrection()
        fixture.presenter.viewDidTapOnUpdateFirmware()
        fixture.presenter.viewDidConfirmFirmwareUpdate()
        XCTAssertTrue(fixture.router.paths.isEmpty)
        fixture.configure()
        fixture.snapshot.metadata.isCloud = true
        fixture.snapshot.metadata.isOwner = false
        fixture.presenter.viewDidTapVisibleMeasurements()
        fixture.presenter.viewDidTapNotes()
        XCTAssertTrue(fixture.router.paths.isEmpty)
        XCTAssertTrue(fixture.router.noteValues.isEmpty)
    }

    func testMissingMetadataPromptsForFirmwareUnlessPreviouslyDismissed() {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        fixture.presenter.viewDidTapOnMacAddress()
        XCTAssertEqual(fixture.view.macs, 1)
        let withoutMac = RuuviTagCardSnapshot.create(id: fixture.snapshot.id, name: "No MAC",
            luid: fixture.sensor.luid, mac: nil, serviceUUID: nil, isCloud: false, isOwner: true,
            isConnectable: true, version: 5)
        fixture.presenter.configure(with: withoutMac, sensor: fixture.sensor, settings: nil)
        fixture.presenter.viewDidTapOnMacAddress()
        fixture.presenter.viewDidTapOnTxPower()
        fixture.presenter.viewDidTapOnMeasurementSequenceNumber()
        fixture.presenter.viewDidTapOnNoValuesView()
        XCTAssertEqual(fixture.view.firmware, 4)
        withoutMac.displayData.txPower = 4
        withoutMac.displayData.measurementSequenceNumber = 12
        fixture.presenter.viewDidTapOnTxPower()
        fixture.presenter.viewDidTapOnMeasurementSequenceNumber()
        fixture.measurements.settings.setFirmwareUpdateDialogWasShown(true, for: fixture.sensor.luid!)
        fixture.presenter.viewDidTriggerFirmwareUpdateDialog()
        XCTAssertEqual(fixture.view.firmware, 4)
        fixture.presenter.viewDidIgnoreFirmwareUpdateDialog()
        fixture.presenter.viewDidConfirmFirmwareUpdate()
        XCTAssertEqual(fixture.view.ignoredFirmware, 1)
        XCTAssertEqual(fixture.router.paths.last?.0, "firmware")
    }

    func testCloudModeBlocksKeepConnectionWhileLocalToggleUpdatesConnectionAndHeartbeatSettings() {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        fixture.measurements.settings.cloudModeEnabled = true
        fixture.snapshot.metadata.isCloud = true
        fixture.presenter.viewDidTriggerKeepConnection(isOn: true)
        XCTAssertEqual(fixture.view.cloudWarnings, 1)
        XCTAssertEqual(fixture.view.resets, 1)
        XCTAssertTrue(fixture.services.connections.changes.isEmpty)
        fixture.snapshot.metadata.isCloud = false
        fixture.presenter.viewDidTriggerKeepConnection(isOn: true)
        XCTAssertEqual(fixture.services.connections.changes.last?.1, true)
        XCTAssertTrue(fixture.measurements.settings.saveHeartbeats)
        XCTAssertEqual(fixture.view.starts, 1)
        fixture.presenter.viewDidTriggerKeepConnection(isOn: false)
        XCTAssertEqual(fixture.services.connections.changes.last?.1, false)
        XCTAssertEqual(fixture.view.stops, 1)
        XCTAssertEqual(fixture.view.resets, 2)
    }

    func testCloudRequestProgressIsScopedToSensorAndStopsWhenScreenCloses() {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        fixture.presenter.start()
        for state: RuuviCloudRequestStateType in [.loading, .success, .failed, .complete] {
            NotificationCenter.default.post(
                name: .RuuviCloudRequestStateDidChange, object: nil,
                userInfo: [
                    RuuviCloudRequestStateKey.macId: fixture.sensor.macId!.value,
                    RuuviCloudRequestStateKey.state: state,
                ])
        }
        XCTAssertEqual(fixture.activity.shown.count, 1)
        XCTAssertEqual(fixture.activity.updates.count, 2)
        XCTAssertEqual(fixture.activity.dismissals.count, 1)
        fixture.presenter.stop()
        NotificationCenter.default.post(
            name: .RuuviCloudRequestStateDidChange, object: nil,
            userInfo: [
                RuuviCloudRequestStateKey.macId: fixture.sensor.macId!.value,
                RuuviCloudRequestStateKey.state: RuuviCloudRequestStateType.loading,
            ])
        XCTAssertEqual(fixture.activity.shown.count, 1)
        var dismissed = false
        fixture.presenter.dismiss { dismissed = true }
        XCTAssertTrue(dismissed)
    }

    func testRepeatedStartAndStopLeaveExactlyOneOwnershipObserverWhileVisible() {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        fixture.presenter.start()
        fixture.presenter.start()
        fixture.center.post(
            name: .RuuviTagOwnershipCheckDidEnd, object: nil,
            userInfo: [RuuviTagOwnershipCheckResultKey.hasOwner: false])
        XCTAssertEqual(fixture.view.claims, 1)
        fixture.presenter.stop()
        fixture.center.post(
            name: .RuuviTagOwnershipCheckDidEnd, object: nil,
            userInfo: [RuuviTagOwnershipCheckResultKey.hasOwner: false])
        XCTAssertEqual(fixture.view.claims, 1)
    }
}
