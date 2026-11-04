#if SWIFT_PACKAGE
    import RuuviCloud
    import RuuviOntology
#endif
import Foundation

public struct RuuviCloudApiPostSettingResponse: Decodable {
    public let action: String?
}
