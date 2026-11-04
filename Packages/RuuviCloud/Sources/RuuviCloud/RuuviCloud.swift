#if SWIFT_PACKAGE
    import RuuviLocal
#endif
import Foundation
import RuuviOntology
import RuuviPool
import RuuviUser

public struct ValidateCodeResponse {
    public var email: String
    public var apiKey: String

    public init(email: String, apiKey: String) {
        self.email = email
        self.apiKey = apiKey
    }
}

public struct ShareSensorResponse {
    public var macId: MACIdentifier?
    public var invited: Bool?

    public init(macId: MACIdentifier? = nil, invited: Bool? = nil) {
        self.macId = macId
        self.invited = invited
    }
}

public protocol RuuviCloud {
    @discardableResult
    func requestCode(email: String) async throws(RuuviCloudError) -> String?

    @discardableResult
    func validateCode(code: String) async throws(RuuviCloudError) -> ValidateCodeResponse

    @discardableResult
    func deleteAccount(email: String) async throws(RuuviCloudError) -> Bool

    @discardableResult
    func registerPNToken(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) async throws(RuuviCloudError) -> Int

    @discardableResult
    func unregisterPNToken(
        token: String?,
        tokenId: Int?
    ) async throws(RuuviCloudError) -> Bool

    @discardableResult
    func listPNTokens() async throws(RuuviCloudError) -> [RuuviCloudPNToken]

    @discardableResult
    func loadSensors() async throws(RuuviCloudError) -> [AnyCloudSensor]

    @discardableResult
    // swiftlint:disable:next function_parameter_count
    func loadSensorsDense(
        for sensor: RuuviTagSensor?,
        measurements: Bool?,
        sharedToOthers: Bool?,
        sharedToMe: Bool?,
        alerts: Bool?,
        settings: Bool?
    ) async throws(RuuviCloudError) -> [RuuviCloudSensorDense]

    @discardableResult
    func loadRecords(
        macId: MACIdentifier,
        since: Date,
        until: Date?
    ) async throws(RuuviCloudError) -> [AnyRuuviTagSensorRecord]

    @discardableResult
    func claim(
        name: String,
        macId: MACIdentifier
    ) async throws(RuuviCloudError) -> MACIdentifier?

    @discardableResult
    func contest(
        macId: MACIdentifier,
        secret: String
    ) async throws(RuuviCloudError) -> MACIdentifier?

    @discardableResult
    func unclaim(
        macId: MACIdentifier,
        removeCloudHistory: Bool
    ) async throws(RuuviCloudError) -> MACIdentifier

    @discardableResult
    func share(
        macId: MACIdentifier,
        with email: String
    ) async throws(RuuviCloudError) -> ShareSensorResponse

    @discardableResult
    func unshare(
        macId: MACIdentifier,
        with email: String?
    ) async throws(RuuviCloudError) -> MACIdentifier

    @discardableResult
    func loadShared(
        for sensor: RuuviTagSensor
    ) async throws(RuuviCloudError) -> Set<AnyShareableSensor>

    @discardableResult
    func checkOwner(macId: MACIdentifier) async throws(RuuviCloudError) -> (String?, String?)

    @discardableResult
    func update(
        name: String,
        for sensor: RuuviTagSensor
    ) async throws(RuuviCloudError) -> AnyRuuviTagSensor

    @discardableResult
    func upload(
        imageData: Data,
        mimeType: MimeType,
        progress: ((MACIdentifier, Double) -> Void)?,
        for macId: MACIdentifier
    ) async throws(RuuviCloudError) -> URL

    @discardableResult
    func resetImage(
        for macId: MACIdentifier
    ) async throws(RuuviCloudError) -> Void

    @discardableResult
    func getCloudSettings() async throws(RuuviCloudError) -> RuuviCloudSettings?

    @discardableResult
    func set(temperatureUnit: TemperatureUnit) async throws(RuuviCloudError) -> TemperatureUnit

    @discardableResult
    func set(temperatureAccuracy: MeasurementAccuracyType) async throws(RuuviCloudError) -> MeasurementAccuracyType

    @discardableResult
    func set(humidityUnit: HumidityUnit) async throws(RuuviCloudError) -> HumidityUnit

    @discardableResult
    func set(humidityAccuracy: MeasurementAccuracyType) async throws(RuuviCloudError) -> MeasurementAccuracyType

    @discardableResult
    func set(userSetting: RuuviCloudApiSetting, value: String) async throws(RuuviCloudError) -> String

    @discardableResult
    func set(pressureUnit: UnitPressure) async throws(RuuviCloudError) -> UnitPressure

    @discardableResult
    func set(pressureAccuracy: MeasurementAccuracyType) async throws(RuuviCloudError) -> MeasurementAccuracyType

    @discardableResult
    func set(showAllData: Bool) async throws(RuuviCloudError) -> Bool

    @discardableResult
    func set(drawDots: Bool) async throws(RuuviCloudError) -> Bool

    @discardableResult
    func set(chartDuration: Int) async throws(RuuviCloudError) -> Int

    @discardableResult
    func set(showMinMaxAvg: Bool) async throws(RuuviCloudError) -> Bool

    @discardableResult
    func set(cloudMode: Bool) async throws(RuuviCloudError) -> Bool

    @discardableResult
    func set(dashboard: Bool) async throws(RuuviCloudError) -> Bool

    @discardableResult
    func set(dashboardType: DashboardType) async throws(RuuviCloudError) -> DashboardType

    @discardableResult
    func set(dashboardTapActionType: DashboardTapActionType) async throws(RuuviCloudError) -> DashboardTapActionType

    @discardableResult
    func set(disableEmailAlert: Bool) async throws(RuuviCloudError) -> Bool

    @discardableResult
    func set(disablePushAlert: Bool) async throws(RuuviCloudError) -> Bool

    @discardableResult
    func getMarketingConsent() async throws(RuuviCloudError) -> RuuviCloudMarketingConsent

    @discardableResult
    func set(marketingPreference: Bool) async throws(RuuviCloudError) -> RuuviCloudMarketingConsent

    @discardableResult
    func set(profileLanguageCode: String) async throws(RuuviCloudError) -> String

    @discardableResult
    func set(dashboardSensorOrder: [String]) async throws(RuuviCloudError) -> [String]

    @discardableResult
    func updateSensorSettings(
        for sensor: RuuviTagSensor,
        types: [String],
        values: [String],
        timestamp: Int?
    ) async throws(RuuviCloudError) -> AnyRuuviTagSensor

    @discardableResult
    func update(
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?,
        for sensor: RuuviTagSensor
    ) async throws(RuuviCloudError) -> AnyRuuviTagSensor

    @discardableResult
    // swiftlint:disable:next function_parameter_count
    func setAlert(
        type: RuuviCloudAlertType,
        settingType: RuuviCloudAlertSettingType,
        isEnabled: Bool,
        min: Double?,
        max: Double?,
        counter: Int?,
        delay: Int?,
        description: String?,
        for macId: MACIdentifier
    ) async throws(RuuviCloudError) -> Void

    @discardableResult
    func loadAlerts() async throws(RuuviCloudError) -> [RuuviCloudSensorAlerts]

    // MARK: Queued requests

    @discardableResult
    func executeQueuedRequest(from request: RuuviCloudQueuedRequest)
        async throws(RuuviCloudError) -> Bool
}

public protocol RuuviCloudFactory {
    func create(baseUrl: URL, user: RuuviUser, pool: RuuviPool?) -> RuuviCloud
}

public enum MimeType: String, Codable {
    case png = "image/png"
    case gif = "image/gif"
    case jpg = "image/jpeg"
}

// MARK: State Observer
public extension Notification.Name {
    static let RuuviCloudRequestStateDidChange =
        Notification.Name("RuuviCloudRequestStateDidChange")
}

public enum RuuviCloudRequestStateKey: String {
    case state
    case macId
}

public enum RuuviCloudRequestStateType: String {
    case loading
    case success
    case failed
    case complete
}
