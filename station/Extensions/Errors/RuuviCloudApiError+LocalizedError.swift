import Foundation
import RuuviCloud
import Localize_Swift

extension RuuviCloudApiError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "RuuviCloudApiError.emptyResponse".localized()
        case .failedToGetDataFromResponse:
            return "RuuviCloudApiError.failedToGetDataFromResponse".localized()
        case .unexpectedHTTPStatusCode:
            return "RuuviCloudApiError.unexpectedHTTPStatusCode".localized()
        case .api(let code):
            return code.localized()
        case .claim(let claimError):
            return claimError.error.localized()
        case .networking(let error):
            return error.localizedDescription
        case .parsing(let error):
            return error.localizedDescription

        }
    }
}
