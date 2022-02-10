import Foundation
import Future
import RuuviOntology

public protocol RuuviServiceExport {
    func csvLog(for uuid: String, settings: SensorSettings) -> Future<URL, RuuviServiceError>
}

public protocol RuuviServiceExportHeaders {
    func getHeaders(_ units: RuuviServiceMeasurementSettingsUnit) -> [String]
}
