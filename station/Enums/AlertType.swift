import Foundation

enum AlertType: CaseIterable {

    case temperature(lower: Double, upper: Double)
    case relativeHumidity(lower: Double, upper: Double)
    case absoluteHumidity(lower: Double, upper: Double)
    case dewPoint(lower: Double, upper: Double)
    case pressure(lower: Double, upper: Double)
    case connection

    static var allCases: [AlertType] {
        return [.temperature(lower: 0, upper: 0),
                .relativeHumidity(lower: 0, upper: 0),
                .absoluteHumidity(lower: 0, upper: 0),
                .dewPoint(lower: 0, upper: 0),
                .pressure(lower: 0, upper: 0),
                .connection]
    }
}

enum AlertState {
    case registered
    case empty
    case firing
}
