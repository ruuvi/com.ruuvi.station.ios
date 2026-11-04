#if SWIFT_PACKAGE
    import RuuviCloud
    import RuuviOntology
#endif
import Foundation

public struct RuuviCloudApiClaimResponse: Decodable {
    public let sensor: String?
}

public struct RuuviCloudApiUnclaimResponse: Decodable {}
