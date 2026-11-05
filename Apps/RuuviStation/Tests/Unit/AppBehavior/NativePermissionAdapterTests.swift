import RuuviCore
import UserNotifications
import XCTest

@MainActor final class NativePermissionAdapterTests: XCTestCase {
    func testDefaultPushAdapterReadsNativeSettingsWithoutPrompting() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let expected: PNAuthorizationStatus
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: expected = .authorized
        case .notDetermined: expected = .notDetermined
        default: expected = .denied
        }
        let completion = expectation(description: "Native notification settings")
        RuuviCorePNImpl().getRemoteNotificationsAuthorizationStatus {
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual($0, expected)
            completion.fulfill()
        }
        await fulfillment(of: [completion], timeout: 2)
    }

}
