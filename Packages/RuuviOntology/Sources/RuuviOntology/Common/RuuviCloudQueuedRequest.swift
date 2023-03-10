import Foundation

public enum RuuviCloudQueuedRequestType: Int, Codable {
    case none = 0
    case sensor = 1
    case unclaim = 2
    case unshare = 3
    case alert = 4
    case settings = 5
    case uploadImage = 6
}

public enum RuuviCloudQueuedRequestStatusType: Int, Codable {
    case success = 1
    case failed = 2
}

public protocol RuuviCloudQueuedRequest {
    var id: Int64? { get }
    var type: RuuviCloudQueuedRequestType? { get }
    var status: RuuviCloudQueuedRequestStatusType? { get }
    var uniqueKey: String? { get }
    var requestDate: Date? { get }
    var successDate: Date? { get }
    var attempts: Int? { get }
    var requestBodyData: Data? { get }
    var additionalData: Data? { get }
}

extension RuuviCloudQueuedRequest {
    public func with(attempts: Int) -> RuuviCloudQueuedRequest {
        return RuuviCloudQueuedRequestStruct(
            id: id,
            type: type,
            status: status,
            uniqueKey: uniqueKey,
            requestDate: requestDate,
            successDate: successDate,
            attempts: attempts,
            requestBodyData: requestBodyData,
            additionalData: additionalData
        )
    }
}

public struct RuuviCloudQueuedRequestStruct: RuuviCloudQueuedRequest {

    public var id: Int64?
    public var type: RuuviCloudQueuedRequestType?
    public var status: RuuviCloudQueuedRequestStatusType?
    public var uniqueKey: String?
    public var requestDate: Date?
    public var successDate: Date?
    public var attempts: Int?
    public var requestBodyData: Data?
    public var additionalData: Data?

    public init(
        id: Int64?,
        type: RuuviCloudQueuedRequestType?,
        status: RuuviCloudQueuedRequestStatusType?,
        uniqueKey: String?,
        requestDate: Date?,
        successDate: Date?,
        attempts: Int?,
        requestBodyData: Data?,
        additionalData: Data?
    ) {
        self.id = id
        self.type = type
        self.status = status
        self.uniqueKey = uniqueKey
        self.requestDate = requestDate
        self.successDate = successDate
        self.attempts = attempts
        self.requestBodyData = requestBodyData
        self.additionalData = additionalData
    }
}
