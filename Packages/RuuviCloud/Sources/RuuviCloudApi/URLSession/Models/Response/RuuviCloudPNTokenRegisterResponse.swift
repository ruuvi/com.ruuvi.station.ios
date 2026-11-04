#if SWIFT_PACKAGE
    import RuuviCloud
    import RuuviOntology
#endif
import Foundation

public struct RuuviCloudPNTokenRegisterResponse: Decodable {
    public let id: Int
    public let lastAccessed: Int?
    public let name: String?
}
