import Foundation

struct RuuviCloudApiGetSensorRequest: Encodable {
    enum Sort: String, Encodable {
        case asc
        case desc
    }

    let sensor: String
    let until: TimeInterval?
    let since: TimeInterval?
    let limit: Int?
    let sort: Sort?
}
