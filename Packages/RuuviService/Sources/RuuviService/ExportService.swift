import Foundation
import Future

public protocol ExportService {
    func csvLog(for uuid: String) -> Future<URL, RuuviServiceError>
}

public protocol ExportServiceHeadersProvider {
    func getHeaders(_ units: RuuviServiceMeasurementSettingsUnit) -> [String]
}
