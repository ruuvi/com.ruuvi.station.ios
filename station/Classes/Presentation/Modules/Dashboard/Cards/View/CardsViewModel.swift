import UIKit
import BTKit
import Humidity
import RuuviOntology
import RuuviLocal

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
    var provider: WeatherProvider?
    var isConnected: Observable<Bool?> = Observable<Bool?>()
    var alertState: Observable<AlertState?> = Observable<AlertState?>()
    var networkSyncStatus: Observable<NetworkSyncStatus?> = .init(NetworkSyncStatus.none)
    var movementCounter: Observable<Int?> = Observable<Int?>()

    private var lastUpdateRssi: Observable<CFTimeInterval?> = Observable<CFTimeInterval?>(CFAbsoluteTimeGetCurrent())

    init(_ webTag: WebTagRealm) {
        type = .web
        id.value = webTag.uuid
        luid.value = webTag.uuid.luid.any
        name.value = webTag.name
        temperature.value = webTag.lastRecord?.temperature
        humidity.value = webTag.lastRecord?.humidity
        pressure.value = webTag.lastRecord?.pressure
        isConnectable.value = false
        isConnected.value = false
        date.value = webTag.data.last?.date
        location.value = webTag.location?.location
        provider = webTag.provider
        source.value = .weatherProvider
    }

    func update(_ data: WebTagDataRealm) {
        temperature.value = data.record?.temperature
        humidity.value = data.record?.humidity
        pressure.value = data.record?.pressure
        isConnectable.value = false
        isConnected.value = false
        currentLocation.value = data.location?.location
        date.value = data.date
    }

    func update(_ wpsData: WPSData, current: Location?) {
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

    func update(rssi: Int?, animated: Bool = false) {
        if rssi == nil {
            self.rssi.value = rssi
        }
        guard let lastUpdateRssiTime = lastUpdateRssi.value,
            CFAbsoluteTimeGetCurrent() - lastUpdateRssiTime > 1 else {
            return
        }
        self.lastUpdateRssi.value = CFAbsoluteTimeGetCurrent()
        self.animateRSSI.value = animated
        self.rssi.value = rssi
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
