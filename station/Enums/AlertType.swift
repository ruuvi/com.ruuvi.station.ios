import Foundation

enum AlertType: CaseIterable {

    case temperature(lower: Double, upper: Double)
    case relativeHumidity(lower: Double, upper: Double)
    
    static var allCases: [AlertType] {
        return [.temperature(lower: 0, upper: 0), .relativeHumidity(lower: 0, upper: 0)]
    }
}

enum AlertState {
    case registered
    case empty
    case firing
}
