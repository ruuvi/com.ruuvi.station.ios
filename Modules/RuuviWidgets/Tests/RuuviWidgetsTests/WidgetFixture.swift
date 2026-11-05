import Foundation
import RuuviCloud
import RuuviLocal
import RuuviOntology
import XCTest
@testable import RuuviWidgets

@MainActor final class WidgetFixture {
    let suite = UUID().uuidString
    let defaults: UserDefaults
    let cache: WidgetSensorCache
    let cloudCache: WidgetCloudCache
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    var response = [RuuviCloudSensorDense]()
    var error: Error?
    var requests = 0
    var beforeResponse: (() async -> Void)?
    lazy var model = WidgetViewModel(
        defaults: defaults, now: { [unowned self] in self.date }, preferredLanguage: { "en" }
    ) { [unowned self] in
        self.requests += 1
        await self.beforeResponse?()
        if let error = self.error { throw error }
        return self.response
    }
    init() throws {
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        cache = WidgetSensorCache(userDefaults: defaults)
        cloudCache = WidgetCloudCache(userDefaults: defaults)
        defaults.set(2, forKey: Constants.temperatureUnitKey.rawValue)
        defaults.set(2, forKey: Constants.temperatureAccuracyKey.rawValue)
        defaults.set(0, forKey: Constants.humidityUnitKey.rawValue)
        defaults.set(2, forKey: Constants.humidityAccuracyKey.rawValue)
        defaults.set(2, forKey: Constants.pressureAccuracyKey.rawValue)
        defaults.set(UnitPressure.hectopascals.hashValue, forKey: Constants.pressureUnitKey.rawValue)
        defaults.set("en", forKey: Constants.languageKey.rawValue)
    }
    func authorize(_ enabled: Bool = true, cloudSensors: Bool = true) {
        defaults.set(enabled, forKey: Constants.isAuthorizedUDKey.rawValue)
        defaults.set(cloudSensors, forKey: Constants.hasCloudSensorsKey.rawValue)
    }
    func clean() { defaults.removePersistentDomain(forName: suite) }
    var provider: WidgetProvider {
        WidgetProvider(
            viewModel: model, localCache: cache, cloudCache: cloudCache, now: { [unowned self] in self.date })
    }
    var multiProvider: MultiSensorWidgetProvider {
        MultiSensorWidgetProvider(
            viewModel: model, localCache: cache, cloudCache: cloudCache, now: { [unowned self] in self.date })
    }
    func record(
        version: Int = 5, seconds: Double = 0, source: RuuviTagSensorRecordSource = .advertisement,
        mac: String = "AA:BB:CC:DD:EE:01", temperature: Double = 20
    ) -> RuuviTagSensorRecordStruct {
        RuuviTagSensorRecordStruct(
            luid: ("00000000-0000-0000-0000-" + mac.replacingOccurrences(of: ":", with: "")).luid,
            date: date.addingTimeInterval(seconds),
            source: source, macId: mac.mac, rssi: -60, version: version,
            temperature: .init(value: temperature, unit: .celsius),
            humidity: .init(relative: 0.5, temperature: .init(value: temperature, unit: .celsius)),
            pressure: .init(value: 1000, unit: .hectopascals),
            acceleration: Acceleration(
                x: .init(value: 1.25, unit: .gravity), y: .init(value: -0.5, unit: .gravity),
                z: .init(value: 0, unit: .gravity)),
            voltage: .init(value: 3, unit: .volts), movementCounter: 7, measurementSequenceNumber: 123,
            txPower: 4, pm1: 1.1, pm25: 2.2, pm4: 4.4, pm10: 10.5, co2: 420, voc: 11, nox: 12,
            luminance: 100, dbaInstant: 30, dbaAvg: 31, dbaPeak: 32, temperatureOffset: 0, humidityOffset: 0,
            pressureOffset: 0)
    }
    func config(_ code: RuuviCloudSensorVisibilityCode, sensor: String = "AA:BB:CC:DD:EE:01")
        -> SingleSensorWidgetConfiguration
    {
        SingleSensorWidgetConfiguration(
            sensorId: sensor, deviceType: .ruuviAir, sensorSelectionIdentifier: code.rawValue, sensor: nil)
    }
    func intent(id: String? = "AA:BB:CC:DD:EE:01") -> RuuviTagSelectionIntent {
        let intent = RuuviTagSelectionIntent()
        if let id { intent.ruuviWidgetTag = RuuviWidgetTag(identifier: id, display: "Sensor") }
        intent.sensor = .temperature
        return intent
    }
    func multiIntent(_ ids: [String]) -> RuuviMultiSensorSelectionIntent {
        let intent = RuuviMultiSensorSelectionIntent()
        let tags = ids.map { RuuviWidgetTag(identifier: $0, display: $0) }
        if tags.count > 0 { intent.sensor1 = tags[0] }
        if tags.count > 1 { intent.sensor2 = tags[1] }
        if tags.count > 2 { intent.sensor3 = tags[2] }
        if tags.count > 3 { intent.sensor4 = tags[3] }
        if tags.count > 4 { intent.sensor5 = tags[4] }
        if tags.count > 5 { intent.sensor6 = tags[5] }
        return intent
    }
    func store(_ record: RuuviTagSensorRecord, name: String = "Local name", order: [String]? = nil) {
        let settings = order.map {
            WidgetSensorSettingsSnapshot(
                temperatureOffset: 2, humidityOffset: 0.1, pressureOffset: 3,
                displayOrder: $0, defaultDisplayOrder: false)
        }
        cache.upsert(
            sensorId: record.macId!.value, name: name, macId: record.macId?.value, luid: record.luid?.value,
            record: WidgetSensorRecordSnapshot(from: record), settings: settings)
    }
    func dense(
        _ record: RuuviTagSensorRecord?, id: String = "AA:BB:CC:DD:EE:01", name: String = "Cloud name",
        settings: RuuviCloudSensorSettings? = nil, temperatureOffset: Double? = nil, humidityOffset: Double? = nil,
        pressureOffset: Double? = nil
    ) -> RuuviCloudSensorDense {
        let sensor = CloudSensorStruct(
            id: id, serviceUUID: nil, name: name, isClaimed: true, isOwner: true,
            owner: nil, ownersPlan: nil, picture: nil, offsetTemperature: temperatureOffset,
            offsetHumidity: humidityOffset, offsetPressure: pressureOffset, isCloudSensor: true, canShare: false,
            sharedTo: [], maxHistoryDays: nil)
        return RuuviCloudSensorDense(
            sensor: sensor, record: record, alerts: WidgetAlerts(), subscription: nil, settings: settings)
    }
}

private struct WidgetAlerts: RuuviCloudSensorAlerts {
    let sensor: String? = nil
    let alerts: [RuuviCloudAlert]? = nil
}
