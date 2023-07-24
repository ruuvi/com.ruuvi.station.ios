// swiftlint:disable file_length
import UserNotifications
import Foundation
import UIKit
import RuuviOntology
import RuuviStorage
import RuuviLocal
import RuuviService
import RuuviVirtual
import RuuviNotification

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
    private let virtualTagTrunk: VirtualStorage
    private let idPersistence: RuuviLocalIDs
    private let settings: RuuviLocalSettings
    private let ruuviAlertService: RuuviServiceAlert

    private weak var output: RuuviNotificationLocalOutput?

    public init(
        ruuviStorage: RuuviStorage,
        virtualTagTrunk: VirtualStorage,
        idPersistence: RuuviLocalIDs,
        settings: RuuviLocalSettings,
        ruuviAlertService: RuuviServiceAlert
    ) {
        self.ruuviStorage = ruuviStorage
        self.virtualTagTrunk = virtualTagTrunk
        self.idPersistence = idPersistence
        self.settings = settings
        self.ruuviAlertService = ruuviAlertService
    }

    var lowTemperatureAlerts = [String: Date]()
    var highTemperatureAlerts = [String: Date]()
    var lowHumidityAlerts = [String: Date]()
    var highHumidityAlerts = [String: Date]()
    var lowRelativeHumidityAlerts = [String: Date]()
    var highRelativeHumidityAlerts = [String: Date]()
    var lowPressureAlerts = [String: Date]()
    var highPressureAlerts = [String: Date]()
    var lowSignalAlerts = [String: Date]()
    var highSignalAlerts = [String: Date]()

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

    private var alertDidChangeToken: NSObjectProtocol?

    public func setup(disableTitle: String,
                      muteTitle: String,
                      output: RuuviNotificationLocalOutput?) {
        setupButtons(disableTitle: disableTitle, muteTitle: muteTitle)
        startObserving()
        self.output = output
    }

    deinit {
        alertDidChangeToken?.invalidate()
    }

    private func id(for uuid: String) -> String {
        var id: String
        if let macId = idPersistence.mac(for: uuid.luid) {
            id = macId.value
        } else {
            id = uuid
        }
        return id
    }

    public func showDidConnect(uuid: String, title: String) {
        if let mutedTill = ruuviAlertService.mutedTill(type: .connection, for: uuid),
           mutedTill > Date() {
            return // muted
        }

        let content = UNMutableNotificationContent()
        content.title = title
        switch settings.alertSound {
        case .systemDefault:
            content.sound = .default
        default:
            content.sound = UNNotificationSound(
                named: UNNotificationSoundName(rawValue: settings.alertSound.rawValue)
            )
        }
        content.userInfo = [blast.uuidKey: uuid, blast.typeKey: BlastNotificationType.connection.rawValue]
        content.categoryIdentifier = blast.id

        ruuviStorage.readOne(id(for: uuid)).on(success: { [weak self] ruuviTag in
            guard let sSelf = self else { return }
            content.subtitle = ruuviTag.name
            content.body = sSelf.ruuviAlertService.connectionDescription(for: uuid) ?? ""
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        })
    }

    public func showDidDisconnect(uuid: String, title: String) {
        if let mutedTill = ruuviAlertService.mutedTill(type: .connection, for: uuid),
           mutedTill > Date() {
            return // muted
        }
        let content = UNMutableNotificationContent()
        switch settings.alertSound {
        case .systemDefault:
            content.sound = .default
        default:
            content.sound = UNNotificationSound(
                named: UNNotificationSoundName(rawValue: settings.alertSound.rawValue)
            )
        }
        content.userInfo = [blast.uuidKey: uuid, blast.typeKey: BlastNotificationType.connection.rawValue]
        content.categoryIdentifier = blast.id
        content.title = title

        ruuviStorage.readOne(id(for: uuid)).on(success: { [weak self] ruuviTag in
            guard let sSelf = self else { return }
            content.subtitle = ruuviTag.name
            content.body = sSelf.ruuviAlertService.connectionDescription(for: uuid) ?? ""
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        })
    }

    public func notifyDidMove(for uuid: String, counter: Int, title: String) {
        if let mutedTill = ruuviAlertService.mutedTill(type: .movement(last: 0), for: uuid),
           mutedTill > Date() {
            return // muted
        }

        let content = UNMutableNotificationContent()
        switch settings.alertSound {
        case .systemDefault:
            content.sound = .default
        default:
            content.sound = UNNotificationSound(
                named: UNNotificationSoundName(rawValue: settings.alertSound.rawValue)
            )
        }
        content.userInfo = [blast.uuidKey: uuid, blast.typeKey: BlastNotificationType.movement.rawValue]
        content.categoryIdentifier = blast.id

        content.title = title

        ruuviStorage.readOne(id(for: uuid)).on(success: { [weak self] ruuviTag in
            guard let sSelf = self else { return }
            content.subtitle = ruuviTag.name
            content.body = sSelf.ruuviAlertService.movementDescription(for: uuid) ?? ""
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        })
    }
}

// MARK: - Notify
extension RuuviNotificationLocalImpl {

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    public func notify(
        _ reason: LowHighNotificationReason,
        _ type: LowHighNotificationType,
        for uuid: String,
        title: String
    ) {
        var needsToShow: Bool
        var cache: [String: Date]
        switch reason {
        case .low:
            switch type {
            case .temperature:
                cache = lowTemperatureAlerts
            case .relativeHumidity:
                cache = lowRelativeHumidityAlerts
            case .humidity:
                cache = lowHumidityAlerts
            case .pressure:
                cache = lowPressureAlerts
            case .signal:
                cache = lowSignalAlerts
            }
        case .high:
            switch type {
            case .temperature:
                cache = highTemperatureAlerts
            case .relativeHumidity:
                cache = highRelativeHumidityAlerts
            case .humidity:
                cache = highHumidityAlerts
            case .pressure:
                cache = highPressureAlerts
            case .signal:
                cache = highSignalAlerts
            }
        }

        if let shownDate = cache[uuid] {
            let intervalPassed = Date().timeIntervalSince(shownDate) >=
                TimeInterval(settings.saveHeartbeatsIntervalMinutes * 60)
            if let mutedTill = ruuviAlertService.mutedTill(type: Self.alertType(from: type), for: uuid) {
                needsToShow = intervalPassed && (Date() > mutedTill)
            } else {
                needsToShow = intervalPassed
            }
        } else if let mutedTill = ruuviAlertService.mutedTill(type: Self.alertType(from: type), for: uuid) {
            needsToShow = Date() > mutedTill
        } else {
            needsToShow = true
        }
        if needsToShow {
            let content = UNMutableNotificationContent()
            switch settings.alertSound {
            case .systemDefault:
                content.sound = .default
            default:
                content.sound = UNNotificationSound(
                    named: UNNotificationSoundName(rawValue: settings.alertSound.rawValue)
                )
            }
            content.title = title
            content.userInfo = [lowHigh.uuidKey: uuid, lowHigh.typeKey: type.rawValue]
            content.categoryIdentifier = lowHigh.id

            let body: String
            switch type {
            case .temperature:
                body = ruuviAlertService.temperatureDescription(for: uuid) ?? ""
            case .relativeHumidity:
                body = ruuviAlertService.relativeHumidityDescription(for: uuid) ?? ""
            case .humidity:
                body = ruuviAlertService.humidityDescription(for: uuid) ?? ""
            case .pressure:
                body = ruuviAlertService.pressureDescription(for: uuid) ?? ""
            case .signal:
                body = ruuviAlertService.signalDescription(for: uuid) ?? ""
            }
            content.body = body

            ruuviStorage.readOne(id(for: uuid)).on(success: { ruuviTag in
                content.subtitle = ruuviTag.name
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
                let request = UNNotificationRequest(identifier: uuid + type.rawValue,
                                                    content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            })
            virtualTagTrunk.readOne(id(for: uuid)).on(success: { virtualTag in
                content.subtitle = virtualTag.name
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
                let request = UNNotificationRequest(identifier: uuid + type.rawValue,
                                                    content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            })

            switch reason {
            case .low:
                switch type {
                case .temperature:
                    lowTemperatureAlerts[uuid] = Date()
                case .relativeHumidity:
                    lowRelativeHumidityAlerts[uuid] = Date()
                case .humidity:
                    lowHumidityAlerts[uuid] = Date()
                case .pressure:
                    lowPressureAlerts[uuid] = Date()
                case .signal:
                    lowSignalAlerts[uuid] = Date()
                }
            case .high:
                switch type {
                case .temperature:
                    highTemperatureAlerts[uuid] = Date()
                case .relativeHumidity:
                    highRelativeHumidityAlerts[uuid] = Date()
                case .humidity:
                    highHumidityAlerts[uuid] = Date()
                case .pressure:
                    highPressureAlerts[uuid] = Date()
                case .signal:
                    highSignalAlerts[uuid] = Date()
                }
            }
        }
    }
}

// MARK: - Private
extension RuuviNotificationLocalImpl {
    private static func alertType(from type: LowHighNotificationType) -> AlertType {
        switch type {
        case .temperature:
            return .temperature(lower: 0, upper: 0)
        case .relativeHumidity:
            return .relativeHumidity(lower: 0, upper: 0)
        case .humidity:
            return .humidity(
                lower: Humidity(value: 0, unit: .absolute),
                upper: Humidity(value: 0, unit: .absolute)
            )
        case .pressure:
            return .pressure(lower: 0, upper: 0)
        case .signal:
            return .signal(lower: 0, upper: 0)
        }
    }

    private static func alertType(from type: BlastNotificationType) -> AlertType {
        switch type {
        case .connection:
            return .connection
        case .movement:
            return .movement(last: 0)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func startObserving() {
        alertDidChangeToken = NotificationCenter
            .default
            .addObserver(forName: .RuuviServiceAlertDidChange,
                         object: nil,
                         queue: .main) { [weak self] (notification) in
            if let userInfo = notification.userInfo,
                let type = userInfo[RuuviServiceAlertDidChangeKey.type] as? AlertType {

                let virtualSensor = userInfo[RuuviServiceAlertDidChangeKey.virtualSensor] as? VirtualSensor
                let physicalSensor = userInfo[RuuviServiceAlertDidChangeKey.physicalSensor] as? PhysicalSensor

                var isOn = false
                if let virtualSensor = virtualSensor {
                    isOn = self?.ruuviAlertService.isOn(type: type, for: virtualSensor) ?? false
                }
                if let physicalSensor = physicalSensor {
                    isOn = self?.ruuviAlertService.isOn(type: type, for: physicalSensor) ?? false
                }

                if let uuid = physicalSensor?.luid?.value ?? physicalSensor?.macId?.value ?? virtualSensor?.id {
                    switch type {
                    case .temperature:
                        self?.lowTemperatureAlerts[uuid] = nil
                        self?.highTemperatureAlerts[uuid] = nil
                        if !isOn {
                            self?.cancel(.temperature, for: uuid)
                        }
                    case .relativeHumidity:
                        self?.lowRelativeHumidityAlerts[uuid] = nil
                        self?.highRelativeHumidityAlerts[uuid] = nil
                        if !isOn {
                            self?.cancel(.relativeHumidity, for: uuid)
                        }
                    case .humidity:
                        self?.lowHumidityAlerts[uuid] = nil
                        self?.highHumidityAlerts[uuid] = nil
                        if !isOn {
                            self?.cancel(.humidity, for: uuid)
                        }
                    case .pressure:
                        self?.lowPressureAlerts[uuid] = nil
                        self?.highPressureAlerts[uuid] = nil
                        if !isOn {
                            self?.cancel(.pressure, for: uuid)
                        }
                    case .signal:
                        self?.lowSignalAlerts[uuid] = nil
                        self?.highSignalAlerts[uuid] = nil
                        if !isOn {
                            self?.cancel(.signal, for: uuid)
                        }
                    case .connection:
                        // do nothing
                        break
                    case .movement:
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
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.alert, .badge, .sound])
    }

    // swiftlint:disable:next function_body_length
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
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
                    sharedTo: []
                )
                ruuviAlertService.unregister(type: Self.alertType(from: type), ruuviTag: ruuviTag)
                let virtualSensor = VirtualSensorStruct(id: uuid)
                ruuviAlertService.unregister(type: Self.alertType(from: type), for: virtualSensor)
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
                    sharedTo: []
                )
                ruuviAlertService.unregister(type: Self.alertType(from: type), ruuviTag: ruuviTag)
                let virtualSensor = VirtualSensorStruct(id: uuid)
                ruuviAlertService.unregister(type: Self.alertType(from: type), for: virtualSensor)
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
        guard let date = muteOffset() else {
            assertionFailure(); return
        }
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
            sharedTo: []
        )
        ruuviAlertService.mute(
            type: Self.alertType(from: type),
            for: ruuviTag,
            till: date
        )
        let virtualSensor = VirtualSensorStruct(id: uuid)
        ruuviAlertService.mute(
            type: Self.alertType(from: type),
            for: virtualSensor,
            till: date
        )
    }

    private func mute(type: BlastNotificationType, uuid: String) {
        guard let date = muteOffset() else {
            assertionFailure(); return
        }
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
            sharedTo: []
        )
        ruuviAlertService.mute(
            type: Self.alertType(from: type),
            for: ruuviTag,
            till: date
        )
        let virtualSensor = VirtualSensorStruct(id: uuid)
        ruuviAlertService.mute(
            type: Self.alertType(from: type),
            for: virtualSensor,
            till: date
        )
    }

    private func muteOffset() -> Date? {
        return Calendar.current.date(
            byAdding: .minute,
            value: self.settings.alertsMuteIntervalMinutes,
            to: Date()
        )
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
