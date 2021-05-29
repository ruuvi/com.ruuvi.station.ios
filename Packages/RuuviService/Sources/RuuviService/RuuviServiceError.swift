import Foundation
import RuuviStorage
import RuuviCloud
import RuuviPool
import RuuviLocal

public enum RuuviServiceError: Error {
    case ruuviStorage(RuuviStorageError)
    case ruuviCloud(RuuviCloudError)
    case ruuviPool(RuuviPoolError)
    case ruuviLocal(RuuviLocalError)
    case networking(Error)
    case macIdIsNil
    case pictureUrlIsNil
    case failedToParseNetworkResponse
}
