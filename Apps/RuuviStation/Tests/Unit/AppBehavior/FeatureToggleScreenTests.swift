import UIKit
import XCTest
@testable import station

@MainActor final class FeatureToggleScreenTests: XCTestCase {
    func testRemoteFeaturesAreReadOnlyAndLocalSwitchEnablesPersistentEditing() throws {
        let fixture = FeatureToggleScreenFixture()
        defer { fixture.close() }
        fixture.service.source = .remote
        fixture.service.fetchFeatureToggles()
        let controller = FeatureTogglesViewController()
        controller.featureToggleService = fixture.service
        controller.settings = AppTestSettings()
        let host = try AppViewHost(controller)
        defer { host.close() }
        let table = controller.tableView!
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), Feature.allCases.count)
        let row = IndexPath(row: 0, section: 0)
        var cell = controller.tableView(table, cellForRowAt: row)
        XCTAssertEqual(cell.textLabel?.text, "Legacy Firmware Update Alert")
        XCTAssertEqual(cell.accessoryType, .checkmark)
        controller.tableView(table, didSelectRowAt: row)
        XCTAssertTrue(
            fixture.service.isEnabled(.legacyFirmwareUpdatePopup), "Remote configuration must remain read-only")
        let toggle = try XCTUnwrap(controller.view.allDescendants.compactMap { $0 as? UISwitch }.first)
        toggle.setOn(true, animated: false)
        toggle.sendActions(for: .valueChanged)
        XCTAssertEqual(fixture.service.source, .local)
        XCTAssertFalse(fixture.service.isEnabled(.legacyFirmwareUpdatePopup))
        controller.tableView(table, didSelectRowAt: row)
        XCTAssertTrue(fixture.service.isEnabled(.legacyFirmwareUpdatePopup))
        cell = controller.tableView(table, cellForRowAt: row)
        XCTAssertEqual(cell.accessoryType, .checkmark)
        fixture.service.fetchFeatureToggles()
        XCTAssertTrue(fixture.service.isEnabled(.legacyFirmwareUpdatePopup), "Reloading must preserve the local choice")
        controller.tableView(table, didSelectRowAt: row)
        XCTAssertFalse(fixture.service.isEnabled(.legacyFirmwareUpdatePopup))
        cell = controller.tableView(table, cellForRowAt: row)
        XCTAssertEqual(cell.accessoryType, .none)
        toggle.setOn(false, animated: false)
        toggle.sendActions(for: .valueChanged)
        XCTAssertEqual(fixture.service.source, .remote)
        XCTAssertTrue(fixture.service.isEnabled(.legacyFirmwareUpdatePopup))
    }

    func testUnavailableRemoteConfigurationUsesTheBundledFallbackWithoutOverwritingLocalPreferences() {
        let fixture = FeatureToggleScreenFixture()
        defer { fixture.close() }
        fixture.remote.values = []
        fixture.fallback.values = [.init(feature: .legacyFirmwareUpdatePopup, enabled: false, source: .remote)]
        fixture.service.fetchFeatureToggles()
        fixture.service.source = .remote
        XCTAssertFalse(fixture.service.isEnabled(.legacyFirmwareUpdatePopup))
        XCTAssertEqual(fixture.fallback.fetches, 1)
        fixture.service.source = .local
        fixture.service.enableLocal(.legacyFirmwareUpdatePopup)
        fixture.remote.values = [.init(feature: .legacyFirmwareUpdatePopup, enabled: true, source: .remote)]
        fixture.service.fetchFeatureToggles()
        XCTAssertTrue(fixture.service.isEnabled(.legacyFirmwareUpdatePopup))
        XCTAssertEqual(fixture.fallback.fetches, 1)
    }
}

@MainActor private final class FeatureToggleScreenFixture {
    let service = FeatureToggleService()
    let remote = FeatureToggleProviderSpy()
    let fallback = FeatureToggleProviderSpy()
    private let saved: [(String, Any?)]
    init() {
        let keys =
            ["FeatureToggleService.sourceUDKey", "FeatureToggleService.remoteTogglesUDKey"]
            + Feature.allCases.map { "LocalFeatureToggleProvider.isEnabledPrefix" + $0.rawValue }
        saved = keys.map { ($0, UserDefaults.standard.object(forKey: $0)) }
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        remote.values = [.init(feature: .legacyFirmwareUpdatePopup, enabled: true, source: .remote)]
        service.firebaseProvider = remote
        service.fallbackProvider = fallback
        service.localProvider = LocalFeatureToggleProvider()
    }
    func close() { saved.forEach { UserDefaults.standard.set($0.1, forKey: $0.0) } }
}
private final class FeatureToggleProviderSpy: FeatureToggleProvider {
    var values = [FeatureToggle]()
    var fetches = 0
    func fetchFeatureToggles(_ completion: @escaping FeatureToggleCallback) { fetches += 1; completion(values) }
}
