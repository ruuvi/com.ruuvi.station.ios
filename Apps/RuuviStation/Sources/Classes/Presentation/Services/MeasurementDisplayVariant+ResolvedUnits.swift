import Foundation
import RuuviOntology

extension MeasurementDisplayVariant {
    func resolvedTemperatureUnit(default defaultUnit: UnitTemperature) -> UnitTemperature {
        temperatureUnit?.unitTemperature ?? defaultUnit
    }

    func resolvedHumidityUnit(default defaultUnit: HumidityUnit) -> HumidityUnit {
        humidityUnit ?? defaultUnit
    }

    func resolvedPressureUnit(default defaultUnit: UnitPressure) -> UnitPressure {
        pressureUnit ?? defaultUnit
    }
}
