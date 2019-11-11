import Foundation

enum AlertType: CaseIterable {
    
    case temperature(lower: Double, upper: Double)
    
    static var allCases: [AlertType] {
        return [.temperature(lower: 0, upper: 0)]
    }
}
