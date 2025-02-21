import Foundation

public final class RuuviLocalFactoryUserDefaults: RuuviLocalFactory {
    public init() {}

    public func createLocalFlags() -> RuuviLocalFlags {
        RuuviLocalFlagsUserDefaults()
    }

    public func createLocalSettings() -> RuuviLocalSettings {
        RuuviLocalSettingsUserDefaults()
    }

    public func createLocalIDs() -> RuuviLocalIDs {
        RuuviLocalIDsUserDefaults()
    }

    public func createLocalConnections() -> RuuviLocalConnections {
        RuuviLocalConnectionsUserDefaults()
    }

    public func createLocalSyncState() -> RuuviLocalSyncState {
        RuuviLocalSyncStateUserDefaults()
    }

    public func createLocalImages() -> RuuviLocalImages {
        RuuviLocalImagesUserDefaults(imagePersistence: ImagePersistenceDocuments())
    }
}
