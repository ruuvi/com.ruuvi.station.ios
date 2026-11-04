#if SWIFT_PACKAGE
    import RuuviCloud
    import RuuviOntology
#endif
import Foundation

public struct RuuviCloudApiGetSensorsRequest: Encodable {
    let sensor: String

    public init(sensor: String) {
        self.sensor = sensor
    }
}
