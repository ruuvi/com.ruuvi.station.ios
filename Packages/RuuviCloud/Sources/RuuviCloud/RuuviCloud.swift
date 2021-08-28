import Foundation
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

public protocol RuuviCloud {
    @discardableResult
    func requestCode(email: String) -> Future<String, RuuviCloudError>

    @discardableResult
    func validateCode(code: String) -> Future<ValidateCodeResponse, RuuviCloudError>

    @discardableResult
    func loadSensors() -> Future<[AnyCloudSensor], RuuviCloudError>

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
    ) -> Future<MACIdentifier, RuuviCloudError>

    @discardableResult
    func unclaim(macId: MACIdentifier) -> Future<MACIdentifier, RuuviCloudError>

    @discardableResult
    func share(
        macId: MACIdentifier,
        with email: String
    ) -> Future<MACIdentifier, RuuviCloudError>

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
    func getCloudSettings() -> Future<RuuviCloudSettings, RuuviCloudError>

    @discardableResult
    func set(temperatureUnit: TemperatureUnit) -> Future<TemperatureUnit, RuuviCloudError>

    @discardableResult
    func set(humidityUnit: HumidityUnit) -> Future<HumidityUnit, RuuviCloudError>

    @discardableResult
    func set(pressureUnit: UnitPressure) -> Future<UnitPressure, RuuviCloudError>

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
        isEnabled: Bool,
        min: Double?,
        max: Double?,
        counter: Int?,
        description: String?,
        for macId: MACIdentifier
    ) -> Future<Void, RuuviCloudError>

    @discardableResult
    func loadAlerts() -> Future<[RuuviCloudSensorAlerts], RuuviCloudError>
}

public protocol RuuviCloudFactory {
    func create(baseUrl: URL, user: RuuviUser) -> RuuviCloud
}

public enum MimeType: String, Encodable {
    case png = "image/png"
    case gif = "image/gif"
    case jpg = "image/jpeg"
}
