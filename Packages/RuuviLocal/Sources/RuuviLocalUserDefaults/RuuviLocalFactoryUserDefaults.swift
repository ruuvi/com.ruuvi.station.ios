import Foundation
import RuuviLocal

public final class RuuviLocalFactoryUserDefaults: RuuviLocalFactory {
    public init() {}

    public func createLocalSettings() -> RuuviLocalSettings {
        return RuuviLocalSettingsUserDefaults()
    }

    public func createLocalIDs() -> RuuviLocalIDs {
        return RuuviLocalIDsUserDefaults()
    }

    public func createLocalConnections() -> RuuviLocalConnections {
        return RuuviLocalConnectionsUserDefaults()
    }

    public func createLocalSyncState() -> RuuviLocalSyncState {
        return RuuviLocalSyncStateUserDefaults()
    }

    public func createLocalImages() -> RuuviLocalImages {
        return RuuviLocalImagesUserDefaults(imagePersistence: ImagePersistenceDocuments())
    }
}
