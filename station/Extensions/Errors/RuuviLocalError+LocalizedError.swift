import Foundation
import RuuviLocal
import Localize_Swift

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
