import UIKit
import BTKit
import Humidity
import RuuviOntology
import RuuviLocal
import RuuviVirtual

enum CardType {
    case ruuvi
    case web
}

struct CardsViewModel {
    var type: CardType = .ruuvi

    var id: Observable<String?> = Observable<String?>()
    var luid: Observable<AnyLocalIdentifier?> = Observable<AnyLocalIdentifier?>()
    var mac: Observable<AnyMACIdentifier?> = Observable<AnyMACIdentifier?>()
    var name: Observable<String?> = Observable<String?>()
    var source: Observable<RuuviTagSensorRecordSource?> = Observable<RuuviTagSensorRecordSource?>()
    var temperature: Observable<Temperature?> = Observable<Temperature?>()
    var humidity: Observable<Humidity?> = Observable<Humidity?>()
    var pressure: Observable<Pressure?> = Observable<Pressure?>()
    var rssi: Observable<Int?> = Observable<Int?>()
    var version: Observable<Int?> = Observable<Int?>()
    var voltage: Observable<Voltage?> = Observable<Voltage?>()
    let batteryNeedsReplacement: Observable<Bool?> = Observable<Bool?>()
    var background: Observable<UIImage?> = Observable<UIImage?>()
    var date: Observable<Date?> = Observable<Date?>()
    var location: Observable<Location?> = Observable<Location?>()
    var currentLocation: Observable<Location?> = Observable<Location?>()
    var animateRSSI: Observable<Bool?> = Observable<Bool?>()
    var isConnectable: Observable<Bool?> = Observable<Bool?>()
    var provider: VirtualProvider?
    var isConnected: Observable<Bool?> = Observable<Bool?>()
    var isCloud: Observable<Bool?> = Observable<Bool?>()
    var isOwner: Observable<Bool?> = Observable<Bool?>()
    var canShareTag: Observable<Bool?> = Observable<Bool?>(false)
    var alertState: Observable<AlertState?> = Observable<AlertState?>()
    var rhAlertLowerBound: Observable<Double?> = Observable<Double?>()
    var rhAlertUpperBound: Observable<Double?> = Observable<Double?>()
    var networkSyncStatus: Observable<NetworkSyncStatus?> = .init(NetworkSyncStatus.none)
    var movementCounter: Observable<Int?> = Observable<Int?>()
    var isChartAvailable: Observable<Bool?> = Observable<Bool?>(false)
    var isAlertAvailable: Observable<Bool?> = Observable<Bool?>(false)

    var latestMeasurement: Observable<RuuviTagSensorRecord?> = Observable<RuuviTagSensorRecord?>()

    let isTemperatureAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let temperatureAlertState: Observable<AlertState?> = Observable<AlertState?>()
    let temperatureAlertMutedTill: Observable<Date?> = Observable<Date?>(nil)

    let isRelativeHumidityAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let relativeHumidityAlertState: Observable<AlertState?> = Observable<AlertState?>()
    let relativeHumidityAlertMutedTill: Observable<Date?> = Observable<Date?>(nil)

    let isPressureAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let pressureAlertState: Observable<AlertState?> = Observable<AlertState?>()
    let pressureAlertMutedTill: Observable<Date?> = Observable<Date?>(nil)

    let isSignalAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let signalAlertState: Observable<AlertState?> = Observable<AlertState?>()
    let signalAlertMutedTill: Observable<Date?> = Observable<Date?>(nil)

    let isMovementAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let movementAlertState: Observable<AlertState?> = Observable<AlertState?>()
    let movementAlertMutedTill: Observable<Date?> = Observable<Date?>(nil)

    let isConnectionAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let connectionAlertState: Observable<AlertState?> = Observable<AlertState?>()
    let connectionAlertMutedTill: Observable<Date?> = Observable<Date?>(nil)

    let isCloudConnectionAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let cloudConnectionAlertState: Observable<AlertState?> = Observable<AlertState?>()

    private var lastUpdateRssi: Observable<CFTimeInterval?> = Observable<CFTimeInterval?>(CFAbsoluteTimeGetCurrent())

    private let batteryStatusProvider = RuuviTagBatteryStatusProvider()

    init(_ virtualSensor: VirtualTagSensor) {
        type = .web
        id.value = virtualSensor.id
        luid.value = virtualSensor.id.luid.any
        name.value = virtualSensor.name
        // TODO: @rinat fetch one
//        temperature.value = virtualSensor.lastRecord?.temperature
//        humidity.value = virtualSensor.lastRecord?.humidity
//        pressure.value = virtualSensor.lastRecord?.pressure
        isConnectable.value = false
        isConnected.value = false
        isCloud.value = false
        isOwner.value = true
//        date.value = virtualSensor.data.last?.date
//        location.value = virtualSensor.location?.location
        provider = virtualSensor.provider
        source.value = .weatherProvider
    }

    func update(_ record: VirtualTagSensorRecord) {
        temperature.value = record.temperature
        humidity.value = record.humidity
        pressure.value = record.pressure
        isConnectable.value = false
        isConnected.value = false
        isCloud.value = false
        isOwner.value = true
        currentLocation.value = record.location
        date.value = record.date
    }

    func update(_ wpsData: VirtualData, current: Location?) {
        isConnectable.value = false
        temperature.value = wpsData.temperature
        humidity.value = wpsData.humidity
        pressure.value = wpsData.pressure
        currentLocation.value = current
        date.value = Date()
    }

    init(_ ruuviTag: RuuviTagSensor) {
        type = .ruuvi
        id.value = ruuviTag.id
        luid.value = ruuviTag.luid?.any
        if let macId = ruuviTag.macId?.any {
            mac.value = macId
        }
        name.value = ruuviTag.name
        version.value = ruuviTag.version
        isConnectable.value = ruuviTag.isConnectable
        isChartAvailable.value = ruuviTag.isConnectable || ruuviTag.isCloud
        isAlertAvailable.value = ruuviTag.isCloud || isConnected.value ?? false
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
        source.value = record.source
        batteryNeedsReplacement.value =
            batteryStatusProvider
            .batteryNeedsReplacement(temperature: record.temperature,
                                     voltage: record.voltage)
        isAlertAvailable.value = isCloud.value ?? false || isConnected.value ?? false
    }

    func update(with ruuviTag: RuuviTag) {
        if !ruuviTag.isConnected, isConnectable.value != ruuviTag.isConnectable, ruuviTag.isConnectable {
            isConnectable.value = ruuviTag.isConnectable
            if let isChart = isChartAvailable.value,
               !isChart,
               ruuviTag.isConnectable {
                isChartAvailable.value = true
            }
        }
        isAlertAvailable.value = isCloud.value ?? false || ruuviTag.isConnected
        temperature.value = ruuviTag.temperature
        humidity.value = ruuviTag.humidity
        pressure.value = ruuviTag.pressure
        version.value = ruuviTag.version
        voltage.value = ruuviTag.voltage
        if let macId = ruuviTag.mac?.mac.any {
            mac.value = macId
        }
        date.value = Date()
        movementCounter.value = ruuviTag.movementCounter
        source.value = ruuviTag.source
    }
}

extension CardsViewModel: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(luid.value)
        hasher.combine(mac.value)
    }
}

extension CardsViewModel: Equatable {
    public static func == (lhs: CardsViewModel, rhs: CardsViewModel) -> Bool {
        return lhs.luid.value == rhs.luid.value && lhs.mac.value == rhs.mac.value
    }
}

extension CardsViewModel: Reorderable {
    var orderElement: String {
        return id.value ?? UUID().uuidString
    }
}
