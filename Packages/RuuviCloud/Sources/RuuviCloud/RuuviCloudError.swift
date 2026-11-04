#if SWIFT_PACKAGE
    import RuuviOntology
    import RuuviPool
    import RuuviLocal
    import RuuviUser
#endif
import Foundation

public enum RuuviCloudError: Error {
    case api(RuuviCloudApiError)
    case notAuthorized
}
