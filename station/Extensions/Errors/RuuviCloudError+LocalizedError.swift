import RuuviCloud
import Foundation

extension RuuviCloudError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .api(let error):
            return error.errorDescription
        case .notAuthorized:
            return "RuuviCloudError.NotAuthorized".localized()
        }
    }
}
