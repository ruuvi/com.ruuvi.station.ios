@testable import station
import XCTest
import RuuviLocal
import RuuviOntology

@MainActor
// swiftlint:disable:next type_body_length
final class MeasurementWarningTests: XCTestCase {
    private var window: UIWindow!
    private var animationsWereEnabled = true

    override func setUp() {
        super.setUp()
        animationsWereEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
    }

    override func tearDown() {
        window?.isHidden = true
        window = nil
        UIView.setAnimationsEnabled(animationsWereEnabled)
        super.tearDown()
    }

    func testRepeatedTapsDoNotQueueMessagesAfterNavigation() {
        let view = host(UIViewController()).view!
        let presenter = MeasurementWarningPresenter(duration: 0.02)
        XCTAssertTrue(presenter.show(for: "stale", in: view))
        XCTAssertFalse(presenter.show(for: "stale", in: view))
        XCTAssertTrue(presenter.show(for: "other", in: view))
        XCTAssertEqual(messages(in: view).count, 1)
        presenter.dismiss()
        XCTAssertTrue(messages(in: view).isEmpty)
        XCTAssertNil(presenter.sensorID)
    }

    func testBackgroundingDismissesTheMessage() {
        let view = host(UIViewController()).view!
        let center = NotificationCenter()
        let presenter = MeasurementWarningPresenter(notificationCenter: center)
        XCTAssertTrue(presenter.show(for: "one", in: view))
        center.post(name: UIApplication.willResignActiveNotification, object: nil)
        XCTAssertTrue(messages(in: view).isEmpty)
        XCTAssertNil(presenter.sensorID)
    }

    func testPresenterCanBeReusedForRepeatedExplicitTapsAndDifferentSensors() {
        let view = host(UIViewController()).view!
        let presenter = MeasurementWarningPresenter()
        XCTAssertTrue(presenter.show(for: "one", in: view))
        presenter.dismiss(for: "different")
        XCTAssertEqual(presenter.sensorID, "one")
        presenter.dismiss(for: "one")
        XCTAssertTrue(presenter.show(for: "one", in: view))
        XCTAssertTrue(presenter.show(for: "two", in: view))
        presenter.dismiss()
        XCTAssertTrue(presenter.show(for: "two", in: view))
        presenter.dismiss()
    }

    func testDashboardUpdatesBothLayoutsAndClearsWarningOnFreshDataOrReuse() throws {
        let flags = MeasurementFlags()
        let delegate = MeasurementCellDelegate()
        for style in [DashboardType.simple, .image] {
            let snapshot = makeSnapshot(id: style.rawValue, age: 3601)
            let cell = DashboardCell(frame: CGRect(x: 0, y: 0, width: 340, height: 220))
            cell.freshnessService = readyService(flags: flags)
            cell.delegate = delegate
            cell.configure(with: snapshot, dashboardType: style)
            let button = try XCTUnwrap(descendants(in: cell).compactMap { $0 as? SensorDataSourceButton }.first)
            XCTAssertTrue(button.isStale)
            XCTAssertTrue(button.isUserInteractionEnabled)
            button.sendActions(for: .touchUpInside)
            XCTAssertEqual(delegate.tappedSensorID, snapshot.id)
            let timestamp = try timestamp(in: cell)
            delegate.tappedSensorID = nil
            XCTAssertTrue(timestamp.accessibilityActivate())
            XCTAssertEqual(delegate.tappedSensorID, snapshot.id)
            snapshot.lastUpdated = Date()
            TimestampUpdateService.shared.refresh()
            cell.updateTimestampLabel()
            XCTAssertFalse(button.isStale)
            XCTAssertFalse(button.isUserInteractionEnabled)
            XCTAssertFalse(timestamp.isUserInteractionEnabled)
            delegate.tappedSensorID = nil
            XCTAssertFalse(timestamp.accessibilityActivate())
            button.sendActions(for: .touchUpInside)
            XCTAssertNil(delegate.tappedSensorID)
            XCTAssertEqual(delegate.refreshedSensorID, snapshot.id)
            snapshot.lastUpdated = Date().addingTimeInterval(-100)
            flags.measurementStaleTimeoutSeconds = 1
            TimestampUpdateService.shared.refresh()
            cell.updateTimestampLabel()
            XCTAssertTrue(button.isStale)
            cell.prepareForReuse()
            XCTAssertFalse(button.isStale)
            XCTAssertFalse(timestamp.isWarningVisible)
            delegate.refreshedSensorID = nil
            cell.configure(with: makeSnapshot(id: snapshot.id, age: 0), dashboardType: style)
            XCTAssertEqual(delegate.refreshedSensorID, snapshot.id)
            flags.measurementStaleTimeoutSeconds = 3600
        }
    }

    func testForegroundGraceHidesCachedWarningsInBothViewsUntilDiscoveryFinishes() throws {
        var uptime: TimeInterval = 0
        let gate = MeasurementFreshnessGate(notificationCenter: NotificationCenter(), uptime: { uptime })
        gate.beginForegroundSession(expectingCloudSync: false)
        let snapshot = makeSnapshot(id: "cached", age: 7200)
        let cell = DashboardCell(frame: CGRect(x: 0, y: 0, width: 340, height: 220))
        let service = MeasurementFreshnessService(gate: gate)
        cell.freshnessService = service
        cell.configure(with: snapshot, dashboardType: .simple)
        let card = CardsBaseViewController(tabs: [:], activeTab: .measurement, freshnessService: service)
        card.loadViewIfNeeded()
        card.setSnapshots([snapshot])
        card.setActiveSnapshotIndex(0)
        host(card)
        card.viewDidAppear(false)
        let cellButton = try XCTUnwrap(descendants(in: cell).compactMap { $0 as? SensorDataSourceButton }.first)
        let cardButton = try XCTUnwrap(descendants(in: card.view).compactMap { $0 as? SensorDataSourceButton }.first)
        XCTAssertFalse(cellButton.isStale)
        XCTAssertFalse(cardButton.isStale)
        XCTAssertTrue(messages(in: card.view).isEmpty)
        uptime = 30
        TimestampUpdateService.shared.refresh()
        XCTAssertTrue(cellButton.isStale)
        XCTAssertTrue(cardButton.isStale)
        XCTAssertTrue(messages(in: card.view).isEmpty)
        gate.beginForegroundSession(expectingCloudSync: false)
        TimestampUpdateService.shared.refresh()
        XCTAssertFalse(cellButton.isStale)
        XCTAssertFalse(cardButton.isStale)
        XCTAssertTrue(messages(in: card.view).isEmpty)
        card.viewWillDisappear(false)
    }

    func testFullCardClearsWarningWhenSwitchingSensorsTabsAndLeavingTheScreen() throws {
        let flags = MeasurementFlags()
        let card = CardsBaseViewController(
            tabs: [:], activeTab: .measurement, freshnessService: readyService(flags: flags)
        )
        card.loadViewIfNeeded()
        let stale = makeSnapshot(id: "old", age: 3601)
        let fresh = makeSnapshot(id: "new", age: 0)
        card.setSnapshots([stale, fresh])
        card.setActiveSnapshotIndex(0)
        host(card)
        card.viewDidAppear(false)
        TimestampUpdateService.shared.refresh()
        card.updateTimestampLabel()
        let button = try XCTUnwrap(descendants(in: card.view).compactMap { $0 as? SensorDataSourceButton }.first)
        XCTAssertTrue(button.isStale)
        XCTAssertTrue(messages(in: card.view).isEmpty)
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(messages(in: card.view).count, 1)
        for (source, name) in sourcePreviews {
            stale.displayData.source = source
            TimestampUpdateService.shared.refresh()
            card.updateTimestampLabel()
            card.view.layoutIfNeeded()
            attachImage(of: card.view, name: "outdated-measurement-full-card-\(name)")
        }
        card.setActiveSnapshotIndex(1)
        XCTAssertFalse(button.isStale)
        XCTAssertTrue(messages(in: card.view).isEmpty)
        card.setActiveSnapshotIndex(0)
        XCTAssertTrue(messages(in: card.view).isEmpty)
        XCTAssertTrue(try timestamp(in: card.view).accessibilityActivate())
        XCTAssertEqual(messages(in: card.view).count, 1)
        card.showContentsForTab(.settings)
        XCTAssertTrue(messages(in: card.view).isEmpty)
        card.showContentsForTab(.measurement)
        button.sendActions(for: .touchUpInside)
        card.viewWillDisappear(false)
        XCTAssertTrue(messages(in: card.view).isEmpty)
        TimestampUpdateService.shared.refresh()
        card.updateTimestampLabel()
        XCTAssertTrue(messages(in: card.view).isEmpty)
    }

    func testFullCardRefreshAndRemovalClearWarningWithoutWaitingForNavigation() throws {
        let card = CardsBaseViewController(tabs: [:], activeTab: .measurement, freshnessService: readyService())
        card.loadViewIfNeeded()
        let snapshot = makeSnapshot(id: "one", age: 3601)
        card.setSnapshots([snapshot])
        card.setActiveSnapshotIndex(0)
        host(card)
        card.viewDidAppear(false)
        XCTAssertTrue(messages(in: card.view).isEmpty)
        let timestamp = try timestamp(in: card.view)
        XCTAssertTrue(timestamp.accessibilityActivate())
        XCTAssertFalse(messages(in: card.view).isEmpty)
        snapshot.lastUpdated = Date()
        TimestampUpdateService.shared.refresh()
        card.updateTimestampLabel()
        XCTAssertTrue(messages(in: card.view).isEmpty)
        XCTAssertFalse(timestamp.accessibilityActivate())
        snapshot.lastUpdated = Date().addingTimeInterval(-7200)
        TimestampUpdateService.shared.refresh()
        card.updateTimestampLabel()
        XCTAssertTrue(messages(in: card.view).isEmpty)
        XCTAssertTrue(timestamp.accessibilityActivate())
        card.setSnapshots([])
        card.setActiveSnapshotIndex(-1)
        TimestampUpdateService.shared.refresh()
        card.updateTimestampLabel()
        XCTAssertTrue(messages(in: card.view).isEmpty)
        card.viewWillDisappear(false)
    }

    // swiftlint:disable:next function_body_length
    func testStatusIconWidthAndBatteryRemainVisibleInLightAndDarkCards() throws {
        let controller = host(UIViewController())
        for style in [UIUserInterfaceStyle.light, .dark] {
            for layout in [DashboardType.simple, .image] {
                let snapshot = makeSnapshot(id: "preview", age: 3601)
                snapshot.displayData.batteryNeedsReplacement = true
                let width: CGFloat = layout == .image ? 340 : 180
                let cell = DashboardCell(frame: CGRect(x: 0, y: 0, width: width, height: 200))
                controller.overrideUserInterfaceStyle = style
                controller.view.addSubview(cell)
                defer { cell.removeFromSuperview() }
                cell.freshnessService = readyService()
                cell.overrideUserInterfaceStyle = style
                if #available(iOS 17.0, *) { cell.updateTraitsIfNeeded() }
                XCTAssertEqual(cell.traitCollection.userInterfaceStyle, style)
                cell.configure(with: snapshot, dashboardType: layout)
                cell.layoutIfNeeded()
                let button = try XCTUnwrap(descendants(in: cell).compactMap { $0 as? SensorDataSourceButton }.first)
                let timestamp = try XCTUnwrap(descendants(in: cell).first {
                    $0.accessibilityIdentifier == "measurement-timestamp"
                } as? UILabel)
                timestamp.font = .systemFont(ofSize: 24)
                timestamp.text = "Päivitetty useita tunteja sitten"
                cell.layoutIfNeeded()
                let originalFrame = button.frame
                snapshot.displayData.source = .ruuviNetwork
                TimestampUpdateService.shared.refresh()
                cell.updateTimestampLabel()
                timestamp.text = "Päivitetty useita tunteja sitten"
                cell.layoutIfNeeded()
                XCTAssertEqual(button.frame, originalFrame)
                XCTAssertEqual(button.bounds.width, SensorDataSourceButton.width, accuracy: 0.1)
                let battery = try XCTUnwrap(descendants(in: cell).first { $0 is BatteryLevelView })
                XCTAssertFalse(battery.isHidden)
                XCTAssertGreaterThan(battery.bounds.width, 0)
                let batteryFrame = battery.convert(battery.bounds, to: cell)
                XCTAssertLessThanOrEqual(batteryFrame.maxX, cell.bounds.maxX)
                let timestampFrame = timestamp.convert(timestamp.bounds, to: cell)
                let sourceFrame = button.convert(button.bounds, to: cell)
                XCTAssertLessThanOrEqual(sourceFrame.maxX, timestampFrame.minX)
                XCTAssertLessThanOrEqual(timestampFrame.maxX, batteryFrame.minX)
                if #available(iOS 17.0, *) { descendants(in: cell).forEach { $0.updateTraitsIfNeeded() } }
                for (source, name) in sourcePreviews {
                    snapshot.displayData.source = source
                    TimestampUpdateService.shared.refresh()
                    cell.updateTimestampLabel()
                    timestamp.text = "Päivitetty useita tunteja sitten"
                    cell.layoutIfNeeded()
                    attachImage(of: cell, name: "outdated-measurement-\(layout.rawValue)-\(style.rawValue)-\(name)")
                }
            }
        }
    }

    func testVisibilityPreviewHasNoWarningAndDoesNotReadFreshnessSettings() throws {
        let preview = DashboardCellPreviewContainerView(frame: CGRect(x: 0, y: 0, width: 340, height: 220))
        let cell = try XCTUnwrap(descendants(in: preview).compactMap { $0 as? DashboardCell }.first)
        var reads = 0
        cell.freshnessService = MeasurementFreshnessService(timeout: { reads += 1; return 1 })
        preview.configure(with: makeSnapshot(id: "preview", age: 7200), dashboardType: .simple)
        let button = try XCTUnwrap(descendants(in: cell).compactMap { $0 as? SensorDataSourceButton }.first)
        let timestamp = try timestamp(in: cell)
        timestamp.text = "Static preview"
        TimestampUpdateService.shared.refresh()
        XCTAssertEqual(reads, 0)
        XCTAssertEqual(timestamp.text, "Static preview")
        XCTAssertFalse(button.isStale)
        XCTAssertFalse(timestamp.isWarningVisible)
    }

    func testSourceImageSizesAndUpperRightBadgeAnchor() throws {
        let button = SensorDataSourceButton(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        host(UIViewController()).view.addSubview(button)
        let source = try XCTUnwrap(button.subviews.first { $0.accessibilityIdentifier == "measurement-source-icon" })
        let badge = try XCTUnwrap(button.subviews.first { $0.accessibilityIdentifier == "measurement-warning-badge" })
        for (type, _) in sourcePreviews {
            button.update(source: type, isStale: true)
            button.layoutIfNeeded()
            XCTAssertEqual(source.bounds.width, type == .ruuviNetwork ? 22 : 16)
            XCTAssertEqual(source.bounds.height, type == .ruuviNetwork ? 20 : 16)
            XCTAssertEqual(badge.frame.minY, source.frame.minY)
            XCTAssertEqual(badge.frame.maxX, button.bounds.maxX)
            XCTAssertGreaterThan(source.frame.maxX, badge.frame.minX)
        }
    }

}

private extension MeasurementWarningTests {
    func timestamp(in view: UIView) throws -> MeasurementTimestampLabel {
        try XCTUnwrap(descendants(in: view).compactMap { $0 as? MeasurementTimestampLabel }.first)
    }

    var sourcePreviews: [(RuuviTagSensorRecordSource, String)] {
        [(.advertisement, "bluetooth"), (.heartbeat, "bluetooth-connected"), (.ruuviNetwork, "gateway")]
    }

    func readyService(flags: MeasurementFlags = MeasurementFlags()) -> MeasurementFreshnessService {
        var uptime: TimeInterval = 0
        let gate = MeasurementFreshnessGate(notificationCenter: NotificationCenter(), uptime: { uptime })
        uptime = 30
        return MeasurementFreshnessService(gate: gate, timeout: { flags.measurementStaleTimeoutSeconds })
    }

    @discardableResult
    func host(_ controller: UIViewController) -> UIViewController {
        window?.isHidden = true
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        return controller
    }

    func attachImage(of view: UIView, name: String) {
        let image = UIGraphicsImageRenderer(bounds: view.bounds).image { context in
            view.layer.render(in: context.cgContext)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func descendants(in view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(in: $0) }
    }

    func messages(in view: UIView) -> [UIView] {
        descendants(in: view).filter { $0.accessibilityIdentifier == "outdated-measurement-message" }
    }

    func makeSnapshot(id: String, age: TimeInterval) -> RuuviTagCardSnapshot {
        var display = RuuviTagCardSnapshotDisplayData()
        display.name = "Living room"
        display.source = .advertisement
        display.indicatorGrid = .init(indicators: [
            .init(variant: .init(type: .temperature), value: "22.5", unit: "°C", isProminent: true,
                  showSubscript: false, tintColor: nil, qualityState: nil),
        ])
        return RuuviTagCardSnapshot(
            id: id, identifierData: .init(), displayData: display,
            lastUpdated: Date().addingTimeInterval(-age)
        )
    }
}

private final class MeasurementFlags: RuuviLocalFlags {
    var showNewSettings = false
    var downloadBetaFirmware = false
    var downloadAlphaFirmware = false
    var autoSyncGattHistoryForRuuviAir = true
    var autoSyncGattHistoryForRuuviAirMinimumLastSyncDateAgeMinutes = 5
    var allowConcurrentGattSyncForMultipleSensors = true
    var showMarketingPreference = false
    var marketingConsentPromptIntervalMinutes = 1
    var showDashboardSensorSearch = false
    var measurementStaleTimeoutSeconds = 3600
    var graphDownsampleMaximumPoints = 3000
}

private final class MeasurementCellDelegate: DashboardCellDelegate {
    var tappedSensorID: String?
    var refreshedSensorID: String?
    func didTapMeasurementWarning(for snapshot: RuuviTagCardSnapshot) { tappedSensorID = snapshot.id }
    func didReceiveFreshMeasurements(for snapshot: RuuviTagCardSnapshot) { refreshedSensorID = snapshot.id }
    func didTapAlertButton(for _: RuuviTagCardSnapshot) {
        // Alert actions are outside the measurement freshness tests.
    }
    func didChangeMoreButtonMenuPresentationState(for _: RuuviTagCardSnapshot, isPresented _: Bool) {
        // Menu presentation is outside the measurement freshness tests.
    }
}
