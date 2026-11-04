#if SWIFT_PACKAGE
    import RuuviCloud
    import RuuviOntology
#endif
import Foundation

public struct RuuviCloudApiSensorImageUploadResponse: Decodable {
    public let uploadURL: URL
}
