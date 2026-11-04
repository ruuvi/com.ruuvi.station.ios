import Foundation
import Testing
import RuuviLocal
import RuuviOntology
import RuuviStorage
@testable import RuuviService
#if SWIFT_PACKAGE
    import RuuviLocalUserDefaults
    @testable import RuuviServiceExport
    import RuuviServiceMeasurement
#endif

@Suite(.serialized) @MainActor struct ExportTests {
    @Test(arguments: [
        ["plain", "plain"], ["a,b", "\"a,b\""], ["a\"b", "\"a\"\"b\""],
        ["a\nb", "\"a\nb\""], ["a\rb", "\"a\rb\""], ["", ""], ["🌿", "🌿"],
    ])
    func csvEscapesDelimitersQuotesAndNewlines(pair: [String]) {
        #expect(RuuviServiceExportImpl.csvCell(pair[0]) == pair[1])
    }

    @Test func csvIsCompleteOnReturnAndRespectsHistoryWindowAndCalibration() async throws {
        let fixture = try PropertiesFixture()
        try await fixture.pool.create(fixture.sensor)
        let settings = RuuviLocalFactoryUserDefaults().createLocalSettings()
        let original = settings.dataPruningOffsetHours
        defer { settings.dataPruningOffsetHours = original }
        settings.dataPruningOffsetHours = 1
        try await fixture.pool.create([
            record(sensor: fixture.sensor, date: Date().addingTimeInterval(-60)),
            record(sensor: fixture.sensor, date: Date().addingTimeInterval(-120)),
            record(sensor: fixture.sensor, date: Date().addingTimeInterval(-7200)),
        ])
        let service = exporter(storage: fixture.storage, settings: settings)
        let calibration = SensorSettingsStruct(
            luid: fixture.sensor.luid, macId: fixture.sensor.macId,
            temperatureOffset: 2, humidityOffset: nil, pressureOffset: nil)
        let url = try await service.csvLog(for: fixture.sensor.id, version: 5, settings: calibration)
        defer { try? FileManager.default.removeItem(at: url) }
        let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
        #expect(lines.count == 3)
        #expect(url.pathExtension == "csv")
        #expect(lines.dropFirst().allSatisfy { $0.split(separator: ",").contains("22") })
    }

    @Test func concurrentXlsxExportsReturnDistinctFinalizedArchivesWithoutSettings() async throws {
        let fixture = try PropertiesFixture()
        try await fixture.pool.create(fixture.sensor)
        try await fixture.pool.create(record(sensor: fixture.sensor, date: Date().addingTimeInterval(-1)))
        let settings = RuuviLocalFactoryUserDefaults().createLocalSettings()
        let service = exporter(storage: fixture.storage, settings: settings)
        async let first = service.xlsxLog(for: fixture.sensor.id, version: 5, settings: nil)
        async let second = service.xlsxLog(for: fixture.sensor.id, version: 5, settings: nil)
        let urls = try await [first, second]
        defer { for url in urls { try? FileManager.default.removeItem(at: url) } }
        #expect(urls[0] != urls[1])
        for url in urls {
            let bytes = try Data(contentsOf: url)
            #expect(bytes.starts(with: [0x50, 0x4b, 0x03, 0x04]))
            #expect(bytes.suffix(22).starts(with: [0x50, 0x4b, 0x05, 0x06]))
            #expect(url.pathExtension == "xlsx")
        }
    }

    @Test(arguments: [false, true])
    func invalidOutputPathReturnsAnErrorInsteadOfCrashing(xlsx: Bool) async throws {
        let fixture = try PropertiesFixture()
        var sensor = fixture.sensor
        sensor.name = String(repeating: "x", count: 300)
        try await fixture.pool.create(sensor)
        let service = exporter(
            storage: fixture.storage, settings: RuuviLocalFactoryUserDefaults().createLocalSettings())
        do {
            _ =
                try await
                (xlsx
                ? service.xlsxLog(for: sensor.id, version: 5, settings: nil)
                : service.csvLog(for: sensor.id, version: 5, settings: nil))
            Issue.record("An overlong filename must report an export error")
        } catch {
            guard case .writeToDisk = error else { Issue.record("Unexpected export error: \(error)"); return }
        }
    }

    @Test(arguments: [false, true])
    func cancelledExportTerminatesBeforeReadingOrWriting(xlsx: Bool) async throws {
        let fixture = try PropertiesFixture()
        let service = exporter(
            storage: fixture.storage, settings: RuuviLocalFactoryUserDefaults().createLocalSettings())
        let task = Task { @MainActor in
            try await
                (xlsx
                ? service.xlsxLog(for: fixture.sensor.id, version: 5, settings: nil)
                : service.csvLog(for: fixture.sensor.id, version: 5, settings: nil))
        }
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Cancelled export succeeded")
        } catch {
            guard let error = error as? RuuviServiceError,
                case .writeToDisk(let underlying) = error, underlying is CancellationError
            else {
                Issue.record("Unexpected cancellation: \(error)"); return
            }
        }
    }

    @Test func missingSensorPreservesStorageError() async throws {
        let fixture = try PropertiesFixture()
        let service = exporter(
            storage: fixture.storage, settings: RuuviLocalFactoryUserDefaults().createLocalSettings())
        do {
            _ = try await service.csvLog(for: fixture.sensor.id, version: 5, settings: nil)
            Issue.record("Missing sensor export succeeded")
        } catch {
            guard case .ruuviStorage(.ruuviPersistence(.failedToFindRuuviTag)) = error else {
                Issue.record("Unexpected missing-sensor error: \(error)"); return
            }
        }
    }

    private func exporter(storage: RuuviStorage, settings: RuuviLocalSettings) -> RuuviServiceExportImpl {
        RuuviServiceExportImpl(
            ruuviStorage: storage,
            measurementService: RuuviServiceMeasurementImpl(
                settings: settings, emptyValueString: "—", percentString: "%"),
            emptyValueString: "—", ruuviLocalSettings: settings)
    }

    private func record(sensor: RuuviTagSensor, date: Date) -> RuuviTagSensorRecordStruct {
        RuuviTagSensorRecordStruct(
            luid: sensor.luid, date: date, source: .log, macId: sensor.macId, rssi: -55,
            version: 5, temperature: .init(value: 20, unit: .celsius), humidity: nil, pressure: nil,
            acceleration: nil, voltage: nil, movementCounter: nil, measurementSequenceNumber: nil, txPower: nil,
            pm1: nil, pm25: nil, pm4: nil, pm10: nil, co2: nil, voc: nil, nox: nil, luminance: nil,
            dbaInstant: nil, dbaAvg: nil, dbaPeak: nil, temperatureOffset: 0, humidityOffset: 0, pressureOffset: 0)
    }
}
