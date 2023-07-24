import Foundation
import RuuviOntology

public struct RuuviCloudApiGetSensorsResponse: Decodable {
    public let sensors: [CloudApiShareableSensor]?

    public struct CloudApiShareableSensor: Decodable {
        public let sensor: String
        public let name: String?
        public let picture: String?
        public let isPublic: Bool?
        public let canShare: Bool?
        public let sharedTo: [String]?

        enum CodingKeys: String, CodingKey {
            case sensor
            case name
            case picture
            case isPublic = "public"
            case canShare
            case sharedTo
        }

        public var shareableSensor: ShareableSensor {
            return ShareableSensorStruct(
                id: sensor,
                canShare: canShare ?? false,
                sharedTo: sharedTo ?? []
            )
        }
    }
}
