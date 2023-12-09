import Foundation
import RuuviLocalization

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
            return RuuviLocalization.na
        }
    }
}
