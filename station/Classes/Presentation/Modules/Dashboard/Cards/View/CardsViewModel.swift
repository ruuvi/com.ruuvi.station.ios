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
    var background: Observable<UIImage?> = Observable<UIImage?>()
    var date: Observable<Date?> = Observable<Date?>()
    var location: Observable<Location?> = Observable<Location?>()
    var currentLocation: Observable<Location?> = Observable<Location?>()
    var animateRSSI: Observable<Bool?> = Observable<Bool?>()
    var isConnectable: Observable<Bool?> = Observable<Bool?>()
    var provider: VirtualProvider?
    var isConnected: Observable<Bool?> = Observable<Bool?>()
    var isCloud: Observable<Bool?> = Observable<Bool?>()
    var alertState: Observable<AlertState?> = Observable<AlertState?>()
    var rhAlertLowerBound: Observable<Double?> = Observable<Double?>()
    var rhAlertUpperBound: Observable<Double?> = Observable<Double?>()
    var networkSyncStatus: Observable<NetworkSyncStatus?> = .init(NetworkSyncStatus.none)
    var movementCounter: Observable<Int?> = Observable<Int?>()
    var isChartAvailable: Observable<Bool?> = Observable<Bool?>(false)

    private var lastUpdateRssi: Observable<CFTimeInterval?> = Observable<CFTimeInterval?>(CFAbsoluteTimeGetCurrent())

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
        isCloud.value = ruuviTag.isCloud
    }

    func update(_ record: RuuviTagSensorRecord) {
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
        temperature.value = ruuviTag.temperature
        humidity.value = ruuviTag.humidity
        pressure.value = ruuviTag.pressure
        version.value = ruuviTag.version
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
        hasher.combine(luid.value?.value)
    }
}

extension CardsViewModel: Equatable {
    public static func == (lhs: CardsViewModel, rhs: CardsViewModel) -> Bool {
        var idIsEqual = false
        if let lhsId = lhs.luid.value, let rhsId = rhs.luid.value {
            idIsEqual = lhsId == rhsId
        }
        var luidIsEqual = false
        if let lhsLuid = lhs.luid.value, let rhsLuid = rhs.luid.value {
            luidIsEqual = lhsLuid == rhsLuid
        }
        var macIsEqual = false
        if let lhsMac = lhs.mac.value, let rhsMac = rhs.mac.value {
            macIsEqual = lhsMac == rhsMac
        }
        return idIsEqual || luidIsEqual || macIsEqual
    }
}

extension CardsViewModel: Reorderable {
    var orderElement: String {
        return id.value ?? UUID().uuidString
    }
}
