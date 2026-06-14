// swiftlint:disable type_body_length file_length

import Foundation
import Future
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
    public func set(temperatureUnit: TemperatureUnit) -> Future<TemperatureUnit, RuuviServiceError> {
        let promise = Promise<TemperatureUnit, RuuviServiceError>()
        localSettings.temperatureUnit = temperatureUnit
        saveUserSetting(
            name: .unitTemperature,
            value: temperatureUnit.ruuviCloudApiSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        cloud.set(temperatureUnit: temperatureUnit)
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
        localSettings.temperatureAccuracy = temperatureAccuracy
        saveUserSetting(
            name: .accuracyTemperature,
            value: temperatureAccuracy.value.ruuviCloudApiSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        cloud.set(temperatureAccuracy: temperatureAccuracy)
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
        localSettings.humidityUnit = humidityUnit
        saveUserSetting(
            name: .unitHumidity,
            value: humidityUnit.ruuviCloudApiSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        cloud.set(humidityUnit: humidityUnit)
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
        localSettings.humidityAccuracy = humidityAccuracy
        saveUserSetting(
            name: .accuracyHumidity,
            value: humidityAccuracy.value.ruuviCloudApiSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        cloud.set(humidityAccuracy: humidityAccuracy)
            .on(success: { accuracy in
                promise.succeed(value: accuracy)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
        })
        return promise.future
    }

    @discardableResult
    public func set(
        relativeHumidityAccuracy: MeasurementAccuracyType
    ) -> Future<MeasurementAccuracyType, RuuviServiceError> {
        return setSyncedAccuracy(
            relativeHumidityAccuracy,
            name: .accuracyHumidityRelative
        ) { [localSettings] in
            localSettings.relativeHumidityAccuracy = $0
        }
    }

    @discardableResult
    public func set(
        absoluteHumidityAccuracy: MeasurementAccuracyType
    ) -> Future<MeasurementAccuracyType, RuuviServiceError> {
        return setSyncedAccuracy(
            absoluteHumidityAccuracy,
            name: .accuracyHumidityAbsolute
        ) { [localSettings] in
            localSettings.absoluteHumidityAccuracy = $0
        }
    }

    @discardableResult
    public func set(
        dewPointAccuracy: MeasurementAccuracyType
    ) -> Future<MeasurementAccuracyType, RuuviServiceError> {
        return setSyncedAccuracy(
            dewPointAccuracy,
            name: .accuracyHumidityDewPoint
        ) { [localSettings] in
            localSettings.dewPointAccuracy = $0
        }
    }

    @discardableResult
    public func set(pressureUnit: UnitPressure) -> Future<UnitPressure, RuuviServiceError> {
        let promise = Promise<UnitPressure, RuuviServiceError>()
        localSettings.pressureUnit = pressureUnit
        saveUserSetting(
            name: .unitPressure,
            value: pressureUnit.ruuviCloudApiSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        cloud.set(pressureUnit: pressureUnit)
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
        localSettings.pressureAccuracy = pressureAccuracy
        saveUserSetting(
            name: .accuracyPressure,
            value: pressureAccuracy.value.ruuviCloudApiSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        cloud.set(pressureAccuracy: pressureAccuracy)
            .on(success: { accuracy in
                promise.succeed(value: accuracy)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
        })
        return promise.future
    }

    @discardableResult
    public func set(
        pmAccuracy: MeasurementAccuracyType
    ) -> Future<MeasurementAccuracyType, RuuviServiceError> {
        return setSyncedAccuracy(
            pmAccuracy,
            name: .accuracyPM
        ) { [localSettings] in
            localSettings.pmAccuracy = $0
        }
    }

    @discardableResult
    public func set(
        accelerationAccuracy: MeasurementAccuracyType
    ) -> Future<MeasurementAccuracyType, RuuviServiceError> {
        return setSyncedAccuracy(
            accelerationAccuracy,
            name: .accuracyAcceleration
        ) { [localSettings] in
            localSettings.accelerationAccuracy = $0
        }
    }

    @discardableResult
    public func set(
        voltageAccuracy: MeasurementAccuracyType
    ) -> Future<MeasurementAccuracyType, RuuviServiceError> {
        return setSyncedAccuracy(
            voltageAccuracy,
            name: .accuracyVoltage
        ) { [localSettings] in
            localSettings.voltageAccuracy = $0
        }
    }

    @discardableResult
    public func set(showAllData: Bool) -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        saveUserSetting(
            name: .chartShowAllPoints,
            value: showAllData.chartBoolSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        cloud.set(showAllData: showAllData)
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
        saveUserSetting(
            name: .chartDrawDots,
            value: drawDots.chartBoolSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        cloud.set(drawDots: drawDots)
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
        cloud.set(chartDuration: chartDuration)
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
        saveUserSetting(
            name: .chartShowMinMaxAverage,
            value: showMinMaxAvg.chartBoolSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        cloud.set(showMinMaxAvg: showMinMaxAvg)
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
        saveUserSetting(
            name: .cloudModeEnabled,
            value: cloudMode.chartBoolSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        cloud.set(cloudMode: cloudMode)
            .on(success: { cloudMode in
                promise.succeed(value: cloudMode)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(dashboard: Bool) -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        saveUserSetting(
            name: .dashboardEnabled,
            value: dashboard.chartBoolSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        cloud.set(dashboard: dashboard)
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
        saveUserSetting(
            name: .dashboardType,
            value: dashboardType.rawValue,
            lastUpdated: UserSettingTimestamp.current()
        )
        cloud.set(dashboardType: dashboardType)
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
        saveUserSetting(
            name: .dashboardTapActionType,
            value: dashboardTapActionType.rawValue,
            lastUpdated: UserSettingTimestamp.current()
        )
        cloud.set(dashboardTapActionType: dashboardTapActionType)
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
        saveUserSetting(
            name: .emailAlertDisabled,
            value: disableEmailAlert.chartBoolSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        cloud.set(disableEmailAlert: disableEmailAlert)
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
        saveUserSetting(
            name: .pushAlertDisabled,
            value: disablePushAlert.chartBoolSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        cloud.set(disablePushAlert: disablePushAlert)
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
        localSettings.marketingPreference = marketingPreference
        saveUserSetting(
            name: .marketingPreference,
            value: marketingPreference.chartBoolSettingString,
            lastUpdated: UserSettingTimestamp.current()
        )
        cloud.set(marketingPreference: marketingPreference)
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
        saveUserSetting(
            name: .profileLanguageCode,
            value: profileLanguageCode,
            lastUpdated: UserSettingTimestamp.current()
        )
        cloud.set(profileLanguageCode: profileLanguageCode)
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
        saveUserSetting(
            name: .dashboardSensorOrder,
            value: RuuviCloudApiHelper.jsonStringFromArray(dashboardSensorOrder),
            lastUpdated: UserSettingTimestamp.current()
        )
        cloud.set(dashboardSensorOrder: dashboardSensorOrder)
            .on(success: { dashboardSensorOrder in
                promise.succeed(value: dashboardSensorOrder)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    private func saveUserSetting(
        name: RuuviCloudApiSetting,
        value: String?,
        lastUpdated: Date
    ) {
        guard let value else {
            return
        }
        let userSetting = RuuviUserSettingStruct(
            key: name.rawValue,
            value: value,
            lastUpdated: lastUpdated
        )
        storage.save(userSetting: userSetting)
            .observe(on: .global(qos: .utility))
            .on()
    }

    private func setSyncedAccuracy(
        _ accuracy: MeasurementAccuracyType,
        name: RuuviCloudApiSetting,
        persist: (MeasurementAccuracyType) -> Void
    ) -> Future<MeasurementAccuracyType, RuuviServiceError> {
        let promise = Promise<MeasurementAccuracyType, RuuviServiceError>()
        persist(accuracy)
        let value = accuracy.value.ruuviCloudApiSettingString
        saveUserSetting(
            name: name,
            value: value,
            lastUpdated: UserSettingTimestamp.current()
        )
        cloud.set(userSetting: name, value: value)
            .on(success: { _ in
                promise.succeed(value: accuracy)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }
}

// swiftlint:enable type_body_length
