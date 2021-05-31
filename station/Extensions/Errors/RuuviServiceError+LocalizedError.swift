import Foundation
import RuuviService
import Localize_Swift

extension RuuviServiceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .ruuviStorage(let error):
            return error.localizedDescription
        case .ruuviPool(let error):
            return error.localizedDescription
        case .ruuviLocal(let error):
            return error.localizedDescription
        case .ruuviCloud(let error):
            return error.localizedDescription
        case .networking(let error):
            return error.localizedDescription
        case .pictureUrlIsNil:
            return "RuuviServiceError.pictureUrlIsNil".localized()
        case .macIdIsNil:
            return "RuuviServiceError.macIdIsNil".localized()
        case .bothLuidAndMacAreNil:
            return "RuuviServiceError.bothLuidAndMacAreNil".localized()
        case .failedToParseNetworkResponse:
            return "RuuviServiceError.failedToParseNetworkResponse".localized()
        case .failedToFindOrGenerateBackgroundImage:
            return "RuuviServiceError.failedToFindOrGenerateBackgroundImage".localized()
        case .failedToGetJpegRepresentation:
            return "RuuviServiceError.failedToGetJpegRepresentation".localized()
        }
    }
}
