import Foundation
import RuuviLocal
import RuuviOntology

public protocol RuuviServiceExport {
    func csvLog(
        for uuid: String,
        version: Int,
        settings: SensorSettings?
    ) async throws -> URL
    func xlsxLog(
        for uuid: String,
        version: Int,
        settings: SensorSettings?
    ) async throws -> URL
}
