import RuuviLocalization
import UIKit
import XCTest
@testable import station

@MainActor final class BackgroundSettingsContractTests: XCTestCase {
    func testDisablingHeartbeatUnpairsConnectionsAndChangingIntervalPreservesMinutes() async throws {
        let measurements = MeasurementFixture()
        defer { measurements.cleanup() }
        let connections = AppConnectionsSpy()
        let identifier = try XCTUnwrap(measurements.sensor.luid)
        connections.setKeepConnection(true, for: identifier)
        let view = HeartbeatSettingsViewSpy()
        let presenter = HeartbeatPresenter()
        presenter.view = view
        presenter.settings = measurements.settings
        presenter.connectionPersistence = connections
        measurements.settings.saveHeartbeats = true
        measurements.settings.saveHeartbeatsIntervalMinutes = 5
        measurements.settings.showSwitchStatusLabel = true
        presenter.configure()
        await flushAppBindings()
        XCTAssertEqual(view.viewModel.bgScanningState.value, true)
        XCTAssertEqual(view.viewModel.bgScanningInterval.value, 5)
        XCTAssertEqual(view.viewModel.hideSwitchStatusLabel.value, false)
        XCTAssertTrue(connections.keepConnection(to: identifier))
        view.viewModel.bgScanningInterval.value = 15
        await waitForAppState("heartbeat interval saved") { measurements.settings.saveHeartbeatsIntervalMinutes == 15 }
        XCTAssertTrue(connections.keepConnection(to: identifier))
        view.viewModel.bgScanningState.value = nil
        await flushAppBindings()
        XCTAssertTrue(measurements.settings.saveHeartbeats)
        view.viewModel.bgScanningState.value = false
        await waitForAppState("background connections unpaired") { connections.keepConnectionUUIDs.isEmpty }
        XCTAssertFalse(measurements.settings.saveHeartbeats)
        view.viewModel.bgScanningState.value = true
        await waitForAppState("background scanning reenabled") { measurements.settings.saveHeartbeats }
        XCTAssertTrue(connections.keepConnectionUUIDs.isEmpty, "Enabling scanning must not recreate old pairings")
    }

    func testHeartbeatContainerPassesItsModelToTheEmbeddedTableAndPresentsDisableConfirmation() async throws {
        let controller = try XCTUnwrap(
            UIStoryboard(name: "Heartbeat", bundle: .main)
                .instantiateViewController(withIdentifier: "HeartbeatViewController") as? HeartbeatViewController)
        controller.viewModel.bgScanningState.value = true
        controller.viewModel.bgScanningInterval.value = 5
        let host = try AppViewHost(controller)
        defer { host.close() }
        let table = try XCTUnwrap(controller.children.compactMap { $0 as? HeartbeatTableViewController }.first)
        await flushAppBindings()
        XCTAssertTrue(table.viewModel === controller.viewModel)
        XCTAssertEqual(controller.navigationItem.title, RuuviLocalization.Settings.BackgroundScanning.title)
        table.didChangeSwitchState(sender: table.bgScanningSwitch, didToggle: false)
        let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.message, RuuviLocalization.Settings.BackgroundScanning.DisableConfirmation.message)
        XCTAssertEqual(alert.actions.map(\.title), [RuuviLocalization.cancel, RuuviLocalization.confirm])
        XCTAssertEqual(controller.viewModel.bgScanningState.value, true)
    }

    func testCloudModeReadsExistingSettingsWithoutWritingAndSavesEachUserChangeEvenOffline() async throws {
        let settings = AppTestSettings()
        settings.cloudModeEnabled = true
        settings.showSwitchStatusLabel = true
        let service = AppSettingsServiceSpy(settings: settings)
        let presenter = RuuviCloudPresenter()
        presenter.settings = settings
        presenter.ruuviAppSettingsService = service
        let view = try XCTUnwrap(presenter.viewController as? RuuviCloudTableViewController)
        let host = try AppViewHost(view)
        defer { host.close() }
        presenter.viewWillAppear()
        await flushAppBindings()
        let model = try XCTUnwrap(view.viewModels.first)
        XCTAssertEqual(view.viewModels.count, 1)
        XCTAssertEqual(model.title, RuuviLocalization.Settings.Label.cloudMode)
        XCTAssertEqual(model.boolean.value, true)
        XCTAssertEqual(model.hideStatusLabel.value, false)
        XCTAssertTrue(service.calls.isEmpty)
        model.boolean.value = false
        await waitForAppState("cloud mode saved") { service.calls.count == 1 }
        XCTAssertFalse(settings.cloudModeEnabled)
        service.failure = .failedToParseNetworkResponse
        model.boolean.value = true
        await waitForAppState("offline cloud setting attempted") { service.calls.count == 2 }
        XCTAssertTrue(settings.cloudModeEnabled)
        XCTAssertEqual(service.calls, ["cloudMode", "cloudMode"])
        XCTAssertTrue(presenter.viewController === view)
    }
}
private final class HeartbeatSettingsViewSpy: HeartbeatViewInput {
    var viewModel = HeartbeatViewModel()
}
