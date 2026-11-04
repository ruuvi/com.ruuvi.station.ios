#if SWIFT_PACKAGE
    import RuuviCloud
    import RuuviOntology
#endif
import Foundation

public struct RuuviCloudApiGetAlertsRequest: Encodable {
    var sensor: String?
    public init() {}
}
