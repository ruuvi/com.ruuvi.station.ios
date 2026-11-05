import Foundation
import RuuviOntology
import XCTest
@testable import station

@MainActor final class DashboardFixture {
    let services = CoordinatorFixture()
    let view = DashboardViewSpy()
    let router = DashboardRouterSpy()
    let interactor = DashboardInteractorSpy()
    let errors = OffsetErrorSpy()
    let settingsService: DashboardSettingsService
    let appSettings: AppSettingsServiceSpy
    var presenter: DashboardPresenter!
    init() {
        appSettings = AppSettingsServiceSpy(settings: services.data.measurements.settings)
        settingsService = DashboardSettingsService(
            settings: services.data.measurements.settings, ruuviAppSettingsService: appSettings, appGroupDefaults: nil)
        presenter = DashboardPresenter(settingsService: settingsService, serviceCoordinatorManager: services.manager)
        presenter.view = view
        presenter.router = router
        presenter.interactor = interactor
        presenter.errorPresenter = errors
        presenter.pushNotificationsManager = services.push
        presenter.flags = services.data.measurements.flags
        presenter.activityPresenter = AccountActivitySpy()
    }
    func start(version: Int = 5, cloud: Bool = false) async throws -> RuuviTagCardSnapshot {
        let sensor = services.data.sensor("Office", version: version, cloud: cloud)
        await services.start([sensor])
        return try XCTUnwrap(services.manager.getSnapshot(for: sensor.id))
    }
    func cleanup() { presenter = nil; settingsService.stopObservingSettings(); services.cleanup() }
}

final class DashboardViewSpy: NewDashboardViewInput {
    var isAuthorized = false
    var dashboardType: DashboardType!
    var dashboardTapActionType: DashboardTapActionType!
    var dashboardSortingType: DashboardSortingType!
    var isRefreshing = false
    var shouldShowSignInBanner = false
    var lists = [[String]]()
    var updates = [(String, Bool)]()
    var empty = [Bool]()
    var bluetooth = [Bool]()
    var chartPrompts = [String]()
    var settingsPrompts = [(String, Bool)]()
    var emails = [String]()
    var resets = 0
    var marketingPrompts = 0
    func updateSnapshots(_ snapshots: [RuuviTagCardSnapshot], withAnimation: Bool) { lists.append(snapshots.map(\.id)) }
    func updateSnapshot(from snapshot: RuuviTagCardSnapshot, invalidateLayout: Bool) {
        updates.append((snapshot.id, invalidateLayout))
    }
    func showNoSensorsAddedMessage(show: Bool) { empty.append(show) }
    func showBluetoothDisabled(userDeclined: Bool) { bluetooth.append(userDeclined) }
    func showKeepConnectionDialogChart(for snapshot: RuuviTagCardSnapshot) { chartPrompts.append(snapshot.id) }
    func showKeepConnectionDialogSettings(for snapshot: RuuviTagCardSnapshot, newlyAddedSensor: Bool) {
        settingsPrompts.append((snapshot.id, newlyAddedSensor))
    }
    func showAlreadyLoggedInAlert(with email: String) { emails.append(email) }
    func showSensorSortingResetConfirmationDialog() { resets += 1 }
    func showMarketingConsentPromptIfNeeded() { marketingPrompts += 1 }
}

final class DashboardRouterSpy: DashboardRouterInput {
    struct Card { let id: String; let snapshots: [String]; let sensors: [String]; let menu: CardsMenuType }
    var paths = [String]()
    var cards = [Card]()
    var removed = [String]()
    var firmware = [String]()
    var urls = [URL]()
    func openMenu(output: MenuModuleOutput) { paths.append("menu") }
    func openDiscover(delegate: DiscoverRouterDelegate) { paths.append("discover") }
    func openSettings() { paths.append("settings") }
    func openAbout() { paths.append("about") }
    func openWhatToMeasurePage() { paths.append("measure") }
    func openRuuviProductsPage() { paths.append("products") }
    func openRuuviProductsPageFromMenu() { paths.append("menu-products") }
    func openSignIn(output: SignInBenefitsModuleOutput) { paths.append("signin") }
    func openFullSensorCard(
        for snapshot: RuuviTagCardSnapshot, snapshots: [RuuviTagCardSnapshot], ruuviTagSensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings], activeMenu: CardsMenuType
    ) {
        cards.append(
            .init(id: snapshot.id, snapshots: snapshots.map(\.id), sensors: ruuviTagSensors.map(\.id), menu: activeMenu)
        )
    }
    func openUpdateFirmware(ruuviTag: RuuviTagSensor) { firmware.append(ruuviTag.id) }
    func openMyRuuviAccount() { paths.append("account") }
    func open(url: URL) { urls.append(url) }
    func openRemove(for sensor: RuuviTagSensor, output: SensorRemovalModuleOutput) { removed.append(sensor.id) }
}

final class DashboardInteractorSpy: DashboardInteractorInput {
    var checked = [String]()
    func checkAndUpdateFirmwareVersion(for ruuviTag: RuuviTagSensor) { checked.append(ruuviTag.id) }
}
