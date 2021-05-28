import Foundation
import RuuviStorage
import RuuviCloud
import RuuviPool

public enum RuuviServiceError: Error {
    case ruuviStorage(RuuviStorageError)
    case ruuviCloud(RuuviCloudError)
    case ruuviPool(RuuviPoolError)
    case macIdIsNil
}
