import Foundation
import Humidity

struct MeasurementsServiceSettingsCache {
    let temperatureUnit: UnitTemperature
    let humidityUnit: HumidityUnit
    let pressureUnit: UnitPressure
}

class MeasurementsServiceImpl: NSObject {
    var settings: Settings!
    private var settingsCache: MeasurementsServiceSettingsCache!

    private let notificationsNamesToObserve: [Notification.Name] = [
        .TemperatureUnitDidChange,
        .HumidityUnitDidChange,
        .PressureUnitDidChange
    ]

    private var queue: OperationQueue = {
        $0.qualityOfService = .userInitiated
        $0.maxConcurrentOperationCount = 3
        return $0
    }(OperationQueue())

    private lazy var formatter: MeasurementFormatter = {
        $0.unitOptions = .naturalScale
        $0.unitStyle = .short
        return $0
    }(MeasurementFormatter())

    private var listeners = NSHashTable<AnyObject>.weakObjects()

    override init() {
        super.init()
        startSettingsObserving()
    }

    func add(_ listener: MeasurementsServiceDelegate) {
        guard !listeners.contains(listener) else { return }
        listeners.add(listener)
    }
}
// MARK: - MeasurementsService
extension MeasurementsServiceImpl: MeasurementsService {
    func double(for measurement: Measurement<Dimension>) -> Double {
        let dimension: Dimension
        switch measurement.unit {
        case is UnitTemperature:
            dimension = settingsCache.temperatureUnit
        case is UnitPressure:
            dimension = settingsCache.pressureUnit
        case is UnitElectricPotentialDifference:
            dimension = UnitElectricPotentialDifference.volts
        default:
            fatalError("Need implement measurement type \(measurement.unit.description)")
        }
        return measurement
            .converted(to: dimension).value
    }

    func string(for measurement: Measurement<Dimension>) -> String {
        let dimension: Dimension
        switch measurement.unit {
        case is UnitTemperature:
            dimension = settingsCache.temperatureUnit
        case is UnitPressure:
            dimension = settingsCache.pressureUnit
        case is UnitElectricPotentialDifference:
            dimension = UnitElectricPotentialDifference.volts
        default:
            fatalError("Need implement measurement type \(measurement.unit.description)")
        }
        return formatter.string(from: dimension)
    }

    func double(for humidity: Humidity, with offset: Double) -> Double {
        let relativeHumidity = min(humidity.rh + offset, 100.0)
        let offsetedHumidity = Humidity(c: humidity.c, rh:relativeHumidity)
        switch settingsCache.humidityUnit {
        case .percent:
            return relativeHumidity
        case .gm3:
            return offsetedHumidity.ah
        case .dew:
            switch settingsCache.temperatureUnit {
            case .celsius:
                return offsetedHumidity.Td ?? .nan
            case .fahrenheit:
                return offsetedHumidity.TdF ?? .nan
            case .kelvin:
                return offsetedHumidity.TdK ?? .nan
            default:
                return offsetedHumidity.Td ?? .nan
            }
        }
    }

    func string(for humidity: Humidity, with offset: Double) -> String {
        let doubleValue = double(for: humidity, with: offset)
        guard doubleValue != .nan else {
            return "N/A".localized()
        }
        switch settingsCache.humidityUnit {
        case .percent:
            return .localizedStringWithFormat("%.2f", doubleValue)
                + " " + "%"
        case .gm3:
            return .localizedStringWithFormat("%.2f", doubleValue)
                + " " + "g/m³".localized()
        case .dew:
            let measurement = Measurement(value: doubleValue, unit: settingsCache.temperatureUnit)
            return formatter.string(from: measurement)
        }
    }
}
// MARK: - Localizable
extension MeasurementsServiceImpl: Localizable {
    func localize() {
        notifyListeners()
    }
}
// MARK: - Private
extension MeasurementsServiceImpl {
    private func notifyListeners() {
        listeners
            .allObjects
            .compactMap({
                $0 as? MeasurementsServiceDelegate
            }).forEach({
                $0.measurementServiceDidUpdateUnit()
            })
    }

    private func updateCache() {
        settingsCache = MeasurementsServiceSettingsCache(temperatureUnit: settings.temperatureUnit.unitTemperature,
                                                         humidityUnit: settings.humidityUnit,
                                                         pressureUnit: settings.pressureUnit)
        notifyListeners()
    }

    private func startSettingsObserving() {
        notificationsNamesToObserve.forEach({
            NotificationCenter
                .default
                .addObserver(forName: $0,
                             object: self,
                             queue: queue) { [weak self] (_) in
                self?.updateCache()
            }
        })
    }
}
