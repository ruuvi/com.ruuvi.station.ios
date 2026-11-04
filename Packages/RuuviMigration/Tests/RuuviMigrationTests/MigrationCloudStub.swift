// swiftlint:disable function_parameter_count
import Foundation
import XCTest
import RuuviCloud
import RuuviOntology

@MainActor final class MigrationCloudStub: RuuviCloud {
    func requestCode(email: String) async throws(RuuviCloudError) -> String? {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func validateCode(code: String) async throws(RuuviCloudError) -> ValidateCodeResponse {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func deleteAccount(email: String) async throws(RuuviCloudError) -> Bool {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func registerPNToken(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) async throws(RuuviCloudError) -> Int {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func unregisterPNToken(
        token: String?,
        tokenId: Int?
    ) async throws(RuuviCloudError) -> Bool {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func listPNTokens() async throws(RuuviCloudError) -> [RuuviCloudPNToken] {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func loadSensors() async throws(RuuviCloudError) -> [AnyCloudSensor] {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func loadSensorsDense(
        for sensor: RuuviTagSensor?,
        measurements: Bool?,
        sharedToOthers: Bool?,
        sharedToMe: Bool?,
        alerts: Bool?,
        settings: Bool?
    ) async throws(RuuviCloudError) -> [RuuviCloudSensorDense] {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func loadRecords(
        macId: MACIdentifier,
        since: Date,
        until: Date?
    ) async throws(RuuviCloudError) -> [AnyRuuviTagSensorRecord] {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func claim(
        name: String,
        macId: MACIdentifier
    ) async throws(RuuviCloudError) -> MACIdentifier? {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func contest(
        macId: MACIdentifier,
        secret: String
    ) async throws(RuuviCloudError) -> MACIdentifier? {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func unclaim(
        macId: MACIdentifier,
        removeCloudHistory: Bool
    ) async throws(RuuviCloudError) -> MACIdentifier {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func share(
        macId: MACIdentifier,
        with email: String
    ) async throws(RuuviCloudError) -> ShareSensorResponse {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func unshare(
        macId: MACIdentifier,
        with email: String?
    ) async throws(RuuviCloudError) -> MACIdentifier {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func loadShared(
        for sensor: RuuviTagSensor
    ) async throws(RuuviCloudError) -> Set<AnyShareableSensor> {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func checkOwner(macId: MACIdentifier) async throws(RuuviCloudError) -> (String?, String?) {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func update(name: String, for sensor: RuuviTagSensor) async throws(RuuviCloudError) -> AnyRuuviTagSensor {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func upload(
        imageData: Data,
        mimeType: MimeType,
        progress: ((MACIdentifier, Double) -> Void)?,
        for macId: MACIdentifier
    ) async throws(RuuviCloudError) -> URL {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func resetImage(
        for macId: MACIdentifier
    ) async throws(RuuviCloudError) -> Void {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func getCloudSettings() async throws(RuuviCloudError) -> RuuviCloudSettings? {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func set(temperatureUnit: TemperatureUnit) async throws(RuuviCloudError) -> TemperatureUnit {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func set(temperatureAccuracy: MeasurementAccuracyType) async throws(RuuviCloudError) -> MeasurementAccuracyType {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func set(humidityUnit: HumidityUnit) async throws(RuuviCloudError) -> HumidityUnit {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func set(humidityAccuracy: MeasurementAccuracyType) async throws(RuuviCloudError) -> MeasurementAccuracyType {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func set(userSetting: RuuviCloudApiSetting, value: String) async throws(RuuviCloudError) -> String {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func set(pressureUnit: UnitPressure) async throws(RuuviCloudError) -> UnitPressure {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func set(pressureAccuracy: MeasurementAccuracyType) async throws(RuuviCloudError) -> MeasurementAccuracyType {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func set(showAllData: Bool) async throws(RuuviCloudError) -> Bool {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func set(drawDots: Bool) async throws(RuuviCloudError) -> Bool {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func set(chartDuration: Int) async throws(RuuviCloudError) -> Int {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func set(showMinMaxAvg: Bool) async throws(RuuviCloudError) -> Bool {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func set(cloudMode: Bool) async throws(RuuviCloudError) -> Bool {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func set(dashboard: Bool) async throws(RuuviCloudError) -> Bool {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func set(dashboardType: DashboardType) async throws(RuuviCloudError) -> DashboardType {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func set(dashboardTapActionType: DashboardTapActionType) async throws(RuuviCloudError) -> DashboardTapActionType {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func set(disableEmailAlert: Bool) async throws(RuuviCloudError) -> Bool {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func set(disablePushAlert: Bool) async throws(RuuviCloudError) -> Bool {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func getMarketingConsent() async throws(RuuviCloudError) -> RuuviCloudMarketingConsent {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func set(marketingPreference: Bool) async throws(RuuviCloudError) -> RuuviCloudMarketingConsent {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func set(profileLanguageCode: String) async throws(RuuviCloudError) -> String {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func set(dashboardSensorOrder: [String]) async throws(RuuviCloudError) -> [String] {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func updateSensorSettings(
        for sensor: RuuviTagSensor,
        types: [String],
        values: [String],
        timestamp: Int?
    ) async throws(RuuviCloudError) -> AnyRuuviTagSensor {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func update(
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?,
        for sensor: RuuviTagSensor
    ) async throws(RuuviCloudError) -> AnyRuuviTagSensor {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

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
    ) async throws(RuuviCloudError) -> Void {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func loadAlerts() async throws(RuuviCloudError) -> [RuuviCloudSensorAlerts] {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

    func executeQueuedRequest(from request: RuuviCloudQueuedRequest)
        async throws(RuuviCloudError) -> Bool
    {
        XCTFail("Local migrations must not call the cloud")
        throw .notAuthorized
    }

}
