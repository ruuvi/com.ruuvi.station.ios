// swiftlint:disable function_parameter_count
import Foundation
import RuuviCloud
import RuuviOntology

/// Offline cloud double: unexpected network operations fail explicitly. Alert writes are recorded.
@MainActor final class CloudSpy: RuuviCloud {
    struct AlertRequest {
        let type: RuuviCloudAlertType
        let settingType: RuuviCloudAlertSettingType
        let enabled: Bool
        let min: Double?
        let max: Double?
        let counter: Int?
        let delay: Int?
        let description: String?
        let mac: String
    }
    var onDense: (() async throws(RuuviCloudError) -> [RuuviCloudSensorDense])?
    var onHistory: ((MACIdentifier, Date) async throws(RuuviCloudError) -> [AnyRuuviTagSensorRecord])?
    var onSettings: (() async throws(RuuviCloudError) -> RuuviCloudSettings?)?
    var onQueuedRequest: ((RuuviCloudQueuedRequest) async throws(RuuviCloudError) -> Bool)?
    var userSettingWrites = [(RuuviCloudApiSetting, String)]()
    var allowUserSettingWrites = false
    var sensorSettingWrites: [([String], [String])] = []
    var alerts = [AlertRequest]()
    var onAlert: (() -> Void)?
    var onName: ((String) async -> Void)?
    var onResetImage: (() async -> Void)?
    var onUnclaim: (() async -> Void)?
    var beforeAlert: (() async -> Void)?
    func requestCode(email: String) async throws(RuuviCloudError) -> String? {
        throw .notAuthorized
    }

    func validateCode(code: String) async throws(RuuviCloudError) -> ValidateCodeResponse {
        throw .notAuthorized
    }

    func deleteAccount(email: String) async throws(RuuviCloudError) -> Bool {
        throw .notAuthorized
    }

    func registerPNToken(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) async throws(RuuviCloudError) -> Int {
        throw .notAuthorized
    }

    func unregisterPNToken(
        token: String?,
        tokenId: Int?
    ) async throws(RuuviCloudError) -> Bool {
        throw .notAuthorized
    }

    func listPNTokens() async throws(RuuviCloudError) -> [RuuviCloudPNToken] {
        throw .notAuthorized
    }

    func loadSensors() async throws(RuuviCloudError) -> [AnyCloudSensor] {
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
        if let onDense { return try await onDense() }
        throw .notAuthorized
    }

    func loadRecords(
        macId: MACIdentifier,
        since: Date,
        until: Date?
    ) async throws(RuuviCloudError) -> [AnyRuuviTagSensorRecord] {
        if let onHistory { return try await onHistory(macId, since) }
        throw .notAuthorized
    }

    func claim(
        name: String,
        macId: MACIdentifier
    ) async throws(RuuviCloudError) -> MACIdentifier? {
        throw .notAuthorized
    }

    func contest(
        macId: MACIdentifier,
        secret: String
    ) async throws(RuuviCloudError) -> MACIdentifier? {
        throw .notAuthorized
    }

    func unclaim(
        macId: MACIdentifier,
        removeCloudHistory: Bool
    ) async throws(RuuviCloudError) -> MACIdentifier {
        await onUnclaim?()
        throw .notAuthorized
    }

    func share(
        macId: MACIdentifier,
        with email: String
    ) async throws(RuuviCloudError) -> ShareSensorResponse {
        throw .notAuthorized
    }

    func unshare(
        macId: MACIdentifier,
        with email: String?
    ) async throws(RuuviCloudError) -> MACIdentifier {
        throw .notAuthorized
    }

    func loadShared(
        for sensor: RuuviTagSensor
    ) async throws(RuuviCloudError) -> Set<AnyShareableSensor> {
        throw .notAuthorized
    }

    func checkOwner(macId: MACIdentifier) async throws(RuuviCloudError) -> (String?, String?) {
        throw .notAuthorized
    }

    func update(name: String, for sensor: RuuviTagSensor) async throws(RuuviCloudError) -> AnyRuuviTagSensor {
        await onName?(name)
        throw .notAuthorized
    }

    func upload(
        imageData: Data,
        mimeType: MimeType,
        progress: ((MACIdentifier, Double) -> Void)?,
        for macId: MACIdentifier
    ) async throws(RuuviCloudError) -> URL {
        throw .notAuthorized
    }

    func resetImage(
        for macId: MACIdentifier
    ) async throws(RuuviCloudError) -> Void {
        await onResetImage?()
        throw .notAuthorized
    }

    func getCloudSettings() async throws(RuuviCloudError) -> RuuviCloudSettings? {
        if let onSettings { return try await onSettings() }
        throw .notAuthorized
    }

    func set(temperatureUnit: TemperatureUnit) async throws(RuuviCloudError) -> TemperatureUnit {
        userSettingWrites.append((.unitTemperature, temperatureUnit.ruuviCloudApiSettingString))
        if allowUserSettingWrites { return temperatureUnit }
        throw .notAuthorized
    }

    func set(temperatureAccuracy: MeasurementAccuracyType) async throws(RuuviCloudError) -> MeasurementAccuracyType {
        userSettingWrites.append((.accuracyTemperature, temperatureAccuracy.value.ruuviCloudApiSettingString))
        if allowUserSettingWrites { return temperatureAccuracy }
        throw .notAuthorized
    }

    func set(humidityUnit: HumidityUnit) async throws(RuuviCloudError) -> HumidityUnit {
        userSettingWrites.append((.unitHumidity, humidityUnit.ruuviCloudApiSettingString))
        if allowUserSettingWrites { return humidityUnit }
        throw .notAuthorized
    }

    func set(humidityAccuracy: MeasurementAccuracyType) async throws(RuuviCloudError) -> MeasurementAccuracyType {
        userSettingWrites.append((.accuracyHumidity, humidityAccuracy.value.ruuviCloudApiSettingString))
        if allowUserSettingWrites { return humidityAccuracy }
        throw .notAuthorized
    }

    func set(userSetting: RuuviCloudApiSetting, value: String) async throws(RuuviCloudError) -> String {
        userSettingWrites.append((userSetting, value))
        if allowUserSettingWrites { return value }
        throw .notAuthorized
    }

    func set(pressureUnit: UnitPressure) async throws(RuuviCloudError) -> UnitPressure {
        userSettingWrites.append((.unitPressure, pressureUnit.ruuviCloudApiSettingString))
        if allowUserSettingWrites { return pressureUnit }
        throw .notAuthorized
    }

    func set(pressureAccuracy: MeasurementAccuracyType) async throws(RuuviCloudError) -> MeasurementAccuracyType {
        userSettingWrites.append((.accuracyPressure, pressureAccuracy.value.ruuviCloudApiSettingString))
        if allowUserSettingWrites { return pressureAccuracy }
        throw .notAuthorized
    }

    func set(showAllData: Bool) async throws(RuuviCloudError) -> Bool {
        userSettingWrites.append((.chartShowAllPoints, showAllData.chartBoolSettingString))
        if allowUserSettingWrites { return showAllData }
        throw .notAuthorized
    }

    func set(drawDots: Bool) async throws(RuuviCloudError) -> Bool {
        userSettingWrites.append((.chartDrawDots, drawDots.chartBoolSettingString))
        if allowUserSettingWrites { return drawDots }
        throw .notAuthorized
    }

    func set(chartDuration: Int) async throws(RuuviCloudError) -> Int {
        userSettingWrites.append((.chartViewPeriod, String(chartDuration)))
        if allowUserSettingWrites { return chartDuration }
        throw .notAuthorized
    }

    func set(showMinMaxAvg: Bool) async throws(RuuviCloudError) -> Bool {
        userSettingWrites.append((.chartShowMinMaxAverage, showMinMaxAvg.chartBoolSettingString))
        if allowUserSettingWrites { return showMinMaxAvg }
        throw .notAuthorized
    }

    func set(cloudMode: Bool) async throws(RuuviCloudError) -> Bool {
        userSettingWrites.append((.cloudModeEnabled, cloudMode.chartBoolSettingString))
        if allowUserSettingWrites { return cloudMode }
        throw .notAuthorized
    }

    func set(dashboard: Bool) async throws(RuuviCloudError) -> Bool {
        userSettingWrites.append((.dashboardEnabled, dashboard.chartBoolSettingString))
        if allowUserSettingWrites { return dashboard }
        throw .notAuthorized
    }

    func set(dashboardType: DashboardType) async throws(RuuviCloudError) -> DashboardType {
        userSettingWrites.append((.dashboardType, dashboardType.rawValue))
        if allowUserSettingWrites { return dashboardType }
        throw .notAuthorized
    }

    func set(dashboardTapActionType: DashboardTapActionType) async throws(RuuviCloudError) -> DashboardTapActionType {
        userSettingWrites.append((.dashboardTapActionType, dashboardTapActionType.rawValue))
        if allowUserSettingWrites { return dashboardTapActionType }
        throw .notAuthorized
    }

    func set(disableEmailAlert: Bool) async throws(RuuviCloudError) -> Bool {
        userSettingWrites.append((.emailAlertDisabled, disableEmailAlert.chartBoolSettingString))
        if allowUserSettingWrites { return disableEmailAlert }
        throw .notAuthorized
    }

    func set(disablePushAlert: Bool) async throws(RuuviCloudError) -> Bool {
        userSettingWrites.append((.pushAlertDisabled, disablePushAlert.chartBoolSettingString))
        if allowUserSettingWrites { return disablePushAlert }
        throw .notAuthorized
    }

    func getMarketingConsent() async throws(RuuviCloudError) -> RuuviCloudMarketingConsent {
        throw .notAuthorized
    }

    func set(marketingPreference: Bool) async throws(RuuviCloudError) -> RuuviCloudMarketingConsent {
        userSettingWrites.append((.marketingPreference, marketingPreference.chartBoolSettingString))
        throw .notAuthorized
    }

    func set(profileLanguageCode: String) async throws(RuuviCloudError) -> String {
        userSettingWrites.append((.profileLanguageCode, profileLanguageCode))
        if allowUserSettingWrites { return profileLanguageCode }
        throw .notAuthorized
    }

    func set(dashboardSensorOrder: [String]) async throws(RuuviCloudError) -> [String] {
        userSettingWrites.append(
            (.dashboardSensorOrder, RuuviCloudApiHelper.jsonStringFromArray(dashboardSensorOrder) ?? ""))
        if allowUserSettingWrites { return dashboardSensorOrder }
        throw .notAuthorized
    }

    func updateSensorSettings(
        for sensor: RuuviTagSensor,
        types: [String],
        values: [String],
        timestamp: Int?
    ) async throws(RuuviCloudError) -> AnyRuuviTagSensor {
        sensorSettingWrites.append((types, values))
        return sensor.any
    }

    func update(
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?,
        for sensor: RuuviTagSensor
    ) async throws(RuuviCloudError) -> AnyRuuviTagSensor {
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
        await beforeAlert?()
        alerts.append(
            AlertRequest(
                type: type, settingType: settingType, enabled: isEnabled, min: min, max: max, counter: counter,
                delay: delay, description: description, mac: macId.value))
        onAlert?()
    }

    func loadAlerts() async throws(RuuviCloudError) -> [RuuviCloudSensorAlerts] {
        throw .notAuthorized
    }

    func executeQueuedRequest(from request: RuuviCloudQueuedRequest)
        async throws(RuuviCloudError) -> Bool
    {
        if let onQueuedRequest { return try await onQueuedRequest(request) }
        throw .notAuthorized
    }
}
