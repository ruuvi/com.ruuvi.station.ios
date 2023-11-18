import Foundation
import RuuviPool
import Future
import RuuviOntology
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
    func requestCode(email: String) -> Future<String?, RuuviCloudError>

    @discardableResult
    func validateCode(code: String) -> Future<ValidateCodeResponse, RuuviCloudError>

    @discardableResult
    func deleteAccount(email: String) -> Future<Bool, RuuviCloudError>

    @discardableResult
    func registerPNToken(token: String,
                         type: String,
                         name: String?,
                         data: String?,
                         params: [String: String]?) -> Future<Int, RuuviCloudError>

    @discardableResult
    func unregisterPNToken(token: String?,
                           tokenId: Int?) -> Future<Bool, RuuviCloudError>

    @discardableResult
    func listPNTokens() -> Future<[RuuviCloudPNToken], RuuviCloudError>

    @discardableResult
    func loadSensors() -> Future<[AnyCloudSensor], RuuviCloudError>

    @discardableResult
    func loadSensorsDense(for sensor: RuuviTagSensor?,
                          measurements: Bool?,
                          sharedToOthers: Bool?,
                          sharedToMe: Bool?,
                          alerts: Bool?
    ) -> Future<[RuuviCloudSensorDense], RuuviCloudError>

    @discardableResult
    func loadRecords(
        macId: MACIdentifier,
        since: Date,
        until: Date?
    ) -> Future<[AnyRuuviTagSensorRecord], RuuviCloudError>

    @discardableResult
    func claim(
        name: String,
        macId: MACIdentifier
    ) -> Future<MACIdentifier?, RuuviCloudError>

    @discardableResult
    func contest(
        macId: MACIdentifier,
        secret: String
    ) -> Future<MACIdentifier?, RuuviCloudError>

    @discardableResult
    func unclaim(
        macId: MACIdentifier,
        removeCloudHistory: Bool
    ) -> Future<MACIdentifier, RuuviCloudError>

    @discardableResult
    func share(
        macId: MACIdentifier,
        with email: String
    ) -> Future<ShareSensorResponse, RuuviCloudError>

    @discardableResult
    func unshare(
        macId: MACIdentifier,
        with email: String?
    ) -> Future<MACIdentifier, RuuviCloudError>

    @discardableResult
    func loadShared(
        for sensor: RuuviTagSensor
    ) -> Future<Set<AnyShareableSensor>, RuuviCloudError>

    @discardableResult
    func checkOwner(macId: MACIdentifier) -> Future<String?, RuuviCloudError>

    @discardableResult
    func update(
        name: String,
        for sensor: RuuviTagSensor
    ) -> Future<AnyRuuviTagSensor, RuuviCloudError>

    @discardableResult
    func upload(
        imageData: Data,
        mimeType: MimeType,
        progress: ((MACIdentifier, Double) -> Void)?,
        for macId: MACIdentifier
    ) -> Future<URL, RuuviCloudError>

    @discardableResult
    func resetImage(
        for macId: MACIdentifier
    ) -> Future<Void, RuuviCloudError>

    @discardableResult
    func getCloudSettings() -> Future<RuuviCloudSettings?, RuuviCloudError>

    @discardableResult
    func set(temperatureUnit: TemperatureUnit) -> Future<TemperatureUnit, RuuviCloudError>

    @discardableResult
    func set(temperatureAccuracy: MeasurementAccuracyType) -> Future<MeasurementAccuracyType, RuuviCloudError>

    @discardableResult
    func set(humidityUnit: HumidityUnit) -> Future<HumidityUnit, RuuviCloudError>

    @discardableResult
    func set(humidityAccuracy: MeasurementAccuracyType) -> Future<MeasurementAccuracyType, RuuviCloudError>

    @discardableResult
    func set(pressureUnit: UnitPressure) -> Future<UnitPressure, RuuviCloudError>

    @discardableResult
    func set(pressureAccuracy: MeasurementAccuracyType) -> Future<MeasurementAccuracyType, RuuviCloudError>

    @discardableResult
    func set(showAllData: Bool) -> Future<Bool, RuuviCloudError>

    @discardableResult
    func set(drawDots: Bool) -> Future<Bool, RuuviCloudError>

    @discardableResult
    func set(chartDuration: Int) -> Future<Int, RuuviCloudError>

    @discardableResult
    func set(showMinMaxAvg: Bool) -> Future<Bool, RuuviCloudError>

    @discardableResult
    func set(cloudMode: Bool) -> Future<Bool, RuuviCloudError>

    @discardableResult
    func set(dashboard: Bool) -> Future<Bool, RuuviCloudError>

    @discardableResult
    func set(dashboardType: DashboardType) -> Future<DashboardType, RuuviCloudError>

    @discardableResult
    func set(dashboardTapActionType: DashboardTapActionType) -> Future<DashboardTapActionType, RuuviCloudError>

    @discardableResult
    func set(emailAlert: Bool) -> Future<Bool, RuuviCloudError>

    @discardableResult
    func set(pushAlert: Bool) -> Future<Bool, RuuviCloudError>

    @discardableResult
    func set(profileLanguageCode: String) -> Future<String, RuuviCloudError>

    @discardableResult
    func update(
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?,
        for sensor: RuuviTagSensor
    ) -> Future<AnyRuuviTagSensor, RuuviCloudError>

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
    ) -> Future<Void, RuuviCloudError>

    @discardableResult
    func loadAlerts() -> Future<[RuuviCloudSensorAlerts], RuuviCloudError>

    // MARK: Queued requests
    @discardableResult
    func executeQueuedRequest(from request: RuuviCloudQueuedRequest)
    -> Future<Bool, RuuviCloudError>
}

public protocol RuuviCloudFactory {
    func create(baseUrl: URL, user: RuuviUser, pool: RuuviPool?) -> RuuviCloud
}

public enum MimeType: String, Codable {
    case png = "image/png"
    case gif = "image/gif"
    case jpg = "image/jpeg"
}
