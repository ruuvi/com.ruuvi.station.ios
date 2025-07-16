import Foundation
import RuuviOntology

protocol AlertPersistence {
    func alert(for uuid: String, of type: AlertType) -> AlertType?
    func register(type: AlertType, for uuid: String)
    func unregister(type: AlertType, for uuid: String)
    func remove(type: AlertType, for uuid: String)
    func mute(type: AlertType, for uuid: String, till date: Date)
    func unmute(type: AlertType, for uuid: String)
    func mutedTill(type: AlertType, for uuid: String) -> Date?
    func trigger(type: AlertType, trigerred: Bool?, trigerredAt: String?, for uuid: String)
    func triggered(for uuid: String, of type: AlertType) -> Bool?
    func triggeredAt(for uuid: String, of type: AlertType) -> String?

    // temperature (celsius)
    func lowerCelsius(for uuid: String) -> Double?
    func setLower(celsius: Double?, for uuid: String)
    func upperCelsius(for uuid: String) -> Double?
    func setUpper(celsius: Double?, for uuid: String)
    func temperatureDescription(for uuid: String) -> String?
    func setTemperature(description: String?, for uuid: String)

    // humidity (fraction of one)
    func lowerRelativeHumidity(for uuid: String) -> Double?
    func setLower(relativeHumidity: Double?, for uuid: String)
    func upperRelativeHumidity(for uuid: String) -> Double?
    func setUpper(relativeHumidity: Double?, for uuid: String)
    func relativeHumidityDescription(for uuid: String) -> String?
    func setRelativeHumidity(description: String?, for uuid: String)

    // humidity (unit humidity)
    func lowerHumidity(for uuid: String) -> Humidity?
    func setLower(humidity: Humidity?, for uuid: String)
    func upperHumidity(for uuid: String) -> Humidity?
    func setUpper(humidity: Humidity?, for uuid: String)
    func humidityDescription(for uuid: String) -> String?
    func setHumidity(description: String?, for uuid: String)

    // pressure (hPa)
    func lowerPressure(for uuid: String) -> Double?
    func setLower(pressure: Double?, for uuid: String)
    func upperPressure(for uuid: String) -> Double?
    func setUpper(pressure: Double?, for uuid: String)
    func pressureDescription(for uuid: String) -> String?
    func setPressure(description: String?, for uuid: String)

    // Signal
    func lowerSignal(for uuid: String) -> Double?
    func setLower(signal: Double?, for uuid: String)
    func upperSignal(for uuid: String) -> Double?
    func setUpper(signal: Double?, for uuid: String)
    func signalDescription(for uuid: String) -> String?
    func setSignal(description: String?, for uuid: String)

    // AQI
    func lowerAQI(for uuid: String) -> Double?
    func setLower(aqi: Double?, for uuid: String)
    func upperAQI(for uuid: String) -> Double?
    func setUpper(aqi: Double?, for uuid: String)
    func aqiDescription(for uuid: String) -> String?
    func setAQI(description: String?, for uuid: String)

    // Carbon Dioxide
    func lowerCarbonDioxide(for uuid: String) -> Double?
    func setLower(carbonDioxide: Double?, for uuid: String)
    func upperCarbonDioxide(for uuid: String) -> Double?
    func setUpper(carbonDioxide: Double?, for uuid: String)
    func carbonDioxideDescription(for uuid: String) -> String?
    func setCarbonDioxide(description: String?, for uuid: String)

    // PM1
    func lowerPM1(for uuid: String) -> Double?
    func setLower(pm1: Double?, for uuid: String)
    func upperPM1(for uuid: String) -> Double?
    func setUpper(pm1: Double?, for uuid: String)
    func pm1Description(for uuid: String) -> String?
    func setPM1(description: String?, for uuid: String)

    // PM2.5
    func lowerPM25(for uuid: String) -> Double?
    func setLower(pm25: Double?, for uuid: String)
    func upperPM25(for uuid: String) -> Double?
    func setUpper(pm25: Double?, for uuid: String)
    func pm25Description(for uuid: String) -> String?
    func setPM25(description: String?, for uuid: String)

    // PM4
    func lowerPM4(for uuid: String) -> Double?
    func setLower(pm4: Double?, for uuid: String)
    func upperPM4(for uuid: String) -> Double?
    func setUpper(pm4: Double?, for uuid: String)
    func pm4Description(for uuid: String) -> String?
    func setPM4(description: String?, for uuid: String)

    // PM10
    func lowerPM10(for uuid: String) -> Double?
    func setLower(pm10: Double?, for uuid: String)
    func upperPM10(for uuid: String) -> Double?
    func setUpper(pm10: Double?, for uuid: String)
    func pm10Description(for uuid: String) -> String?
    func setPM10(description: String?, for uuid: String)

    // VOC
    func lowerVOC(for uuid: String) -> Double?
    func setLower(voc: Double?, for uuid: String)
    func upperVOC(for uuid: String) -> Double?
    func setUpper(voc: Double?, for uuid: String)
    func vocDescription(for uuid: String) -> String?
    func setVOC(description: String?, for uuid: String)

    // NOX
    func lowerNOX(for uuid: String) -> Double?
    func setLower(nox: Double?, for uuid: String)
    func upperNOX(for uuid: String) -> Double?
    func setUpper(nox: Double?, for uuid: String)
    func noxDescription(for uuid: String) -> String?
    func setNOX(description: String?, for uuid: String)

    // Sound Instant
    func lowerSoundInstant(for uuid: String) -> Double?
    func setLower(soundInstant: Double?, for uuid: String)
    func upperSoundInstant(for uuid: String) -> Double?
    func setUpper(soundInstant: Double?, for uuid: String)
    func soundInstantDescription(for uuid: String) -> String?
    func setSoundInstant(description: String?, for uuid: String)

    // Sound Average
    func lowerSoundAverage(for uuid: String) -> Double?
    func setLower(soundAverage: Double?, for uuid: String)
    func upperSoundAverage(for uuid: String) -> Double?
    func setUpper(soundAverage: Double?, for uuid: String)
    func soundAverageDescription(for uuid: String) -> String?
    func setSoundAverage(description: String?, for uuid: String)

    // Sound Peak
    func lowerSoundPeak(for uuid: String) -> Double?
    func setLower(soundPeak: Double?, for uuid: String)
    func upperSoundPeak(for uuid: String) -> Double?
    func setUpper(soundPeak: Double?, for uuid: String)
    func soundPeakDescription(for uuid: String) -> String?
    func setSoundPeak(description: String?, for uuid: String)

    // Luminosity
    func lowerLuminosity(for uuid: String) -> Double?
    func setLower(luminosity: Double?, for uuid: String)
    func upperLuminosity(for uuid: String) -> Double?
    func setUpper(luminosity: Double?, for uuid: String)
    func luminosityDescription(for uuid: String) -> String?
    func setLuminosity(description: String?, for uuid: String)

    // connection
    func connectionDescription(for uuid: String) -> String?
    func setConnection(description: String?, for uuid: String)

    // cloud connection
    func cloudConnectionUnseenDuration(for uuid: String) -> Double?
    func setCloudConnection(unseenDuration: Double?, for uuid: String)
    func cloudConnectionDescription(for uuid: String) -> String?
    func setCloudConnection(description: String?, for uuid: String)

    // movement counter
    func movementCounter(for uuid: String) -> Int?
    func setMovement(counter: Int?, for uuid: String)
    func movementDescription(for uuid: String) -> String?
    func setMovement(description: String?, for uuid: String)
}
