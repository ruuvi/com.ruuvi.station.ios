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
    func requestCode(email: String) async throws -> String?

    @discardableResult
    func validateCode(code: String) async throws -> ValidateCodeResponse

    @discardableResult
    func deleteAccount(email: String) async throws -> Bool

    @discardableResult
    func registerPNToken(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) async throws -> Int

    @discardableResult
    func unregisterPNToken(
        token: String?,
        tokenId: Int?
    ) async throws -> Bool

    @discardableResult
    func listPNTokens() async throws -> [RuuviCloudPNToken]

    @discardableResult
    func loadSensors() async throws -> [AnyCloudSensor]

    @discardableResult
    // swiftlint:disable:next function_parameter_count
    func loadSensorsDense(
        for sensor: RuuviTagSensor?,
        measurements: Bool?,
        sharedToOthers: Bool?,
        sharedToMe: Bool?,
        alerts: Bool?,
        settings: Bool?
    ) async throws -> [RuuviCloudSensorDense]

    @discardableResult
    func loadRecords(
        macId: MACIdentifier,
        since: Date,
        until: Date?
    ) async throws -> [AnyRuuviTagSensorRecord]

    @discardableResult
    func claim(
        name: String,
        macId: MACIdentifier
    ) async throws -> MACIdentifier?

    @discardableResult
    func contest(
        macId: MACIdentifier,
        secret: String
    ) async throws -> MACIdentifier?

    @discardableResult
    func unclaim(
        macId: MACIdentifier,
        removeCloudHistory: Bool
    ) async throws -> MACIdentifier

    @discardableResult
    func share(
        macId: MACIdentifier,
        with email: String
    ) async throws -> ShareSensorResponse

    @discardableResult
    func unshare(
        macId: MACIdentifier,
        with email: String?
    ) async throws -> MACIdentifier

    @discardableResult
    func loadShared(
        for sensor: RuuviTagSensor
    ) async throws -> Set<AnyShareableSensor>

    @discardableResult
    func checkOwner(macId: MACIdentifier) async throws -> (String?, String?)

    @discardableResult
    func update(
        name: String,
        for sensor: RuuviTagSensor
    ) async throws -> AnyRuuviTagSensor

    @discardableResult
    func upload(
        imageData: Data,
        mimeType: MimeType,
        progress: ((MACIdentifier, Double) -> Void)?,
        for macId: MACIdentifier
    ) async throws -> URL

    @discardableResult
    func resetImage(
        for macId: MACIdentifier
    ) async throws -> Void

    @discardableResult
    func getCloudSettings() async throws -> RuuviCloudSettings?

    @discardableResult
    func set(temperatureUnit: TemperatureUnit) async throws -> TemperatureUnit

    @discardableResult
    func set(temperatureAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType

    @discardableResult
    func set(humidityUnit: HumidityUnit) async throws -> HumidityUnit

    @discardableResult
    func set(humidityAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType

    @discardableResult
    func set(pressureUnit: UnitPressure) async throws -> UnitPressure

    @discardableResult
    func set(pressureAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType

    @discardableResult
    func set(showAllData: Bool) async throws -> Bool

    @discardableResult
    func set(drawDots: Bool) async throws -> Bool

    @discardableResult
    func set(chartDuration: Int) async throws -> Int

    @discardableResult
    func set(showMinMaxAvg: Bool) async throws -> Bool

    @discardableResult
    func set(cloudMode: Bool) async throws -> Bool

    @discardableResult
    func set(dashboard: Bool) async throws -> Bool

    @discardableResult
    func set(dashboardType: DashboardType) async throws -> DashboardType

    @discardableResult
    func set(dashboardTapActionType: DashboardTapActionType) async throws -> DashboardTapActionType

    @discardableResult
    func set(disableEmailAlert: Bool) async throws -> Bool

    @discardableResult
    func set(disablePushAlert: Bool) async throws -> Bool

    @discardableResult
    func set(profileLanguageCode: String) async throws -> String

    @discardableResult
    func set(dashboardSensorOrder: [String]) async throws -> [String]

    @discardableResult
    func updateSensorSettings(
        for sensor: RuuviTagSensor,
        types: [String],
        values: [String],
        timestamp: Int?
    ) async throws -> AnyRuuviTagSensor

    @discardableResult
    func update(
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?,
        for sensor: RuuviTagSensor
    ) async throws -> AnyRuuviTagSensor

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
    ) async throws -> Void

    @discardableResult
    func loadAlerts() async throws -> [RuuviCloudSensorAlerts]

    // MARK: Queued requests

    @discardableResult
    func executeQueuedRequest(from request: RuuviCloudQueuedRequest)
        async throws -> Bool
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
