import Foundation
import Future
import RuuviOntology

public extension Notification.Name {
    static let RuuviServiceAlertDidChange = Notification.Name("RuuviServiceAlertDidChange")
    static let RuuviServiceAlertTriggerDidChange =
        Notification.Name("RuuviServiceAlertTriggerDidChange")
}

public enum RuuviServiceAlertDidChangeKey: String {
    case physicalSensor
    case type
}

public protocol RuuviServiceAlert: RuuviServiceAlertRuuviTag,
    RuuviServiceAlertPhysicalSensor,
    RuuviServiceAlertCloud,
    RuuviServiceAlertDeprecated {}

public protocol RuuviServiceAlertRuuviTag {
    func register(type: AlertType, ruuviTag: RuuviTagSensor)
    func unregister(type: AlertType, ruuviTag: RuuviTagSensor)
    func remove(type: AlertType, ruuviTag: RuuviTagSensor)

    // temperature (celsius)
    func setLower(celsius: Double?, ruuviTag: RuuviTagSensor)
    func setUpper(celsius: Double?, ruuviTag: RuuviTagSensor)
    func setTemperature(description: String?, ruuviTag: RuuviTagSensor)

    // relative humidity (fraction of one)
    func setLower(relativeHumidity: Double?, ruuviTag: RuuviTagSensor)
    func setUpper(relativeHumidity: Double?, ruuviTag: RuuviTagSensor)
    func setRelativeHumidity(description: String?, ruuviTag: RuuviTagSensor)

    // pressure
    func setLower(pressure: Double?, ruuviTag: RuuviTagSensor)
    func setUpper(pressure: Double?, ruuviTag: RuuviTagSensor)
    func setPressure(description: String?, ruuviTag: RuuviTagSensor)

    // signal (dB)
    func setLower(signal: Double?, ruuviTag: RuuviTagSensor)
    func setUpper(signal: Double?, ruuviTag: RuuviTagSensor)
    func setSignal(description: String?, ruuviTag: RuuviTagSensor)

    // Carbon Dioxide
    func setLower(carbonDioxide: Double?, ruuviTag: RuuviTagSensor)
    func setUpper(carbonDioxide: Double?, ruuviTag: RuuviTagSensor)
    func setCarbonDioxide(description: String?, ruuviTag: RuuviTagSensor)

    // PM1
    func setLower(pm1: Double?, ruuviTag: RuuviTagSensor)
    func setUpper(pm1: Double?, ruuviTag: RuuviTagSensor)
    func setPM1(description: String?, ruuviTag: RuuviTagSensor)

    // PM2.5
    func setLower(pm25: Double?, ruuviTag: RuuviTagSensor)
    func setUpper(pm25: Double?, ruuviTag: RuuviTagSensor)
    func setPM25(description: String?, ruuviTag: RuuviTagSensor)

    // PM4
    func setLower(pm4: Double?, ruuviTag: RuuviTagSensor)
    func setUpper(pm4: Double?, ruuviTag: RuuviTagSensor)
    func setPM4(description: String?, ruuviTag: RuuviTagSensor)

    // PM10
    func setLower(pm10: Double?, ruuviTag: RuuviTagSensor)
    func setUpper(pm10: Double?, ruuviTag: RuuviTagSensor)
    func setPM10(description: String?, ruuviTag: RuuviTagSensor)

    // VOC
    func setLower(voc: Double?, ruuviTag: RuuviTagSensor)
    func setUpper(voc: Double?, ruuviTag: RuuviTagSensor)
    func setVOC(description: String?, ruuviTag: RuuviTagSensor)

    // NOX
    func setLower(nox: Double?, ruuviTag: RuuviTagSensor)
    func setUpper(nox: Double?, ruuviTag: RuuviTagSensor)
    func setNOX(description: String?, ruuviTag: RuuviTagSensor)

    // Sound
    func setLower(sound: Double?, ruuviTag: RuuviTagSensor)
    func setUpper(sound: Double?, ruuviTag: RuuviTagSensor)
    func setSound(description: String?, ruuviTag: RuuviTagSensor)

    // Luminosity
    func setLower(luminosity: Double?, ruuviTag: RuuviTagSensor)
    func setUpper(luminosity: Double?, ruuviTag: RuuviTagSensor)
    func setLuminosity(description: String?, ruuviTag: RuuviTagSensor)

    // movement
    func setMovement(description: String?, ruuviTag: RuuviTagSensor)

    // Cloud connection
    func setCloudConnection(unseenDuration: Double?, ruuviTag: RuuviTagSensor)
    func setCloudConnection(description: String?, ruuviTag: RuuviTagSensor)
}

public protocol RuuviServiceAlertCloud {
    func sync(cloudAlerts: [RuuviCloudSensorAlerts])
}

public protocol RuuviServiceAlertDeprecated {
    func isOn(type: AlertType, for uuid: String) -> Bool
    func alert(for uuid: String, of type: AlertType) -> AlertType?
    func mutedTill(type: AlertType, for uuid: String) -> Date?

    // temperature (celsius)
    func lowerCelsius(for uuid: String) -> Double?
    func upperCelsius(for uuid: String) -> Double?
    func temperatureDescription(for uuid: String) -> String?

    // humidity (fraction of one)
    func lowerRelativeHumidity(for uuid: String) -> Double?
    func upperRelativeHumidity(for uuid: String) -> Double?
    func relativeHumidityDescription(for uuid: String) -> String?

    // humidity (unitHumidity)
    func lowerHumidity(for uuid: String) -> Humidity?
    func upperHumidity(for uuid: String) -> Humidity?
    func humidityDescription(for uuid: String) -> String?

    // pressure (hPa)
    func lowerPressure(for uuid: String) -> Double?
    func upperPressure(for uuid: String) -> Double?
    func pressureDescription(for uuid: String) -> String?

    // Signal (RSSI)
    func lowerSignal(for uuid: String) -> Double?
    func upperSignal(for uuid: String) -> Double?
    func signalDescription(for uuid: String) -> String?

    // Carbon Dioxide
    func lowerCarbonDioxide(for uuid: String) -> Double?
    func upperCarbonDioxide(for uuid: String) -> Double?
    func carbonDioxideDescription(for uuid: String) -> String?

    // PM1
    func lowerPM1(for uuid: String) -> Double?
    func upperPM1(for uuid: String) -> Double?
    func pm1Description(for uuid: String) -> String?

    // PM2.5
    func lowerPM25(for uuid: String) -> Double?
    func upperPM25(for uuid: String) -> Double?
    func pm25Description(for uuid: String) -> String?

    // PM4
    func lowerPM4(for uuid: String) -> Double?
    func upperPM4(for uuid: String) -> Double?
    func pm4Description(for uuid: String) -> String?

    // PM10
    func lowerPM10(for uuid: String) -> Double?
    func upperPM10(for uuid: String) -> Double?
    func pm10Description(for uuid: String) -> String?

    // VOC
    func lowerVOC(for uuid: String) -> Double?
    func upperVOC(for uuid: String) -> Double?
    func vocDescription(for uuid: String) -> String?

    // NOX
    func lowerNOX(for uuid: String) -> Double?
    func upperNOX(for uuid: String) -> Double?
    func noxDescription(for uuid: String) -> String?

    // Sound
    func lowerSound(for uuid: String) -> Double?
    func upperSound(for uuid: String) -> Double?
    func soundDescription(for uuid: String) -> String?

    // Luminosity
    func lowerLuminosity(for uuid: String) -> Double?
    func upperLuminosity(for uuid: String) -> Double?
    func luminosityDescription(for uuid: String) -> String?

    // connection
    func connectionDescription(for uuid: String) -> String?

    // movement
    func movementCounter(for uuid: String) -> Int?
    func movementDescription(for uuid: String) -> String?
}

public protocol RuuviServiceAlertPhysicalSensor {
    // physical sensor
    func hasRegistrations(for sensor: PhysicalSensor) -> Bool
    func isOn(type: AlertType, for sensor: PhysicalSensor) -> Bool
    func alert(for sensor: PhysicalSensor, of type: AlertType) -> AlertType?
    func mute(type: AlertType, for sensor: PhysicalSensor, till date: Date)
    func unmute(type: AlertType, for sensor: PhysicalSensor)
    func mutedTill(type: AlertType, for sensor: PhysicalSensor) -> Date?
    func trigger(type: AlertType, trigerred: Bool?, trigerredAt: String?, for sensor: PhysicalSensor)
    func triggered(for sensor: PhysicalSensor, of type: AlertType) -> Bool?
    func triggeredAt(for sensor: PhysicalSensor, of type: AlertType) -> String?

    // temperature (celsius)
    func lowerCelsius(for sensor: PhysicalSensor) -> Double?
    func upperCelsius(for sensor: PhysicalSensor) -> Double?
    func temperatureDescription(for sensor: PhysicalSensor) -> String?

    // relative humidity (fraction of one)
    func lowerRelativeHumidity(for sensor: PhysicalSensor) -> Double?
    func upperRelativeHumidity(for sensor: PhysicalSensor) -> Double?
    func relativeHumidityDescription(for sensor: PhysicalSensor) -> String?

    // humidity (unitHumidity)
    func lowerHumidity(for sensor: PhysicalSensor) -> Humidity?
    func setLower(humidity: Humidity?, for sensor: PhysicalSensor)
    func upperHumidity(for sensor: PhysicalSensor) -> Humidity?
    func setUpper(humidity: Humidity?, for sensor: PhysicalSensor)
    func humidityDescription(for sensor: PhysicalSensor) -> String?
    func setHumidity(description: String?, for sensor: PhysicalSensor)

    /// pressure (hPa)
    func lowerPressure(for sensor: PhysicalSensor) -> Double?
    func upperPressure(for sensor: PhysicalSensor) -> Double?
    func pressureDescription(for sensor: PhysicalSensor) -> String?

    // signal (dB)
    func lowerSignal(for sensor: PhysicalSensor) -> Double?
    func upperSignal(for sensor: PhysicalSensor) -> Double?
    func signalDescription(for sensor: PhysicalSensor) -> String?

    // Carbon Dioxide
    func lowerCarbonDioxide(for sensor: PhysicalSensor) -> Double?
    func upperCarbonDioxide(for sensor: PhysicalSensor) -> Double?
    func carbonDioxideDescription(for sensor: PhysicalSensor) -> String?

    // PM1
    func lowerPM1(for sensor: PhysicalSensor) -> Double?
    func upperPM1(for sensor: PhysicalSensor) -> Double?
    func pm1Description(for sensor: PhysicalSensor) -> String?

    // PM2.5
    func lowerPM25(for sensor: PhysicalSensor) -> Double?
    func upperPM25(for sensor: PhysicalSensor) -> Double?
    func pm25Description(for sensor: PhysicalSensor) -> String?

    // PM4
    func lowerPM4(for sensor: PhysicalSensor) -> Double?
    func upperPM4(for sensor: PhysicalSensor) -> Double?
    func pm4Description(for sensor: PhysicalSensor) -> String?

    // PM10
    func lowerPM10(for sensor: PhysicalSensor) -> Double?
    func upperPM10(for sensor: PhysicalSensor) -> Double?
    func pm10Description(for sensor: PhysicalSensor) -> String?

    // VOC
    func lowerVOC(for sensor: PhysicalSensor) -> Double?
    func upperVOC(for sensor: PhysicalSensor) -> Double?
    func vocDescription(for sensor: PhysicalSensor) -> String?

    // NOX
    func lowerNOX(for sensor: PhysicalSensor) -> Double?
    func upperNOX(for sensor: PhysicalSensor) -> Double?
    func noxDescription(for sensor: PhysicalSensor) -> String?

    // Sound
    func lowerSound(for sensor: PhysicalSensor) -> Double?
    func upperSound(for sensor: PhysicalSensor) -> Double?
    func soundDescription(for sensor: PhysicalSensor) -> String?

    // Luminosity
    func lowerLuminosity(for sensor: PhysicalSensor) -> Double?
    func upperLuminosity(for sensor: PhysicalSensor) -> Double?
    func luminosityDescription(for sensor: PhysicalSensor) -> String?

    // connection
    func connectionDescription(for sensor: PhysicalSensor) -> String?
    func setConnection(description: String?, for sensor: PhysicalSensor)

    // cloud connection
    func setCloudConnection(unseenDuration: Double?, for sensor: PhysicalSensor)
    func cloudConnectionUnseenDuration(for sensor: PhysicalSensor) -> Double?
    func cloudConnectionDescription(for sensor: PhysicalSensor) -> String?
    func setCloudConnection(description: String?, for sensor: PhysicalSensor)

    // movement
    func movementCounter(for sensor: PhysicalSensor) -> Int?
    func setMovement(counter: Int?, for sensor: PhysicalSensor)
    func movementDescription(for sensor: PhysicalSensor) -> String?
}
