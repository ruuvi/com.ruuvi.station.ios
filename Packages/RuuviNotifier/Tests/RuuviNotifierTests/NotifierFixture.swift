import Foundation
import RuuviLocal
import RuuviNotification
import RuuviNotifier
import RuuviOntology
import RuuviService
#if SWIFT_PACKAGE
    import RuuviLocalUserDefaults
    @testable import RuuviNotifierImpl
    import RuuviServiceMeasurement
#else
    @testable import RuuviNotifier
#endif
import XCTest

final class NotifierAlerts: NotifierAlertAccess {
    var registered = true
    var alerts: [String: AlertType] = [:]
    var movementBaselines: [Int?] = []
    var enabledMovementIDs: Set<String> = []
    func hasRegistrations(for sensor: PhysicalSensor) -> Bool { registered }
    func alert(for uuid: String, of type: AlertType) -> AlertType? { alerts[type.rawValue] }
    func isOn(type: AlertType, for uuid: String) -> Bool {
        if case .movement = type { return enabledMovementIDs.contains(uuid) }
        return alerts[type.rawValue] != nil
    }
    func isOn(type: AlertType, for sensor: PhysicalSensor) -> Bool {
        isOn(type: type, for: sensor.luid?.value ?? sensor.macId?.value ?? "")
    }
    func setMovement(counter: Int?, for sensor: PhysicalSensor) {
        movementBaselines.append(counter)
        if let counter { alerts[AlertType.movement(last: 0).rawValue] = .movement(last: counter) }
    }
}

final class NotifierNotifications: RuuviNotificationLocal {
    struct Alert { let reason: LowHighNotificationReason; let type: AlertType; let uuid: String; let title: String }
    var alerts: [Alert] = []
    var moves: [(String, Int, String)] = []
    func setup(disableTitle: String, muteTitle: String, output: RuuviNotificationLocalOutput?) {}
    func showDidConnect(uuid: String, title: String) { XCTFail("Unexpected connection notification") }
    func showDidDisconnect(uuid: String, title: String) { XCTFail("Unexpected disconnection notification") }
    func notifyDidMove(for uuid: String, counter: Int, title: String) {
        XCTAssertTrue(Thread.isMainThread)
        moves.append((uuid, counter, title))
    }
    func notify(_ reason: LowHighNotificationReason, _ type: AlertType, for uuid: String, title: String) {
        XCTAssertTrue(Thread.isMainThread)
        alerts.append(.init(reason: reason, type: type, uuid: uuid, title: title))
    }
}

final class NotifierObserver: RuuviNotifierObserver {
    var overall: [(String, Bool)] = []
    var types: [(String, AlertType, Bool)] = []
    func ruuvi(notifier: RuuviNotifier, isTriggered: Bool, for uuid: String) {
        XCTAssertTrue(Thread.isMainThread)
        overall.append((uuid, isTriggered))
    }
    func ruuvi(notifier: RuuviNotifier, alertType: AlertType, isTriggered: Bool, for uuid: String) {
        XCTAssertTrue(Thread.isMainThread)
        types.append((uuid, alertType, isTriggered))
    }
}

final class NotifierClock { var date = Date(timeIntervalSince1970: 1_700_000_000) }

@MainActor final class NotifierFixture {
    let alerts = NotifierAlerts()
    let notifications = NotifierNotifications()
    let observer = NotifierObserver()
    let clock = NotifierClock()
    let luid = UUID().uuidString.luid
    let mac = "AA:BB:CC:DD:EE:99".mac
    let settings: RuuviLocalSettings
    let sync: RuuviLocalSyncState
    let measurement: RuuviServiceMeasurement
    var notifier: RuuviNotifierImpl!
    private var previous: [String: Any] = [:]
    private let keys = [
        "SettingsUserDefaults.movementAlertHysteresisLastEvents", "SettingsUserDefaults.movementAlertHysteresisMinutes",
        "RuuviLocalSyncStateUserDefaults.syncDateAllIDKey.",
    ]

    init() {
        let factory = RuuviLocalFactoryUserDefaults()
        settings = factory.createLocalSettings()
        sync = factory.createLocalSyncState()
        measurement = RuuviServiceMeasurementImpl(settings: settings, emptyValueString: "missing", percentString: "%")
        for key in keys {
            previous[key] = UserDefaults.standard.object(forKey: key); UserDefaults.standard.removeObject(forKey: key)
        }
        settings.movementAlertHysteresisMinutes = 0
        rebuild()
    }

    func rebuild() {
        notifier = RuuviNotifierImpl(
            alertAccess: alerts, ruuviNotificationLocal: notifications,
            localSyncState: sync, measurementService: measurement,
            settings: settings, titles: NotifierTitles(), now: { [clock] in clock.date })
        notifier.subscribe(observer, to: luid.value)
        notifier.subscribe(observer, to: mac.value)
    }

    func close() {
        notifier = nil
        for key in keys {
            if let value = previous[key] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    func drain() async {
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
    }

    func record() -> RuuviTagSensorRecordStruct {
        .init(
            luid: luid, date: clock.date, source: .advertisement, macId: mac, rssi: nil, version: 225,
            temperature: nil, humidity: nil, pressure: nil, acceleration: nil, voltage: nil,
            movementCounter: nil, measurementSequenceNumber: nil, txPower: nil, pm1: nil, pm25: nil,
            pm4: nil, pm10: nil, co2: nil, voc: nil, nox: nil, luminance: nil, dbaInstant: nil,
            dbaAvg: nil, dbaPeak: nil, temperatureOffset: 0, humidityOffset: 0, pressureOffset: 0)
    }

    func process(_ record: RuuviTagSensorRecord, network: Bool, trigger: Bool = true) async {
        notifications.alerts.removeAll()
        observer.overall.removeAll()
        observer.types.removeAll()
        if network {
            notifier.processNetwork(record: record, trigger: trigger, for: mac)
        } else {
            notifier.process(record: record, trigger: trigger)
        }
        await drain()
    }
}

struct NotifierTitles: RuuviNotifierTitles {
    func lowTemperature(_ value: String) -> String { "lowTemperature|" + value }
    func highTemperature(_ value: String) -> String { "highTemperature|" + value }
    func lowHumidity(_ value: String) -> String { "lowHumidity|" + value }
    func highHumidity(_ value: String) -> String { "highHumidity|" + value }
    func lowAbsoluteHumidity(_ value: String) -> String { "lowAbsoluteHumidity|" + value }
    func highAbsoluteHumidity(_ value: String) -> String { "highAbsoluteHumidity|" + value }
    func lowDewPoint(_ value: String) -> String { "lowDewPoint|" + value }
    func highDewPoint(_ value: String) -> String { "highDewPoint|" + value }
    func lowPressure(_ value: String) -> String { "lowPressure|" + value }
    func highPressure(_ value: String) -> String { "highPressure|" + value }
    func lowSignal(_ value: String) -> String { "lowSignal|" + value }
    func highSignal(_ value: String) -> String { "highSignal|" + value }
    func lowAQI(_ value: String) -> String { "lowAQI|" + value }
    func highAQI(_ value: String) -> String { "highAQI|" + value }
    func lowCarbonDioxide(_ value: String) -> String { "lowCarbonDioxide|" + value }
    func highCarbonDioxide(_ value: String) -> String { "highCarbonDioxide|" + value }
    func lowPMatter1(_ value: String) -> String { "lowPMatter1|" + value }
    func highPMatter1(_ value: String) -> String { "highPMatter1|" + value }
    func lowPMatter25(_ value: String) -> String { "lowPMatter25|" + value }
    func highPMatter25(_ value: String) -> String { "highPMatter25|" + value }
    func lowPMatter4(_ value: String) -> String { "lowPMatter4|" + value }
    func highPMatter4(_ value: String) -> String { "highPMatter4|" + value }
    func lowPMatter10(_ value: String) -> String { "lowPMatter10|" + value }
    func highPMatter10(_ value: String) -> String { "highPMatter10|" + value }
    func lowVOC(_ value: String) -> String { "lowVOC|" + value }
    func highVOC(_ value: String) -> String { "highVOC|" + value }
    func lowNOx(_ value: String) -> String { "lowNOx|" + value }
    func highNOx(_ value: String) -> String { "highNOx|" + value }
    func lowSoundInstant(_ value: String) -> String { "lowSoundInstant|" + value }
    func highSoundInstant(_ value: String) -> String { "highSoundInstant|" + value }
    func lowSoundAverage(_ value: String) -> String { "lowSoundAverage|" + value }
    func highSoundAverage(_ value: String) -> String { "highSoundAverage|" + value }
    func lowSoundPeak(_ value: String) -> String { "lowSoundPeak|" + value }
    func highSoundPeak(_ value: String) -> String { "highSoundPeak|" + value }
    func lowLuminosity(_ value: String) -> String { "lowLuminosity|" + value }
    func highLuminosity(_ value: String) -> String { "highLuminosity|" + value }
    func lowBatteryVoltage(_ value: String) -> String { "lowBatteryVoltage|" + value }
    func highBatteryVoltage(_ value: String) -> String { "highBatteryVoltage|" + value }
    var didMove: String { "movement" }
}
