#if SWIFT_PACKAGE
    import RuuviOntology
    import RuuviPool
    import RuuviLocal
    import RuuviUser
#endif
import Foundation

public enum RuuviCloudApiError: Error {
    case connection
    case networking(Error)
    case parsing(Error)
    case api(RuuviCloudApiErrorCode)
    case emptyResponse
    case unexpectedHTTPStatusCode(Int)
    case unexpectedHTTPStatusCodeShouldRetry(Int)
    case failedToGetDataFromResponse
    case badParameters
}
