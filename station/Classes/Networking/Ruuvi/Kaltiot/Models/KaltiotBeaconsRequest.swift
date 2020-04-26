import Foundation

class KaltiotBeaconsRequest: Encodable {
    /// Filter results depending on if the device is movable. Accepted values: yes, no, ignore. Defaults to ignore.
    enum FilterResultsDepending: String, Encodable {
        case yes, no, ignore
        init(_ boolValue: Bool?) {
            switch boolValue {
            case .none:
                self = .ignore
            case .some(true):
                self = .yes
            case .some(false):
                self = .no
            }
        }
    }
    /// Filter results by full ids. Comma-separated.
    private var ids: String?
    /// Return full info (as from GET /beacons/:id) instead of just ids.
    var complete: Bool?
    /// Filter results depending on if the device is movable. Accepted values: yes, no, ignore. Defaults to ignore
    var movable: FilterResultsDepending?
    /// Filter results depending on if the device is a phone. Accepted values: yes, no, ignore. Defaults to ignore.
    var isPhone: FilterResultsDepending?
    /// Page of items to fetch. Starts at 0.
    var page: Int?
    /// Number of items to fetch per page. Default 20
    var perPage: Int?
    /// Wildcard filter for trackable id. Use * to match all beacons with any non-empty trackable id.
    var trackableId: String?
    /// Match all beacons whose location name contains this string.
    var locationName: String?

    enum CodingKeys: String, CodingKey {
        case ids = "ids"
        case complete = "complete"
        case movable = "movable"
        case isPhone = "is_phone"
        case page = "page"
        case perPage = "per_page"
        case trackableId = "trackable_id"
        case locationName = "location_name"
    }
}
extension KaltiotBeaconsRequest {
    var identifiers: [String] {
        get {
            return ids?.components(separatedBy: ",") ?? []
        }
        set {
            ids = newValue.reduce(into: String(), { (result, nextItem) in
                result += nextItem
                if nextItem != newValue.last {
                    result += ","
                }
            })
        }
    }
}
