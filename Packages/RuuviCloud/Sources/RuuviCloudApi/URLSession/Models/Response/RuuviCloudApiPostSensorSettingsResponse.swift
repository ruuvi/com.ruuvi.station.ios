#if SWIFT_PACKAGE
    import RuuviCloud
    import RuuviOntology
#endif
import Foundation

public struct RuuviCloudApiPostSensorSettingsResponse: Codable {
    public struct DataPayload: Codable {
        public let action: String?
    }

    public let result: String?
    public let data: DataPayload?
}
