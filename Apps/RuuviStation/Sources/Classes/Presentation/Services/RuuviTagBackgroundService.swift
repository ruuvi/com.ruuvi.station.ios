import Foundation
import UIKit
import RuuviLocal
import RuuviOntology
import RuuviService

protocol RuuviTagBackgroundServiceDelegate: AnyObject {
    func backgroundService(
        _ service: RuuviTagBackgroundService,
        didUpdateSnapshot snapshot: RuuviTagCardSnapshot
    )
    func backgroundService(
        _ service: RuuviTagBackgroundService,
        didEncounterError error: Error
    )
}

class RuuviTagBackgroundService {

    // MARK: - Dependencies
    private let ruuviSensorPropertiesService: RuuviServiceSensorProperties

    // MARK: - Properties
    weak var delegate: RuuviTagBackgroundServiceDelegate?

    // MARK: - Observation Tokens
    private var backgroundToken: NSObjectProtocol?

    // MARK: - Cache
    private var backgroundCache: [String: UIImage] = [:]
    private var sensorRegistry: [String: AnyRuuviTagSensor] = [:]

    // MARK: - Initialization
    init(ruuviSensorPropertiesService: RuuviServiceSensorProperties) {
        self.ruuviSensorPropertiesService = ruuviSensorPropertiesService
    }

    deinit {
        stopObservingBackgroundChanges()
    }

    // MARK: - Public Interface
    func startObservingBackgroundChanges() {
        observeBackgroundChanges()
    }

    func stopObservingBackgroundChanges() {
        backgroundToken?.invalidate()
        backgroundToken = nil
    }

    func registerSensors(_ sensors: [AnyRuuviTagSensor]) {
        for sensor in sensors {
            sensorRegistry[sensor.id] = sensor
        }
    }

    func unregisterSensor(id: String) {
        sensorRegistry.removeValue(forKey: id)
    }

    func loadBackgrounds(for snapshots: [RuuviTagCardSnapshot], sensors: [AnyRuuviTagSensor]) {
        // Register sensors for background change tracking
        registerSensors(sensors)

        for snapshot in snapshots {
            guard let sensor = sensors.first(where: { $0.id == snapshot.id }) else { continue }
            loadBackground(for: snapshot, sensor: sensor)
        }
    }

    func loadBackground(for snapshot: RuuviTagCardSnapshot, sensor: AnyRuuviTagSensor) {
        // Check cache first
        if let cachedImage = backgroundCache[sensor.id] {

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                snapshot.updateBackgroundImage(cachedImage)
                self.delegate?.backgroundService(self, didUpdateSnapshot: snapshot)
            }
            return
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
              guard let self = self else { return }

              self.ruuviSensorPropertiesService.getImage(for: sensor)
                  .on(success: { [weak self] image in
                      guard let self = self else { return }

                      // Cache on background thread
                      self.backgroundCache[sensor.id] = image

                      DispatchQueue.main.async {
                          snapshot.updateBackgroundImage(image)
                          self.delegate?.backgroundService(self, didUpdateSnapshot: snapshot)
                      }

                  }, failure: { [weak self] error in
                      DispatchQueue.main.async {
                          guard let self = self else { return }
                          self.delegate?.backgroundService(self, didEncounterError: error)
                      }
                  })
          }
    }

    func clearCache() {
        backgroundCache.removeAll()
    }

    func removeFromCache(sensorId: String) {
        backgroundCache.removeValue(forKey: sensorId)
    }
}

// MARK: - Private Implementation
private extension RuuviTagBackgroundService {

    func observeBackgroundChanges() {
        backgroundToken?.invalidate()
        backgroundToken = NotificationCenter.default.addObserver(
            forName: .BackgroundPersistenceDidChangeBackground,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            if let userInfo = notification.userInfo {
                let luid = userInfo[BPDidChangeBackgroundKey.luid] as? LocalIdentifier
                let macId = userInfo[BPDidChangeBackgroundKey.macId] as? MACIdentifier

                // Find the affected sensor ID
                var affectedSensorId: String?

                if let luid = luid {
                    // Find sensor by LUID
                    affectedSensorId = self.findSensorId(by: luid.any, type: .luid)
                } else if let macId = macId {
                    // Find sensor by MAC
                    affectedSensorId = self.findSensorId(by: macId.any, type: .mac)
                }

                if let sensorId = affectedSensorId {
                    // Clear cache for this sensor
                    self.removeFromCache(sensorId: sensorId)

                    // Notify that background changed - delegate should reload
                    self.notifyBackgroundChanged(for: sensorId, luid: luid, macId: macId)
                }
            }
        }
    }

    private func findSensorId(by identifier: Any, type: IdentifierType) -> String? {
        switch type {
        case .luid:
            if let luid = identifier as? LocalIdentifier {
                return sensorRegistry.first { _, sensor in
                    sensor.luid?.any == luid.any
                }?.key
            } else if let luidString = identifier as? String {
                return sensorRegistry.first { _, sensor in
                    sensor.luid?.value == luidString
                }?.key
            }

        case .mac:
            if let mac = identifier as? MACIdentifier {
                return sensorRegistry.first { _, sensor in
                    sensor.macId?.any == mac.any
                }?.key
            } else if let macString = identifier as? String {
                return sensorRegistry.first { _, sensor in
                    sensor.macId?.value == macString
                }?.key
            }
        }

        return nil
    }

    func notifyBackgroundChanged(for sensorId: String, luid: LocalIdentifier?, macId: MACIdentifier?) {
        // Create a notification that the delegate can handle
        // Since we don't have direct access to sensors/snapshots here,
        // the delegate (presenter) will need to reload the background
        NotificationCenter.default.post(
            name: .DashboardBackgroundDidChange,
            object: nil,
            userInfo: [
                "sensorId": sensorId,
                "luid": luid as Any,
                "macId": macId as Any,
            ]
        )
    }
}

// MARK: - Helper Types
private enum IdentifierType {
    case luid, mac
}

// MARK: - Notification Names
extension Notification.Name {
    static let DashboardBackgroundDidChange = Notification.Name("DashboardBackgroundDidChange")
}

// MARK: - Memory Management
extension RuuviTagBackgroundService {

    func handleMemoryWarning() {
        // Clear cache on memory warning
        clearCache()
    }

    func cleanupUnusedBackgrounds(activeSensorIds: Set<String>) {
        // Remove cached backgrounds for sensors that are no longer active
        let keysToRemove = backgroundCache.keys.filter { !activeSensorIds.contains($0) }
        for key in keysToRemove {
            backgroundCache.removeValue(forKey: key)
        }
    }
}
