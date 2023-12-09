import Foundation
import RuuviLocalization

extension Int {
    var stringValue: String {
        "\(self)"
    }
}

extension Int? {
    var stringValue: String {
        if let self {
            "\(self)"
        } else {
            RuuviLocalization.na
        }
    }
}
