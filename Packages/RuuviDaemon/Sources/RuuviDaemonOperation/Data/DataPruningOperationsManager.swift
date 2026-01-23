import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviStorage

public final class DataPruningOperationsManager {
    private let settings: RuuviLocalSettings
    private let ruuviStorage: RuuviStorage
    private let ruuviPool: RuuviPool

    public init(
        settings: RuuviLocalSettings,
        ruuviStorage: RuuviStorage,
        ruuviPool: RuuviPool
    ) {
        self.settings = settings
        self.ruuviStorage = ruuviStorage
        self.ruuviPool = ruuviPool
    }

    /// Prunes old data for all sensors sequentially
    /// - Returns: true if pruning completed successfully
    public func pruneAllSensors() async throws -> Bool {
        let ruuviTags: [AnyRuuviTagSensor]
        do {
            ruuviTags = try await ruuviStorage.readAll()
        } catch let error as RuuviStorageError {
            throw RuuviDaemonError.ruuviStorage(error)
        }

        for sensor in ruuviTags {
            await RuuviTagDataPruning.prune(
                id: sensor.id,
                ruuviPool: ruuviPool,
                settings: settings
            )
        }

        return true
    }
}
