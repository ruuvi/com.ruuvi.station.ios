import Foundation
import RuuviCloud
import RuuviLocalization

extension RuuviCloudError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .api(error):
            error.errorDescription
        case .notAuthorized:
            RuuviLocalization.RuuviCloudError.notAuthorized
        }
    }
}
