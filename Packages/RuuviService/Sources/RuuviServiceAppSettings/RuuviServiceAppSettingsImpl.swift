import Foundation
import Future
import RuuviOntology
import RuuviCloud
import RuuviLocal

final class RuuviServiceAppSettingsImpl: RuuviServiceAppSettings {
    private let cloud: RuuviCloud
    private var localSettings: RuuviLocalSettings

    init(
        cloud: RuuviCloud,
        localSettings: RuuviLocalSettings
    ) {
        self.cloud = cloud
        self.localSettings = localSettings
    }

    @discardableResult
    func set(temperatureUnit: TemperatureUnit) -> Future<TemperatureUnit, RuuviServiceError> {
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
    func set(humidityUnit: HumidityUnit) -> Future<HumidityUnit, RuuviServiceError> {
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
    func set(pressureUnit: UnitPressure) -> Future<UnitPressure, RuuviServiceError> {
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
}
