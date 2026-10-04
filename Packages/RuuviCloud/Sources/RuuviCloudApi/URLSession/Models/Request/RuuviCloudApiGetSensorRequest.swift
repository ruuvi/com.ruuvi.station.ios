import Foundation

public struct RuuviCloudApiGetSensorRequest: Encodable {
    public enum Sort: String, Encodable {
        case asc
        case desc
    }

    let mode: String?
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
        sort: Sort?,
        mode: String? = nil
    ) {
        self.mode = mode
        self.sensor = sensor
        self.until = until
        self.since = since
        self.limit = limit
        self.sort = sort
    }
}
