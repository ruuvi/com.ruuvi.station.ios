import Foundation
import RuuviOntology
import RuuviPresenters
import RuuviService
@testable import station

@MainActor final class OffsetCorrectionFixture {
    let measurements = MeasurementFixture()
    let reactor = AppTestReactor()
    let view = OffsetCorrectionViewSpy()
    let service = OffsetCorrectionServiceSpy()
    let errors = OffsetErrorSpy()
    let notifications = NotificationCenter()
    var presenter: OffsetCorrectionPresenter?
    init() {
        let presenter = OffsetCorrectionPresenter(notificationCenter: notifications)
        self.presenter = presenter
        presenter.view = view
        presenter.settings = measurements.settings
        presenter.ruuviStorage = measurements.storage
        presenter.ruuviReactor = reactor
        presenter.ruuviOffsetCalibrationService = service
        presenter.errorPresenter = errors
        measurements.storage.useLatestOverride = true
        measurements.storage.latestOverride = measurements.record()
    }
    func configure(_ type: OffsetCorrectionType, offsets: SensorSettings? = nil) {
        presenter?.configure(type: type, ruuviTag: measurements.sensor, sensorSettings: offsets)
    }
    func offsets(_ temperature: Double? = 2, _ humidity: Double? = 0.1, _ pressure: Double? = 10) -> SensorSettings {
        SensorSettingsStruct(
            luid: measurements.sensor.luid, macId: measurements.sensor.macId,
            temperatureOffset: temperature, humidityOffset: humidity, pressureOffset: pressure)
    }
}

final class OffsetCorrectionViewSpy: OffsetCorrectionViewInput {
    var viewModel = OffsetCorrectionViewModel()
    var calibrationDialogs = 0
    var clearDialogs = 0
    func showCalibrateDialog() { calibrationDialogs += 1 }
    func showClearConfirmationDialog() { clearDialogs += 1 }
}

@MainActor final class OffsetCorrectionServiceSpy: RuuviServiceOffsetCalibration {
    struct Call {
        let offset: Double?
        let type: OffsetCorrectionType
        let sensor: RuuviTagSensor
        let record: RuuviTagSensorRecord?
    }
    var calls = [Call]()
    var completed = 0
    var failure: RuuviServiceError?
    var beforeSave: (() async -> Void)?
    func set(
        offset: Double?, of type: OffsetCorrectionType, for sensor: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws(RuuviServiceError) -> SensorSettings {
        calls.append(.init(offset: offset, type: type, sensor: sensor, record: record))
        await beforeSave?()
        defer { completed += 1 }
        if let failure { throw failure }
        return SensorSettingsStruct(
            luid: sensor.luid, macId: sensor.macId,
            temperatureOffset: type == .temperature ? offset : nil,
            humidityOffset: type == .humidity ? offset : nil,
            pressureOffset: type == .pressure ? offset : nil)
    }
}

final class OffsetErrorSpy: ErrorPresenter {
    var errors = [Error]()
    func present(error: Error) { errors.append(error) }
}
