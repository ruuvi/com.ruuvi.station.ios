import Foundation

struct RuuviCloudApiSharedResponse: Decodable {
    let sensors: [Sensor]

    struct Sensor: Decodable {
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
    }
}
