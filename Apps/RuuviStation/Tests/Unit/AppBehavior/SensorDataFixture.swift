import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviReactor
import RuuviService
import UIKit
@testable import station

@MainActor final class SensorDataFixture {
    let measurements = MeasurementFixture()
    let reactor = AppTestReactor()
    let pool = AppPoolSpy()
    let properties = AppSensorPropertiesSpy()
    let delegate = SensorDataDelegateSpy()
    let notifications = NotificationCenter()
    var service: RuuviTagDataService!
    var sensors = [RuuviTagSensorStruct]()
    private let originalRefresh = UserDefaults(suiteName: AppGroupConstants.appGroupSuiteIdentifier)?
        .object(forKey: AppGroupConstants.forceRefreshWidgetKey)
    init() {
        measurements.storage.useLatestOverride = true
        service = RuuviTagDataService(
            ruuviReactor: reactor, ruuviStorage: measurements.storage,
            measurementService: measurements.measurement, ruuviSensorPropertiesService: properties,
            settings: measurements.settings, flags: measurements.flags, ruuviPool: pool,
            notificationCenter: notifications)
        service.delegate = delegate
    }
    func sensor(_ name: String = "Office", version: Int = 225, cloud: Bool = false) -> RuuviTagSensorStruct {
        var sensor = measurements.sensor
        sensor.luid = UUID().uuidString.luid
        sensor.macId = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12)).mac
        sensor.name = name
        sensor.version = version
        sensor.isCloudSensor = cloud
        sensor.isClaimed = cloud
        sensors.append(sensor)
        return sensor
    }
    func start(_ sensors: [RuuviTagSensorStruct]) async {
        service.startObservingSensors()
        send(.initial(sensors.map(\.any)))
        await waitForAppState("initial snapshots") { service.getAllSnapshots().count == sensors.count }
        await flushAppBindings()
    }
    func send(_ change: RuuviReactorChange<AnyRuuviTagSensor>) {
        Array(reactor.sensors.values).forEach { $0(change) }
    }
    func cleanup() {
        service?.stopObservingSensors()
        for sensor in sensors { RuuviTagDataService.clearMeasurementDisplayPreference(for: sensor.id) }
        if let units = AppAssembly.shared.assembler.resolver.resolve(RuuviServiceMeasurement.self)?.units {
            RuuviTagDataService.setPreferredUnits(units)
        }
        let ids = Set(sensors.map(\.id))
        let cache = WidgetSensorCache()
        cache.prune(keeping: Set(cache.loadAll().filter { !ids.contains($0.id) }.map(\.id)))
        UserDefaults(suiteName: AppGroupConstants.appGroupSuiteIdentifier)?
            .set(originalRefresh, forKey: AppGroupConstants.forceRefreshWidgetKey)
    }
    func image(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { context in
            color.setFill(); context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
    }
    func calibration(
        _ sensor: RuuviTagSensor, temperature: Double? = 2,
        codes: [String]? = nil, useDefault: Bool? = nil
    ) -> SensorSettings {
        SensorSettingsStruct(
            luid: sensor.luid, macId: sensor.macId, temperatureOffset: temperature,
            humidityOffset: 0.1, pressureOffset: 10, displayOrder: codes, defaultDisplayOrder: useDefault)
    }
}

final class SensorDataDelegateSpy: RuuviTagDataServiceDelegate {
    struct Update { let id: String; let invalidateLayout: Bool }
    var lists = [[RuuviTagCardSnapshot]]()
    var animations = [Bool]()
    var updates = [Update]()
    var inserted = [String]()
    var orders = [[String]]()
    var errors = [Error]()
    func sensorDataService(
        _ service: RuuviTagDataService, didUpdateSnapshots snapshots: [RuuviTagCardSnapshot],
        withAnimation: Bool
    ) {
        lists.append(snapshots); animations.append(withAnimation)
    }
    func sensorDataService(
        _ service: RuuviTagDataService, didUpdateSnapshot snapshot: RuuviTagCardSnapshot,
        invalidateLayout: Bool
    ) {
        updates.append(.init(id: snapshot.id, invalidateLayout: invalidateLayout))
    }
    func sensorDataService(_ service: RuuviTagDataService, didAddNewSensor sensor: RuuviTagSensor, newOrder: [String]) {
        inserted.append(sensor.id); orders.append(newOrder)
    }
    func sensorDataService(_ service: RuuviTagDataService, didEncounterError error: Error) { errors.append(error) }
}

struct AppSubscription: CloudSensorSubscription {
    var macId: String?
    var subscriptionName: String?
    var isActive: Bool?
    var maxClaims: Int?
    var maxHistoryDays: Int?
    var maxResolutionMinutes: Int?
    var maxShares: Int?
    var maxSharesPerSensor: Int?
    var delayedAlertAllowed: Bool?
    var emailAlertAllowed: Bool?
    var offlineAlertAllowed: Bool?
    var pdfExportAllowed: Bool?
    var pushAlertAllowed: Bool?
    var telegramAlertAllowed: Bool?
    var endAt: String?
}
