import Foundation
import Future
import RuuviLocal
import RuuviOntology

public protocol RuuviServiceExport {
    func csvLog(
        for uuid: String,
        version: Int,
        settings: SensorSettings?
    ) -> Future<URL, RuuviServiceError>
    func xlsxLog(
        for uuid: String,
        version: Int,
        settings: SensorSettings?
    ) -> Future<URL, RuuviServiceError>
}

public protocol RuuviServiceExportHeaders {
    func getHeaders(
        version: Int,
        units: RuuviServiceMeasurementSettingsUnit,
        settings: RuuviLocalSettings
    ) -> [String]
}
