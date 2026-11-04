#if SWIFT_PACKAGE
    import RuuviCloud
    import RuuviOntology
#endif
import Foundation

public struct RuuviCloudApiContestRequest: Codable {
    let sensor: String
    let secret: String

    public init(sensor: String, secret: String) {
        self.sensor = sensor
        self.secret = secret
    }
}
