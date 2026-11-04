#if SWIFT_PACKAGE
    import RuuviService
#endif
// swiftlint:disable type_body_length file_length

import Foundation
import RuuviCloud
import RuuviLocal
import RuuviOntology
import RuuviStorage

public final class RuuviServiceAppSettingsImpl: RuuviServiceAppSettings {
    private let cloud: RuuviCloud
    private var localSettings: RuuviLocalSettings
    private let storage: RuuviStorage

    public init(
        cloud: RuuviCloud,
        localSettings: RuuviLocalSettings,
        storage: RuuviStorage
    ) {
        self.cloud = cloud
        self.localSettings = localSettings
        self.storage = storage
    }

    @discardableResult
    @MainActor
    public func set(temperatureUnit: TemperatureUnit) async throws(RuuviServiceError) -> TemperatureUnit {
        var outcome: Result<TemperatureUnit, RuuviServiceError>
        localSettings.temperatureUnit = temperatureUnit
        try await saveUserSetting(
            name: .unitTemperature,
            value: temperatureUnit.ruuviCloudApiSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        do {
            let temperatureUnit = try await cloud.set(temperatureUnit: temperatureUnit)
            outcome = .success(temperatureUnit)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(
        temperatureAccuracy: MeasurementAccuracyType
    ) async throws(RuuviServiceError) -> MeasurementAccuracyType {
        var outcome: Result<MeasurementAccuracyType, RuuviServiceError>
        localSettings.temperatureAccuracy = temperatureAccuracy
        try await saveUserSetting(
            name: .accuracyTemperature,
            value: temperatureAccuracy.value.ruuviCloudApiSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        do {
            let accuracy = try await cloud.set(temperatureAccuracy: temperatureAccuracy)
            outcome = .success(accuracy)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(humidityUnit: HumidityUnit) async throws(RuuviServiceError) -> HumidityUnit {
        var outcome: Result<HumidityUnit, RuuviServiceError>
        localSettings.humidityUnit = humidityUnit
        try await saveUserSetting(
            name: .unitHumidity,
            value: humidityUnit.ruuviCloudApiSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        do {
            let humidityUnit = try await cloud.set(humidityUnit: humidityUnit)
            outcome = .success(humidityUnit)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(
        humidityAccuracy: MeasurementAccuracyType
    ) async throws(RuuviServiceError) -> MeasurementAccuracyType {
        var outcome: Result<MeasurementAccuracyType, RuuviServiceError>
        localSettings.humidityAccuracy = humidityAccuracy
        try await saveUserSetting(
            name: .accuracyHumidity,
            value: humidityAccuracy.value.ruuviCloudApiSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        do {
            let accuracy = try await cloud.set(humidityAccuracy: humidityAccuracy)
            outcome = .success(accuracy)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(
        relativeHumidityAccuracy: MeasurementAccuracyType
    ) async throws(RuuviServiceError) -> MeasurementAccuracyType {
        return try await setSyncedAccuracy(
            relativeHumidityAccuracy,
            name: .accuracyHumidityRelative
        ) { [localSettings] in
            localSettings.relativeHumidityAccuracy = $0
        }
    }

    @discardableResult
    @MainActor
    public func set(
        absoluteHumidityAccuracy: MeasurementAccuracyType
    ) async throws(RuuviServiceError) -> MeasurementAccuracyType {
        return try await setSyncedAccuracy(
            absoluteHumidityAccuracy,
            name: .accuracyHumidityAbsolute
        ) { [localSettings] in
            localSettings.absoluteHumidityAccuracy = $0
        }
    }

    @discardableResult
    @MainActor
    public func set(
        dewPointAccuracy: MeasurementAccuracyType
    ) async throws(RuuviServiceError) -> MeasurementAccuracyType {
        return try await setSyncedAccuracy(
            dewPointAccuracy,
            name: .accuracyHumidityDewPoint
        ) { [localSettings] in
            localSettings.dewPointAccuracy = $0
        }
    }

    @discardableResult
    @MainActor
    public func set(pressureUnit: UnitPressure) async throws(RuuviServiceError) -> UnitPressure {
        var outcome: Result<UnitPressure, RuuviServiceError>
        localSettings.pressureUnit = pressureUnit
        try await saveUserSetting(
            name: .unitPressure,
            value: pressureUnit.ruuviCloudApiSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        do {
            let pressureUnit = try await cloud.set(pressureUnit: pressureUnit)
            outcome = .success(pressureUnit)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(
        pressureAccuracy: MeasurementAccuracyType
    ) async throws(RuuviServiceError) -> MeasurementAccuracyType {
        var outcome: Result<MeasurementAccuracyType, RuuviServiceError>
        localSettings.pressureAccuracy = pressureAccuracy
        try await saveUserSetting(
            name: .accuracyPressure,
            value: pressureAccuracy.value.ruuviCloudApiSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        do {
            let accuracy = try await cloud.set(pressureAccuracy: pressureAccuracy)
            outcome = .success(accuracy)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(
        pmAccuracy: MeasurementAccuracyType
    ) async throws(RuuviServiceError) -> MeasurementAccuracyType {
        return try await setSyncedAccuracy(
            pmAccuracy,
            name: .accuracyPM
        ) { [localSettings] in
            localSettings.pmAccuracy = $0
        }
    }

    @discardableResult
    @MainActor
    public func set(
        accelerationAccuracy: MeasurementAccuracyType
    ) async throws(RuuviServiceError) -> MeasurementAccuracyType {
        return try await setSyncedAccuracy(
            accelerationAccuracy,
            name: .accuracyAcceleration
        ) { [localSettings] in
            localSettings.accelerationAccuracy = $0
        }
    }

    @discardableResult
    @MainActor
    public func set(
        voltageAccuracy: MeasurementAccuracyType
    ) async throws(RuuviServiceError) -> MeasurementAccuracyType {
        return try await setSyncedAccuracy(
            voltageAccuracy,
            name: .accuracyVoltage
        ) { [localSettings] in
            localSettings.voltageAccuracy = $0
        }
    }

    @discardableResult
    @MainActor
    public func set(showAllData: Bool) async throws(RuuviServiceError) -> Bool {
        var outcome: Result<Bool, RuuviServiceError>
        try await saveUserSetting(
            name: .chartShowAllPoints,
            value: showAllData.chartBoolSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        do {
            let showAllData = try await cloud.set(showAllData: showAllData)
            outcome = .success(showAllData)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(drawDots: Bool) async throws(RuuviServiceError) -> Bool {
        var outcome: Result<Bool, RuuviServiceError>
        try await saveUserSetting(
            name: .chartDrawDots,
            value: drawDots.chartBoolSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        do {
            let drawDots = try await cloud.set(drawDots: drawDots)
            outcome = .success(drawDots)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(chartDuration: Int) async throws(RuuviServiceError) -> Int {
        var outcome: Result<Int, RuuviServiceError>
        do {
            let chartDuration = try await cloud.set(chartDuration: chartDuration)
            outcome = .success(chartDuration)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(showMinMaxAvg: Bool) async throws(RuuviServiceError) -> Bool {
        var outcome: Result<Bool, RuuviServiceError>
        try await saveUserSetting(
            name: .chartShowMinMaxAverage,
            value: showMinMaxAvg.chartBoolSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        do {
            let show = try await cloud.set(showMinMaxAvg: showMinMaxAvg)
            outcome = .success(show)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(cloudMode: Bool) async throws(RuuviServiceError) -> Bool {
        var outcome: Result<Bool, RuuviServiceError>
        try await saveUserSetting(
            name: .cloudModeEnabled,
            value: cloudMode.chartBoolSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        do {
            let cloudMode = try await cloud.set(cloudMode: cloudMode)
            outcome = .success(cloudMode)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(dashboard: Bool) async throws(RuuviServiceError) -> Bool {
        var outcome: Result<Bool, RuuviServiceError>
        try await saveUserSetting(
            name: .dashboardEnabled,
            value: dashboard.chartBoolSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        do {
            let enabled = try await cloud.set(dashboard: dashboard)
            outcome = .success(enabled)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(dashboardType: DashboardType) async throws(RuuviServiceError) -> DashboardType {
        var outcome: Result<DashboardType, RuuviServiceError>
        try await saveUserSetting(
            name: .dashboardType,
            value: dashboardType.rawValue,
            lastUpdated: UserSettingTimestamp.current()
        )
        do {
            let type = try await cloud.set(dashboardType: dashboardType)
            outcome = .success(type)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(dashboardTapActionType: DashboardTapActionType) async throws(RuuviServiceError)
        -> DashboardTapActionType
    {
        var outcome: Result<DashboardTapActionType, RuuviServiceError>
        try await saveUserSetting(
            name: .dashboardTapActionType,
            value: dashboardTapActionType.rawValue,
            lastUpdated: UserSettingTimestamp.current()
        )
        do {
            let type = try await cloud.set(dashboardTapActionType: dashboardTapActionType)
            outcome = .success(type)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(disableEmailAlert: Bool) async throws(RuuviServiceError) -> Bool {
        var outcome: Result<Bool, RuuviServiceError>
        try await saveUserSetting(
            name: .emailAlertDisabled,
            value: disableEmailAlert.chartBoolSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        do {
            let disabled = try await cloud.set(disableEmailAlert: disableEmailAlert)
            outcome = .success(disabled)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(disablePushAlert: Bool) async throws(RuuviServiceError) -> Bool {
        var outcome: Result<Bool, RuuviServiceError>
        try await saveUserSetting(
            name: .pushAlertDisabled,
            value: disablePushAlert.chartBoolSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        do {
            let disabled = try await cloud.set(disablePushAlert: disablePushAlert)
            outcome = .success(disabled)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func getMarketingConsent() async throws(RuuviServiceError) -> RuuviCloudMarketingConsent {
        var outcome: Result<RuuviCloudMarketingConsent, RuuviServiceError>
        do {
            let marketingConsent = try await cloud.getMarketingConsent()
            self.localSettings.marketingPreference = marketingConsent.consent
            outcome = .success(marketingConsent)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(marketingPreference: Bool) async throws(RuuviServiceError) -> RuuviCloudMarketingConsent {
        var outcome: Result<RuuviCloudMarketingConsent, RuuviServiceError>
        do {
            let marketingConsent = try await cloud.set(marketingPreference: marketingPreference)
            self.localSettings.marketingPreference = marketingConsent.consent
            outcome = .success(marketingConsent)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(profileLanguageCode: String) async throws(RuuviServiceError) -> String {
        var outcome: Result<String, RuuviServiceError>
        try await saveUserSetting(
            name: .profileLanguageCode,
            value: profileLanguageCode,
            lastUpdated: UserSettingTimestamp.current()
        )
        do {
            let profileLanguageCode = try await cloud.set(profileLanguageCode: profileLanguageCode)
            outcome = .success(profileLanguageCode)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(dashboardSensorOrder: [String]) async throws(RuuviServiceError) -> [String] {
        var outcome: Result<[String], RuuviServiceError>
        try await saveUserSetting(
            name: .dashboardSensorOrder,
            value: RuuviCloudApiHelper.jsonStringFromArray(dashboardSensorOrder),
            lastUpdated: UserSettingTimestamp.current()
        )
        do {
            let dashboardSensorOrder = try await cloud.set(dashboardSensorOrder: dashboardSensorOrder)
            outcome = .success(dashboardSensorOrder)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @MainActor
    private func saveUserSetting(
        name: RuuviCloudApiSetting,
        value: String?,
        lastUpdated: Date
    ) async throws(RuuviServiceError) {
        guard let value else {
            return
        }
        let userSetting = RuuviUserSettingStruct(
            key: name.rawValue,
            value: value,
            lastUpdated: lastUpdated
        )
        do {
            let _ = try await storage.save(userSetting: userSetting)
        } catch {
            throw .ruuviStorage(error)
        }
    }

    @MainActor
    private func setSyncedAccuracy(
        _ accuracy: MeasurementAccuracyType,
        name: RuuviCloudApiSetting,
        persist: (MeasurementAccuracyType) -> Void
    ) async throws(RuuviServiceError) -> MeasurementAccuracyType {
        var outcome: Result<MeasurementAccuracyType, RuuviServiceError>
        persist(accuracy)
        let value = accuracy.value.ruuviCloudApiSettingString
        try await saveUserSetting(
            name: name,
            value: value,
            lastUpdated: UserSettingTimestamp.current()
        )
        do {
            let _ = try await cloud.set(userSetting: name, value: value)
            outcome = .success(accuracy)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }
}

// swiftlint:enable type_body_length
