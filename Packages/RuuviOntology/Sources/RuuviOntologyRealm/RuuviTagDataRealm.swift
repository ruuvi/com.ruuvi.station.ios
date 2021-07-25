import Foundation
import RealmSwift
import BTKit
import RuuviOntology

public final class RuuviTagDataRealm: Object {

    @objc public dynamic var ruuviTag: RuuviTagRealm?
    @objc public dynamic var date: Date = Date()
    @objc public dynamic var compoundKey: String = UUID().uuidString
    @objc public dynamic var sourceString: String = "unknown"

    // all versions
    public let rssi = RealmProperty<Int?>()
    public let celsius = RealmProperty<Double?>()
    public let humidity = RealmProperty<Double?>()
    public let pressure = RealmProperty<Double?>()

    // v3 & v5
    public let accelerationX = RealmProperty<Double?>()
    public let accelerationY = RealmProperty<Double?>()
    public let accelerationZ = RealmProperty<Double?>()
    public let voltage = RealmProperty<Double?>()

    // v5
    public let movementCounter = RealmProperty<Int?>()
    public let measurementSequenceNumber = RealmProperty<Int?>()
    public let txPower = RealmProperty<Int?>()

    @objc public dynamic var temperatureOffset: Double = 0.0
    @objc public dynamic var humidityOffset: Double = 0.0
    @objc public dynamic var pressureOffset: Double = 0.0

    public var fahrenheit: Double? {
        return celsius.value?.fahrenheit
    }

    public var kelvin: Double? {
        return celsius.value?.kelvin
    }

    public var source: RuuviTagSensorRecordSource {
        return RuuviTagSensorRecordSource(rawValue: sourceString) ?? .unknown
    }

    public override static func primaryKey() -> String? {
        return "compoundKey"
    }

    public convenience init(ruuviTag: RuuviTagRealm, data: RuuviTagProtocol, date: Date) {
        self.init(ruuviTag: ruuviTag, data: data)
        self.date = date
    }

    public convenience init(ruuviTag: RuuviTagRealm, data: RuuviTagProtocol) {
        self.init()
        self.ruuviTag = ruuviTag
        self.sourceString = data.source.rawValue
        self.rssi.value = data.rssi
        self.celsius.value = data.celsius
        self.humidity.value = data.relativeHumidity
        self.pressure.value = data.hectopascals
        self.accelerationX.value = data.accelerationX
        self.accelerationY.value = data.accelerationY
        self.accelerationZ.value = data.accelerationZ
        self.voltage.value = data.volts
        self.movementCounter.value = data.movementCounter
        self.measurementSequenceNumber.value = data.measurementSequenceNumber
        self.txPower.value = data.txPower
        self.compoundKey = ruuviTag.uuid + "\(date.timeIntervalSince1970)"
    }

    public convenience init(ruuviTag: RuuviTagRealm, data: RuuviTagEnvLogFull) {
        self.init()
        self.ruuviTag = ruuviTag
        self.sourceString = RuuviTagSensorRecordSource.log.rawValue
        self.date = data.date
        self.celsius.value = data.temperature
        self.humidity.value = data.humidity
        self.pressure.value = data.pressure
        self.compoundKey = ruuviTag.uuid + "\(date.timeIntervalSince1970)"
    }

    public convenience init(ruuviTag: RuuviTagRealm, record: RuuviTagSensorRecord) {
        self.init()
        self.ruuviTag = ruuviTag
        self.sourceString = record.source.rawValue
        self.rssi.value = record.rssi
        self.celsius.value = record.temperature?.converted(to: .celsius).value
        self.humidity.value = record.humidity?.value
        self.pressure.value = record.pressure?.converted(to: .hectopascals).value
        self.accelerationX.value = record.acceleration?.x.value
        self.accelerationY.value = record.acceleration?.y.value
        self.accelerationZ.value = record.acceleration?.z.value
        self.voltage.value = record.voltage?.converted(to: .volts).value
        self.movementCounter.value = record.movementCounter
        self.measurementSequenceNumber.value = record.measurementSequenceNumber
        self.txPower.value = record.txPower
        self.compoundKey = record.id
        self.temperatureOffset = record.temperatureOffset
        self.humidityOffset = record.humidityOffset
        self.pressureOffset = record.pressureOffset
    }
}
