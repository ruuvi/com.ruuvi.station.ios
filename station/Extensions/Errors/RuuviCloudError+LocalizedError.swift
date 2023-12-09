import RuuviCloud
import Foundation
import RuuviLocalization

extension RuuviCloudError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .api(let error):
            return error.errorDescription
        case .notAuthorized:
            return RuuviLocalization.RuuviCloudError.notAuthorized
        }
    }
}
