import Foundation
import RuuviLocal
import RuuviLocalization

extension RuuviLocalError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .disk(error):
            error.localizedDescription
        case .failedToGetJpegRepresentation:
            RuuviLocalization.RuuviLocalError.failedToGetJpegRepresentation
        case .failedToGetDocumentsDirectory:
            RuuviLocalization.RuuviLocalError.failedToGetDocumentsDirectory
        }
    }
}
