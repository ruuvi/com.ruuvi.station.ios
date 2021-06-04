import Foundation
import RuuviStorage
import RuuviCloud
import RuuviPool
import RuuviLocal
import RuuviRepository

public enum RuuviServiceError: Error {
    case ruuviRepository(RuuviRepositoryError)
    case ruuviStorage(RuuviStorageError)
    case ruuviCloud(RuuviCloudError)
    case ruuviPool(RuuviPoolError)
    case ruuviLocal(RuuviLocalError)
    case networking(Error)
    case macIdIsNil
    case pictureUrlIsNil
    case failedToParseNetworkResponse
    case bothLuidAndMacAreNil
    case failedToGetJpegRepresentation
    case failedToFindOrGenerateBackgroundImage
}
