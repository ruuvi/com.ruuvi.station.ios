import Foundation
import RuuviDFU
import Localize_Swift

extension RuuviDfuError: LocalizedError {
    public var errorDescription: String? {
        return description.localized()
    }
}
