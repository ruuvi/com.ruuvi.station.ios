import Foundation
import Future

protocol ExportService {
    func csvLog(for uuid: String) -> Future<URL, RUError>
}
