import Foundation
import RuuviLocal
import RuuviOntology
import RuuviService
import UIKit
import XCTest
@testable import station

@MainActor final class VisibilitySettingsTests: XCTestCase {
    func testProgrammaticDismissFlushesTheLatestEdit() async {
        let fixture = VisibilityFixture()
        defer { fixture.cleanup() }
        fixture.presenter.viewDidLoad()
        await fixture.settle()
        fixture.presenter.viewDidRequestHideItem(at: 1)
        var completion = false
        fixture.presenter.dismiss { completion = true }
        XCTAssertTrue(completion)
        await waitForAppState("dismissed edit saved") { fixture.service.completed == 1 }
        XCTAssertEqual(fixture.service.calls.last?.codes, ["TEMPERATURE_C", "PM25_MGM3"])
    }

    func testRemovingDewPointWarnsEvenWhenRelativeHumidityRemainsVisible() async {
        let fixture = VisibilityFixture()
        defer { fixture.cleanup() }
        let relative = MeasurementDisplayVariant(type: .humidity, humidityUnit: .percent)
        let dew = MeasurementDisplayVariant(type: .humidity, temperatureUnit: .celsius, humidityUnit: .dew)
        fixture.measurements.snapshot.displayData.measurementVisibility = .init(
            usesDefaultOrder: false, availableVariants: [relative, dew, fixture.co2],
            visibleVariants: [relative, dew, fixture.co2]
        )
        fixture.measurements.snapshot.updateAlertConfig(
            for: .dewPoint(lower: 0, upper: 10),
            config: .init(
                type: .humidity, alertType: .dewPoint(lower: 0, upper: 10),
                isActive: true, isFiring: false, mutedTill: nil
            ))
        fixture.presenter.viewDidLoad()
        await fixture.settle()
        fixture.presenter.viewDidRequestHideItem(at: 1)
        XCTAssertEqual(fixture.view.confirmations, 1, "Relative humidity and dew point have independent alerts")
        fixture.view.cancel?()
        XCTAssertEqual(fixture.view.model.visibleItems.map(\.variant), [relative, dew, fixture.co2])
    }

    func testRestoringDefaultsDeactivatesOnlyAlertsForHiddenMeasurementsAfterConfirmation() async {
        let fixture = VisibilityFixture()
        defer { fixture.cleanup() }
        let pm1 = MeasurementDisplayVariant(type: .pm10)
        let pm4 = MeasurementDisplayVariant(type: .pm40)
        fixture.measurements.snapshot.displayData.measurementVisibility?.visibleVariants = [
            fixture.temperature, pm1, pm4,
        ]
        let alerts: [(MeasurementType, AlertType)] = [
            (.pm10, .pMatter1(lower: 1, upper: 10)), (.pm40, .pMatter4(lower: 1, upper: 10)),
        ]
        for (type, alert) in alerts {
            fixture.measurements.register(alert)
            fixture.measurements.snapshot.updateAlertConfig(
                for: alert,
                config: .init(
                    type: type, alertType: alert, isActive: true, isFiring: false, mutedTill: nil,
                    lowerBound: 1, upperBound: 10
                ))
        }
        fixture.presenter.viewDidLoad()
        await fixture.settle()
        fixture.presenter.viewDidToggleUseDefault(isOn: true)
        XCTAssertEqual(fixture.view.confirmations, 1)
        fixture.view.cancel?()
        XCTAssertFalse(fixture.view.model.useDefault)
        for (_, alert) in alerts {
            XCTAssertTrue(fixture.measurements.alerts.isOn(type: alert, for: fixture.measurements.sensor))
        }
        fixture.presenter.viewDidToggleUseDefault(isOn: true)
        fixture.view.confirm?()
        XCTAssertTrue(fixture.view.model.useDefault)
        for (_, alert) in alerts {
            XCTAssertFalse(
                fixture.measurements.alerts.isOn(type: alert, for: fixture.measurements.sensor),
                "The confirmation promises to deactivate this hidden alert")
        }
        fixture.presenter.viewWillDisappear()
        await waitForAppState("default selection saved") { fixture.service.completed == 1 }
        XCTAssertTrue(fixture.service.calls.last?.useDefault == true)
        XCTAssertNil(fixture.service.calls.last?.codes)
    }

    func testDebounceSavesOnceAndMissingVisibilityUsesSensorDefaults() async {
        let fixture = VisibilityFixture()
        defer { fixture.cleanup() }
        fixture.measurements.snapshot.displayData.measurementVisibility = nil
        fixture.presenter.configure(
            snapshot: fixture.measurements.snapshot, sensor: fixture.measurements.sensor,
            sensorSettings: nil)
        fixture.presenter.viewDidLoad()
        await fixture.settle()
        XCTAssertTrue(fixture.view.model.useDefault)
        XCTAssertFalse(fixture.view.model.visibleItems.isEmpty)
        fixture.presenter.viewDidToggleUseDefault(isOn: false)
        fixture.presenter.viewDidRequestHideItem(at: 0)
        fixture.presenter.viewDidRequestHideItem(at: 0)
        await waitForAppState("debounced visibility save") { fixture.service.completed == 1 }
        XCTAssertEqual(fixture.service.calls.count, 1)
    }

    func testHideShowReorderAndLastMeasurementProtectionPersistThePreviewOrder() async throws {
        let fixture = VisibilityFixture()
        defer { fixture.cleanup() }
        let presenter = fixture.presenter
        presenter.viewDidLoad()
        await fixture.settle()
        XCTAssertEqual(fixture.view.model.visibleItems.map(\.variant), fixture.initial)
        XCTAssertNotNil(fixture.view.model.preview)
        presenter.viewDidRequestHideItem(at: -1)
        presenter.viewDidRequestShowItem(at: 999)
        presenter.viewDidMoveVisibleItem(from: 0, to: 999)
        presenter.viewDidMoveVisibleItem(from: 0, to: 0)
        presenter.viewDidStartReorderingVisibleItems()
        presenter.viewDidMoveVisibleItem(from: 0, to: 2)
        presenter.viewDidFinishReorderingVisibleItems()
        XCTAssertEqual(fixture.view.model.visibleItems.map(\.variant), [fixture.co2, fixture.pm, fixture.temperature])
        presenter.viewDidRequestHideItem(at: 1)
        presenter.viewDidRequestHideItem(at: 1)
        presenter.viewDidRequestHideItem(at: 0)
        XCTAssertEqual(fixture.view.model.visibleItems.map(\.variant), [fixture.co2])
        XCTAssertEqual(fixture.view.messages.count, 1)
        let temperatureIndex = try XCTUnwrap(
            fixture.view.model.hiddenItems.firstIndex { $0.variant == fixture.temperature })
        presenter.viewDidRequestShowItem(at: temperatureIndex)
        presenter.viewWillDisappear()
        await waitForAppState("visibility persistence") { fixture.service.completed == 1 }
        XCTAssertEqual(fixture.service.calls.last?.codes, ["CO2_PPM", "TEMPERATURE_C"])
        XCTAssertEqual(fixture.service.calls.last?.useDefault, false)
        XCTAssertEqual(fixture.view.saving.last, false)
        let preview = try XCTUnwrap(fixture.view.model.preview)
        XCTAssertEqual(
            preview.snapshot.displayData.indicatorGrid?.indicators.map(\.variant),
            [fixture.co2, fixture.temperature])
        XCTAssertNotEqual(preview.snapshot.id, fixture.measurements.snapshot.id)
    }

    func testClosingDuringASaveStillPersistsTheFinalSelectionInOrder() async {
        let fixture = VisibilityFixture()
        defer { fixture.cleanup() }
        var release: CheckedContinuation<Void, Never>?
        fixture.service.beforeSave = { await withCheckedContinuation { release = $0 } }
        fixture.presenter.viewDidLoad()
        await fixture.settle()
        fixture.presenter.viewDidRequestHideItem(at: 1)
        fixture.presenter.viewWillDisappear()
        await waitForAppState("first pending visibility save") { release != nil }
        fixture.service.beforeSave = nil
        fixture.presenter.viewDidRequestHideItem(at: 1)
        fixture.presenter.viewDidAskToDismiss()
        weak var weakPresenter = fixture.optionalPresenter
        fixture.optionalPresenter = nil
        XCTAssertNil(weakPresenter, "Persistence must not retain the dismissed screen")
        XCTAssertEqual(fixture.router.dismissals, 1)
        XCTAssertEqual(fixture.output.finishes, 1)
        release?.resume()
        await waitForAppState("final visibility selection saved") { fixture.service.completed == 2 }
        XCTAssertEqual(
            fixture.service.calls.map(\.codes),
            [
                ["TEMPERATURE_C", "PM25_MGM3"], ["TEMPERATURE_C"],
            ])
        XCTAssertEqual(fixture.service.maximumConcurrentSaves, 1)
    }

    func testUseDefaultRestoresDefaultMeasurementsAndCanRestoreThePreviousCustomOrder() async {
        let fixture = VisibilityFixture()
        defer { fixture.cleanup() }
        fixture.presenter.viewDidLoad()
        await fixture.settle()
        fixture.presenter.viewDidRequestHideItem(at: 1)
        let custom = fixture.view.model.visibleItems.map(\.variant)
        fixture.presenter.viewDidToggleUseDefault(isOn: true)
        XCTAssertTrue(fixture.view.model.useDefault)
        XCTAssertTrue(
            fixture.view.model.visibleItems.contains { $0.variant.type == .aqi },
            "Restoring defaults must ignore the previous custom preference")
        XCTAssertTrue(fixture.view.model.visibleItems.contains { $0.variant.type == .co2 })
        fixture.presenter.viewDidToggleUseDefault(isOn: false)
        XCTAssertEqual(fixture.view.model.visibleItems.map(\.variant), custom)
        fixture.presenter.viewWillDisappear()
        await waitForAppState("restored custom order") { fixture.service.completed == 1 }
        XCTAssertEqual(fixture.service.calls.last?.codes, ["TEMPERATURE_C", "PM25_MGM3"])
    }

    func testConfirmationHidesTheRequestedVariantEvenIfItWasReordered() async {
        let fixture = VisibilityFixture()
        defer { fixture.cleanup() }
        fixture.measurements.snapshot.updateAlertConfig(
            for: .co2,
            config: .init(
                type: .co2, isActive: true, isFiring: false, mutedTill: nil, lowerBound: 400, upperBound: 1000
            ))
        fixture.presenter.viewDidLoad()
        await fixture.settle()
        fixture.presenter.viewDidRequestHideItem(at: 1)
        XCTAssertEqual(fixture.view.confirmations, 1)
        let confirmation = fixture.view.confirm
        fixture.view.cancel?()
        XCTAssertEqual(fixture.view.model.visibleItems.map(\.variant), fixture.initial)
        fixture.presenter.viewDidRequestHideItem(at: 1)
        fixture.presenter.viewDidMoveVisibleItem(from: 1, to: 2)
        confirmation?()
        XCTAssertFalse(fixture.view.model.visibleItems.contains { $0.variant == fixture.co2 })
        XCTAssertTrue(fixture.view.model.visibleItems.contains { $0.variant == fixture.pm })
        fixture.presenter.viewWillDisappear()
        await waitForAppState("confirmed visibility") { fixture.service.completed == 1 }
    }

    func testReadOnlySharedSensorAndMissingConfigurationCloseWithoutWriting() {
        let fixture = VisibilityFixture()
        defer { fixture.cleanup() }
        fixture.measurements.snapshot.metadata.isCloud = true
        fixture.measurements.snapshot.metadata.isOwner = false
        fixture.presenter.viewDidLoad()
        XCTAssertEqual(fixture.output.finishes, 1)
        XCTAssertEqual(fixture.router.dismissals, 1)
        XCTAssertTrue(fixture.service.calls.isEmpty)
        let empty = VisibilitySettingsPresenter(
            sensorPropertiesService: fixture.service, settings: fixture.measurements.settings)
        empty.output = fixture.output
        empty.router = fixture.router
        empty.viewDidLoad()
        XCTAssertEqual(fixture.output.finishes, 2)
        XCTAssertTrue(fixture.service.calls.isEmpty)
    }

    func testFailureIsVisibleAndAnUnchangedFlushDoesNotDuplicateAnInFlightWrite() async {
        let fixture = VisibilityFixture()
        defer { fixture.cleanup() }
        var release: CheckedContinuation<Void, Never>?
        fixture.service.beforeSave = { await withCheckedContinuation { release = $0 } }
        fixture.service.failure = true
        fixture.presenter.viewDidLoad()
        await fixture.settle()
        fixture.presenter.viewDidRequestHideItem(at: 1)
        fixture.presenter.viewWillDisappear()
        await waitForAppState("save started") { release != nil }
        fixture.presenter.viewWillDisappear()
        XCTAssertEqual(fixture.service.calls.count, 1)
        release?.resume()
        await waitForAppState("save error") { !fixture.view.messages.isEmpty }
        XCTAssertEqual(fixture.view.saving.last, false)
        XCTAssertEqual(fixture.service.calls.count, 1)
    }

    func testActiveSignalAlertForcesSignalIntoVisibleMeasurements() async {
        let fixture = VisibilityFixture()
        defer { fixture.cleanup() }
        fixture.measurements.snapshot.updateAlertConfig(
            for: .rssi,
            config: .init(
                type: .rssi, isActive: true, isFiring: false, mutedTill: nil, lowerBound: -80, upperBound: -20
            ))
        fixture.presenter.viewDidLoad()
        await fixture.settle()
        XCTAssertTrue(fixture.view.model.visibleItems.contains { $0.variant.type == .rssi })
        XCTAssertFalse(fixture.view.model.hiddenItems.contains { $0.variant.type == .rssi })
        fixture.measurements.snapshot.displayData.name = "Updated preview"
        await waitForAppState("live preview name") {
            fixture.view.model.preview?.snapshot.displayData.name == "Updated preview"
        }
        XCTAssertEqual(Set(fixture.view.model.visibleItems.map(\.variant)).count, fixture.view.model.visibleItems.count)
    }
}

@MainActor private final class VisibilityFixture {
    let services = CoordinatorFixture()
    var measurements: MeasurementFixture { services.data.measurements }
    let service = VisibilityPropertiesSpy()
    let view = VisibilityViewSpy()
    let router = VisibilityRouterSpy()
    let output = VisibilityOutputSpy()
    let temperature = MeasurementDisplayVariant(type: .temperature, temperatureUnit: .celsius)
    let co2 = MeasurementDisplayVariant(type: .co2)
    let pm = MeasurementDisplayVariant(type: .pm25)
    var initial: [MeasurementDisplayVariant] { [temperature, co2, pm] }
    var optionalPresenter: VisibilitySettingsPresenter?
    var presenter: VisibilitySettingsPresenter { optionalPresenter! }
    private let originalRefresh = UserDefaults(suiteName: AppGroupConstants.appGroupSuiteIdentifier)?
        .object(forKey: AppGroupConstants.forceRefreshWidgetKey)

    init() {
        let available = RuuviTagDataService.defaultMeasurementDisplayProfile(for: measurements.sensor)
            .entriesSupporting(.indicator).map(\.variant)
        measurements.snapshot.displayData.measurementVisibility = .init(
            usesDefaultOrder: false, availableVariants: available, visibleVariants: initial,
            hiddenVariants: available.filter { !initial.contains($0) }
        )
        measurements.snapshot.displayData.indicatorGrid = .init(indicators: available.map(measurements.indicator))
        let presenter = VisibilitySettingsPresenter(
            sensorPropertiesService: service, settings: measurements.settings, coordinatorManager: services.manager
        )
        presenter.view = view
        presenter.router = router
        presenter.configure(output: output)
        presenter.configure(
            snapshot: measurements.snapshot, sensor: measurements.sensor,
            sensorSettings: SensorSettingsStruct(
                luid: measurements.sensor.luid, macId: measurements.sensor.macId,
                temperatureOffset: nil, humidityOffset: nil, pressureOffset: nil,
                displayOrder: ["TEMPERATURE_C", "CO2_PPM", "PM25_MGM3"], defaultDisplayOrder: false
            )
        )
        optionalPresenter = presenter
    }
    func settle() async { try? await Task.sleep(nanoseconds: 30_000_000) }
    func cleanup() {
        optionalPresenter?.dismiss(completion: nil)
        services.cleanup()
        measurements.cleanup()
        RuuviTagDataService.clearMeasurementDisplayPreference(for: measurements.sensor.id)
        let cache = WidgetSensorCache()
        cache.prune(keeping: Set(cache.loadAll().filter { $0.id != measurements.sensor.id }.map(\.id)))
        UserDefaults(suiteName: AppGroupConstants.appGroupSuiteIdentifier)?
            .set(originalRefresh, forKey: AppGroupConstants.forceRefreshWidgetKey)
    }
}

@MainActor private final class VisibilityPropertiesSpy: RuuviServiceSensorProperties {
    struct Call { let codes: [String]?; let useDefault: Bool }
    var calls: [Call] = []
    var completed = 0
    var active = 0
    var maximumConcurrentSaves = 0
    var beforeSave: (() async -> Void)?
    var failure = false
    func updateDisplaySettings(
        for sensor: RuuviTagSensor, displayOrder: [String]?, defaultDisplayOrder: Bool
    ) async throws(RuuviServiceError) -> SensorSettings {
        calls.append(.init(codes: displayOrder, useDefault: defaultDisplayOrder))
        active += 1
        maximumConcurrentSaves = max(active, maximumConcurrentSaves)
        defer { active -= 1 }
        await beforeSave?()
        if failure { throw .failedToParseNetworkResponse }
        completed += 1
        return SensorSettingsStruct(
            luid: sensor.luid, macId: sensor.macId, temperatureOffset: nil, humidityOffset: nil, pressureOffset: nil,
            displayOrder: displayOrder, defaultDisplayOrder: defaultDisplayOrder
        )
    }
    func set(name: String, for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> AnyRuuviTagSensor {
        sensor.any
    }
    func set(
        image: UIImage, for sensor: RuuviTagSensor, progress: ((MACIdentifier, Double) -> Void)?,
        maxSize: CGSize, compressionQuality: CGFloat
    ) async throws(RuuviServiceError) -> URL { throw .failedToGetJpegRepresentation }
    func setNextDefaultBackground(for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> UIImage { UIImage() }
    func getImage(for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> UIImage { UIImage() }
    func removeImage(for sensor: RuuviTagSensor) {}
    func updateDescription(
        for sensor: RuuviTagSensor, description: String?
    ) async throws(RuuviServiceError) -> SensorSettings { throw .failedToParseNetworkResponse }
}

private final class VisibilityViewSpy: VisibilitySettingsViewInput {
    var model = VisibilitySettingsViewModel.empty
    var messages: [String] = []
    var saving: [Bool] = []
    var confirmations = 0
    var confirm: (() -> Void)?
    var cancel: (() -> Void)?
    func display(viewModel: VisibilitySettingsViewModel) { model = viewModel }
    func setUseDefaultSwitch(isOn: Bool) {}
    func setSaving(_ isSaving: Bool) { saving.append(isSaving) }
    func showMessage(_ message: String) { messages.append(message) }
    func presentConfirmation(
        title: String?, message: String, confirmTitle: String, cancelTitle: String,
        onConfirm: @escaping () -> Void, onCancel: (() -> Void)?
    ) { confirmations += 1; confirm = onConfirm; cancel = onCancel }
}
private final class VisibilityRouterSpy: VisibilitySettingsRouterInput {
    var dismissals = 0
    func dismiss() { dismissals += 1 }
}
private final class VisibilityOutputSpy: VisibilitySettingsModuleOutput {
    var finishes = 0
    func visibilitySettingsModuleDidFinish(_ module: VisibilitySettingsModuleInput) { finishes += 1 }
}
