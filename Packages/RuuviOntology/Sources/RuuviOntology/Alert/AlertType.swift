import Foundation

public enum AlertType: CaseIterable {
    case temperature(lower: Double, upper: Double) // celsius
    case humidity(lower: Humidity, upper: Humidity)
    case relativeHumidity(lower: Double, upper: Double) // fraction of one
    case pressure(lower: Double, upper: Double) // hPa
    case signal(lower: Double, upper: Double) // dB
    case connection
    case cloudConnection(unseenDuration: Double)
    case movement(last: Int)

    public static var allCases: [AlertType] {
        return [.temperature(lower: 0, upper: 0),
                .relativeHumidity(lower: 0, upper: 0),
                .humidity(lower: Humidity.zeroAbsolute,
                          upper: Humidity.zeroAbsolute),
                .pressure(lower: 0, upper: 0),
                .signal(lower: 0, upper: 0),
                .connection,
                .cloudConnection(unseenDuration: 0),
                .movement(last: 0)]
    }
}

public enum AlertState {
    case registered
    case empty
    case firing
}
