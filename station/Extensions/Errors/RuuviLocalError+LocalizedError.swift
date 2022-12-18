import Foundation
import RuuviLocal

extension RuuviLocalError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .disk(let error):
            return error.localizedDescription
        case .failedToGetJpegRepresentation:
            return "RuuviLocalError.failedToGetJpegRepresentation".localized()
        case .failedToGetDocumentsDirectory:
            return "RuuviLocalError.failedToGetDocumentsDirectory".localized()
        }
    }
}
