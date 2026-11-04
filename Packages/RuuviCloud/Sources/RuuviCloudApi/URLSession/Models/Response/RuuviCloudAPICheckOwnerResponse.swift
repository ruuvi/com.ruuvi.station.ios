#if SWIFT_PACKAGE
    import RuuviCloud
    import RuuviOntology
#endif
import Foundation

public struct RuuviCloudAPICheckOwnerResponse: Decodable {
    public let email: String?
    public let sensor: String?
}
