import Foundation

public enum RuuviCloudApiError: Error {
    case connection
    case networking(Error)
    case parsing(Error)
    case api(RuuviCloudApiErrorCode)
    case emptyResponse
    case unexpectedHTTPStatusCode
    case failedToGetDataFromResponse
    case unauthorized
}
