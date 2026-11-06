import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class DashboardScreenFixture {
    let data = SensorDataFixture()
    let view = DashboardViewController()
    let output = DashboardOutputSpy()
    var host: AppViewHost?
    var snapshots = [RuuviTagCardSnapshot]()
    var collection: UICollectionView { descendants(view.view).compactMap { $0 as? UICollectionView }.first! }
    func start(names: [String] = ["Office", "Kitchen", "Outside"]) async throws {
        let sensors = names.map { data.sensor($0, version: 5) }
        await data.start(sensors)
        snapshots = sensors.compactMap { data.service.getSnapshot(for: $0.id) }
        view.output = output
        view.measurementService = data.measurements.measurement
        data.measurements.flags.showDashboardSensorSearch = true
        view.flags = data.measurements.flags
        view.dashboardType = .simple
        view.dashboardTapActionType = .card
        view.dashboardSortingType = .alphabetical
        host = try AppViewHost(view)
        view.updateSnapshots(snapshots, withAnimation: false)
        await flushAppBindings()
        view.view.layoutIfNeeded()
    }
    func menu(at index: Int) throws -> UIMenu {
        let path = IndexPath(item: index, section: 0)
        collection.scrollToItem(at: path, at: .centeredVertically, animated: false)
        collection.layoutIfNeeded()
        let cell = try XCTUnwrap(collection.cellForItem(at: path))
        return try XCTUnwrap(descendants(cell).compactMap { ($0 as? UIButton)?.menu }.first)
    }
    func actions(_ menu: UIMenu) -> [UIAction] {
        menu.children.flatMap { element -> [UIAction] in
            if let action = element as? UIAction { return [action] }
            if let child = element as? UIMenu { return actions(child) }
            return []
        }
    }
    func choose(_ title: String, in menu: UIMenu) throws {
        let action = try XCTUnwrap(actions(menu).first { $0.title == title })
        let sender = UIButton(type: .system)
        sender.addAction(action, for: .touchUpInside)
        sender.sendActions(for: .touchUpInside)
    }
    func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
    func cleanup() { host?.close(); host = nil; data.cleanup(); data.measurements.cleanup() }
}

final class DashboardOutputSpy: DashboardViewOutput {
    var lifecycle = [String]()
    var navigation = [(String, String?)]()
    var types = [DashboardType]()
    var taps = [DashboardTapActionType]()
    var orders = [(DashboardSortingType, [String])]()
    var resets = 0
    var hides = 0
    var refreshes = 0
    var connections = [(String, String, Bool)]()
    func viewDidLoad() { lifecycle.append("load") }
    func viewWillAppear() { lifecycle.append("appear") }
    func viewWillDisappear() { lifecycle.append("disappear") }
    func viewDidTriggerSignIn() { navigation.append(("signin", nil)) }
    func viewDidTriggerAddSensors() { navigation.append(("add", nil)) }
    func viewDidTriggerMenu() { navigation.append(("menu", nil)) }
    func viewDidTriggerBuySensors() { navigation.append(("buy", nil)) }
    func viewDidTriggerOpenCardImageView(for snapshot: RuuviTagCardSnapshot?) {
        navigation.append(("image", snapshot?.id))
    }
    func viewDidTriggerOpenSensorCardFromWidget(for snapshot: RuuviTagCardSnapshot?) {
        navigation.append(("widget", snapshot?.id))
    }
    func viewDidTriggerSettings(for snapshot: RuuviTagCardSnapshot) { navigation.append(("settings", snapshot.id)) }
    func viewDidTriggerAlerts(for snapshot: RuuviTagCardSnapshot) { navigation.append(("alerts", snapshot.id)) }
    func viewDidTriggerChart(for snapshot: RuuviTagCardSnapshot) { navigation.append(("chart", snapshot.id)) }
    func viewDidTriggerRemove(for snapshot: RuuviTagCardSnapshot) { navigation.append(("remove", snapshot.id)) }
    func viewDidTriggerDashboardCard(for snapshot: RuuviTagCardSnapshot) { navigation.append(("card", snapshot.id)) }
    func viewDidConfirmToKeepConnectionChart(to snapshot: RuuviTagCardSnapshot) {
        connections.append(("chart-keep", snapshot.id, false))
    }
    func viewDidDismissKeepConnectionDialogChart(for snapshot: RuuviTagCardSnapshot) {
        connections.append(("chart-dismiss", snapshot.id, false))
    }
    func viewDidConfirmToKeepConnectionSettings(to snapshot: RuuviTagCardSnapshot, newlyAddedSensor: Bool) {
        connections.append(("settings-keep", snapshot.id, newlyAddedSensor))
    }
    func viewDidDismissKeepConnectionDialogSettings(for snapshot: RuuviTagCardSnapshot, newlyAddedSensor: Bool) {
        connections.append(("settings-dismiss", snapshot.id, newlyAddedSensor))
    }
    func viewDidChangeDashboardType(dashboardType: DashboardType) { types.append(dashboardType) }
    func viewDidChangeDashboardTapAction(type: DashboardTapActionType) { taps.append(type) }
    func viewDidTriggerPullToRefresh() { refreshes += 1 }
    func viewDidReorderSensors(with type: DashboardSortingType, orderedIds: [String]) {
        orders.append((type, orderedIds))
    }
    func viewDidResetManualSorting() { resets += 1 }
    func viewDidHideSignInBanner() { hides += 1 }
}
