import Foundation

public protocol RuuviLocalFactory {
    func createLocalSettings() -> RuuviLocalSettings
    func createLocalIDs() -> RuuviLocalIDs
    func createLocalConnections() -> RuuviLocalConnections
    func createLocalSyncState() -> RuuviLocalSyncState
    func createLocalImages() -> RuuviLocalImages
}
