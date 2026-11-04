#if SWIFT_PACKAGE
    import RuuviCloud
    import RuuviOntology
#endif
import Foundation

public struct RuuviCloudApiVerifyRequest: Encodable {
    var token: String
    public init(token: String) {
        self.token = token
    }
}
