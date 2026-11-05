import Foundation
import XCTest
import RuuviCloud
import RuuviLocal
import RuuviOntology
@testable import RuuviService
#if SWIFT_PACKAGE
    import RuuviLocalUserDefaults
    @testable import RuuviServiceAlert
#endif

struct AlertMetric {
    let type: AlertType
    let cloudType: RuuviCloudAlertType
    let lower: Double
    let upper: Double
    let scale: Double
    let setLower: (RuuviServiceAlert, Double?, RuuviTagSensor) -> Void
    let setUpper: (RuuviServiceAlert, Double?, RuuviTagSensor) -> Void
    let setDescription: (RuuviServiceAlert, String?, RuuviTagSensor) -> Void
    let lowerValue: (RuuviServiceAlert, PhysicalSensor) -> Double?
    let upperValue: (RuuviServiceAlert, PhysicalSensor) -> Double?
    let description: (RuuviServiceAlert, PhysicalSensor) -> String?
    let legacyLower: (RuuviServiceAlert, String) -> Double?
    let legacyUpper: (RuuviServiceAlert, String) -> Double?
    let legacyDescription: (RuuviServiceAlert, String) -> String?
}

extension AlertMetric {
    static let all: [AlertMetric] = [
        .init(
            type: .temperature(lower: -10, upper: 30), cloudType: .temperature,
            lower: -10, upper: 30, scale: 1,
            setLower: { $0.setLower(celsius: $1, ruuviTag: $2) },
            setUpper: { $0.setUpper(celsius: $1, ruuviTag: $2) },
            setDescription: { $0.setTemperature(description: $1, ruuviTag: $2) },
            lowerValue: { $0.lowerCelsius(for: $1) }, upperValue: { $0.upperCelsius(for: $1) },
            description: { $0.temperatureDescription(for: $1) },
            legacyLower: { $0.lowerCelsius(for: $1) }, legacyUpper: { $0.upperCelsius(for: $1) },
            legacyDescription: { $0.temperatureDescription(for: $1) }),
        .init(
            type: .relativeHumidity(lower: 0.2, upper: 0.8), cloudType: .humidity,
            lower: 0.2, upper: 0.8, scale: 100,
            setLower: { $0.setLower(relativeHumidity: $1, ruuviTag: $2) },
            setUpper: { $0.setUpper(relativeHumidity: $1, ruuviTag: $2) },
            setDescription: { $0.setRelativeHumidity(description: $1, ruuviTag: $2) },
            lowerValue: { $0.lowerRelativeHumidity(for: $1) }, upperValue: { $0.upperRelativeHumidity(for: $1) },
            description: { $0.relativeHumidityDescription(for: $1) },
            legacyLower: { $0.lowerRelativeHumidity(for: $1) }, legacyUpper: { $0.upperRelativeHumidity(for: $1) },
            legacyDescription: { $0.relativeHumidityDescription(for: $1) }),
        .init(
            type: .dewPoint(lower: -5, upper: 15), cloudType: .dewPoint,
            lower: -5, upper: 15, scale: 1,
            setLower: { $0.setLower(dewPoint: $1, ruuviTag: $2) },
            setUpper: { $0.setUpper(dewPoint: $1, ruuviTag: $2) },
            setDescription: { $0.setDewPoint(description: $1, ruuviTag: $2) },
            lowerValue: { $0.lowerDewPoint(for: $1) }, upperValue: { $0.upperDewPoint(for: $1) },
            description: { $0.dewPointDescription(for: $1) },
            legacyLower: { $0.lowerDewPoint(for: $1) }, legacyUpper: { $0.upperDewPoint(for: $1) },
            legacyDescription: { $0.dewPointDescription(for: $1) }),
        .init(
            type: .pressure(lower: 950, upper: 1050), cloudType: .pressure,
            lower: 950, upper: 1050, scale: 100,
            setLower: { $0.setLower(pressure: $1, ruuviTag: $2) },
            setUpper: { $0.setUpper(pressure: $1, ruuviTag: $2) },
            setDescription: { $0.setPressure(description: $1, ruuviTag: $2) },
            lowerValue: { $0.lowerPressure(for: $1) }, upperValue: { $0.upperPressure(for: $1) },
            description: { $0.pressureDescription(for: $1) },
            legacyLower: { $0.lowerPressure(for: $1) }, legacyUpper: { $0.upperPressure(for: $1) },
            legacyDescription: { $0.pressureDescription(for: $1) }),
        .init(
            type: .signal(lower: -90, upper: -20), cloudType: .signal,
            lower: -90, upper: -20, scale: 1,
            setLower: { $0.setLower(signal: $1, ruuviTag: $2) },
            setUpper: { $0.setUpper(signal: $1, ruuviTag: $2) },
            setDescription: { $0.setSignal(description: $1, ruuviTag: $2) },
            lowerValue: { $0.lowerSignal(for: $1) }, upperValue: { $0.upperSignal(for: $1) },
            description: { $0.signalDescription(for: $1) },
            legacyLower: { $0.lowerSignal(for: $1) }, legacyUpper: { $0.upperSignal(for: $1) },
            legacyDescription: { $0.signalDescription(for: $1) }),
        .init(
            type: .batteryVoltage(lower: 2, upper: 3.6), cloudType: .battery,
            lower: 2, upper: 3.6, scale: 1,
            setLower: { $0.setLower(batteryVoltage: $1, ruuviTag: $2) },
            setUpper: { $0.setUpper(batteryVoltage: $1, ruuviTag: $2) },
            setDescription: { $0.setBatteryVoltage(description: $1, ruuviTag: $2) },
            lowerValue: { $0.lowerBatteryVoltage(for: $1) }, upperValue: { $0.upperBatteryVoltage(for: $1) },
            description: { $0.batteryVoltageDescription(for: $1) },
            legacyLower: { $0.lowerBatteryVoltage(for: $1) }, legacyUpper: { $0.upperBatteryVoltage(for: $1) },
            legacyDescription: { $0.batteryVoltageDescription(for: $1) }),
        .init(
            type: .aqi(lower: 10, upper: 90), cloudType: .aqi,
            lower: 10, upper: 90, scale: 1,
            setLower: { $0.setLower(aqi: $1, ruuviTag: $2) },
            setUpper: { $0.setUpper(aqi: $1, ruuviTag: $2) },
            setDescription: { $0.setAQI(description: $1, ruuviTag: $2) },
            lowerValue: { $0.lowerAQI(for: $1) }, upperValue: { $0.upperAQI(for: $1) },
            description: { $0.aqiDescription(for: $1) },
            legacyLower: { $0.lowerAQI(for: $1) }, legacyUpper: { $0.upperAQI(for: $1) },
            legacyDescription: { $0.aqiDescription(for: $1) }),
        .init(
            type: .carbonDioxide(lower: 400, upper: 2000), cloudType: .co2,
            lower: 400, upper: 2000, scale: 1,
            setLower: { $0.setLower(carbonDioxide: $1, ruuviTag: $2) },
            setUpper: { $0.setUpper(carbonDioxide: $1, ruuviTag: $2) },
            setDescription: { $0.setCarbonDioxide(description: $1, ruuviTag: $2) },
            lowerValue: { $0.lowerCarbonDioxide(for: $1) }, upperValue: { $0.upperCarbonDioxide(for: $1) },
            description: { $0.carbonDioxideDescription(for: $1) },
            legacyLower: { $0.lowerCarbonDioxide(for: $1) }, legacyUpper: { $0.upperCarbonDioxide(for: $1) },
            legacyDescription: { $0.carbonDioxideDescription(for: $1) }),
        .init(
            type: .pMatter1(lower: 1, upper: 60), cloudType: .pm10,
            lower: 1, upper: 60, scale: 1,
            setLower: { $0.setLower(pm1: $1, ruuviTag: $2) },
            setUpper: { $0.setUpper(pm1: $1, ruuviTag: $2) },
            setDescription: { $0.setPM1(description: $1, ruuviTag: $2) },
            lowerValue: { $0.lowerPM1(for: $1) }, upperValue: { $0.upperPM1(for: $1) },
            description: { $0.pm1Description(for: $1) },
            legacyLower: { $0.lowerPM1(for: $1) }, legacyUpper: { $0.upperPM1(for: $1) },
            legacyDescription: { $0.pm1Description(for: $1) }),
        .init(
            type: .pMatter25(lower: 2, upper: 70), cloudType: .pm25,
            lower: 2, upper: 70, scale: 1,
            setLower: { $0.setLower(pm25: $1, ruuviTag: $2) },
            setUpper: { $0.setUpper(pm25: $1, ruuviTag: $2) },
            setDescription: { $0.setPM25(description: $1, ruuviTag: $2) },
            lowerValue: { $0.lowerPM25(for: $1) }, upperValue: { $0.upperPM25(for: $1) },
            description: { $0.pm25Description(for: $1) },
            legacyLower: { $0.lowerPM25(for: $1) }, legacyUpper: { $0.upperPM25(for: $1) },
            legacyDescription: { $0.pm25Description(for: $1) }),
        .init(
            type: .pMatter4(lower: 3, upper: 80), cloudType: .pm40,
            lower: 3, upper: 80, scale: 1,
            setLower: { $0.setLower(pm4: $1, ruuviTag: $2) },
            setUpper: { $0.setUpper(pm4: $1, ruuviTag: $2) },
            setDescription: { $0.setPM4(description: $1, ruuviTag: $2) },
            lowerValue: { $0.lowerPM4(for: $1) }, upperValue: { $0.upperPM4(for: $1) },
            description: { $0.pm4Description(for: $1) },
            legacyLower: { $0.lowerPM4(for: $1) }, legacyUpper: { $0.upperPM4(for: $1) },
            legacyDescription: { $0.pm4Description(for: $1) }),
        .init(
            type: .pMatter10(lower: 4, upper: 90), cloudType: .pm100,
            lower: 4, upper: 90, scale: 1,
            setLower: { $0.setLower(pm10: $1, ruuviTag: $2) },
            setUpper: { $0.setUpper(pm10: $1, ruuviTag: $2) },
            setDescription: { $0.setPM10(description: $1, ruuviTag: $2) },
            lowerValue: { $0.lowerPM10(for: $1) }, upperValue: { $0.upperPM10(for: $1) },
            description: { $0.pm10Description(for: $1) },
            legacyLower: { $0.lowerPM10(for: $1) }, legacyUpper: { $0.upperPM10(for: $1) },
            legacyDescription: { $0.pm10Description(for: $1) }),
        .init(
            type: .voc(lower: 10, upper: 250), cloudType: .voc,
            lower: 10, upper: 250, scale: 1,
            setLower: { $0.setLower(voc: $1, ruuviTag: $2) },
            setUpper: { $0.setUpper(voc: $1, ruuviTag: $2) },
            setDescription: { $0.setVOC(description: $1, ruuviTag: $2) },
            lowerValue: { $0.lowerVOC(for: $1) }, upperValue: { $0.upperVOC(for: $1) },
            description: { $0.vocDescription(for: $1) },
            legacyLower: { $0.lowerVOC(for: $1) }, legacyUpper: { $0.upperVOC(for: $1) },
            legacyDescription: { $0.vocDescription(for: $1) }),
        .init(
            type: .nox(lower: 5, upper: 200), cloudType: .nox,
            lower: 5, upper: 200, scale: 1,
            setLower: { $0.setLower(nox: $1, ruuviTag: $2) },
            setUpper: { $0.setUpper(nox: $1, ruuviTag: $2) },
            setDescription: { $0.setNOX(description: $1, ruuviTag: $2) },
            lowerValue: { $0.lowerNOX(for: $1) }, upperValue: { $0.upperNOX(for: $1) },
            description: { $0.noxDescription(for: $1) },
            legacyLower: { $0.lowerNOX(for: $1) }, legacyUpper: { $0.upperNOX(for: $1) },
            legacyDescription: { $0.noxDescription(for: $1) }),
        .init(
            type: .soundInstant(lower: 20, upper: 80), cloudType: .soundInstant,
            lower: 20, upper: 80, scale: 1,
            setLower: { $0.setLower(soundInstant: $1, ruuviTag: $2) },
            setUpper: { $0.setUpper(soundInstant: $1, ruuviTag: $2) },
            setDescription: { $0.setSoundInstant(description: $1, ruuviTag: $2) },
            lowerValue: { $0.lowerSoundInstant(for: $1) }, upperValue: { $0.upperSoundInstant(for: $1) },
            description: { $0.soundInstantDescription(for: $1) },
            legacyLower: { $0.lowerSoundInstant(for: $1) }, legacyUpper: { $0.upperSoundInstant(for: $1) },
            legacyDescription: { $0.soundInstantDescription(for: $1) }),
        .init(
            type: .soundAverage(lower: 25, upper: 85), cloudType: .soundAverage,
            lower: 25, upper: 85, scale: 1,
            setLower: { $0.setLower(soundAverage: $1, ruuviTag: $2) },
            setUpper: { $0.setUpper(soundAverage: $1, ruuviTag: $2) },
            setDescription: { $0.setSoundAverage(description: $1, ruuviTag: $2) },
            lowerValue: { $0.lowerSoundAverage(for: $1) }, upperValue: { $0.upperSoundAverage(for: $1) },
            description: { $0.soundAverageDescription(for: $1) },
            legacyLower: { $0.lowerSoundAverage(for: $1) }, legacyUpper: { $0.upperSoundAverage(for: $1) },
            legacyDescription: { $0.soundAverageDescription(for: $1) }),
        .init(
            type: .soundPeak(lower: 30, upper: 90), cloudType: .soundPeak,
            lower: 30, upper: 90, scale: 1,
            setLower: { $0.setLower(soundPeak: $1, ruuviTag: $2) },
            setUpper: { $0.setUpper(soundPeak: $1, ruuviTag: $2) },
            setDescription: { $0.setSoundPeak(description: $1, ruuviTag: $2) },
            lowerValue: { $0.lowerSoundPeak(for: $1) }, upperValue: { $0.upperSoundPeak(for: $1) },
            description: { $0.soundPeakDescription(for: $1) },
            legacyLower: { $0.lowerSoundPeak(for: $1) }, legacyUpper: { $0.upperSoundPeak(for: $1) },
            legacyDescription: { $0.soundPeakDescription(for: $1) }),
        .init(
            type: .luminosity(lower: 10, upper: 20000), cloudType: .luminosity,
            lower: 10, upper: 20000, scale: 1,
            setLower: { $0.setLower(luminosity: $1, ruuviTag: $2) },
            setUpper: { $0.setUpper(luminosity: $1, ruuviTag: $2) },
            setDescription: { $0.setLuminosity(description: $1, ruuviTag: $2) },
            lowerValue: { $0.lowerLuminosity(for: $1) }, upperValue: { $0.upperLuminosity(for: $1) },
            description: { $0.luminosityDescription(for: $1) },
            legacyLower: { $0.lowerLuminosity(for: $1) }, legacyUpper: { $0.upperLuminosity(for: $1) },
            legacyDescription: { $0.luminosityDescription(for: $1) }),
        .init(
            type: .humidity(lower: .init(value: 2, unit: .absolute), upper: .init(value: 15, unit: .absolute)),
            cloudType: .humidityAbsolute, lower: 2, upper: 15, scale: 1,
            setLower: { $0.setLower(humidity: $1.map { Humidity(value: $0, unit: .absolute) }, for: $2) },
            setUpper: { $0.setUpper(humidity: $1.map { Humidity(value: $0, unit: .absolute) }, for: $2) },
            setDescription: { $0.setHumidity(description: $1, for: $2) },
            lowerValue: { $0.lowerHumidity(for: $1)?.value }, upperValue: { $0.upperHumidity(for: $1)?.value },
            description: { $0.humidityDescription(for: $1) },
            legacyLower: { $0.lowerHumidity(for: $1)?.value }, legacyUpper: { $0.upperHumidity(for: $1)?.value },
            legacyDescription: { $0.humidityDescription(for: $1) }),
    ]
}

@MainActor final class AlertMatrixFixture {
    let cloud = CloudSpy()
    let service: RuuviServiceAlertImpl
    let sensor: RuuviTagSensorStruct
    let settings: RuuviLocalSettings
    let ids: RuuviLocalIDs
    private let suite = "AlertMatrixTests." + UUID().uuidString
    let defaults: UserDefaults
    var persistence: AlertPersistenceUserDefaults { AlertPersistenceUserDefaults(defaults: defaults) }
    init(identity: Int = 2, cloud enabled: Bool = false) {
        defaults = UserDefaults(suiteName: suite)!
        let factory = RuuviLocalFactoryUserDefaults()
        ids = factory.createLocalIDs()
        settings = factory.createLocalSettings()
        service = RuuviServiceAlertImpl(cloud: cloud, localIDs: ids, ruuviLocalSettings: settings, defaults: defaults)
        let bytes = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12)
        let mac = stride(from: 0, to: 12, by: 2).map { offset in
            let start = bytes.index(bytes.startIndex, offsetBy: offset)
            return String(bytes[start..<bytes.index(start, offsetBy: 2)])
        }.joined(separator: ":")
        sensor = RuuviTagSensorStruct(
            version: 5, firmwareVersion: nil,
            luid: identity == 1 ? nil : UUID().uuidString.luid, macId: identity == 0 ? nil : mac.mac,
            serviceUUID: nil, isConnectable: true, name: "Alert matrix", isClaimed: enabled,
            isOwner: true, owner: nil, ownersPlan: nil, isCloudSensor: enabled, canShare: false,
            sharedTo: [], maxHistoryDays: nil)
        if let luid = sensor.luid, let mac = sensor.macId {
            ids.set(luid: luid, for: mac); ids.set(mac: mac, for: luid)
        }
    }
    func clean() {
        defaults.removePersistentDomain(forName: suite)
        let identities = [sensor.luid?.value, sensor.macId?.value].compactMap { $0 }
        let standard = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName
        let values = standard.persistentDomain(forName: domain) ?? [:]
        standard.setPersistentDomain(
            values.filter { key, _ in
                !identities.contains { key == $0 || key.hasSuffix("." + $0) }
            }, forName: domain)
    }
}

struct CloudAlertFixture: RuuviCloudAlert {
    var type: RuuviCloudAlertType?
    var enabled: Bool? = true
    var min: Double?
    var max: Double?
    var counter: Int?
    var delay: Int?
    var description: String? = "Cloud description"
    var triggered: Bool? = true
    var triggeredAt: String? = "2026-01-02T03:04:05Z"
    var lastUpdated: Date?
}
struct CloudSensorAlertsFixture: RuuviCloudSensorAlerts {
    var sensor: String?
    var alerts: [RuuviCloudAlert]?
}
