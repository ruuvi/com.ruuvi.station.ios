import BTKit
import Foundation
import RealmSwift
import RuuviOntology

public final class RuuviTagLatestDataRealm: Object {
    @objc public dynamic var uuid: String = ""
    @objc public dynamic var ruuviTag: RuuviTagRealm?
    @objc public dynamic var date: Date = .init()
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
        celsius.value?.fahrenheit
    }

    public var kelvin: Double? {
        celsius.value?.kelvin
    }

    public var source: RuuviTagSensorRecordSource {
        RuuviTagSensorRecordSource(rawValue: sourceString) ?? .unknown
    }

    override public static func primaryKey() -> String? {
        "uuid"
    }

    public convenience init(ruuviTag: RuuviTagRealm, data: RuuviTagProtocol, date: Date) {
        self.init(ruuviTag: ruuviTag, data: data)
        self.date = date
    }

    public convenience init(ruuviTag: RuuviTagRealm, data: RuuviTagProtocol) {
        self.init()
        uuid = ruuviTag.uuid
        self.ruuviTag = ruuviTag
        sourceString = data.source.rawValue
        rssi.value = data.rssi
        celsius.value = data.celsius
        humidity.value = data.relativeHumidity
        pressure.value = data.hectopascals
        accelerationX.value = data.accelerationX
        accelerationY.value = data.accelerationY
        accelerationZ.value = data.accelerationZ
        voltage.value = data.volts
        movementCounter.value = data.movementCounter
        measurementSequenceNumber.value = data.measurementSequenceNumber
        txPower.value = data.txPower
    }

    public convenience init(ruuviTag: RuuviTagRealm, data: RuuviTagEnvLogFull) {
        self.init()
        self.ruuviTag = ruuviTag
        sourceString = RuuviTagSensorRecordSource.log.rawValue
        date = data.date
        celsius.value = data.temperature
        humidity.value = data.humidity
        pressure.value = data.pressure
        uuid = ruuviTag.uuid
    }

    public convenience init(ruuviTag: RuuviTagRealm, record: RuuviTagSensorRecord) {
        self.init()
        self.ruuviTag = ruuviTag
        sourceString = record.source.rawValue
        rssi.value = record.rssi
        celsius.value = record.temperature?.converted(to: .celsius).value
        humidity.value = record.humidity?.value
        pressure.value = record.pressure?.converted(to: .hectopascals).value
        accelerationX.value = record.acceleration?.x.value
        accelerationY.value = record.acceleration?.y.value
        accelerationZ.value = record.acceleration?.z.value
        voltage.value = record.voltage?.converted(to: .volts).value
        movementCounter.value = record.movementCounter
        measurementSequenceNumber.value = record.measurementSequenceNumber
        txPower.value = record.txPower
        uuid = record.uuid
        temperatureOffset = record.temperatureOffset
        humidityOffset = record.humidityOffset
        pressureOffset = record.pressureOffset
    }
}
