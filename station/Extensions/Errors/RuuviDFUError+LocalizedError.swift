import RuuviLocalization
import Foundation
import RuuviDFU

extension RuuviDfuError: LocalizedError {
    public var errorDescription: String? {
        return description
    }
}
