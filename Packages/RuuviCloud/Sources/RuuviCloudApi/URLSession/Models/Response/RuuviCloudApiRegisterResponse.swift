#if SWIFT_PACKAGE
    import RuuviCloud
    import RuuviOntology
#endif
import Foundation

public struct RuuviCloudApiRegisterResponse: Decodable {
    public let email: String?
}
