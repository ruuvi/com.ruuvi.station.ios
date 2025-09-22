import Foundation
import RuuviLocalization
import RuuviService

extension RuuviServiceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .btkit(error):
            error.localizedDescription
        case let .writeToDisk(error):
            error.localizedDescription
        case let .ruuviRepository(error):
            error.errorDescription
        case let .ruuviStorage(error):
            error.errorDescription
        case let .ruuviPool(error):
            error.errorDescription
        case let .ruuviLocal(error):
            error.errorDescription
        case let .ruuviCloud(error):
            error.errorDescription
        case let .networking(error):
            error.localizedDescription
        case .pictureUrlIsNil:
            RuuviLocalization.RuuviServiceError.pictureUrlIsNil
        case .macIdIsNil:
            RuuviLocalization.RuuviServiceError.macIdIsNil
        case .bothLuidAndMacAreNil:
            RuuviLocalization.RuuviServiceError.bothLuidAndMacAreNil
        case .failedToParseNetworkResponse:
            RuuviLocalization.RuuviServiceError.failedToParseNetworkResponse
        case .failedToFindOrGenerateBackgroundImage:
            RuuviLocalization.RuuviServiceError.failedToFindOrGenerateBackgroundImage
        case .failedToGetJpegRepresentation:
            RuuviLocalization.RuuviServiceError.failedToGetJpegRepresentation
        case .isAlreadySyncingLogsWithThisTag:
            RuuviLocalization.ExpectedError.isAlreadySyncingLogsWithThisTag
        default:
            nil
        }
    }
}
