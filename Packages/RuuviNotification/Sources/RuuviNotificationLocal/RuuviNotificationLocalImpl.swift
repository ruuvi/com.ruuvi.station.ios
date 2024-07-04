import Foundation
import RuuviLocal
import RuuviOntology
import RuuviService
import RuuviStorage
import UIKit
// swiftlint:disable file_length
import UserNotifications

struct LocalAlertCategory {
    var id: String
    var disable: String
    var mute: String
    var uuidKey: String
    var typeKey: String
}

enum BlastNotificationType: String {
    case connection
    case movement
}

public final class RuuviNotificationLocalImpl: NSObject, RuuviNotificationLocal {
    private let ruuviStorage: RuuviStorage
    private let idPersistence: RuuviLocalIDs
    private let settings: RuuviLocalSettings
    private let ruuviAlertService: RuuviServiceAlert

    private weak var output: RuuviNotificationLocalOutput?

    public init(
        ruuviStorage: RuuviStorage,
        idPersistence: RuuviLocalIDs,
        settings: RuuviLocalSettings,
        ruuviAlertService: RuuviServiceAlert
    ) {
        self.ruuviStorage = ruuviStorage
        self.idPersistence = idPersistence
        self.settings = settings
        self.ruuviAlertService = ruuviAlertService
    }

    private let lowHigh = LocalAlertCategory(
        id: "com.ruuvi.station.alerts.lh",
        disable: "com.ruuvi.station.alerts.lh.disable",
        mute: "com.ruuvi.station.alerts.lh.mute",
        uuidKey: "com.ruuvi.station.alerts.lh.uuid",
        typeKey: "com.ruuvi.station.alerts.lh.type"
    )
    private let blast = LocalAlertCategory(
        id: "com.ruuvi.station.alerts.blast",
        disable: "com.ruuvi.station.alerts.blast.disable",
        mute: "com.ruuvi.station.alerts.blast.mute",
        uuidKey: "com.ruuvi.station.alerts.blast.uuid",
        typeKey: "com.ruuvi.station.alerts.blast.type"
    )

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale.autoupdatingCurrent
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return df
    }()

    private var alertDidChangeToken: NSObjectProtocol?

    public func setup(
        disableTitle: String,
        muteTitle: String,
        output: RuuviNotificationLocalOutput?
    ) {
        setupButtons(disableTitle: disableTitle, muteTitle: muteTitle)
        startObserving()
        self.output = output
    }

    deinit {
        alertDidChangeToken?.invalidate()
    }

    private func id(for uuid: String) -> String {
        idPersistence.mac(for: uuid.luid)?.value ?? uuid
    }

    public func showDidConnect(uuid: String, title: String) {
        isMuted(for: .connection, uuid: uuid) { [weak self] muted in
            guard !muted else { return }
            guard let sSelf = self else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            switch sSelf.settings.alertSound {
            case .systemDefault:
                content.sound = .default
            default:
                content.sound = UNNotificationSound(
                    named: UNNotificationSoundName(
                        rawValue: sSelf.settings.alertSound.rawValue
                    )
                )
            }
            content.userInfo = [
                sSelf.blast.uuidKey: uuid,
                sSelf.blast.typeKey: BlastNotificationType.connection.rawValue,
            ]
            content.categoryIdentifier = sSelf.blast.id
            sSelf.setAlertBadge(for: content)

            sSelf.ruuviStorage.readOne(sSelf.id(for: uuid)).on(success: { [weak self] ruuviTag in
                guard let sSelf = self else { return }
                content.subtitle = ruuviTag.name
                content.body = sSelf.ruuviAlertService.connectionDescription(for: uuid) ?? ""
                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: 0.1,
                    repeats: false
                )
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: trigger
                )
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                sSelf.setTriggered(for: Self.alertType(from: .connection), uuid: uuid)
            })
        }
    }

    public func showDidDisconnect(uuid: String, title: String) {
        isMuted(for: .connection, uuid: uuid) { [weak self] muted in
            guard !muted else { return }

            guard let sSelf = self else { return }
            let content = UNMutableNotificationContent()
            switch sSelf.settings.alertSound {
            case .systemDefault:
                content.sound = .default
            default:
                content.sound = UNNotificationSound(
                    named: UNNotificationSoundName(
                        rawValue: sSelf.settings.alertSound.rawValue
                    )
                )
            }
            content.userInfo = [
                sSelf.blast.uuidKey: uuid,
                sSelf.blast.typeKey: BlastNotificationType.connection.rawValue,
            ]
            content.categoryIdentifier = sSelf.blast.id
            content.title = title
            sSelf.setAlertBadge(for: content)

            sSelf.ruuviStorage.readOne(sSelf.id(for: uuid)).on(success: { [weak self] ruuviTag in
                guard let sSelf = self else { return }
                content.subtitle = ruuviTag.name
                content.body = sSelf.ruuviAlertService.connectionDescription(for: uuid) ?? ""
                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: 0.1,
                    repeats: false
                )
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: trigger
                )
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                sSelf.setTriggered(for: Self.alertType(from: .connection), uuid: uuid)
            })
        }
    }

    public func notifyDidMove(for uuid: String, counter _: Int, title: String) {
        isMuted(for: .movement(last: 0), uuid: uuid) { [weak self] muted in
            guard !muted else { return }

            guard let sSelf = self else { return }

            let content = UNMutableNotificationContent()
            switch sSelf.settings.alertSound {
            case .systemDefault:
                content.sound = .default
            default:
                content.sound = UNNotificationSound(
                    named: UNNotificationSoundName(rawValue: sSelf.settings.alertSound.rawValue)
                )
            }
            content.userInfo = [
                sSelf.blast.uuidKey: uuid,
                sSelf.blast.typeKey: BlastNotificationType.movement.rawValue,
            ]
            content.categoryIdentifier = sSelf.blast.id
            sSelf.setAlertBadge(for: content)

            content.title = title

            sSelf.ruuviStorage.readOne(sSelf.id(for: uuid)).on(success: { [weak self] ruuviTag in
                guard let sSelf = self else { return }
                content.subtitle = ruuviTag.name
                content.body = sSelf.ruuviAlertService.movementDescription(for: uuid) ?? ""
                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: 0.1,
                    repeats: false
                )
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: trigger
                )
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                sSelf.setTriggered(for: Self.alertType(from: .movement), uuid: uuid)
            })
        }
    }
}

// MARK: - Notify

public extension RuuviNotificationLocalImpl {

    func notify(
        _ reason: LowHighNotificationReason,
        _ type: LowHighNotificationType,
        for uuid: String,
        title: String
    ) {
        isMuted(for: Self.alertType(from: type), uuid: uuid) { [weak self] muted in
            guard !muted else { return }
            guard let sSelf = self else { return }

            let content = UNMutableNotificationContent()
            switch sSelf.settings.alertSound {
            case .systemDefault:
                content.sound = .default
            default:
                content.sound = UNNotificationSound(
                    named: UNNotificationSoundName(
                        rawValue: sSelf.settings.alertSound.rawValue
                    )
                )
            }
            content.title = title
            content.userInfo = [
                sSelf.lowHigh.uuidKey: uuid,
                sSelf.lowHigh.typeKey: type.rawValue,
            ]
            content.categoryIdentifier = sSelf.lowHigh.id
            sSelf.setAlertBadge(for: content)

            let body: String = switch type {
            case .temperature:
                sSelf.ruuviAlertService.temperatureDescription(for: uuid) ?? ""
            case .relativeHumidity:
                sSelf.ruuviAlertService.relativeHumidityDescription(for: uuid) ?? ""
            case .humidity:
                sSelf.ruuviAlertService.humidityDescription(for: uuid) ?? ""
            case .pressure:
                sSelf.ruuviAlertService.pressureDescription(for: uuid) ?? ""
            case .signal:
                sSelf.ruuviAlertService.signalDescription(for: uuid) ?? ""
            }
            content.body = body

            sSelf.ruuviStorage.readOne(sSelf.id(for: uuid)).on(success: { [weak self] ruuviTag in
                content.subtitle = ruuviTag.name
                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: 0.1,
                    repeats: false
                )
                let request = UNNotificationRequest(
                    identifier: uuid + type.rawValue,
                    content: content,
                    trigger: trigger
                )
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                self?.setTriggered(for: Self.alertType(from: type), uuid: uuid)
            })
        }
    }
}

// MARK: - Private

extension RuuviNotificationLocalImpl {
    private static func alertType(from type: LowHighNotificationType) -> AlertType {
        switch type {
        case .temperature:
            .temperature(lower: 0, upper: 0)
        case .relativeHumidity:
            .relativeHumidity(lower: 0, upper: 0)
        case .humidity:
            .humidity(
                lower: Humidity(value: 0, unit: .absolute),
                upper: Humidity(value: 0, unit: .absolute)
            )
        case .pressure:
            .pressure(lower: 0, upper: 0)
        case .signal:
            .signal(lower: 0, upper: 0)
        }
    }

    private static func alertType(from type: BlastNotificationType) -> AlertType {
        switch type {
        case .connection:
            .connection
        case .movement:
            .movement(last: 0)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func startObserving() {
        alertDidChangeToken = NotificationCenter
            .default
            .addObserver(
                forName: .RuuviServiceAlertDidChange,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let type = userInfo[RuuviServiceAlertDidChangeKey.type] as? AlertType {
                    let physicalSensor = userInfo[RuuviServiceAlertDidChangeKey.physicalSensor] as? PhysicalSensor

                    var isOn = false
                    if let physicalSensor {
                        isOn = self?.ruuviAlertService.isOn(type: type, for: physicalSensor) ?? false
                    }

                    if let uuid = physicalSensor?.luid?.value ?? physicalSensor?.macId?.value {
                        switch type {
                        case .temperature:
                            if !isOn {
                                self?.cancel(.temperature, for: uuid)
                            }
                        case .relativeHumidity:
                            if !isOn {
                                self?.cancel(.relativeHumidity, for: uuid)
                            }
                        case .humidity:
                            if !isOn {
                                self?.cancel(.humidity, for: uuid)
                            }
                        case .pressure:
                            if !isOn {
                                self?.cancel(.pressure, for: uuid)
                            }
                        case .signal:
                            if !isOn {
                                self?.cancel(.signal, for: uuid)
                            }
                        case .connection, .cloudConnection, .movement:
                            // do nothing
                            break
                        }
                    }
                }
            }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension RuuviNotificationLocalImpl: UNUserNotificationCenterDelegate {
    private func setupButtons(disableTitle: String, muteTitle: String) {
        let nc = UNUserNotificationCenter.current()
        nc.delegate = self

        // alerts actions and categories
        let disableLowHighAction = UNNotificationAction(
            identifier: lowHigh.disable,
            title: disableTitle,
            options: UNNotificationActionOptions(rawValue: 0)
        )
        let muteLowHighAction = UNNotificationAction(
            identifier: lowHigh.mute,
            title: muteTitle,
            options: UNNotificationActionOptions(rawValue: 0)
        )
        let lowHighCategory = UNNotificationCategory(
            identifier: lowHigh.id,
            actions: [muteLowHighAction, disableLowHighAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        let disableBlastAction = UNNotificationAction(
            identifier: blast.disable,
            title: disableTitle,
            options: UNNotificationActionOptions(rawValue: 0)
        )
        let muteBlastAction = UNNotificationAction(
            identifier: blast.mute,
            title: muteTitle,
            options: UNNotificationActionOptions(rawValue: 0)
        )
        let blastCategory = UNNotificationCategory(
            identifier: blast.id,
            actions: [muteBlastAction, disableBlastAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        nc.setNotificationCategories([lowHighCategory, blastCategory])
    }

    public func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .badge, .sound])
    }

    // swiftlint:disable:next function_body_length
    public func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let uuid = userInfo[lowHigh.uuidKey] as? String,
           let typeString = userInfo[lowHigh.typeKey] as? String,
           let type = LowHighNotificationType(rawValue: typeString) {
            switch response.actionIdentifier {
            case lowHigh.disable:
                // TODO: @rinat go with sensors instead of pure uuid
                let ruuviTag = RuuviTagSensorStruct(
                    version: 5,
                    firmwareVersion: nil,
                    luid: uuid.luid,
                    macId: uuid.mac,
                    isConnectable: true,
                    name: "",
                    isClaimed: false,
                    isOwner: false,
                    owner: nil,
                    ownersPlan: nil,
                    isCloudSensor: false,
                    canShare: false,
                    sharedTo: [],
                    maxHistoryDays: nil
                )
                ruuviAlertService.unregister(type: Self.alertType(from: type), ruuviTag: ruuviTag)
            case lowHigh.mute:
                mute(type: type, uuid: uuid)
            default:
                break
            }
        } else if let uuid = userInfo[blast.uuidKey] as? String,
                  let typeString = userInfo[blast.typeKey] as? String,
                  let type = BlastNotificationType(rawValue: typeString) {
            switch response.actionIdentifier {
            case blast.disable:
                // TODO: @rinat go with sensors instead of pure uuid
                let ruuviTag = RuuviTagSensorStruct(
                    version: 5,
                    firmwareVersion: nil,
                    luid: uuid.luid,
                    macId: uuid.mac,
                    isConnectable: true,
                    name: "",
                    isClaimed: false,
                    isOwner: false,
                    owner: nil,
                    ownersPlan: nil,
                    isCloudSensor: false,
                    canShare: false,
                    sharedTo: [],
                    maxHistoryDays: nil
                )
                ruuviAlertService.unregister(type: Self.alertType(from: type), ruuviTag: ruuviTag)
            case blast.mute:
                mute(type: type, uuid: uuid)
            default:
                break
            }
        }

        if let uuid = userInfo[lowHigh.uuidKey] as? String
            ?? userInfo[blast.uuidKey] as? String {
            NotificationCenter.default.post(name: .LNMDidReceive, object: nil, userInfo: [LNMDidReceiveKey.uuid: uuid])
            output?.notificationDidTap(for: uuid)
        }

        // Handle push notification tap
        if let macId = userInfo["id"] as? String {
            output?.notificationDidTap(for: macId)
        }

        completionHandler()
    }

    private func cancel(_ type: LowHighNotificationType, for uuid: String) {
        let nc = UNUserNotificationCenter.current()
        nc.removePendingNotificationRequests(withIdentifiers: [uuid + type.rawValue])
        nc.removeDeliveredNotifications(withIdentifiers: [uuid + type.rawValue])
    }

    private func mute(type: LowHighNotificationType, uuid: String) {
        guard let date = muteOffset()
        else {
            assertionFailure(); return
        }
        ruuviStorage.readOne(uuid).on(success: { [weak self] ruuviTag in
            self?.ruuviAlertService.mute(
                type: Self.alertType(from: type),
                for: ruuviTag,
                till: date
            )
        })
    }

    private func mute(type: BlastNotificationType, uuid: String) {
        guard let date = muteOffset()
        else {
            assertionFailure(); return
        }
        ruuviStorage.readOne(uuid).on(success: { [weak self] ruuviTag in
            self?.ruuviAlertService.mute(
                type: Self.alertType(from: type),
                for: ruuviTag,
                till: date
            )
        })
    }

    private func muteOffset() -> Date? {
        Calendar.current.date(
            byAdding: .minute,
            value: settings.alertsMuteIntervalMinutes,
            to: Date()
        )
    }

    private func isMuted(
        for type: AlertType,
        uuid: String,
        completion: @escaping (Bool) -> Void
    ) {
        ruuviStorage.readOne(uuid).on(success: { [weak self] ruuviTag in
            guard let self = self else { return }
            if let triggeredAt = self.ruuviAlertService.triggeredAt(for: ruuviTag, of: type),
               let date = self.dateFormatter.date(from: triggeredAt) {
                let intervalPassed = Date() > self.muteOffset(from: date)
                self.evaluateMutedState(
                    for: type,
                    uuid: uuid,
                    intervalPassed: intervalPassed,
                    completion: completion
                )
            } else {
                self.evaluateMutedState(
                    for: type,
                    uuid: uuid,
                    intervalPassed: true,
                    completion: completion
                )
            }
        })
    }

    private func evaluateMutedState(
        for type: AlertType, uuid: String,
        intervalPassed: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        if let mutedTill = ruuviAlertService.mutedTill(type: type, for: uuid) {
            completion(!(intervalPassed && mutedTill > Date()))
        } else {
            completion(!intervalPassed)
        }
    }

    private func setTriggered(
        for type: AlertType,
        uuid: String
    ) {
        ruuviStorage.readOne(uuid).on(success: { [weak self] ruuviTag in
            guard let sSelf = self else { return }
            sSelf.ruuviAlertService.trigger(
                type: type,
                trigerred: true,
                trigerredAt: sSelf.dateFormatter.string(from: Date()),
                for: ruuviTag
            )
        })
    }

    /// Limit alert notification settings prevents new alerts within one hour
    /// of last one. When the settings is off we still will prevent new notifications
    /// based on save heartbeats background interval minutes (5mins).
    /// When app is in foreground we save heartbeats every 2 seconds, but that's not
    /// very user friendly to trigger notifications as that frequent alerts basically
    /// makes app unusable by spamming. Besides, if user is in foreground they will
    /// see the alert bells anyway.
    private func muteOffset(from shown: Date) -> Date {
        Calendar.current.date(
            byAdding: .minute,
            value: settings.limitAlertNotificationsEnabled ?
                settings.alertsMuteIntervalMinutes : settings.saveHeartbeatsIntervalMinutes,
            to: shown
        ) ?? Date()
    }

    private func setAlertBadge(for content: UNMutableNotificationContent) {
        let currentCount = settings.notificationsBadgeCount()
        let newBadgeCount = currentCount + 1
        content.badge = newBadgeCount as NSNumber
        settings.setNotificationsBadgeCount(value: newBadgeCount)
    }

    private func ruuviTag(
        for uuid: String,
        completion: @escaping(AnyRuuviTagSensor) -> Void
    ) {
        ruuviStorage.readOne(uuid).on(success: completion)
    }
}

extension NSObjectProtocol {
    func invalidate() {
        // swiftlint:disable:next notification_center_detachment
        NotificationCenter
            .default
            .removeObserver(self)
    }
}

// swiftlint:enable file_length
