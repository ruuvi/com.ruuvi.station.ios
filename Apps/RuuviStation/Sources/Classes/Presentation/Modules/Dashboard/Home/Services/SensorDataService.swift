import Foundation
import RuuviOntology
import RuuviReactor
import RuuviStorage
import RuuviService
import UIKit

protocol SensorDataServiceProtocol: AnyObject {
    var sensors: [AnyRuuviTagSensor] { get }
    var sensorSettings: [SensorSettings] { get }
    
    var onSensorsChanged: (([AnyRuuviTagSensor]) -> Void)? { get set }
    var onSensorSettingsChanged: (([SensorSettings]) -> Void)? { get set }
    var onLatestRecordChanged: ((String, RuuviTagSensorRecord?) -> Void)? { get set }
    
    func startObservingSensors()
    func stopObservingSensors()
    func getLatestRecord(for sensor: AnyRuuviTagSensor) async throws -> RuuviTagSensorRecord?
    func getSensorImage(for sensor: AnyRuuviTagSensor) async throws -> UIImage?
}

final class SensorDataService: SensorDataServiceProtocol {
    // MARK: - Dependencies
    private let ruuviReactor: RuuviReactor
    private let ruuviStorage: RuuviStorage
    private let ruuviSensorPropertiesService: RuuviServiceSensorProperties
    
    // MARK: - Private Properties
    private var _sensors: [AnyRuuviTagSensor] = []
    private var _sensorSettings: [SensorSettings] = []
    private var ruuviTagToken: RuuviReactorToken?
    private var sensorSettingsTokens = [RuuviReactorToken]()
    private var latestRecordTokens = [RuuviReactorToken]()
    
    // MARK: - Public Properties
    var sensors: [AnyRuuviTagSensor] {
        return _sensors
    }
    
    var sensorSettings: [SensorSettings] {
        return _sensorSettings
    }
    
    var onSensorsChanged: (([AnyRuuviTagSensor]) -> Void)?
    var onSensorSettingsChanged: (([SensorSettings]) -> Void)?
    var onLatestRecordChanged: ((String, RuuviTagSensorRecord?) -> Void)?
    
    // MARK: - Initialization
    init(
        ruuviReactor: RuuviReactor,
        ruuviStorage: RuuviStorage,
        ruuviSensorPropertiesService: RuuviServiceSensorProperties
    ) {
        self.ruuviReactor = ruuviReactor
        self.ruuviStorage = ruuviStorage
        self.ruuviSensorPropertiesService = ruuviSensorPropertiesService
    }
    
    deinit {
        stopObservingSensors()
    }
    
    // MARK: - Public Methods
    func startObservingSensors() {
        ruuviTagToken = ruuviReactor.observe { [weak self] change in
            guard let self = self else { return }
            switch change {
            case .initial(let sensors):
                self._sensors = sensors
                self.onSensorsChanged?(sensors)
                self.observeSensorSettings(for: sensors)
                self.observeLatestRecords(for: sensors)
            case .update(let sensor):
                if let index = self._sensors.firstIndex(where: { $0.id == sensor.id }) {
                    self._sensors[index] = sensor
                } else {
                    self._sensors.append(sensor)
                }
                self.onSensorsChanged?(self._sensors)
            case .insert(let sensor):
                self._sensors.append(sensor)
                self.onSensorsChanged?(self._sensors)
                self.observeSensorSettings(for: [sensor])
                self.observeLatestRecords(for: [sensor])
            case .delete(let sensor):
                self._sensors.removeAll { $0.id == sensor.id }
                self.onSensorsChanged?(self._sensors)
            case .error(_):
                break
            }
        }
    }
    
    func stopObservingSensors() {
        ruuviTagToken?.invalidate()
        ruuviTagToken = nil
        sensorSettingsTokens.forEach { $0.invalidate() }
        sensorSettingsTokens.removeAll()
        latestRecordTokens.forEach { $0.invalidate() }
        latestRecordTokens.removeAll()
    }
    
    func getLatestRecord(for sensor: AnyRuuviTagSensor) async throws -> RuuviTagSensorRecord? {
        return try await withCheckedThrowingContinuation { continuation in
            let future = ruuviStorage.readLatest(sensor)
            future.on(success: { record in
                continuation.resume(returning: record)
            }, failure: { error in
                continuation.resume(throwing: error)
            })
        }
    }
    
    func getSensorImage(for sensor: AnyRuuviTagSensor) async throws -> UIImage? {
        return try await withCheckedThrowingContinuation { continuation in
            let future = ruuviSensorPropertiesService.getImage(for: sensor)
            future.on(success: { image in
                continuation.resume(returning: image)
            }, failure: { error in
                continuation.resume(throwing: error)
            })
        }
    }
    
    // MARK: - Private Methods
    private func observeSensorSettings(for sensors: [AnyRuuviTagSensor]) {
        for sensor in sensors {
            let token = ruuviReactor.observe(sensor) { [weak self] change in
                guard let self = self else { return }
                
                switch change {
                case .insert(let settings):
                    self._sensorSettings.append(settings)
                    self.onSensorSettingsChanged?(self._sensorSettings)
                case .update(let settings):
                    if let index = self._sensorSettings.firstIndex(where: { $0.id == settings.id }) {
                        self._sensorSettings[index] = settings
                        self.onSensorSettingsChanged?(self._sensorSettings)
                    }
                case .delete(let settings):
                    self._sensorSettings.removeAll { $0.id == settings.id }
                    self.onSensorSettingsChanged?(self._sensorSettings)
                case .initial(_):
                    // TODO
                    break
                case .error(_):
                    // TODO
                    break
                }
            }
            sensorSettingsTokens.append(token)
        }
    }
    
    private func observeLatestRecords(for sensors: [AnyRuuviTagSensor]) {
        for sensor in sensors {
            let token = ruuviReactor.observeLatest(sensor) { [weak self] change in
                guard let self = self else { return }
                
                if case let .update(record) = change {
                    self.onLatestRecordChanged?(sensor.id, record)
                }
            }
            latestRecordTokens.append(token)
        }
    }
}
