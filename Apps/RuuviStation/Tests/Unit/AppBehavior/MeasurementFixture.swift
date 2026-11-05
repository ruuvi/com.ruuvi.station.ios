import Combine
import DGCharts
import Foundation
import Humidity
import RuuviLocal
import RuuviOntology
import RuuviReactor
import RuuviService
import RuuviStorage
import Swinject
import XCTest
@testable import station

@MainActor final class MeasurementFixture {
    let settings = AppTestSettings()
    let sensor: RuuviTagSensorStruct
    let snapshot: RuuviTagCardSnapshot
    let alerts: RuuviServiceAlert
    let measurement: RuuviServiceMeasurement
    let storage: AppTestStorage
    let cloud = AppTestCloudSync()
    let view = DetailsViewSpy()
    let output = DetailsOutputSpy()
    let flags = AppTestFlags()
    var registeredAlerts: [AlertType] = []

    init(cloud: Bool = false) {
        sensor = RuuviTagSensorStruct(
            version: 225, firmwareVersion: nil, luid: UUID().uuidString.luid,
            macId: String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12)).mac, serviceUUID: nil,
            isConnectable: true, name: "Measurement fixture", isClaimed: cloud,
            isOwner: true, owner: nil, ownersPlan: nil, isCloudSensor: cloud,
            canShare: false, sharedTo: [], maxHistoryDays: nil
        )
        snapshot = RuuviTagCardSnapshot.create(
            id: sensor.id, name: sensor.name, luid: sensor.luid, mac: sensor.macId,
            serviceUUID: nil, isCloud: cloud, isOwner: true, isConnectable: true, version: sensor.version
        )
        let resolver = AppAssembly.shared.assembler.resolver
        alerts = resolver.resolve(RuuviServiceAlert.self)!
        measurement = RuuviServiceMeasurementImpl(settings: settings, emptyValueString: "-", percentString: "%")
        storage = AppTestStorage(resolver.resolve(RuuviStorage.self)!)
    }

    func presenter(
        type: MeasurementType = .temperature, variant: MeasurementDisplayVariant? = nil,
        calibration: SensorSettings? = nil
    ) -> MeasurementDetailsPresenter {
        let presenter = MeasurementDetailsPresenter(
            settings: settings, flags: flags, measurementService: measurement, alertService: alerts,
            ruuviStorage: storage, cloudSyncService: cloud
        )
        presenter.view = view
        presenter.configure(
            with: snapshot, measurementType: type, variant: variant, ruuviTag: sensor,
            sensorSettings: calibration, output: output
        )
        return presenter
    }

    func resolver() -> MeasurementVariantResolver {
        MeasurementVariantResolver(settings: settings, measurementService: measurement, alertService: alerts)
    }

    func register(_ type: AlertType) {
        precondition(!sensor.isCloud)
        alerts.register(type: type, ruuviTag: sensor)
        registeredAlerts.append(type)
    }

    func cleanup() { registeredAlerts.forEach { alerts.remove(type: $0, ruuviTag: sensor) } }

    func record(date: Date = Date(), temperature: Double = 20, co2: Double = 800) -> RuuviTagSensorRecordStruct {
        RuuviTagSensorRecordStruct(
            luid: sensor.luid, date: date, source: .advertisement, macId: sensor.macId, rssi: -60,
            version: 225, temperature: Temperature(value: temperature, unit: .celsius),
            humidity: Humidity(relative: 0.5, temperature: Temperature(value: temperature, unit: .celsius)),
            pressure: Pressure(value: 1000, unit: .hectopascals),
            acceleration: Acceleration(
                x: .init(value: 0.1, unit: .gravity), y: .init(value: -0.2, unit: .gravity),
                z: .init(value: 1, unit: .gravity)
            ), voltage: Voltage(value: 3, unit: .volts), movementCounter: 12,
            measurementSequenceNumber: 42, txPower: 4, pm1: 1, pm25: 2.5, pm4: 4, pm10: 10,
            co2: co2, voc: 100, nox: 5, luminance: 200, dbaInstant: 30, dbaAvg: 25, dbaPeak: 40,
            temperatureOffset: 0, humidityOffset: 0, pressureOffset: 0
        )
    }

    func indicator(_ variant: MeasurementDisplayVariant) -> RuuviTagCardSnapshotIndicatorData {
        .init(
            variant: variant, value: "20", unit: "°C", isProminent: true, showSubscript: false,
            tintColor: nil, qualityState: nil)
    }
}

final class AppTestFlags: RuuviLocalFlags {
    var showNewSettings = true
    var downloadBetaFirmware = false
    var downloadAlphaFirmware = false
    var autoSyncGattHistoryForRuuviAir = false
    var autoSyncGattHistoryForRuuviAirMinimumLastSyncDateAgeMinutes = 0
    var allowConcurrentGattSyncForMultipleSensors = false
    var showMarketingPreference = false
    var marketingConsentPromptIntervalMinutes = 0
    var showDashboardSensorSearch = false
    var graphDownsampleMaximumPoints = 3000
}

@MainActor final class AppTestCloudSync: RuuviServiceCloudSync {
    var count = 0
    var failure = false
    var beforeSync: (() async -> Void)?
    func sync(sensor: RuuviTagSensor) async throws(RuuviServiceError) -> [AnyRuuviTagSensorRecord] {
        count += 1
        await beforeSync?()
        if failure { throw .failedToParseNetworkResponse }
        return []
    }
    func syncAll() async throws(RuuviServiceError) -> Set<AnyRuuviTagSensor> { [] }
    func syncAllHistory() async throws(RuuviServiceError) -> Bool { true }
    func refreshLatestRecord() async throws(RuuviServiceError) -> Bool { true }
    func syncAllRecords() async throws(RuuviServiceError) -> Bool { true }
    func syncSettings() async throws(RuuviServiceError) -> RuuviCloudSettings { throw .failedToParseNetworkResponse }
    func executePendingRequests() async throws(RuuviServiceError) -> Bool { true }
}

final class DetailsViewSpy: MeasurementDetailsViewInput {
    var charts: [RuuviGraphViewDataModel] = []
    var units: [String] = []
    var appended: [ChartDataEntry] = []
    var noData: [Bool] = []
    var measurements: [RuuviTagCardSnapshotDisplayData?] = []
    var alertUpdates = 0
    func updateMeasurements(with indicatorData: RuuviTagCardSnapshotDisplayData?) { measurements.append(indicatorData) }
    func updateAlertStates() { alertUpdates += 1 }
    func setChartData(
        _ data: RuuviGraphViewDataModel, settings: RuuviLocalSettings, displayType: MeasurementType,
        unit: String, measurementService: RuuviServiceMeasurement
    ) { charts.append(data); units.append(unit) }
    func updateChartData(_ entries: [ChartDataEntry], showAlertRangeInGraph: Bool) { appended += entries }
    func setNoDataLabelVisibility(show: Bool) { noData.append(show) }
    var values: [Double] { (charts.last?.chartData?.dataSets.first as? LineChartDataSet)?.entries.map(\.y) ?? [] }
}

final class DetailsOutputSpy: MeasurementDetailsPresenterOutput {
    var variant: MeasurementDisplayVariant?
    var sensorID: String?
    func detailsViewDidDismiss(
        for snapshot: RuuviTagCardSnapshot, measurement: MeasurementType, variant: MeasurementDisplayVariant?,
        ruuviTag: RuuviTagSensor, module: MeasurementDetailsPresenterInput
    ) { self.variant = variant; sensorID = ruuviTag.id }
}

@MainActor func waitForAppState(
    _ description: String, file: StaticString = #filePath, line: UInt = #line,
    _ condition: () -> Bool
) async {
    for _ in 0..<200 {
        if condition() { return }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTFail("Timed out waiting for " + description, file: file, line: line)
}
