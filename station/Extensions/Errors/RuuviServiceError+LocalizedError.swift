import RuuviLocalization
import Foundation
import RuuviService

extension RuuviServiceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .btkit(let error):
            return error.localizedDescription
        case .writeToDisk(let error):
            return error.localizedDescription
        case .ruuviRepository(let error):
            return error.errorDescription
        case .ruuviStorage(let error):
            return error.errorDescription
        case .ruuviPool(let error):
            return error.errorDescription
        case .ruuviLocal(let error):
            return error.errorDescription
        case .ruuviCloud(let error):
            return error.errorDescription
        case .networking(let error):
            return error.localizedDescription
        case .pictureUrlIsNil:
            return RuuviLocalization.RuuviServiceError.pictureUrlIsNil
        case .macIdIsNil:
            return RuuviLocalization.RuuviServiceError.macIdIsNil
        case .bothLuidAndMacAreNil:
            return RuuviLocalization.RuuviServiceError.bothLuidAndMacAreNil
        case .failedToParseNetworkResponse:
            return RuuviLocalization.RuuviServiceError.failedToParseNetworkResponse
        case .failedToFindOrGenerateBackgroundImage:
            return RuuviLocalization.RuuviServiceError.failedToFindOrGenerateBackgroundImage
        case .failedToGetJpegRepresentation:
            return RuuviLocalization.RuuviServiceError.failedToGetJpegRepresentation
        case .isAlreadySyncingLogsWithThisTag:
            return RuuviLocalization.ExpectedError.isAlreadySyncingLogsWithThisTag
        }
    }
}
