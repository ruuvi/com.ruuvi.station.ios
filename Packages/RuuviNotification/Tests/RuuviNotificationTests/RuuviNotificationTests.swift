@testable import RuuviNotification
import XCTest

final class RuuviNotificationTests: XCTestCase {
    func testNotificationConstantsRemainStable() {
        XCTAssertEqual(Notification.Name.LNMDidReceive.rawValue, "LNMDidReceive")
        XCTAssertEqual(LNMDidReceiveKey.uuid.rawValue, "uuid")
    }

    func testLocalAlertCategoryStoresProvidedConfiguration() {
        let category = LocalAlertCategory(
            id: "alerts.id",
            disable: "alerts.disable",
            mute: "alerts.mute",
            uuidKey: "alerts.uuid",
            typeKey: "alerts.type"
        )

        XCTAssertEqual(category.id, "alerts.id")
        XCTAssertEqual(category.disable, "alerts.disable")
        XCTAssertEqual(category.mute, "alerts.mute")
        XCTAssertEqual(category.uuidKey, "alerts.uuid")
        XCTAssertEqual(category.typeKey, "alerts.type")
    }

    func testBlastNotificationTypesHaveStableRawValues() {
        XCTAssertEqual(BlastNotificationType.connection.rawValue, "connection")
        XCTAssertEqual(BlastNotificationType.movement.rawValue, "movement")
    }
}
