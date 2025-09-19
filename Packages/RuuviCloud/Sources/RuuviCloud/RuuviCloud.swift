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
    func requestCode(email: String) async throws -> String?
    func validateCode(code: String) async throws -> ValidateCodeResponse
    func deleteAccount(email: String) async throws -> Bool
    func registerPNToken(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) async throws -> Int
    func unregisterPNToken(token: String?, tokenId: Int?) async throws -> Bool
    func listPNTokens() async throws -> [RuuviCloudPNToken]
    func loadSensors() async throws -> [AnyCloudSensor]
    func loadSensorsDense(
        for sensor: RuuviTagSensor?,
        measurements: Bool?,
        sharedToOthers: Bool?,
        sharedToMe: Bool?,
        alerts: Bool?
    ) async throws -> [RuuviCloudSensorDense]
    func loadRecords(
        macId: MACIdentifier,
        since: Date,
        until: Date?
    ) async throws -> [AnyRuuviTagSensorRecord]
    func claim(name: String, macId: MACIdentifier) async throws -> MACIdentifier?
    func contest(macId: MACIdentifier, secret: String) async throws -> MACIdentifier?
    func unclaim(macId: MACIdentifier, removeCloudHistory: Bool) async throws -> MACIdentifier
    func share(macId: MACIdentifier, with email: String) async throws -> ShareSensorResponse
    func unshare(macId: MACIdentifier, with email: String?) async throws -> MACIdentifier
    func loadShared(for sensor: RuuviTagSensor) async throws -> Set<AnyShareableSensor>
    func checkOwner(macId: MACIdentifier) async throws -> String?
    func update(name: String, for sensor: RuuviTagSensor) async throws -> AnyRuuviTagSensor
    func upload(
        imageData: Data,
        mimeType: MimeType,
        progress: ((MACIdentifier, Double) -> Void)?,
        for macId: MACIdentifier
    ) async throws -> URL
    func resetImage(for macId: MACIdentifier) async throws -> Void
    func getCloudSettings() async throws -> RuuviCloudSettings?
    func set(temperatureUnit: TemperatureUnit) async throws -> TemperatureUnit
    func set(temperatureAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType
    func set(humidityUnit: HumidityUnit) async throws -> HumidityUnit
    func set(humidityAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType
    func set(pressureUnit: UnitPressure) async throws -> UnitPressure
    func set(pressureAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType
    func set(showAllData: Bool) async throws -> Bool
    func set(drawDots: Bool) async throws -> Bool
    func set(chartDuration: Int) async throws -> Int
    func set(showMinMaxAvg: Bool) async throws -> Bool
    func set(cloudMode: Bool) async throws -> Bool
    func set(dashboard: Bool) async throws -> Bool
    func set(dashboardType: DashboardType) async throws -> DashboardType
    func set(dashboardTapActionType: DashboardTapActionType) async throws -> DashboardTapActionType
    func set(disableEmailAlert: Bool) async throws -> Bool
    func set(disablePushAlert: Bool) async throws -> Bool
    func set(profileLanguageCode: String) async throws -> String
    func set(dashboardSensorOrder: [String]) async throws -> [String]
    func update(
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?,
        for sensor: RuuviTagSensor
    ) async throws -> AnyRuuviTagSensor
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
    func loadAlerts() async throws -> [RuuviCloudSensorAlerts]
    // MARK: Queued requests
    func executeQueuedRequest(from request: RuuviCloudQueuedRequest) async throws -> Bool
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
