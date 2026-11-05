import Foundation
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import XCTest
@testable import station

@MainActor final class DefaultsPresenterTests: XCTestCase {
    func testEveryBooleanPreferenceDisplaysAndUpdatesItsOwnSetting() async throws {
        let fixture = DefaultsPresenterFixture()
        for (_, key, _) in booleanSettings { fixture.settings[keyPath: key] = true }
        fixture.configure()
        for (title, key, absentValue) in booleanSettings {
            let model = try row(title, in: fixture)
            XCTAssertEqual(model.type.value, .switcher)
            XCTAssertEqual(model.boolean.value, true, title)
            XCTAssertEqual(model.hideStatusLabel.value, false)
            model.boolean.value = false
            await flushBindings()
            XCTAssertFalse(fixture.settings[keyPath: key], title)
            model.boolean.value = true
            await flushBindings()
            XCTAssertTrue(fixture.settings[keyPath: key], title)
            model.boolean.value = nil
            await flushBindings()
            XCTAssertEqual(fixture.settings[keyPath: key], absentValue, title)
        }
    }

    func testEveryFeatureFlagDisplaysAndUpdatesItsOwnSetting() async throws {
        let fixture = DefaultsPresenterFixture()
        for (_, key) in booleanFlags { fixture.flags[keyPath: key] = true }
        fixture.configure()
        for (title, key) in booleanFlags {
            let model = try row(title, in: fixture)
            XCTAssertEqual(model.boolean.value, true, title)
            XCTAssertEqual(model.hideStatusLabel.value, true)
            model.boolean.value = false
            await flushBindings()
            XCTAssertFalse(fixture.flags[keyPath: key], title)
            model.boolean.value = true
            await flushBindings()
            XCTAssertTrue(fixture.flags[keyPath: key], title)
            model.boolean.value = nil
            await flushBindings()
            XCTAssertFalse(fixture.flags[keyPath: key], title)
        }
    }

    func testIntegerPreferencesPreserveTheirUnitsAndPersistEditedValues() async throws {
        let fixture = DefaultsPresenterFixture()
        for item in integerSettings { fixture.settings[keyPath: item.key] = 17 }
        fixture.configure()
        for item in integerSettings {
            let model = try row(item.title, in: fixture)
            XCTAssertEqual(model.type.value, .stepper)
            XCTAssertEqual(model.integer.value, 17, item.title)
            XCTAssertEqual(model.unit, item.unit)
            model.integer.value = 23
            await flushBindings()
            XCTAssertEqual(fixture.settings[keyPath: item.key], 23, item.title)
            model.integer.value = nil
            await flushBindings()
            XCTAssertEqual(fixture.settings[keyPath: item.key], 0, item.title)
        }
    }

    func testTimeoutsTruncateFiniteSecondsAndHandleCorruptPreferencesWithoutCrashing() async throws {
        for seconds in [Double.nan, .infinity, -.infinity, .greatestFiniteMagnitude, Double(Int.max), -1, 12.75] {
            let fixture = DefaultsPresenterFixture()
            fixture.settings.connectionTimeout = seconds
            fixture.settings.serviceTimeout = seconds
            fixture.configure()
            for title in [
                RuuviLocalization.Defaults.ConnectionTimeout.title, RuuviLocalization.Defaults.ServiceTimeout.title,
            ] {
                let model = try row(title, in: fixture)
                XCTAssertEqual(model.unit, .seconds)
                XCTAssertEqual(model.integer.value, seconds == 12.75 ? 12 : 0)
                model.integer.value = 8
            }
            await flushBindings()
            XCTAssertEqual(fixture.settings.connectionTimeout, 8)
            XCTAssertEqual(fixture.settings.serviceTimeout, 8)
        }
    }

    func testBoundedFlagsAndMarketingEditorEnforceTheirDocumentedRanges() async throws {
        let fixture = DefaultsPresenterFixture()
        fixture.flags.graphDownsampleMaximumPoints = Int.max
        fixture.flags.marketingConsentPromptIntervalMinutes = 0
        fixture.configure()
        let points = try row("Graph downsample max points", in: fixture)
        XCTAssertEqual(points.item.value, .graphDownsampleMaximumPoints)
        XCTAssertEqual(points.integer.value, 5000)
        for (input, expected) in [(0, 1000), (3000, 3000), (Int.max, 5000)] {
            points.integer.value = input
            await flushBindings()
            XCTAssertEqual(fixture.flags.graphDownsampleMaximumPoints, expected)
        }
        let age = try row("Auto sync Ruuvi Air minimum age since last sync date", in: fixture)
        for (input, expected) in [(-1, 0), (17, 17)] {
            age.integer.value = input
            await flushBindings()
            XCTAssertEqual(fixture.flags.autoSyncGattHistoryForRuuviAirMinimumLastSyncDateAgeMinutes, expected)
        }
        let marketing = try row("Marketing consent prompt interval", in: fixture)
        XCTAssertEqual(marketing.integer.value, 1)
        let editor = try XCTUnwrap(marketing.integerEditor)
        XCTAssertEqual(editor.presets.map(\.value), [1, RuuviMarketingConsentPromptInterval.defaultMinutes])
        XCTAssertEqual(editor.range, RuuviMarketingConsentPromptInterval.allowedMinutes)
        for (input, expected) in [(0, 1), (17, 17), (Int.max, Int(Int32.max))] {
            marketing.integer.value = input
            await flushBindings()
            XCTAssertEqual(fixture.flags.marketingConsentPromptIntervalMinutes, expected)
        }
        XCTAssertEqual(
            try row(RuuviLocalization.Defaults.ImageCompressionQuality.title, in: fixture).item.value,
            .imageCompressionQuality)
    }

    func testAuthRowsAreUniqueAndDashboardChoiceDoesNotChangeForAnAbsentValue() async throws {
        let fixture = DefaultsPresenterFixture()
        fixture.configure()
        let auth = try row(RuuviLocalization.Defaults.UserAuthorized.title, in: fixture)
        XCTAssertEqual(auth.type.value, .plain)
        XCTAssertEqual(auth.value.value, RuuviLocalization.no)
        XCTAssertEqual(try row("Auth Token", in: fixture).value.value, "test-token")
        fixture.user.isAuthorized = true
        fixture.configure()
        XCTAssertEqual(
            try row(RuuviLocalization.Defaults.UserAuthorized.title, in: fixture).value.value,
            RuuviLocalization.yes)
        let dashboard = try row(RuuviLocalization.Defaults.DashboardTapActionChart.title, in: fixture)
        dashboard.boolean.value = true
        await flushBindings()
        XCTAssertEqual(fixture.settings.dashboardTapActionType, .chart)
        dashboard.boolean.value = nil
        await flushBindings()
        XCTAssertEqual(fixture.settings.dashboardTapActionType, .chart)
        dashboard.boolean.value = false
        await flushBindings()
        XCTAssertEqual(fixture.settings.dashboardTapActionType, .card)
    }

    func testEndpointChangeRequiresTheViewConfirmationBeforePersistingAndNotifying() async throws {
        let fixture = DefaultsPresenterFixture()
        fixture.configure()
        let endpoint = try row(RuuviLocalization.Defaults.DevServer.title, in: fixture)
        XCTAssertEqual(endpoint.boolean.value, false)
        endpoint.boolean.value = true
        await flushBindings()
        XCTAssertEqual(fixture.view.confirmations, [true])
        XCTAssertFalse(fixture.defaults.bool(forKey: AppGroupConstants.useDevServerKey))
        XCTAssertTrue(fixture.effects.reloadedWidgets.isEmpty)
        XCTAssertEqual(fixture.output.dismissals, 0)
        var notifications = 0
        let token = fixture.effects.notifications.addObserver(
            forName: .NetworkSyncDidFailForAuthorization, object: fixture.presenter, queue: .main
        ) { _ in notifications += 1 }
        defer { fixture.effects.notifications.removeObserver(token) }
        fixture.presenter.viewDidTriggerUseDevServer(useDevServer: true)
        XCTAssertTrue(fixture.defaults.bool(forKey: AppGroupConstants.useDevServerKey))
        XCTAssertEqual(
            fixture.effects.reloadedWidgets,
            [
                AppAssemblyConstants.simpleWidgetKindId, AppAssemblyConstants.multiSensorWidgetKindId,
            ])
        XCTAssertEqual(notifications, 1)
        XCTAssertEqual(fixture.output.dismissals, 1)
        fixture.presenter.viewDidTriggerUseDevServer(useDevServer: nil)
        XCTAssertNil(fixture.defaults.object(forKey: AppGroupConstants.useDevServerKey))
        XCTAssertEqual(notifications, 2)
        XCTAssertEqual(fixture.output.dismissals, 2)
    }

    func testDismissAndReleaseDoNotRetainThePresenterThroughBindings() async throws {
        let fixture = DefaultsPresenterFixture()
        var completed = 0
        fixture.presenter.dismiss { completed += 1 }
        fixture.presenter.dismiss(completion: nil)
        XCTAssertEqual(fixture.router.dismissals, 2)
        XCTAssertEqual(completed, 1)
        var another: DefaultsPresenterFixture? = DefaultsPresenterFixture()
        another?.configure()
        let model = try XCTUnwrap(another?.view.viewModels.first)
        weak var released = another?.presenter
        another = nil
        XCTAssertNil(released)
        model.boolean.value = true
        await flushBindings()
    }

    private func row(_ title: String, in fixture: DefaultsPresenterFixture) throws -> DefaultsViewModel {
        let rows = fixture.view.viewModels.filter { $0.title == title }
        XCTAssertEqual(rows.count, 1, "Each preference must appear once: \(title)")
        return try XCTUnwrap(rows.first)
    }

    private func flushBindings() async {
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
    }
}
