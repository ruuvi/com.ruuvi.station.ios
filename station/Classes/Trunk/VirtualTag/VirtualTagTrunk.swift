import Foundation
import Future

protocol VirtualTagTrunk {
    func readAll() -> Future<[AnyVirtualTagSensor], RUError>
}
