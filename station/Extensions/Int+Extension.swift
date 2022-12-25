import Foundation

extension Int {
    var stringValue: String {
        return "\(self)"
    }
}

extension Optional where Wrapped == Int {
    var stringValue: String {
        if let self = self {
            return "\(self)"
        } else {
            return "N/A".localized()
        }
    }
}
