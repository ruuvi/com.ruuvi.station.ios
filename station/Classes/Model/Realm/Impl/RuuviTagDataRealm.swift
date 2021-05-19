import RealmSwift
import BTKit
import Foundation

class RuuviTagDataRealm: Object {

    @objc dynamic var ruuviTag: RuuviTagRealm?
    @objc dynamic var date: Date = Date()
    @objc dynamic var compoundKey: String = UUID().uuidString

    // all versions
//    @objc dynamic var rssi: Int = 0
    let rssi = RealmOptional<Int>()
    let celsius = RealmOptional<Double>()
    let humidity = RealmOptional<Double>()
    let pressure = RealmOptional<Double>()

    // v3 & v5
    let accelerationX = RealmOptional<Double>()
    let accelerationY = RealmOptional<Double>()
    let accelerationZ = RealmOptional<Double>()
    let voltage = RealmOptional<Double>()

    // v5
    let movementCounter = RealmOptional<Int>()
    let measurementSequenceNumber = RealmOptional<Int>()
    let txPower = RealmOptional<Int>()

    @objc dynamic var  temperatureOffset: Double = 0.0
    @objc dynamic var  humidityOffset: Double = 0.0
    @objc dynamic var  pressureOffset: Double = 0.0

    var fahrenheit: Double? {
        return celsius.value?.fahrenheit
    }

    var kelvin: Double? {
        return celsius.value?.kelvin
    }

    override static func primaryKey() -> String? {
        return "compoundKey"
    }

    // this one is not use anymore, consider to delete
    convenience init(ruuviTag: RuuviTagRealm, data: RuuviTag) {
        self.init()
        self.ruuviTag = ruuviTag
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
        self.temperatureOffset = data.temperatureOffset
        self.humidityOffset = data.humidityOffset
        self.pressureOffset = data.pressureOffset
    }

    convenience init(ruuviTag: RuuviTagRealm, data: RuuviTagEnvLogFull) {
        self.init()
        self.ruuviTag = ruuviTag
        self.date = data.date
        self.celsius.value = data.temperature
        self.humidity.value = data.humidity
        self.pressure.value = data.pressure
        self.compoundKey = ruuviTag.uuid + "\(date.timeIntervalSince1970)"
    }

    convenience init(ruuviTag: RuuviTagRealm, record: RuuviTagSensorRecord) {
        self.init()
        self.ruuviTag = ruuviTag
        self.rssi.value = record.rssi
        self.celsius.value = record.temperature?.converted(to: .celsius).value
        if let temperature = record.temperature {
            let humidity = record.humidity?.converted(to: .relative(temperature: temperature))
            self.humidity.value = humidity?.value
        }
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
