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
}

extension MeasurementType {
    static var chartsCases: [MeasurementType] {
        [
            .temperature,
            .humidity,
            .pressure,
        ]
    }
}
