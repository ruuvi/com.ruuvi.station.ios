import UIKit
import XCTest
@testable import station

@MainActor final class AppDelegateRoutingTests: XCTestCase {
    func testWidgetURLParsingPreservesLegacyIdentifiersAndPrefersTheDecodedSensorQuery() throws {
        let delegate = AppDelegate()
        for (raw, expected) in [
            ("ruuvi://sensor?sensorId=AA%3ABB%3ACC%3ADD%3AEE%3AFF", "AA:BB:CC:DD:EE:FF"),
            ("ruuvi://sensor?sensorId=first&sensorId=second", "first"),
            ("ruuvi://sensor?sensorId=Room%20%F0%9F%8C%BF", "Room 🌿"),
            ("aa:bb:cc:dd:ee:ff", "aa:bb:cc:dd:ee:ff"),
            ("ruuvi://sensor/AA%3ABB", "ruuvi://sensor/AA:BB"),
            ("ruuvi://sensor?sensorId=", "ruuvi://sensor?sensorId="),
        ] {
            XCTAssertEqual(delegate.widgetSensorIdentifier(from: try XCTUnwrap(URL(string: raw))), expected)
        }
    }

    func testNotificationAndWidgetNavigationStoreTheExactPendingIdentityBeforeForwarding() {
        let delegate = AppDelegate()
        let settings = AppTestSettings()
        let state = AppDelegateStateSpy()
        delegate.settings = settings
        delegate.appStateService = state
        state.onWidget = { identifier in XCTAssertEqual(settings.cardToOpenFromWidget(), identifier) }
        delegate.notificationDidTap(for: "AA:BB:CC:DD:EE:FF")
        delegate.openSelectedCard(for: "local-identifier", application: UIApplication.shared)
        XCTAssertEqual(state.identifiers, ["AA:BB:CC:DD:EE:FF", "local-identifier"])
        XCTAssertEqual(state.hasApplication, [false, true])
        delegate.appStateService = nil
        delegate.openSelectedCard(for: "pending-before-startup")
        XCTAssertEqual(settings.cardToOpenFromWidget(), "pending-before-startup")
        XCTAssertEqual(state.identifiers.count, 2)
    }
}
private final class AppDelegateStateSpy: AppStateService {
    var identifiers = [String]()
    var hasApplication = [Bool]()
    var onWidget: ((String) -> Void)?
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) {}
    func applicationWillResignActive(_ application: UIApplication) {}
    func applicationDidBecomeActive(_ application: UIApplication) {}
    func applicationDidEnterBackground(_ application: UIApplication) {}
    func applicationWillEnterForeground(_ application: UIApplication) {}
    func applicationDidOpenWithUniversalLink(_ application: UIApplication, url: URL) {
        XCTFail("Unexpected universal-link route")
    }
    func applicationDidOpenWithWidgetDeepLink(_ application: UIApplication?, macId: String) {
        onWidget?(macId); identifiers.append(macId); hasApplication.append(application != nil)
    }
}
