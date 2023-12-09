import Foundation
import Future
import RuuviCloud
import RuuviLocal
import RuuviOntology
import RuuviService

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

    @discardableResult
    public func set(temperatureUnit: TemperatureUnit) -> Future<TemperatureUnit, RuuviServiceError> {
        let promise = Promise<TemperatureUnit, RuuviServiceError>()
        localSettings.temperatureUnit = temperatureUnit
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
        cloud.set(humidityAccuracy: humidityAccuracy)
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
        localSettings.pressureUnit = pressureUnit
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
        cloud.set(pressureAccuracy: pressureAccuracy)
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
        Future<DashboardTapActionType, RuuviServiceError>
    {
        let promise = Promise<DashboardTapActionType, RuuviServiceError>()
        cloud.set(dashboardTapActionType: dashboardTapActionType)
            .on(success: { type in
                promise.succeed(value: type)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(emailAlert: Bool) -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        cloud.set(emailAlert: emailAlert)
            .on(success: { enabled in
                promise.succeed(value: enabled)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(pushAlert: Bool) -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        cloud.set(pushAlert: pushAlert)
            .on(success: { enabled in
                promise.succeed(value: enabled)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(profileLanguageCode: String) -> Future<String, RuuviServiceError> {
        let promise = Promise<String, RuuviServiceError>()
        cloud.set(profileLanguageCode: profileLanguageCode)
            .on(success: { profileLanguageCode in
                promise.succeed(value: profileLanguageCode)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }
}
