import Foundation
import RuuviDFU
import RuuviLocalization

extension RuuviDfuError: @retroactive LocalizedError {
    public var errorDescription: String? {
        description
    }
}
