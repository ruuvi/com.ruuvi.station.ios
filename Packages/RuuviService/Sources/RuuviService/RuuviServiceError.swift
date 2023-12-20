import BTKit
import Foundation
import RuuviCloud
import RuuviLocal
import RuuviPool
import RuuviRepository
import RuuviStorage

public enum RuuviServiceError: Error {
    case ruuviRepository(RuuviRepositoryError)
    case ruuviStorage(RuuviStorageError)
    case ruuviCloud(RuuviCloudError)
    case ruuviPool(RuuviPoolError)
    case ruuviLocal(RuuviLocalError)
    case btkit(BTError)
    case networking(Error)
    case writeToDisk(Error)
    case macIdIsNil
    case pictureUrlIsNil
    case failedToParseNetworkResponse
    case bothLuidAndMacAreNil
    case failedToGetJpegRepresentation
    case failedToFindOrGenerateBackgroundImage
    case isAlreadySyncingLogsWithThisTag
}
