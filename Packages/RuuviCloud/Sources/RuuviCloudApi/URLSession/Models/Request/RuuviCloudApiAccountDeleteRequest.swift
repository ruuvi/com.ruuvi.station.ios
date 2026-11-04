#if SWIFT_PACKAGE
    import RuuviCloud
    import RuuviOntology
#endif
import Foundation

public struct RuuviCloudApiAccountDeleteRequest: Encodable {
    var email: String
    public init(email: String) {
        self.email = email
    }
}
