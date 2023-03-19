import Foundation
import RuuviCloud

extension RuuviCloudApiError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .connection:
            return "internet_connection_problem".localized()
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
        case .unauthorized:
            return nil

        }
    }
}
