#if SWIFT_PACKAGE
    import RuuviCloud
    import RuuviOntology
#endif
import Foundation

public struct RuuviCloudApiAccountDeleteResponse: Codable {
    public let email: String?
}
