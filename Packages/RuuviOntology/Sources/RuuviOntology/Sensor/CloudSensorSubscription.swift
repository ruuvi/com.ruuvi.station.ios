import Foundation

public protocol CloudSensorSubscription: Sendable {
    var id: String { get }
    var macId: String? { get }
    var subscriptionName: String? { get }
    var isActive: Bool? { get }
    var maxClaims: Int? { get }
    var maxHistoryDays: Int? { get }
    var maxResolutionMinutes: Int? { get }
    var maxShares: Int? { get }
    var maxSharesPerSensor: Int? { get }
    var delayedAlertAllowed: Bool? { get }
    var emailAlertAllowed: Bool? { get }
    var offlineAlertAllowed: Bool? { get }
    var pdfExportAllowed: Bool? { get }
    var pushAlertAllowed: Bool? { get }
    var telegramAlertAllowed: Bool? { get }
    var endAt: String? { get }
}

public extension CloudSensorSubscription {
    var id: String {
        if let macId {
            "\(macId)-subscription"
        } else {
            fatalError()
        }
    }
}

public extension CloudSensorSubscription {
    func with(macId: String) -> CloudSensorSubscription {
        CloudSensorSubscriptionStruct(
            macId: macId,
            subscriptionName: subscriptionName,
            isActive: isActive,
            maxClaims: maxClaims,
            maxHistoryDays: maxHistoryDays,
            maxResolutionMinutes: maxResolutionMinutes,
            maxShares: maxShares,
            maxSharesPerSensor: maxSharesPerSensor,
            delayedAlertAllowed: delayedAlertAllowed,
            emailAlertAllowed: emailAlertAllowed,
            offlineAlertAllowed: offlineAlertAllowed,
            pdfExportAllowed: pdfExportAllowed,
            pushAlertAllowed: pushAlertAllowed,
            telegramAlertAllowed: telegramAlertAllowed,
            endAt: endAt
        )
    }
}

public struct CloudSensorSubscriptionStruct: CloudSensorSubscription {

    public var macId: String?
    public var subscriptionName: String?
    public var isActive: Bool?
    public var maxClaims: Int?
    public var maxHistoryDays: Int?
    public var maxResolutionMinutes: Int?
    public var maxShares: Int?
    public var maxSharesPerSensor: Int?
    public var delayedAlertAllowed: Bool?
    public var emailAlertAllowed: Bool?
    public var offlineAlertAllowed: Bool?
    public var pdfExportAllowed: Bool?
    public var pushAlertAllowed: Bool?
    public var telegramAlertAllowed: Bool?
    public var endAt: String?

    init(
        macId: String? = nil,
        subscriptionName: String?,
        isActive: Bool?,
        maxClaims: Int?,
        maxHistoryDays: Int?,
        maxResolutionMinutes: Int?,
        maxShares: Int?,
        maxSharesPerSensor: Int?,
        delayedAlertAllowed: Bool?,
        emailAlertAllowed: Bool?,
        offlineAlertAllowed: Bool?,
        pdfExportAllowed: Bool?,
        pushAlertAllowed: Bool?,
        telegramAlertAllowed: Bool?,
        endAt: String?
    ) {
        self.macId = macId
        self.subscriptionName = subscriptionName
        self.isActive = isActive
        self.maxClaims = maxClaims
        self.maxHistoryDays = maxHistoryDays
        self.maxResolutionMinutes = maxResolutionMinutes
        self.maxShares = maxShares
        self.maxSharesPerSensor = maxSharesPerSensor
        self.delayedAlertAllowed = delayedAlertAllowed
        self.emailAlertAllowed = emailAlertAllowed
        self.offlineAlertAllowed = offlineAlertAllowed
        self.pdfExportAllowed = pdfExportAllowed
        self.pushAlertAllowed = pushAlertAllowed
        self.telegramAlertAllowed = telegramAlertAllowed
        self.endAt = endAt
    }
}
