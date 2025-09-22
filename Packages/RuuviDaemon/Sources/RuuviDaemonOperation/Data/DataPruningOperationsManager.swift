import Foundation
import RuuviLocal
import RuuviPool
import RuuviStorage
import RuuviOntology

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

    public func ruuviTagPruningOperations() async throws -> [Operation] {
        let ruuviTags: [RuuviTagSensor]
        do {
            ruuviTags = try await ruuviStorage.readAll()
        } catch let error as RuuviStorageError {
            throw RuuviDaemonError.ruuviStorage(error)
        } catch {
            throw error
        }
        return ruuviTags.map {
            RuuviTagDataPruningOperation(
                id: $0.id,
                ruuviPool: ruuviPool,
                settings: settings
            )
        }
    }
}
