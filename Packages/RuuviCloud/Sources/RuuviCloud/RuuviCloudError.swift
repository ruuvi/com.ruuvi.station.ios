import Foundation

public enum RuuviCloudError: Error {
    case api(Error)
    case notAuthorized
}
