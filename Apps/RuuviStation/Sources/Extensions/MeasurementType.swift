enum MeasurementType: String {
    case rssi
    case temperature
    case humidity
    case pressure
    // v3 & v5
    case acceleration
    case voltage
    // v5
    case movementCounter
    case txPower
    // E0/F0
    case aqi
    case co2
    case pm25
    case pm10
    case nox
    case voc
    case luminosity
    case sound
}

extension MeasurementType {
    static var chartsCases: [MeasurementType] {
        [
            .temperature,
            .humidity,
            .pressure,
            .aqi,
            .co2,
            .pm25,
            .pm10,
            .nox,
            .voc,
            .luminosity,
            .sound,
        ]
    }
}
