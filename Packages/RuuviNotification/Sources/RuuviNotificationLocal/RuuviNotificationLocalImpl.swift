#if SWIFT_PACKAGE
    import RuuviNotification
#endif
import Foundation
import RuuviLocal
import RuuviOntology
import RuuviService
import RuuviStorage
import UserNotifications

private struct LocalAlertCategory {
    let id: String
    let disable: String
    let mute: String
    let uuidKey: String
    let typeKey: String

    init(_ suffix: String) {
        id = "com.ruuvi.station.alerts." + suffix
        disable = id + ".disable"
        mute = id + ".mute"
        uuidKey = id + ".uuid"
        typeKey = id + ".type"
    }
}

public final class RuuviNotificationLocalImpl: NSObject, RuuviNotificationLocal {
    private let readSensor: (String) async throws -> AnyRuuviTagSensor
    private let idPersistence: RuuviLocalIDs
    private let settings: RuuviLocalSettings
    private let ruuviAlertService: RuuviServiceAlert
    private let center: LocalNotificationCenter
    private let now: () -> Date
    private weak var output: RuuviNotificationLocalOutput?
    private let lowHigh = LocalAlertCategory("lh")
    private let blast = LocalAlertCategory("blast")
    private var alertDidChangeToken: NSObjectProtocol?
    @MainActor private var deliveryTask: Task<Void, Never>?

    public convenience init(
        ruuviStorage: RuuviStorage,
        idPersistence: RuuviLocalIDs,
        settings: RuuviLocalSettings,
        ruuviAlertService: RuuviServiceAlert
    ) {
        self.init(
            readSensor: { try await ruuviStorage.readOne($0) }, idPersistence: idPersistence,
            settings: settings, ruuviAlertService: ruuviAlertService,
            center: SystemLocalNotificationCenter(), now: Date.init)
    }

    init(
        readSensor: @escaping (String) async throws -> AnyRuuviTagSensor,
        idPersistence: RuuviLocalIDs, settings: RuuviLocalSettings,
        ruuviAlertService: RuuviServiceAlert, center: LocalNotificationCenter,
        now: @escaping () -> Date
    ) {
        self.readSensor = readSensor
        self.idPersistence = idPersistence
        self.settings = settings
        self.ruuviAlertService = ruuviAlertService
        self.center = center
        self.now = now
    }

    deinit {
        if let alertDidChangeToken { NotificationCenter.default.removeObserver(alertDidChangeToken) }
    }

    public func setup(disableTitle: String, muteTitle: String, output: RuuviNotificationLocalOutput?) {
        self.output = output
        center.delegate = self
        let categories = [lowHigh, blast].map { category in
            UNNotificationCategory(
                identifier: category.id,
                actions: [
                    UNNotificationAction(identifier: category.mute, title: muteTitle, options: []),
                    UNNotificationAction(identifier: category.disable, title: disableTitle, options: []),
                ], intentIdentifiers: [], options: .customDismissAction)
        }
        center.setNotificationCategories(Set(categories))
        if let alertDidChangeToken { NotificationCenter.default.removeObserver(alertDidChangeToken) }
        alertDidChangeToken = NotificationCenter.default.addObserver(
            forName: .RuuviServiceAlertDidChange, object: nil, queue: .main
        ) { [weak self] notification in
            guard let self, let info = notification.userInfo,
                let type = info[RuuviServiceAlertDidChangeKey.type] as? AlertType,
                let sensor = info[RuuviServiceAlertDidChangeKey.physicalSensor] as? PhysicalSensor,
                let uuid = sensor.luid?.value ?? sensor.macId?.value,
                !ruuviAlertService.isOn(type: type, for: sensor)
            else { return }
            switch type {
            case .connection, .cloudConnection, .movement: break
            default:
                let identifiers = [uuid + type.rawValue]
                center.removePendingNotificationRequests(withIdentifiers: identifiers)
                center.removeDeliveredNotifications(withIdentifiers: identifiers)
            }
        }
    }

    public func showDidConnect(uuid: String, title: String) {
        enqueue(type: .connection, uuid: uuid, title: title, isBlast: true)
    }

    public func showDidDisconnect(uuid: String, title: String) {
        enqueue(type: .connection, uuid: uuid, title: title, isBlast: true)
    }

    public func notifyDidMove(for uuid: String, counter: Int, title: String) {
        enqueue(type: .movement(last: counter), uuid: uuid, title: title, isBlast: true)
    }

    public func notify(_ reason: LowHighNotificationReason, _ type: AlertType, for uuid: String, title: String) {
        enqueue(type: type, uuid: uuid, title: title, isBlast: false)
    }

    private func enqueue(type: AlertType, uuid: String, title: String, isBlast: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let previous = deliveryTask
            deliveryTask = Task { @MainActor [weak self] in
                await previous?.value
                await self?.deliver(type: type, uuid: uuid, title: title, isBlast: isBlast)
            }
        }
    }

    /// A single queue keeps throttle state and badge numbers consistent when several readings arrive together.
    @MainActor private func deliver(type: AlertType, uuid: String, title: String, isBlast: Bool) async {
        do {
            let storageID = idPersistence.mac(for: uuid.luid)?.value ?? uuid
            let sensor = try await readSensor(storageID)
            guard !isMuted(type: type, sensor: sensor, uuid: uuid) else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.subtitle = sensor.name
            content.body = description(for: type, uuid: uuid)
            content.sound =
                settings.alertSound == .systemDefault
                ? .default : UNNotificationSound(named: UNNotificationSoundName(rawValue: settings.alertSound.rawValue))
            let category = isBlast ? blast : lowHigh
            content.categoryIdentifier = category.id
            content.userInfo = [category.uuidKey: uuid, category.typeKey: type.rawValue]
            let previousBadge = max(0, settings.notificationsBadgeCount())
            let nextBadge = previousBadge == Int.max ? Int.max : previousBadge + 1
            content.badge = NSNumber(value: nextBadge)
            let request = UNNotificationRequest(
                identifier: isBlast ? UUID().uuidString : uuid + type.rawValue,
                content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false))
            try await center.add(request)
            // Failed delivery must not consume a badge or suppress the next attempt.
            settings.setNotificationsBadgeCount(value: nextBadge)
            center.setBadgeCount(nextBadge)
            ruuviAlertService.trigger(
                type: type, trigerred: true,
                trigerredAt: Self.timestamp(now()), for: sensor)
            debugLog("Scheduled \(type.rawValue) for \(uuid)")
        } catch {
            debugLog("Notification failed for \(uuid): \(error)")
        }
    }

    private func isMuted(type: AlertType, sensor: AnyRuuviTagSensor, uuid: String) -> Bool {
        let current = now()
        if let mutedUntil = ruuviAlertService.mutedTill(type: type, for: uuid), mutedUntil > current {
            return true
        }
        guard settings.limitAlertNotificationsEnabled,
            let timestamp = ruuviAlertService.triggeredAt(for: sensor, of: type),
            let lastTriggered = Self.date(from: timestamp)
        else { return false }
        return current < lastTriggered.addingTimeInterval(Double(settings.alertsMuteIntervalMinutes) * 60)
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func date(from timestamp: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: timestamp) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: timestamp)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func description(for type: AlertType, uuid: String) -> String {
        switch type {
        case .temperature:
            ruuviAlertService.temperatureDescription(for: uuid) ?? ""
        case .relativeHumidity:
            ruuviAlertService.relativeHumidityDescription(for: uuid) ?? ""
        case .humidity:
            ruuviAlertService.humidityDescription(for: uuid) ?? ""
        case .dewPoint:
            ruuviAlertService.dewPointDescription(for: uuid) ?? ""
        case .pressure:
            ruuviAlertService.pressureDescription(for: uuid) ?? ""
        case .signal:
            ruuviAlertService.signalDescription(for: uuid) ?? ""
        case .batteryVoltage:
            ruuviAlertService.batteryVoltageDescription(for: uuid) ?? ""
        case .aqi:
            ruuviAlertService.aqiDescription(for: uuid) ?? ""
        case .carbonDioxide:
            ruuviAlertService.carbonDioxideDescription(for: uuid) ?? ""
        case .pMatter1:
            ruuviAlertService.pm1Description(for: uuid) ?? ""
        case .pMatter25:
            ruuviAlertService.pm25Description(for: uuid) ?? ""
        case .pMatter4:
            ruuviAlertService.pm4Description(for: uuid) ?? ""
        case .pMatter10:
            ruuviAlertService.pm10Description(for: uuid) ?? ""
        case .voc:
            ruuviAlertService.vocDescription(for: uuid) ?? ""
        case .nox:
            ruuviAlertService.noxDescription(for: uuid) ?? ""
        case .soundInstant:
            ruuviAlertService.soundInstantDescription(for: uuid) ?? ""
        case .soundAverage:
            ruuviAlertService.soundAverageDescription(for: uuid) ?? ""
        case .soundPeak:
            ruuviAlertService.soundPeakDescription(for: uuid) ?? ""
        case .luminosity:
            ruuviAlertService.luminosityDescription(for: uuid) ?? ""
        case .connection:
            ruuviAlertService.connectionDescription(for: uuid) ?? ""
        case .movement:
            ruuviAlertService.movementDescription(for: uuid) ?? ""
        case .cloudConnection:
            ""
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG || ALPHA
            RuuviAlertDebugLog.append("AlertNotification", message)
        #endif
    }
}

extension RuuviNotificationLocalImpl: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(
        _: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler(presentationOptions(for: notification.request.content.categoryIdentifier))
    }

    func presentationOptions(for category: String) -> UNNotificationPresentationOptions {
        if !settings.limitAlertNotificationsEnabled, category == lowHigh.id || category == blast.id {
            return [.list, .badge]
        }
        return [.banner, .list, .badge, .sound]
    }

    public func userNotificationCenter(
        _: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handle(
            action: response.actionIdentifier, userInfo: response.notification.request.content.userInfo,
            completion: completionHandler)
    }

    func handle(action: String, userInfo: [AnyHashable: Any], completion: @escaping () -> Void) {
        var alert: (type: AlertType, uuid: String, disable: Bool)?
        for category in [lowHigh, blast] {
            guard let uuid = userInfo[category.uuidKey] as? String else { continue }
            if let rawType = userInfo[category.typeKey] as? String,
                let type = AlertType.alertType(from: rawType),
                action == category.disable || action == category.mute
            {
                alert = (type, uuid, action == category.disable)
            }
            NotificationCenter.default.post(name: .LNMDidReceive, object: nil, userInfo: [LNMDidReceiveKey.uuid: uuid])
            output?.notificationDidTap(for: uuid)
        }
        if let mac = userInfo["id"] as? String { output?.notificationDidTap(for: mac) }
        guard let alert else { completion(); return }
        Task { @MainActor [self] in
            defer { completion() }
            do {
                let storageID = idPersistence.mac(for: alert.uuid.luid)?.value ?? alert.uuid
                let sensor = try await readSensor(storageID)
                if alert.disable {
                    if let configured = ruuviAlertService.alert(for: sensor, of: alert.type) {
                        ruuviAlertService.unregister(type: configured, ruuviTag: sensor)
                    }
                } else {
                    ruuviAlertService.mute(
                        type: alert.type, for: sensor,
                        till: now().addingTimeInterval(Double(settings.alertsMuteIntervalMinutes) * 60))
                }
            } catch {
                debugLog("Notification action failed for \(alert.uuid): \(error)")
            }
        }
    }
}
