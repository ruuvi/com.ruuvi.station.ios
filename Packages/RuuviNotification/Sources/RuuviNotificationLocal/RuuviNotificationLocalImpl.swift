import Foundation
import RuuviLocal
import RuuviOntology
import RuuviService
import RuuviStorage
import UIKit
// swiftlint:disable file_length
import UserNotifications

protocol UserNotificationCentering: AnyObject {
    var delegate: UNUserNotificationCenterDelegate? { get set }
    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: ((Error?) -> Void)?
    )
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
    func setBadgeCount(_ badgeCount: Int)
}

extension UNUserNotificationCenter: UserNotificationCentering {
    func setBadgeCount(_ badgeCount: Int) {
        if #available(iOS 16.0, *) {
            setBadgeCount(badgeCount, withCompletionHandler: nil)
        }
    }
}

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
    private let userNotificationCenter: UserNotificationCentering
    private let observerCenter: NotificationCenter
    private let badgeUpdater: (Int) -> Void

    private weak var output: RuuviNotificationLocalOutput?

    public convenience init(
        ruuviStorage: RuuviStorage,
        idPersistence: RuuviLocalIDs,
        settings: RuuviLocalSettings,
        ruuviAlertService: RuuviServiceAlert
    ) {
        self.init(
            ruuviStorage: ruuviStorage,
            idPersistence: idPersistence,
            settings: settings,
            ruuviAlertService: ruuviAlertService,
            userNotificationCenter: UNUserNotificationCenter.current(),
            observerCenter: .default,
            badgeUpdater: { UIApplication.shared.applicationIconBadgeNumber = $0 }
        )
    }

    init(
        ruuviStorage: RuuviStorage,
        idPersistence: RuuviLocalIDs,
        settings: RuuviLocalSettings,
        ruuviAlertService: RuuviServiceAlert,
        userNotificationCenter: UserNotificationCentering,
        observerCenter: NotificationCenter,
        badgeUpdater: @escaping (Int) -> Void
    ) {
        self.ruuviStorage = ruuviStorage
        self.idPersistence = idPersistence
        self.settings = settings
        self.ruuviAlertService = ruuviAlertService
        self.userNotificationCenter = userNotificationCenter
        self.observerCenter = observerCenter
        self.badgeUpdater = badgeUpdater
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
        if let alertDidChangeToken {
            observerCenter.removeObserver(alertDidChangeToken)
        }
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

            sSelf.ruuviTag(for: sSelf.id(for: uuid)) { [weak self] ruuviTag in
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
                sSelf.userNotificationCenter.add(request, withCompletionHandler: nil)
                sSelf.setTriggered(for: Self.alertType(from: .connection), uuid: uuid)
            }
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

            sSelf.ruuviTag(for: sSelf.id(for: uuid)) { [weak self] ruuviTag in
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
                sSelf.userNotificationCenter.add(request, withCompletionHandler: nil)
                sSelf.setTriggered(for: Self.alertType(from: .connection), uuid: uuid)
            }
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

            sSelf.ruuviTag(for: sSelf.id(for: uuid)) { [weak self] ruuviTag in
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
                sSelf.userNotificationCenter.add(request, withCompletionHandler: nil)
                sSelf.setTriggered(for: Self.alertType(from: .movement), uuid: uuid)
            }
        }
    }
}

// MARK: - Notify

public extension RuuviNotificationLocalImpl {

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func notify(
        _ reason: LowHighNotificationReason,
        _ type: AlertType,
        for uuid: String,
        title: String
    ) {
        isMuted(for: type, uuid: uuid) { [weak self] muted in
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
            case .dewPoint:
                sSelf.ruuviAlertService.dewPointDescription(for: uuid) ?? ""
            case .pressure:
                sSelf.ruuviAlertService.pressureDescription(for: uuid) ?? ""
            case .signal:
                sSelf.ruuviAlertService.signalDescription(for: uuid) ?? ""
            case .batteryVoltage:
                sSelf.ruuviAlertService.batteryVoltageDescription(for: uuid) ?? ""
            case .aqi:
                sSelf.ruuviAlertService.aqiDescription(for: uuid) ?? ""
            case .carbonDioxide:
                sSelf.ruuviAlertService.carbonDioxideDescription(for: uuid) ?? ""
            case .pMatter1:
                sSelf.ruuviAlertService.pm1Description(for: uuid) ?? ""
            case .pMatter25:
                sSelf.ruuviAlertService.pm25Description(for: uuid) ?? ""
            case .pMatter4:
                sSelf.ruuviAlertService.pm4Description(for: uuid) ?? ""
            case .pMatter10:
                sSelf.ruuviAlertService.pm10Description(for: uuid) ?? ""
            case .voc:
                sSelf.ruuviAlertService.vocDescription(for: uuid) ?? ""
            case .nox:
                sSelf.ruuviAlertService.noxDescription(for: uuid) ?? ""
            case .soundInstant:
                sSelf.ruuviAlertService.soundInstantDescription(for: uuid) ?? ""
            case .soundAverage:
                sSelf.ruuviAlertService.soundAverageDescription(for: uuid) ?? ""
            case .soundPeak:
                sSelf.ruuviAlertService.soundPeakDescription(for: uuid) ?? ""
            case .luminosity:
                sSelf.ruuviAlertService.luminosityDescription(for: uuid) ?? ""
            default:
                ""
            }
            content.body = body

            sSelf.ruuviTag(for: sSelf.id(for: uuid)) { [weak self] ruuviTag in
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
                self?.userNotificationCenter.add(request, withCompletionHandler: nil)
                self?.setTriggered(for: type, uuid: uuid)
            }
        }
    }
}

// MARK: - Private

extension RuuviNotificationLocalImpl {

    private static func alertType(from type: BlastNotificationType) -> AlertType {
        switch type {
        case .connection:
            .connection
        case .movement:
            .movement(last: 0)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func startObserving() {
        alertDidChangeToken = observerCenter
            .addObserver(
                forName: .RuuviServiceAlertDidChange,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard
                    let userInfo = notification.userInfo,
                    let type = userInfo[RuuviServiceAlertDidChangeKey.type] as? AlertType,
                    let physicalSensor = userInfo[RuuviServiceAlertDidChangeKey.physicalSensor] as? PhysicalSensor,
                    let uuid = physicalSensor.luid?.value ?? physicalSensor.macId?.value
                else {
                    return
                }

                let isOn = self?.ruuviAlertService.isOn(type: type, for: physicalSensor) ?? false
                guard !isOn else { return }

                switch type {
                case .temperature:
                    self?.cancel(.temperature(lower: 0, upper: 0), for: uuid)
                case .relativeHumidity:
                    self?.cancel(.relativeHumidity(lower: 0, upper: 0), for: uuid)
                case .humidity:
                    self?.cancel(
                        .humidity(lower: .zeroAbsolute, upper: .zeroAbsolute),
                        for: uuid
                    )
                case .dewPoint:
                    self?.cancel(.dewPoint(lower: 0, upper: 0), for: uuid)
                case .pressure:
                    self?.cancel(.pressure(lower: 0, upper: 0), for: uuid)
                case .signal:
                    self?.cancel(.signal(lower: 0, upper: 0), for: uuid)
                case .batteryVoltage:
                    self?.cancel(.batteryVoltage(lower: 0, upper: 0), for: uuid)
                case .carbonDioxide:
                    self?.cancel(.carbonDioxide(lower: 0, upper: 0), for: uuid)
                case .aqi:
                    self?.cancel(.aqi(lower: 0, upper: 0), for: uuid)
                case .pMatter1:
                    self?.cancel(.pMatter1(lower: 0, upper: 0), for: uuid)
                case .pMatter25:
                    self?.cancel(.pMatter25(lower: 0, upper: 0), for: uuid)
                case .pMatter4:
                    self?.cancel(.pMatter4(lower: 0, upper: 0), for: uuid)
                case .pMatter10:
                    self?.cancel(.pMatter10(lower: 0, upper: 0), for: uuid)
                case .voc:
                    self?.cancel(.voc(lower: 0, upper: 0), for: uuid)
                case .nox:
                    self?.cancel(.nox(lower: 0, upper: 0), for: uuid)
                case .soundInstant:
                    self?.cancel(.soundInstant(lower: 0, upper: 0), for: uuid)
                case .soundAverage:
                    self?.cancel(.soundAverage(lower: 0, upper: 0), for: uuid)
                case .soundPeak:
                    self?.cancel(.soundPeak(lower: 0, upper: 0), for: uuid)
                case .luminosity:
                    self?.cancel(.luminosity(lower: 0, upper: 0), for: uuid)
                case .connection, .cloudConnection, .movement:
                    break
                }
            }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension RuuviNotificationLocalImpl: UNUserNotificationCenterDelegate {
    private func setupButtons(disableTitle: String, muteTitle: String) {
        let nc = userNotificationCenter
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
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler(
            presentationOptions(forCategoryIdentifier: notification.request.content.categoryIdentifier)
        )
    }

    // swiftlint:disable:next function_body_length
    public func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleNotificationResponse(
            userInfo: response.notification.request.content.userInfo,
            actionIdentifier: response.actionIdentifier
        )
        completionHandler()
    }

    func presentationOptions(forCategoryIdentifier category: String) -> UNNotificationPresentationOptions {
        let isAlertCategory = category == lowHigh.id || category == blast.id
        if !settings.limitAlertNotificationsEnabled, isAlertCategory {
            return [.list, .badge]
        } else {
            return [.banner, .list, .badge, .sound]
        }
    }

    func handleNotificationResponse(
        userInfo: [AnyHashable: Any],
        actionIdentifier: String
    ) {
        if let uuid = userInfo[lowHigh.uuidKey] as? String,
           let typeString = userInfo[lowHigh.typeKey] as? String,
           let type = AlertType.alertType(from: typeString) {
            switch actionIdentifier {
            case lowHigh.disable:
                unregister(type: type, uuid: uuid)
            case lowHigh.mute:
                mute(type: type, uuid: uuid)
            default:
                break
            }
        } else if let uuid = userInfo[blast.uuidKey] as? String,
                  let typeString = userInfo[blast.typeKey] as? String,
                  let type = BlastNotificationType(rawValue: typeString) {
            switch actionIdentifier {
            case blast.disable:
                unregister(type: Self.alertType(from: type), uuid: uuid)
            case blast.mute:
                mute(type: type, uuid: uuid)
            default:
                break
            }
        }

        if let uuid = userInfo[lowHigh.uuidKey] as? String
            ?? userInfo[blast.uuidKey] as? String {
            observerCenter.post(
                name: .LNMDidReceive,
                object: nil,
                userInfo: [LNMDidReceiveKey.uuid: uuid]
            )
            output?.notificationDidTap(for: uuid)
        }

        if let macId = userInfo["id"] as? String {
            output?.notificationDidTap(for: macId)
        }
    }

    private func unregister(type: AlertType, uuid: String) {
        ruuviTag(for: uuid) { [weak self] ruuviTag in
            self?.ruuviAlertService.unregister(type: type, ruuviTag: ruuviTag)
        }
    }

    private func cancel(_ type: AlertType, for uuid: String) {
        userNotificationCenter.removePendingNotificationRequests(withIdentifiers: [uuid + type.rawValue])
        userNotificationCenter.removeDeliveredNotifications(withIdentifiers: [uuid + type.rawValue])
    }

    private func mute(type: AlertType, uuid: String) {
        let date = muteOffset()
        ruuviTag(for: uuid) { [weak self] ruuviTag in
            self?.ruuviAlertService.mute(
                type: type,
                for: ruuviTag,
                till: date
            )
        }
    }

    private func mute(type: BlastNotificationType, uuid: String) {
        let date = muteOffset()
        ruuviTag(for: uuid) { [weak self] ruuviTag in
            self?.ruuviAlertService.mute(
                type: Self.alertType(from: type),
                for: ruuviTag,
                till: date
            )
        }
    }

    private func muteOffset() -> Date {
        Date().addingTimeInterval(TimeInterval(settings.alertsMuteIntervalMinutes * 60))
    }

    private func isMuted(
        for type: AlertType,
        uuid: String,
        completion: @escaping (Bool) -> Void
    ) {
        ruuviTag(for: uuid) { [weak self] ruuviTag in
            guard let self = self else { return }
            if let triggeredAt = self.ruuviAlertService.triggeredAt(for: ruuviTag, of: type),
               let date = self.dateFormatter.date(from: triggeredAt) {
                let intervalPassed = !self.settings.limitAlertNotificationsEnabled
                    || Date() > self.muteOffset(from: date)
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
        }
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
        ruuviTag(for: uuid) { [weak self] ruuviTag in
            guard let sSelf = self else { return }
            sSelf.ruuviAlertService.trigger(
                type: type,
                trigerred: true,
                trigerredAt: sSelf.dateFormatter.string(from: Date()),
                for: ruuviTag
            )
        }
    }

    /// Limit alert notification settings prevents new alerts within one hour
    /// of last one. When the setting is off, alerts are not time-throttled here.
    private func muteOffset(from shown: Date) -> Date {
        shown.addingTimeInterval(TimeInterval(settings.alertsMuteIntervalMinutes * 60))
    }

    private func setAlertBadge(for content: UNMutableNotificationContent) {
        let currentCount = settings.notificationsBadgeCount()
        let newBadgeCount = currentCount + 1
        content.badge = newBadgeCount as NSNumber
        settings.setNotificationsBadgeCount(value: newBadgeCount)

        if #available(iOS 16.0, *) {
            userNotificationCenter.setBadgeCount(newBadgeCount)
        } else {
            badgeUpdater(newBadgeCount)
        }
    }

    private func ruuviTag(
        for uuid: String,
        completion: @escaping (AnyRuuviTagSensor) -> Void
    ) {
        Task {
            if let ruuviTag = try? await ruuviStorage.readOne(uuid) {
                completion(ruuviTag)
            }
        }
    }
}

// swiftlint:enable file_length
