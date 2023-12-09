import RuuviLocalization
import Foundation
import RuuviLocal

extension RuuviLocalError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .disk(let error):
            return error.localizedDescription
        case .failedToGetJpegRepresentation:
            return RuuviLocalization.RuuviLocalError.failedToGetJpegRepresentation
        case .failedToGetDocumentsDirectory:
            return RuuviLocalization.RuuviLocalError.failedToGetDocumentsDirectory
        }
    }
}
