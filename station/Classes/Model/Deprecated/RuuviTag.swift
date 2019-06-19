import RealmSwift

class RuuviTagOld: Object  {
    @objc dynamic var uuid: String = ""
    @objc dynamic var mac: String = ""
    @objc dynamic var name: String = ""
    @objc dynamic var dataFormat: Int = 0
    @objc dynamic var temperature: Double = 0.0
    @objc dynamic var humidity: Double = 0.0
    @objc dynamic var pressure: Double = 0.0
    @objc dynamic var accelerationX: Double = 0.0
    @objc dynamic var accelerationY: Double = 0.0
    @objc dynamic var accelerationZ: Double = 0.0
    @objc dynamic var rssi: Int = 0
    @objc dynamic var voltage: Double = 0.0
    @objc dynamic var movementCounter: Int = 0
    @objc dynamic var measurementSequenceNumber: Int = 0
    @objc dynamic var txPower: Int = 0
    @objc dynamic var updatedAt: NSDate? = nil
    @objc dynamic var defaultBackground: Int = 1
    
    override static func primaryKey() -> String {
        return "uuid"
    }
}
