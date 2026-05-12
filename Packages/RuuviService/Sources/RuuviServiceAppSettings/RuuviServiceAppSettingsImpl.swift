import Foundation
import Future
import RuuviCloud
import RuuviLocal
import RuuviOntology

public final class RuuviServiceAppSettingsImpl: RuuviServiceAppSettings {
    private let cloud: RuuviCloud
    private var localSettings: RuuviLocalSettings

    public init(
        cloud: RuuviCloud,
        localSettings: RuuviLocalSettings
    ) {
        self.cloud = cloud
        self.localSettings = localSettings
    }

    private func makeSettingTimestamp() -> (unix: Int, date: Date) {
        let unixTimestamp = Int(Date().timeIntervalSince1970)
        return (
            unix: unixTimestamp,
            date: Date(timeIntervalSince1970: TimeInterval(unixTimestamp))
        )
    }

    @discardableResult
    public func set(temperatureUnit: TemperatureUnit) -> Future<TemperatureUnit, RuuviServiceError> {
        let promise = Promise<TemperatureUnit, RuuviServiceError>()
        let timestamp = makeSettingTimestamp()
        localSettings.temperatureUnit = temperatureUnit
        localSettings.unitTemperatureLastUpdated = timestamp.date
        cloud.set(temperatureUnit: temperatureUnit, timestamp: timestamp.unix)
            .on(success: { temperatureUnit in
                promise.succeed(value: temperatureUnit)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(
        temperatureAccuracy: MeasurementAccuracyType
    ) -> Future<MeasurementAccuracyType, RuuviServiceError> {
        let promise = Promise<MeasurementAccuracyType, RuuviServiceError>()
        let timestamp = makeSettingTimestamp()
        localSettings.temperatureAccuracy = temperatureAccuracy
        localSettings.accuracyTemperatureLastUpdated = timestamp.date
        cloud.set(temperatureAccuracy: temperatureAccuracy, timestamp: timestamp.unix)
            .on(success: { accuracy in
                promise.succeed(value: accuracy)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(humidityUnit: HumidityUnit) -> Future<HumidityUnit, RuuviServiceError> {
        let promise = Promise<HumidityUnit, RuuviServiceError>()
        let timestamp = makeSettingTimestamp()
        localSettings.humidityUnit = humidityUnit
        localSettings.unitHumidityLastUpdated = timestamp.date
        cloud.set(humidityUnit: humidityUnit, timestamp: timestamp.unix)
            .on(success: { humidityUnit in
                promise.succeed(value: humidityUnit)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(
        humidityAccuracy: MeasurementAccuracyType
    ) -> Future<MeasurementAccuracyType, RuuviServiceError> {
        let promise = Promise<MeasurementAccuracyType, RuuviServiceError>()
        let timestamp = makeSettingTimestamp()
        localSettings.humidityAccuracy = humidityAccuracy
        localSettings.accuracyHumidityLastUpdated = timestamp.date
        cloud.set(humidityAccuracy: humidityAccuracy, timestamp: timestamp.unix)
            .on(success: { accuracy in
                promise.succeed(value: accuracy)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(pressureUnit: UnitPressure) -> Future<UnitPressure, RuuviServiceError> {
        let promise = Promise<UnitPressure, RuuviServiceError>()
        let timestamp = makeSettingTimestamp()
        localSettings.pressureUnit = pressureUnit
        localSettings.unitPressureLastUpdated = timestamp.date
        cloud.set(pressureUnit: pressureUnit, timestamp: timestamp.unix)
            .on(success: { pressureUnit in
                promise.succeed(value: pressureUnit)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(
        pressureAccuracy: MeasurementAccuracyType
    ) -> Future<MeasurementAccuracyType, RuuviServiceError> {
        let promise = Promise<MeasurementAccuracyType, RuuviServiceError>()
        let timestamp = makeSettingTimestamp()
        localSettings.pressureAccuracy = pressureAccuracy
        localSettings.accuracyPressureLastUpdated = timestamp.date
        cloud.set(pressureAccuracy: pressureAccuracy, timestamp: timestamp.unix)
            .on(success: { accuracy in
                promise.succeed(value: accuracy)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(showAllData: Bool) -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        let timestamp = makeSettingTimestamp()
        localSettings.chartDownsamplingOn = !showAllData
        localSettings.chartShowAllPointsLastUpdated = timestamp.date
        cloud.set(showAllData: showAllData, timestamp: timestamp.unix)
            .on(success: { showAllData in
                promise.succeed(value: showAllData)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(drawDots: Bool) -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        let timestamp = makeSettingTimestamp()
        localSettings.chartDrawDotsOn = drawDots
        localSettings.chartDrawDotsLastUpdated = timestamp.date
        cloud.set(drawDots: drawDots, timestamp: timestamp.unix)
            .on(success: { drawDots in
                promise.succeed(value: drawDots)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(chartDuration: Int) -> Future<Int, RuuviServiceError> {
        let promise = Promise<Int, RuuviServiceError>()
        let timestamp = makeSettingTimestamp()
        localSettings.chartDurationHours = chartDuration
        localSettings.chartViewPeriodLastUpdated = timestamp.date
        cloud.set(chartDuration: chartDuration, timestamp: timestamp.unix)
            .on(success: { chartDuration in
                promise.succeed(value: chartDuration)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(showMinMaxAvg: Bool) -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        let timestamp = makeSettingTimestamp()
        localSettings.chartStatsOn = showMinMaxAvg
        localSettings.chartShowMinMaxAvgLastUpdated = timestamp.date
        cloud.set(showMinMaxAvg: showMinMaxAvg, timestamp: timestamp.unix)
            .on(success: { show in
                promise.succeed(value: show)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(cloudMode: Bool) -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        let timestamp = makeSettingTimestamp()
        localSettings.cloudModeEnabled = cloudMode
        localSettings.cloudModeEnabledLastUpdated = timestamp.date
        cloud.set(cloudMode: cloudMode, timestamp: timestamp.unix)
            .on(success: { cloudMode in
                promise.succeed(value: cloudMode)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    public func setLocalOnly(cloudMode: Bool) {
        localSettings.cloudModeEnabled = cloudMode
        localSettings.cloudModeEnabledLastUpdated = nil
    }

    @discardableResult
    public func set(dashboard: Bool) -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        let timestamp = makeSettingTimestamp()
        localSettings.dashboardEnabled = dashboard
        localSettings.dashboardEnabledLastUpdated = timestamp.date
        cloud.set(dashboard: dashboard, timestamp: timestamp.unix)
            .on(success: { enabled in
                promise.succeed(value: enabled)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(dashboardType: DashboardType) -> Future<DashboardType, RuuviServiceError> {
        let promise = Promise<DashboardType, RuuviServiceError>()
        let timestamp = makeSettingTimestamp()
        localSettings.dashboardType = dashboardType
        localSettings.dashboardTypeLastUpdated = timestamp.date
        cloud.set(dashboardType: dashboardType, timestamp: timestamp.unix)
            .on(success: { type in
                promise.succeed(value: type)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(dashboardTapActionType: DashboardTapActionType) ->
    Future<DashboardTapActionType, RuuviServiceError> {
        let promise = Promise<DashboardTapActionType, RuuviServiceError>()
        let timestamp = makeSettingTimestamp()
        localSettings.dashboardTapActionType = dashboardTapActionType
        localSettings.dashboardTapActionTypeLastUpdated = timestamp.date
        cloud.set(dashboardTapActionType: dashboardTapActionType, timestamp: timestamp.unix)
            .on(success: { type in
                promise.succeed(value: type)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(disableEmailAlert: Bool) -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        let timestamp = makeSettingTimestamp()
        localSettings.emailAlertDisabled = disableEmailAlert
        localSettings.emailAlertDisabledLastUpdated = timestamp.date
        cloud.set(disableEmailAlert: disableEmailAlert, timestamp: timestamp.unix)
            .on(success: { disabled in
                promise.succeed(value: disabled)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(disablePushAlert: Bool) -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        let timestamp = makeSettingTimestamp()
        localSettings.pushAlertDisabled = disablePushAlert
        localSettings.pushAlertDisabledLastUpdated = timestamp.date
        cloud.set(disablePushAlert: disablePushAlert, timestamp: timestamp.unix)
            .on(success: { disabled in
                promise.succeed(value: disabled)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(marketingPreference: Bool) -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        let timestamp = makeSettingTimestamp()
        localSettings.marketingPreference = marketingPreference
        localSettings.marketingPreferenceLastUpdated = timestamp.date
        cloud.set(marketingPreference: marketingPreference, timestamp: timestamp.unix)
            .on(success: { marketingPreference in
                promise.succeed(value: marketingPreference)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(profileLanguageCode: String) -> Future<String, RuuviServiceError> {
        let promise = Promise<String, RuuviServiceError>()
        let timestamp = makeSettingTimestamp()
        localSettings.cloudProfileLanguageCode = profileLanguageCode
        localSettings.profileLanguageCodeLastUpdated = timestamp.date
        cloud.set(profileLanguageCode: profileLanguageCode, timestamp: timestamp.unix)
            .on(success: { profileLanguageCode in
                promise.succeed(value: profileLanguageCode)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(dashboardSensorOrder: [String]) -> Future<[String], RuuviServiceError> {
        let promise = Promise<[String], RuuviServiceError>()
        let timestamp = makeSettingTimestamp()
        localSettings.dashboardSensorOrder = dashboardSensorOrder
        localSettings.dashboardSensorOrderLastUpdated = timestamp.date
        cloud.set(dashboardSensorOrder: dashboardSensorOrder, timestamp: timestamp.unix)
            .on(success: { dashboardSensorOrder in
                promise.succeed(value: dashboardSensorOrder)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }
}
