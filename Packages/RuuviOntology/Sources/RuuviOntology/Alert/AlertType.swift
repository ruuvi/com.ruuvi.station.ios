import Foundation

public enum AlertType: CaseIterable {
    case temperature(lower: Double, upper: Double)
    case humidity(lower: Humidity, upper: Humidity)
    case dewPoint(lower: Double, upper: Double)
    case pressure(lower: Double, upper: Double)
    case connection
    case movement(last: Int)

    public static var allCases: [AlertType] {
        return [.temperature(lower: 0, upper: 0),
                .humidity(lower: Humidity.zeroAbsolute,
                          upper: Humidity.zeroAbsolute),
                .dewPoint(lower: 0, upper: 0),
                .pressure(lower: 0, upper: 0),
                .connection,
                .movement(last: 0)]
    }
}

public enum AlertState {
    case registered
    case empty
    case firing
}
