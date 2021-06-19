import Foundation

public struct RuuviCloudApiGetSensorRequest: Encodable {
    public enum Sort: String, Encodable {
        case asc
        case desc
    }

    let sensor: String
    let until: TimeInterval?
    let since: TimeInterval?
    let limit: Int?
    let sort: Sort?

    public init(
        sensor: String,
        until: TimeInterval?,
        since: TimeInterval?,
        limit: Int?,
        sort: Sort?
    ) {
        self.sensor = sensor
        self.until = until
        self.since = since
        self.limit = limit
        self.sort = sort
    }
}
