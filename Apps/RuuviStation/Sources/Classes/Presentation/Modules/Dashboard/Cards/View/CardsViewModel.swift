import BTKit
import Humidity
import RuuviLocal
import RuuviOntology
import UIKit
import MobileCoreServices

enum CardType {
    case ruuvi
}

class CardsViewModel: NSObject {
    var type: CardType = .ruuvi

    var id: Observable<String?> = .init()
    var luid: Observable<AnyLocalIdentifier?> = .init()
    var mac: Observable<AnyMACIdentifier?> = .init()
    var serviceUUID: Observable<String?> = .init()
    var name: Observable<String?> = .init()
    var source: Observable<RuuviTagSensorRecordSource?> = .init()
    var temperature: Observable<Temperature?> = .init()
    var humidity: Observable<Humidity?> = .init()
    var pressure: Observable<Pressure?> = .init()
    var rssi: Observable<Int?> = .init()
    var version: Observable<Int?> = .init()
    var voltage: Observable<Voltage?> = .init()
    var pm1: Observable<Double?> = .init()
    var pm2_5: Observable<Double?> = .init()
    var pm4: Observable<Double?> = .init()
    var pm10: Observable<Double?> = .init()
    var co2: Observable<Double?> = .init()
    var voc: Observable<Double?> = .init()
    var nox: Observable<Double?> = .init()
    var luminance: Observable<Double?> = .init()
    var dbaAvg: Observable<Double?> = .init()
    var dbaPeak: Observable<Double?> = .init()
    let batteryNeedsReplacement: Observable<Bool?> = .init()
    var background: Observable<UIImage?> = .init()
    var date: Observable<Date?> = .init()
    var location: Observable<Location?> = .init()
    var currentLocation: Observable<Location?> = .init()
    var animateRSSI: Observable<Bool?> = .init()
    var isConnectable: Observable<Bool?> = .init()
    var isConnected: Observable<Bool?> = .init()
    var isCloud: Observable<Bool?> = .init()
    var isOwner: Observable<Bool?> = .init()
    var canShareTag: Observable<Bool?> = .init(false)
    var alertState: Observable<AlertState?> = .init()
    var rhAlertLowerBound: Observable<Double?> = .init()
    var rhAlertUpperBound: Observable<Double?> = .init()
    var networkSyncStatus: Observable<NetworkSyncStatus?> = .init(NetworkSyncStatus.none)
    var movementCounter: Observable<Int?> = .init()
    var isChartAvailable: Observable<Bool?> = .init(false)
    var isAlertAvailable: Observable<Bool?> = .init(false)

    var latestMeasurement: Observable<RuuviTagSensorRecord?> = .init()

    let isTemperatureAlertOn: Observable<Bool?> = .init(false)
    let temperatureAlertState: Observable<AlertState?> = .init()
    let temperatureAlertMutedTill: Observable<Date?> = .init(nil)

    let isRelativeHumidityAlertOn: Observable<Bool?> = .init(false)
    let relativeHumidityAlertState: Observable<AlertState?> = .init()
    let relativeHumidityAlertMutedTill: Observable<Date?> = .init(nil)

    let isPressureAlertOn: Observable<Bool?> = .init(false)
    let pressureAlertState: Observable<AlertState?> = .init()
    let pressureAlertMutedTill: Observable<Date?> = .init(nil)

    let isSignalAlertOn: Observable<Bool?> = .init(false)
    let signalAlertState: Observable<AlertState?> = .init()
    let signalAlertMutedTill: Observable<Date?> = .init(nil)

    let isMovementAlertOn: Observable<Bool?> = .init(false)
    let movementAlertState: Observable<AlertState?> = .init()
    let movementAlertMutedTill: Observable<Date?> = .init(nil)

    let isConnectionAlertOn: Observable<Bool?> = .init(false)
    let connectionAlertState: Observable<AlertState?> = .init()
    let connectionAlertMutedTill: Observable<Date?> = .init(nil)

    let isCloudConnectionAlertOn: Observable<Bool?> = .init(false)
    let cloudConnectionAlertState: Observable<AlertState?> = .init()

    private var lastUpdateRssi: Observable<CFTimeInterval?> = .init(CFAbsoluteTimeGetCurrent())

    private let batteryStatusProvider = RuuviTagBatteryStatusProvider()

    init(_ ruuviTag: RuuviTagSensor) {
        type = .ruuvi
        id.value = ruuviTag.id
        luid.value = ruuviTag.luid?.any
        if let macId = ruuviTag.macId?.any {
            mac.value = macId
        }
        serviceUUID.value = ruuviTag.serviceUUID
        name.value = ruuviTag.name
        version.value = ruuviTag.version
        isConnectable.value = ruuviTag.isConnectable
        isChartAvailable.value = ruuviTag.isConnectable || ruuviTag.isCloud || ruuviTag.serviceUUID != nil
        isAlertAvailable.value = ruuviTag.isCloud || isConnected.value ?? false || ruuviTag.serviceUUID != nil
        isCloud.value = ruuviTag.isCloud
        isOwner.value = ruuviTag.isOwner
        canShareTag.value =
            (ruuviTag.isOwner && ruuviTag.isClaimed) || ruuviTag.canShare
    }

    func update(_ record: RuuviTagSensorRecord) {
        latestMeasurement.value = record
        temperature.value = record.temperature
        humidity.value = record.humidity
        pressure.value = record.pressure
        if let macId = record.macId?.any {
            mac.value = macId
        }
        date.value = record.date
        rssi.value = record.rssi
        movementCounter.value = record.movementCounter
        pm1.value = record.pm1
        pm2_5.value = record.pm2_5
        pm4.value = record.pm4
        pm10.value = record.pm10
        co2.value = record.co2
        voc.value = record.voc
        nox.value = record.nox
        luminance.value = record.luminance
        dbaAvg.value = record.dbaAvg
        dbaPeak.value = record.dbaPeak
        source.value = record.source
        batteryNeedsReplacement.value =
            batteryStatusProvider
                .batteryNeedsReplacement(
                    temperature: record.temperature,
                    voltage: record.voltage
                )
        isAlertAvailable.value = isCloud.value ?? false || isConnected.value ?? false || serviceUUID.value != nil
    }

    func update(with ruuviTag: RuuviTag) {
        if !ruuviTag.isConnected, isConnectable.value != ruuviTag.isConnectable, ruuviTag.isConnectable {
            isConnectable.value = ruuviTag.isConnectable
            if let isChart = isChartAvailable.value,
               !isChart,
               ruuviTag.isConnectable {
                isChartAvailable.value = true
            }
        } else {
            if let isChart = isChartAvailable.value,
               !isChart,
               ruuviTag.serviceUUID != nil {
                isChartAvailable.value = true
            }
        }
        isAlertAvailable.value = isCloud.value ?? false ||
            ruuviTag.isConnected || ruuviTag.serviceUUID != nil
        temperature.value = ruuviTag.temperature
        humidity.value = ruuviTag.humidity
        pressure.value = ruuviTag.pressure
        version.value = ruuviTag.version
        voltage.value = ruuviTag.voltage
        if let macId = ruuviTag.mac?.mac.any {
            mac.value = macId
        }
        serviceUUID.value = ruuviTag.serviceUUID
        date.value = Date()
        movementCounter.value = ruuviTag.movementCounter
        pm1.value = ruuviTag.pm1
        pm2_5.value = ruuviTag.pm2_5
        pm4.value = ruuviTag.pm4
        pm10.value = ruuviTag.pm10
        co2.value = ruuviTag.co2
        voc.value = ruuviTag.voc
        nox.value = ruuviTag.nox
        luminance.value = ruuviTag.luminance
        dbaAvg.value = ruuviTag.dbaAvg
        dbaPeak.value = ruuviTag.dbaPeak
        source.value = ruuviTag.source
    }
}

extension CardsViewModel: Reorderable {
    var orderElement: String {
        id.value ?? UUID().uuidString
    }
}

// Comform to NSItemProviderWriting to enable drag and drop of item with CardsViewModel
extension CardsViewModel: NSItemProviderWriting {
    public static var writableTypeIdentifiersForItemProvider: [String] {
        return [kUTTypePlainText as String]
    }

    public func loadData(
        withTypeIdentifier typeIdentifier: String,
        forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void
    ) -> Progress? {
        return Progress()
    }
}
