import Foundation

public enum RuuviCloudApiError: Error {
    case networking(Error)
    case parsing(Error)
    case api(String)
    case emptyResponse
    case unexpectedHTTPStatusCode
    case failedToGetDataFromResponse
}
