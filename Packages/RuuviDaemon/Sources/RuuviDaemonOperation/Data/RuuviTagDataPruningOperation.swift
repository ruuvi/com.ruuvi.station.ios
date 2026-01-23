import Foundation
import RuuviLocal
import RuuviPool

/// Data pruning service that removes old sensor records
public enum RuuviTagDataPruning {
    /// Prunes old records for a sensor based on settings
    /// - Parameters:
    ///   - id: The sensor ID to prune records for
    ///   - ruuviPool: The pool to delete records from
    ///   - settings: Settings containing the pruning offset
    public static func prune(
        id: String,
        ruuviPool: RuuviPool,
        settings: RuuviLocalSettings
    ) async {
        let offset = settings.dataPruningOffsetHours
        let date = Calendar.current.date(
            byAdding: .hour,
            value: -offset,
            to: Date()
        ) ?? Date()
        do {
            _ = try await ruuviPool.deleteAllRecords(id, before: date)
        } catch {
            print(error.localizedDescription)
        }
    }
}
