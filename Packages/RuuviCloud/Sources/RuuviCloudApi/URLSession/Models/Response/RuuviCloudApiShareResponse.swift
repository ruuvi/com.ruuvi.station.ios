#if SWIFT_PACKAGE
    import RuuviCloud
    import RuuviOntology
#endif
import Foundation

public struct RuuviCloudApiShareResponse: Decodable {
    public let sensor: String?
    public let invited: Bool?
}
