import Foundation
import Future

class VirtualTagTrunkCoordinator: VirtualTagTrunk {

    var realm: WebTagPersistence!

    func readAll() -> Future<[AnyVirtualTagSensor], RUError> {
        return realm.readAll()
    }

}
