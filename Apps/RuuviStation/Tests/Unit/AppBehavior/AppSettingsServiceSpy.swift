import Foundation
import RuuviCloud
import RuuviOntology
import RuuviService
@testable import station

@MainActor final class AppSettingsServiceSpy: RuuviServiceAppSettings {
    let settings: AppTestSettings
    var onGetMarketing: (() async throws(RuuviServiceError) -> RuuviCloudMarketingConsent)?
    var onSetMarketing: ((Bool) async throws(RuuviServiceError) -> RuuviCloudMarketingConsent)?
    var calls = [String]()
    var beforeSave: (() async -> Void)?
    var failure: RuuviServiceError?
    init(settings: AppTestSettings) { self.settings = settings }
    private func saved<Value>(_ name: String, _ value: Value) async throws(RuuviServiceError) -> Value {
        calls.append(name)
        await beforeSave?()
        if let failure { throw failure }
        return value
    }
    func set(temperatureUnit: TemperatureUnit) async throws(RuuviServiceError) -> TemperatureUnit {
        settings.temperatureUnit = temperatureUnit
        return try await saved("temperatureUnit", temperatureUnit)
    }
    func set(temperatureAccuracy: MeasurementAccuracyType) async throws(RuuviServiceError) -> MeasurementAccuracyType {
        settings.temperatureAccuracy = temperatureAccuracy
        return try await saved("temperatureAccuracy", temperatureAccuracy)
    }
    func set(humidityUnit: HumidityUnit) async throws(RuuviServiceError) -> HumidityUnit {
        settings.humidityUnit = humidityUnit
        return try await saved("humidityUnit", humidityUnit)
    }
    func set(humidityAccuracy: MeasurementAccuracyType) async throws(RuuviServiceError) -> MeasurementAccuracyType {
        settings.humidityAccuracy = humidityAccuracy
        return try await saved("humidityAccuracy", humidityAccuracy)
    }
    func set(relativeHumidityAccuracy: MeasurementAccuracyType) async throws(RuuviServiceError)
        -> MeasurementAccuracyType
    {
        settings.relativeHumidityAccuracy = relativeHumidityAccuracy
        return try await saved("relativeHumidityAccuracy", relativeHumidityAccuracy)
    }
    func set(absoluteHumidityAccuracy: MeasurementAccuracyType) async throws(RuuviServiceError)
        -> MeasurementAccuracyType
    {
        settings.absoluteHumidityAccuracy = absoluteHumidityAccuracy
        return try await saved("absoluteHumidityAccuracy", absoluteHumidityAccuracy)
    }
    func set(dewPointAccuracy: MeasurementAccuracyType) async throws(RuuviServiceError) -> MeasurementAccuracyType {
        settings.dewPointAccuracy = dewPointAccuracy
        return try await saved("dewPointAccuracy", dewPointAccuracy)
    }
    func set(pressureUnit: UnitPressure) async throws(RuuviServiceError) -> UnitPressure {
        settings.pressureUnit = pressureUnit
        return try await saved("pressureUnit", pressureUnit)
    }
    func set(pressureAccuracy: MeasurementAccuracyType) async throws(RuuviServiceError) -> MeasurementAccuracyType {
        settings.pressureAccuracy = pressureAccuracy
        return try await saved("pressureAccuracy", pressureAccuracy)
    }
    func set(pmAccuracy: MeasurementAccuracyType) async throws(RuuviServiceError) -> MeasurementAccuracyType {
        settings.pmAccuracy = pmAccuracy
        return try await saved("pmAccuracy", pmAccuracy)
    }
    func set(accelerationAccuracy: MeasurementAccuracyType) async throws(RuuviServiceError) -> MeasurementAccuracyType {
        settings.accelerationAccuracy = accelerationAccuracy
        return try await saved("accelerationAccuracy", accelerationAccuracy)
    }
    func set(voltageAccuracy: MeasurementAccuracyType) async throws(RuuviServiceError) -> MeasurementAccuracyType {
        settings.voltageAccuracy = voltageAccuracy
        return try await saved("voltageAccuracy", voltageAccuracy)
    }
    func set(showAllData: Bool) async throws(RuuviServiceError) -> Bool {
        settings.chartShowAll = showAllData
        return try await saved("showAllData", showAllData)
    }
    func set(drawDots: Bool) async throws(RuuviServiceError) -> Bool {
        settings.chartDrawDotsOn = drawDots
        return try await saved("drawDots", drawDots)
    }
    func set(chartDuration: Int) async throws(RuuviServiceError) -> Int {
        settings.chartDurationHours = chartDuration
        return try await saved("chartDuration", chartDuration)
    }
    func set(showMinMaxAvg: Bool) async throws(RuuviServiceError) -> Bool {
        settings.chartStatsOn = showMinMaxAvg
        return try await saved("showMinMaxAvg", showMinMaxAvg)
    }
    func set(cloudMode: Bool) async throws(RuuviServiceError) -> Bool {
        settings.cloudModeEnabled = cloudMode
        return try await saved("cloudMode", cloudMode)
    }
    func set(dashboard: Bool) async throws(RuuviServiceError) -> Bool {
        settings.dashboardEnabled = dashboard
        return try await saved("dashboard", dashboard)
    }
    func set(dashboardType: DashboardType) async throws(RuuviServiceError) -> DashboardType {
        settings.dashboardType = dashboardType
        return try await saved("dashboardType", dashboardType)
    }
    func set(dashboardTapActionType: DashboardTapActionType) async throws(RuuviServiceError) -> DashboardTapActionType {
        settings.dashboardTapActionType = dashboardTapActionType
        return try await saved("dashboardTapActionType", dashboardTapActionType)
    }
    func set(disableEmailAlert: Bool) async throws(RuuviServiceError) -> Bool {
        settings.emailAlertDisabled = disableEmailAlert
        return try await saved("disableEmailAlert", disableEmailAlert)
    }
    func set(disablePushAlert: Bool) async throws(RuuviServiceError) -> Bool {
        settings.pushAlertDisabled = disablePushAlert
        return try await saved("disablePushAlert", disablePushAlert)
    }
    func set(profileLanguageCode: String) async throws(RuuviServiceError) -> String {
        settings.cloudProfileLanguageCode = profileLanguageCode
        return try await saved("profileLanguageCode", profileLanguageCode)
    }
    func set(dashboardSensorOrder: [String]) async throws(RuuviServiceError) -> [String] {
        settings.dashboardSensorOrder = dashboardSensorOrder
        return try await saved("dashboardSensorOrder", dashboardSensorOrder)
    }
    func getMarketingConsent() async throws(RuuviServiceError) -> RuuviCloudMarketingConsent {
        calls.append("getMarketing")
        if let onGetMarketing { return try await onGetMarketing() }
        throw .failedToParseNetworkResponse
    }
    func set(marketingPreference: Bool) async throws(RuuviServiceError) -> RuuviCloudMarketingConsent {
        calls.append("setMarketing")
        if let onSetMarketing { return try await onSetMarketing(marketingPreference) }
        settings.marketingPreference = marketingPreference
        throw .failedToParseNetworkResponse
    }
}
