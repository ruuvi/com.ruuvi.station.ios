#if SWIFT_PACKAGE
    import RuuviCloud
    import RuuviOntology
#endif
import Foundation

public struct RuuviCloudApiSensorUpdateResponse: Decodable {
    public let name: String?
}
