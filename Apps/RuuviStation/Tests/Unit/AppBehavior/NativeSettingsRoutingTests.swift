import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class NativeSettingsRoutingTests: XCTestCase {
    func testShareRouteBuildsTheRealScreenWithTheSelectedSensorsRecipients() async throws {
        let fixture = try await NativeRouteFixture()
        defer { fixture.close() }
        let sensor = fixture.measurements.sensor.with(canShare: true).with(sharedTo: ["FRIEND@EXAMPLE.COM"])
        fixture.router.openShare(for: sensor)
        let view: ShareViewController = try await fixture.destination()
        XCTAssertTrue(view.output is SharePresenter)
        XCTAssertEqual(view.viewModel.canShare.value, true)
        XCTAssertEqual(view.viewModel.sharedEmails.value, ["friend@example.com"])
        XCTAssertEqual(view.tableView.numberOfRows(inSection: 2), 1)
        fixture.host.navigation.popViewController(animated: false)
        await fixture.waitForRoot()
    }

    func testOwnershipRoutesKeepTheirModeAndCarryTheOriginalSensorIntoTheClaim() async throws {
        for mode in [OwnershipMode.claim, .unclaim] {
            let fixture = try await NativeRouteFixture()
            defer { fixture.close() }
            fixture.router.openOwner(ruuviTag: fixture.measurements.sensor, mode: mode)
            let view: OwnerViewController = try await fixture.destination()
            XCTAssertEqual(view.mode, mode)
            let presenter = try XCTUnwrap(view.output as? OwnerPresenter)
            let ownership = ShareOwnershipSpy()
            presenter.ruuviOwnershipService = ownership
            presenter.settings = fixture.measurements.settings
            presenter.activityPresenter = AccountActivitySpy()
            presenter.connectionPersistence = AppConnectionsSpy()
            if mode == .claim {
                presenter.viewDidTapOnClaim(mode: .claim)
            } else {
                presenter.viewDidConfirmUnclaim(removeCloudHistory: false)
            }
            await waitForAppState("ownership request uses the routed sensor") {
                ownership.claims.count + ownership.unclaims.count == 1
            }
            XCTAssertEqual((ownership.claims.first ?? ownership.unclaims.first?.0)?.id, fixture.measurements.sensor.id)
            XCTAssertEqual(ownership.unclaims.first?.1, mode == .unclaim ? false : nil)
            await fixture.waitForRoot()
        }
    }

    func testEachCalibrationRouteKeepsItsMeasurementTypeAndConfiguredOffset() async throws {
        for type in [OffsetCorrectionType.temperature, .humidity, .pressure] {
            let fixture = try await NativeRouteFixture()
            defer { fixture.close() }
            let sensor = fixture.measurements.sensor
            let settings = SensorSettingsStruct(
                luid: sensor.luid, macId: sensor.macId, temperatureOffset: 2, humidityOffset: 0.1, pressureOffset: 1000)
            fixture.router.openOffsetCorrection(type: type, ruuviTag: sensor, sensorSettings: settings)
            let view: OffsetCorrectionAppleViewController = try await fixture.destination()
            XCTAssertEqual(view.viewModel.type, type)
            XCTAssertEqual(view.title, view.viewModel.title)
            XCTAssertFalse(view.correctedValueView.isHidden)
            XCTAssertTrue(view.clearButton.isEnabled)
            fixture.router.dismissToRoot(completion: nil)
            await fixture.waitForRoot()
        }
    }

    func testRemovalRouteConnectsTheRealPresenterAndOriginalOutputWithoutDeletingStoredData() async throws {
        let fixture = try await NativeRouteFixture()
        defer { fixture.close() }
        let output = NativeRemovalOutput()
        fixture.router.openSensorRemoval(ruuviTag: fixture.measurements.sensor, output: output)
        let view: SensorRemovalViewController = try await fixture.destination()
        let presenter = try XCTUnwrap(view.output as? SensorRemovalPresenter)
        XCTAssertTrue(presenter.output === output)
        let service = ShareOwnershipSpy()
        service.allowRemovals = true
        presenter.ruuviOwnershipService = service
        presenter.viewDidConfirmTagRemoval(with: false)
        await waitForAppState("removal callback keeps sensor and module") { output.sensor != nil }
        XCTAssertEqual(service.removals.first?.0.id, fixture.measurements.sensor.id)
        XCTAssertEqual(service.removals.first?.1, false)
        XCTAssertEqual(output.sensor?.id, fixture.measurements.sensor.id)
        XCTAssertTrue(output.module === presenter)
        presenter.viewDidDismiss()
        await fixture.waitForRoot()
    }

    func testContestAndVisibilityRoutesBuildTheirRealScreensAndCloseWithoutAWrite() async throws {
        let fixture = try await NativeRouteFixture()
        defer { fixture.close() }
        fixture.router.openContest(ruuviTag: fixture.measurements.sensor)
        let contest: SensorForceClaimViewController = try await fixture.destination()
        XCTAssertTrue(contest.output is SensorForceClaimPresenter)
        XCTAssertEqual(contest.deviceType, .ruuviAir)
        fixture.router.dismissToRoot(completion: nil)
        await fixture.waitForRoot()
        fixture.router.openVisibilitySettings(
            snapshot: fixture.measurements.snapshot, ruuviTag: fixture.measurements.sensor, sensorSettings: nil)
        let visibility: VisibilitySettingsViewController = try await fixture.destination()
        XCTAssertTrue(visibility.output is VisibilitySettingsPresenter)
        XCTAssertEqual(visibility.title, RuuviLocalization.visibleMeasurements)
        visibility.backButtonDidTap()
        await fixture.waitForRoot()
    }
}

@MainActor private final class NativeRouteFixture {
    let measurements = MeasurementFixture()
    let root = UIViewController()
    let host: AppViewHost
    let router = CardsSettingsRouter()
    init() async throws {
        host = try AppViewHost(root)
        router.transitionHandler = root
        await waitForAppState("native route root attached") { self.root.view.window === self.host.window }
    }
    func destination<T: UIViewController>() async throws -> T {
        await waitForAppState("native destination attached") {
            self.host.navigation.topViewController is T && self.host.navigation.transitionCoordinator == nil
                && self.host.navigation.topViewController?.view.window === self.host.window
        }
        return try XCTUnwrap(host.navigation.topViewController as? T)
    }
    func waitForRoot() async {
        await waitForAppState("native route returned to root") {
            self.host.navigation.topViewController === self.root && self.host.navigation.viewControllers.count == 1
        }
    }
    func close() { host.close(); measurements.cleanup() }
}
private final class NativeRemovalOutput: SensorRemovalModuleOutput {
    var sensor: RuuviTagSensor?
    weak var module: SensorRemovalModuleInput?
    func sensorRemovalDidRemoveTag(module: SensorRemovalModuleInput, ruuviTag: RuuviTagSensor) {
        self.module = module; sensor = ruuviTag
    }
    func sensorRemovalDidDismiss(module: SensorRemovalModuleInput) {}
}
