// swiftlint:disable function_parameter_count
import Foundation
import RuuviCloud
import RuuviOntology

/// Offline cloud double: unexpected network operations fail explicitly. Alert writes are recorded.
@MainActor final class AppCloudSpy: RuuviCloud {
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
    struct PushRegistration {
        let token: String
        let type: String
        let name: String?
        let data: String?
        let params: [String: String]?
    }
    var pushRegistrations = [PushRegistration]()
    var pushUnregisters = [(String?, Int?)]()
    var pushTokens = [RuuviCloudPNToken]()
    var pushTokenID: Int?
    var pushFailure: RuuviCloudError?
    var pushListReads = 0
    var onDense: (() async throws(RuuviCloudError) -> [RuuviCloudSensorDense])?
    var onHistory: ((MACIdentifier, Date) async throws(RuuviCloudError) -> [AnyRuuviTagSensorRecord])?
    var onSettings: (() async throws(RuuviCloudError) -> RuuviCloudSettings?)?
    var onQueuedRequest: ((RuuviCloudQueuedRequest) async throws(RuuviCloudError) -> Bool)?
    var sensorSettingWrites: [([String], [String])] = []
    var alerts = [AlertRequest]()
    var onAlert: (() -> Void)?
    var onName: ((String) async -> Void)?
    var onResetImage: (() async -> Void)?
    var onUnclaim: (() async -> Void)?
    var beforeAlert: (() async -> Void)?
    var deletedEmails = [String]()
    var onDeleteAccount: ((String) async throws(RuuviCloudError) -> Bool)?
    var requestedEmails = [String]()
    var requestedCodes = [String]()
    var onRequestCode: ((String) async throws(RuuviCloudError) -> String?)?
    var onValidateCode: ((String) async throws(RuuviCloudError) -> ValidateCodeResponse)?
    func requestCode(email: String) async throws(RuuviCloudError) -> String? {
        requestedEmails.append(email)
        if let onRequestCode { return try await onRequestCode(email) }
        throw .notAuthorized
    }

    func validateCode(code: String) async throws(RuuviCloudError) -> ValidateCodeResponse {
        requestedCodes.append(code)
        if let onValidateCode { return try await onValidateCode(code) }
        throw .notAuthorized
    }

    func deleteAccount(email: String) async throws(RuuviCloudError) -> Bool {
        deletedEmails.append(email)
        if let onDeleteAccount { return try await onDeleteAccount(email) }
        throw .notAuthorized
    }

    func registerPNToken(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) async throws(RuuviCloudError) -> Int {
        pushRegistrations.append(.init(token: token, type: type, name: name, data: data, params: params))
        if let pushFailure { throw pushFailure }
        if let pushTokenID { return pushTokenID }
        throw .notAuthorized
    }

    func unregisterPNToken(
        token: String?,
        tokenId: Int?
    ) async throws(RuuviCloudError) -> Bool {
        pushUnregisters.append((token, tokenId))
        if let pushFailure { throw pushFailure }
        if pushTokenID != nil { return true }
        throw .notAuthorized
    }

    func listPNTokens() async throws(RuuviCloudError) -> [RuuviCloudPNToken] {
        pushListReads += 1
        if let pushFailure { throw pushFailure }
        if pushTokenID != nil { return pushTokens }
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
        throw .notAuthorized
    }

    func set(temperatureAccuracy: MeasurementAccuracyType) async throws(RuuviCloudError) -> MeasurementAccuracyType {
        throw .notAuthorized
    }

    func set(humidityUnit: HumidityUnit) async throws(RuuviCloudError) -> HumidityUnit {
        throw .notAuthorized
    }

    func set(humidityAccuracy: MeasurementAccuracyType) async throws(RuuviCloudError) -> MeasurementAccuracyType {
        throw .notAuthorized
    }

    func set(userSetting: RuuviCloudApiSetting, value: String) async throws(RuuviCloudError) -> String {
        throw .notAuthorized
    }

    func set(pressureUnit: UnitPressure) async throws(RuuviCloudError) -> UnitPressure {
        throw .notAuthorized
    }

    func set(pressureAccuracy: MeasurementAccuracyType) async throws(RuuviCloudError) -> MeasurementAccuracyType {
        throw .notAuthorized
    }

    func set(showAllData: Bool) async throws(RuuviCloudError) -> Bool {
        throw .notAuthorized
    }

    func set(drawDots: Bool) async throws(RuuviCloudError) -> Bool {
        throw .notAuthorized
    }

    func set(chartDuration: Int) async throws(RuuviCloudError) -> Int {
        throw .notAuthorized
    }

    func set(showMinMaxAvg: Bool) async throws(RuuviCloudError) -> Bool {
        throw .notAuthorized
    }

    func set(cloudMode: Bool) async throws(RuuviCloudError) -> Bool {
        throw .notAuthorized
    }

    func set(dashboard: Bool) async throws(RuuviCloudError) -> Bool {
        throw .notAuthorized
    }

    func set(dashboardType: DashboardType) async throws(RuuviCloudError) -> DashboardType {
        throw .notAuthorized
    }

    func set(dashboardTapActionType: DashboardTapActionType) async throws(RuuviCloudError) -> DashboardTapActionType {
        throw .notAuthorized
    }

    func set(disableEmailAlert: Bool) async throws(RuuviCloudError) -> Bool {
        throw .notAuthorized
    }

    func set(disablePushAlert: Bool) async throws(RuuviCloudError) -> Bool {
        throw .notAuthorized
    }

    func getMarketingConsent() async throws(RuuviCloudError) -> RuuviCloudMarketingConsent {
        throw .notAuthorized
    }

    func set(marketingPreference: Bool) async throws(RuuviCloudError) -> RuuviCloudMarketingConsent {
        throw .notAuthorized
    }

    func set(profileLanguageCode: String) async throws(RuuviCloudError) -> String {
        throw .notAuthorized
    }

    func set(dashboardSensorOrder: [String]) async throws(RuuviCloudError) -> [String] {
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
