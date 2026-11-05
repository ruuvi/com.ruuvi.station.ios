import Foundation
import RuuviOntology
import UIKit
@testable import station

@MainActor final class CardSettingsFixture {
    let services = CoordinatorFixture()
    let view = CardSettingsViewSpy()
    let router = CardSettingsRouterSpy()
    let output = CardSettingsOutputSpy()
    let activity = AccountActivitySpy()
    let errors = OffsetErrorSpy()
    let center = NotificationCenter()
    var presenter: CardsSettingsPresenter!
    var sensor: AnyRuuviTagSensor
    var calibration: SensorSettings?
    var measurements: MeasurementFixture { services.data.measurements }
    var snapshot: RuuviTagCardSnapshot { measurements.snapshot }
    init() {
        sensor = services.data.measurements.sensor.with(firmwareVersion: "1.3.0").any
        presenter = CardsSettingsPresenter(
            ruuviSensorPropertiesService: services.data.properties,
            measurementService: services.data.measurements.measurement,
            settings: services.data.measurements.settings, errorPresenter: errors, activityPresenter: activity,
            coordinatorManager: services.manager, notificationCenter: center, pool: services.data.pool)
        presenter.view = view
        presenter.router = router
        presenter.output = output
        snapshot.displayData.firmwareVersion = "1.3.0"
        snapshot.displayData.measurementVisibility = .init(
            usesDefaultOrder: false,
            availableVariants: [.init(type: .temperature), .init(type: .humidity), .init(type: .pressure)],
            visibleVariants: [.init(type: .temperature), .init(type: .humidity)])
        configure()
    }
    func configure(withSensor: Bool = true) {
        presenter.configure(
            with: [snapshot], snapshot: snapshot, sensor: withSensor ? sensor : nil, settings: calibration)
    }
    func cleanup() { presenter?.shutdown(); services.cleanup(); measurements.cleanup() }
}

final class CardSettingsViewSpy: CardsSettingsViewInput {
    var snapshots = [RuuviTagCardSnapshot]()
    var sorting = [DashboardSortingType?]()
    var sections = [[CardsSettingsAlertSectionModel]]()
    var claims = 0
    var macs = 0
    var firmware = 0
    var ignoredFirmware = 0
    var resets = 0
    var timeouts = 0
    var cloudWarnings = 0
    var stops = 0
    var starts = 0
    var freezes = 0
    var unfreezes = 0
    var visible = [(String?, Bool)]()
    var brightness = [RuuviLedBrightnessLevel]()
    var notes = [(String?, Bool)]()
    func configure(snapshot: RuuviTagCardSnapshot, dashboardSortingType: DashboardSortingType?) {
        snapshots.append(snapshot); sorting.append(dashboardSortingType)
    }
    func updateAlertSections(_ sections: [CardsSettingsAlertSectionModel]) { self.sections.append(sections) }
    func showTagClaimDialog() { claims += 1 }
    func showMacAddressDetail() { macs += 1 }
    func showFirmwareUpdateDialog() { firmware += 1 }
    func showFirmwareDismissConfirmationUpdateDialog() { ignoredFirmware += 1 }
    func resetKeepConnectionSwitch() { resets += 1 }
    func showKeepConnectionTimeoutDialog() { timeouts += 1 }
    func showKeepConnectionCloudModeDialog() { cloudWarnings += 1 }
    func stopKeepConnectionAnimatingDots() { stops += 1 }
    func startKeepConnectionAnimatingDots() { starts += 1 }
    func freezeKeepConnectionDisplay() { freezes += 1 }
    func unfreezeKeepConnectionDisplay() { unfreezes += 1 }
    func updateVisibleMeasurementsSummary(value: String?, isVisible: Bool) { visible.append((value, isVisible)) }
    func updateLedBrightnessSelection(_ selection: RuuviLedBrightnessLevel) { brightness.append(selection) }
    func updateNotes(value: String?, isEditable: Bool) { notes.append((value, isEditable)) }
}

final class CardSettingsRouterSpy: CardsSettingsRouterInput {
    var paths = [(String, String)]()
    var owners = [OwnershipMode]()
    var offsets = [OffsetCorrectionType]()
    var removals = [SensorRemovalModuleOutput]()
    var noteValues = [String?]()
    var saveNotes: ((String?, @escaping (Result<Void, Error>) -> Void) -> Void)?
    var selectLED: ((RuuviLedBrightnessLevel, @escaping (Result<Void, Error>) -> Void) -> Void)?
    var updateFirmware: (() -> Void)?
    var selectedLED: RuuviLedBrightnessLevel?
    var ledFirmware: String?
    var ledSnapshotID: String?
    func dismiss(completion: (() -> Void)?) { completion?() }
    func dismissToRoot(completion: (() -> Void)?) { paths.append(("root", "")); completion?() }
    func openBackgroundSelectionView(ruuviTag: RuuviTagSensor) { paths.append(("background", ruuviTag.id)) }
    func openShare(for sensor: RuuviTagSensor) { paths.append(("share", sensor.id)) }
    func openOffsetCorrection(type: OffsetCorrectionType, ruuviTag: RuuviTagSensor, sensorSettings: SensorSettings?) {
        paths.append(("offset", ruuviTag.id)); offsets.append(type)
    }
    func openUpdateFirmware(ruuviTag: RuuviTagSensor) { paths.append(("firmware", ruuviTag.id)) }
    func openOwner(ruuviTag: RuuviTagSensor, mode: OwnershipMode) {
        paths.append(("owner", ruuviTag.id)); owners.append(mode)
    }
    func openContest(ruuviTag: RuuviTagSensor) { paths.append(("contest", ruuviTag.id)) }
    func openSensorRemoval(ruuviTag: RuuviTagSensor, output: SensorRemovalModuleOutput) {
        paths.append(("removal", ruuviTag.id)); removals.append(output)
    }
    func openLedBrightnessSettings(
        selection: RuuviLedBrightnessLevel?, firmwareVersion: String?, snapshotId: String?,
        onUpdateFirmware: (() -> Void)?,
        onSelection: @escaping (RuuviLedBrightnessLevel, @escaping (Result<Void, Error>) -> Void) -> Void
    ) {
        selectedLED = selection; ledFirmware = firmwareVersion; ledSnapshotID = snapshotId
        updateFirmware = onUpdateFirmware; selectLED = onSelection
    }
    func openNotesSettings(notes: String?, onSave: @escaping (String?, @escaping (Result<Void, Error>) -> Void) -> Void)
    {
        noteValues.append(notes); saveNotes = onSave
    }
    func openVisibilitySettings(
        snapshot: RuuviTagCardSnapshot, ruuviTag: RuuviTagSensor, sensorSettings: SensorSettings?
    ) {
        paths.append(("visibility", ruuviTag.id))
    }
}

final class CardSettingsOutputSpy: CardsSettingsPresenterOutput {
    var dismissals = 0
    var alerts = 0
    var deletions = [String]()
    func cardSettingsDidDeleteDevice(module: CardsSettingsPresenterInput, ruuviTag: RuuviTagSensor) {
        deletions.append(ruuviTag.id)
    }
    func cardSettingsDidRequestOpenAlerts(module: CardsSettingsPresenterInput) { alerts += 1 }
    func cardSettingsDidDismiss(module: CardsSettingsPresenterInput) { dismissals += 1 }
}

final class SensorRemovalModuleSpy: SensorRemovalModuleInput {
    var dismissals = 0
    func configure(ruuviTag: RuuviTagSensor, output: SensorRemovalModuleOutput) {}
    func dismiss(completion: (() -> Void)?) { dismissals += 1; completion?() }
}
