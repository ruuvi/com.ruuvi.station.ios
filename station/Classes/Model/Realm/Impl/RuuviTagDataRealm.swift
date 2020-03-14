import RealmSwift
import BTKit
import Foundation

class RuuviTagDataRealm: Object {

    @objc dynamic var ruuviTag: RuuviTagRealmImpl?
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

    var fahrenheit: Double? {
        return celsius.value?.fahrenheit
    }

    var kelvin: Double? {
        return celsius.value?.kelvin
    }

    override static func primaryKey() -> String? {
        return "compoundKey"
    }

    convenience init(ruuviTag: RuuviTagRealmImpl, data: RuuviTag) {
        self.init()
        self.ruuviTag = ruuviTag
        self.rssi.value = data.rssi
        self.celsius.value = data.celsius
        self.humidity.value = data.humidity
        self.pressure.value = data.pressure
        self.accelerationX.value = data.accelerationX
        self.accelerationY.value = data.accelerationY
        self.accelerationZ.value = data.accelerationZ
        self.voltage.value = data.voltage
        self.movementCounter.value = data.movementCounter
        self.measurementSequenceNumber.value = data.measurementSequenceNumber
        self.txPower.value = data.txPower
        self.compoundKey = ruuviTag.uuid + "\(date.timeIntervalSince1970)"
    }

    convenience init(ruuviTag: RuuviTagRealmImpl, data: RuuviTagEnvLogFull) {
        self.init()
        self.ruuviTag = ruuviTag
        self.date = data.date
        self.celsius.value = data.temperature
        self.humidity.value = data.humidity
        self.pressure.value = data.pressure
        self.compoundKey = ruuviTag.uuid + "\(date.timeIntervalSince1970)"
    }
}
