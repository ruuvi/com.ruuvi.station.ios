import Foundation

public enum RuuviCloudError: Error {
    case api(RuuviCloudApiError)
    case notAuthorized
}
