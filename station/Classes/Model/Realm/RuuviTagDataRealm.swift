import RealmSwift
import BTKit

class RuuviTagDataRealm: Object {
    
    @objc dynamic var ruuviTag: RuuviTagRealm?
    @objc dynamic var date: Date = Date()
    
    // all versions
    @objc dynamic var rssi: Int = 0
    @objc dynamic var celsius: Double = 0.0
    @objc dynamic var humidity: Double = 0.0
    @objc dynamic var pressure: Double = 0.0
    
    // v3 & v5
    let accelerationX = RealmOptional<Double>()
    let accelerationY = RealmOptional<Double>()
    let accelerationZ = RealmOptional<Double>()
    let voltage = RealmOptional<Double>()
    
    // v5
    let movementCounter = RealmOptional<Int>()
    let measurementSequenceNumber = RealmOptional<Int>()
    let txPower = RealmOptional<Int>()

    var fahrenheit: Double {
        return (celsius * 9.0/5.0) + 32.0
    }
    
    convenience init(ruuviTag: RuuviTagRealm, data: RuuviTag) {
        self.init()
        self.ruuviTag = ruuviTag
        self.rssi = data.rssi
        self.celsius = data.celsius
        self.humidity = data.humidity
        self.pressure = data.pressure
        self.accelerationX.value = data.accelerationX
        self.accelerationY.value = data.accelerationY
        self.accelerationZ.value = data.accelerationZ
        self.voltage.value = data.voltage
        self.movementCounter.value = data.movementCounter
        self.measurementSequenceNumber.value = data.measurementSequenceNumber
        self.txPower.value = data.txPower
    }
}
