import Foundation
import RuuviLocal
import RuuviOntology
import RuuviService
@testable import RuuviNotification
import UserNotifications
#if SWIFT_PACKAGE
    import RuuviLocalUserDefaults
    @testable import RuuviServiceAlert
    @testable import RuuviNotificationLocal
#endif

@MainActor final class LocalNotificationFixture {
    private let suite = "LocalNotificationTests." + UUID().uuidString
    private let defaults: UserDefaults
    let center = NotificationCenterSpy()
    let cloud = NotificationCloudSpy()
    var settings: RuuviLocalSettings
    let ids: RuuviLocalIDs
    let alerts: RuuviServiceAlertImpl
    let sensor: RuuviTagSensorStruct
    var date = Date(timeIntervalSince1970: 1_800_000_000)
    var reads: [String] = []
    var failRead = false
    private struct SavedSettings {
        let limited: Bool
        let minutes: Int
        let sound: RuuviAlertSound
        let badge: Int
    }
    private let saved: SavedSettings
    lazy var notifications = RuuviNotificationLocalImpl(
        readSensor: { [unowned self] id in
            reads.append(id)
            if failRead { throw NSError(domain: "test-storage", code: 1) }
            return sensor.any
        }, idPersistence: ids, settings: settings, ruuviAlertService: alerts,
        center: center, now: { [unowned self] in date })

    init() {
        defaults = UserDefaults(suiteName: suite)!
        let local = RuuviLocalFactoryUserDefaults()
        settings = local.createLocalSettings()
        ids = local.createLocalIDs()
        saved = SavedSettings(
            limited: settings.limitAlertNotificationsEnabled,
            minutes: settings.alertsMuteIntervalMinutes,
            sound: settings.alertSound,
            badge: settings.notificationsBadgeCount()
        )
        settings.limitAlertNotificationsEnabled = false
        settings.alertsMuteIntervalMinutes = 60
        settings.alertSound = .systemDefault
        settings.setNotificationsBadgeCount(value: 0)
        let bytes = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12)
        let mac = stride(from: 0, to: 12, by: 2).map { offset in
            let start = bytes.index(bytes.startIndex, offsetBy: offset)
            return String(bytes[start..<bytes.index(start, offsetBy: 2)])
        }.joined(separator: ":")
        sensor = RuuviTagSensorStruct(
            version: 5, firmwareVersion: nil, luid: UUID().uuidString.luid, macId: mac.mac,
            serviceUUID: nil, isConnectable: true, name: "Office 🌿", isClaimed: false,
            isOwner: true, owner: nil, ownersPlan: nil, isCloudSensor: false,
            canShare: false, sharedTo: [], maxHistoryDays: nil)
        ids.set(mac: sensor.macId!, for: sensor.luid!)
        ids.set(luid: sensor.luid!, for: sensor.macId!)
        alerts = RuuviServiceAlertImpl(cloud: cloud, localIDs: ids, ruuviLocalSettings: settings, defaults: defaults)
    }

    var uuid: String { sensor.luid!.value }
    func clean() {
        defaults.removePersistentDomain(forName: suite)
        UserDefaults.standard.removeObject(forKey: sensor.luid!.value)
        UserDefaults.standard.removeObject(forKey: sensor.macId!.value)
        settings.limitAlertNotificationsEnabled = saved.limited
        settings.alertsMuteIntervalMinutes = saved.minutes
        settings.alertSound = saved.sound
        settings.setNotificationsBadgeCount(value: saved.badge)
    }
}

final class NotificationCenterSpy: LocalNotificationCenter {
    weak var delegate: UNUserNotificationCenterDelegate?
    var categories: Set<UNNotificationCategory> = []
    var requests: [UNNotificationRequest] = []
    var badges: [Int] = []
    var pendingRemovals: [String] = []
    var deliveredRemovals: [String] = []
    var onAdd: (() -> Void)?
    var onBadge: (() -> Void)?
    var failAdd = false
    var beforeAdd: (() async -> Void)?
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) { self.categories = categories }
    func add(_ request: UNNotificationRequest) async throws {
        await beforeAdd?()
        if failAdd { onAdd?(); throw NSError(domain: "test-center", code: 1) }
        requests.append(request)
        onAdd?()
    }
    func setBadgeCount(_ count: Int) { badges.append(count); onBadge?() }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) { pendingRemovals += identifiers }
    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) { deliveredRemovals += identifiers }
}

final class NotificationOutputSpy: RuuviNotificationLocalOutput {
    var identifiers: [String] = []
    func notificationDidTap(for uuid: String) { identifiers.append(uuid) }
}
