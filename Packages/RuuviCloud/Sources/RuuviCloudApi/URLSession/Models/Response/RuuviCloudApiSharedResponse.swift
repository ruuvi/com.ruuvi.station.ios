import Foundation
import RuuviOntology

struct RuuviCloudApiSharedResponse: Decodable {
    let sensors: [CloudApiShareableSensor]

    struct CloudApiShareableSensor: Decodable {
        let sensor: String
        let name: String
        let picture: String
        let isPublic: Bool
        let sharedTo: String

        enum CodingKeys: String, CodingKey {
            case sensor
            case name
            case picture
            case isPublic = "public"
            case sharedTo
        }

        var shareableSensor: ShareableSensor {
            return ShareableSensorStruct(id: sensor, sharedTo: sharedTo)
        }
    }
}
