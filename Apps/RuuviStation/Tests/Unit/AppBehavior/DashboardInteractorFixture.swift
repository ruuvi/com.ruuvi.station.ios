import BTKit
import Foundation
import RuuviOntology
@testable import station

@MainActor final class DashboardInteractorFixture {
    let measurements = MeasurementFixture()
    let pool = AppPoolSpy()
    let ownership = ShareOwnershipSpy()
    let user = DefaultsUserSpy()
    let interactor = DashboardInteractor()
    var firmwareRequests = [String]()
    var firmwareCompletion: ((Result<String, Error>) -> Void)?
    var sensor: RuuviTagSensorStruct
    init() {
        sensor = measurements.sensor
        interactor.background = BTKit.background
        interactor.ruuviPool = pool
        interactor.ruuviOwnershipService = ownership
        interactor.settings = measurements.settings
        interactor.ruuviUser = user
        interactor.ruuviStorage = measurements.storage
        interactor.ownerCheckDelay = 0
        interactor.readFirmwareVersion = { [weak self] uuid, completion in
            self?.firmwareRequests.append(uuid)
            self?.firmwareCompletion = completion
        }
        pool.allowSensorUpdates = true
        pool.beforeUpdate = { [weak self] in
            guard let self, let updated = self.pool.updatedSensors.last else { return }
            self.measurements.storage.oneSensors?[updated.macId?.value ?? updated.id] = updated
        }
        saveSensor()
    }
    func saveSensor() { measurements.storage.oneSensors = [sensor.macId?.value ?? sensor.id: sensor.any] }
    func start() { interactor.checkAndUpdateFirmwareVersion(for: sensor) }
    func cleanup() { measurements.cleanup() }
}
