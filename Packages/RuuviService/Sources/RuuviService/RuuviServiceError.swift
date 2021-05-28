import Foundation
import RuuviStorage
import RuuviCloud

public enum RuuviServiceError: Error {
    case ruuviStorage(RuuviStorageError)
    case ruuviCloud(RuuviCloudError)
}
