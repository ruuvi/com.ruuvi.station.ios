import Foundation
import RuuviDFU
import RuuviLocalization

extension RuuviDfuError: LocalizedError {
    public var errorDescription: String? {
        description
    }
}
