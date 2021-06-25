import Foundation
import Future

public protocol RuuviServiceExport {
    func csvLog(for uuid: String) -> Future<URL, RuuviServiceError>
}

public protocol RuuviServiceExportHeaders {
    func getHeaders(_ units: RuuviServiceMeasurementSettingsUnit) -> [String]
}
