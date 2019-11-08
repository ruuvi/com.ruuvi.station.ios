import Foundation

enum AlertType: CaseIterable {
    
    case temperature(lower: Int, upper: Int)
    
    static var allCases: [AlertType] {
        return [.temperature(lower: 0, upper: 0)]
    }
}
