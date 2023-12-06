import Foundation

public enum RuuviCloudApiError: Error {
    case connection
    case networking(Error)
    case parsing(Error)
    case api(RuuviCloudApiErrorCode)
    case claim(RuuviCloudApiClaimError)
    case emptyResponse
    case unexpectedHTTPStatusCode
    case failedToGetDataFromResponse
    case unauthorized
}

public struct RuuviCloudApiClaimError: Decodable {
    public let error, code: String?
}
