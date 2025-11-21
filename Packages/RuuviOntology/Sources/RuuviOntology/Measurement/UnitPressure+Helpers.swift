import Foundation

public extension UnitPressure {
    var supportsResolutionSelection: Bool {
        self != .newtonsPerMetersSquared
    }

    func resolvedAccuracyValue(from accuracy: MeasurementAccuracyType) -> Int {
        supportsResolutionSelection ? accuracy.value : 0
    }

    func convert(value: Double, from source: UnitPressure) -> Double {
        if source == .hectopascals, self == .newtonsPerMetersSquared {
            return value * 100.0
        }
        let measurement = Measurement(value: value, unit: source)
        return measurement.converted(to: self).value
    }

    func convertedValue(from pressure: Pressure) -> Double {
        convert(value: pressure.value, from: pressure.unit)
    }

    func convert(_ pressure: Pressure) -> Pressure {
        Pressure(value: convertedValue(from: pressure), unit: self)
    }
}
