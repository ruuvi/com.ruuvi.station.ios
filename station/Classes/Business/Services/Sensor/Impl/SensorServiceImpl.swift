import Foundation
import Future
import UIKit
import RuuviOntology
import RuuviLocal
import RuuviCore

final class SensorServiceImpl: SensorService {
    var localImages: RuuviLocalImages!
    var coreImage: RuuviCoreImage!

    func setNextDefaultBackground(for identifier: Identifier) -> Future<UIImage, RUError> {
        let promise = Promise<UIImage, RUError>()
        if let image = localImages.setNextDefaultBackground(for: identifier) {
            promise.succeed(value: image)
        } else {
            promise.fail(error: .unexpected(.failedToFindOrGenerateBackgroundImage))
        }
        return promise.future
    }

    func setCustomBackground(image: UIImage, virtualSensor: VirtualTagSensor) -> Future<URL, RUError> {
        let promise = Promise<URL, RUError>()
        localImages.setCustomBackground(
            image: image,
            for: virtualSensor.id.luid
        ).on(success: { url in
            promise.succeed(value: url)
        }, failure: { error in
            promise.fail(error: .ruuviLocal(error))
        })
        return promise.future
    }

    func setBackground(_ id: Int, for identifier: Identifier) {
        localImages.setBackground(id, for: identifier)
    }

    func deleteCustomBackground(for uuid: Identifier) {
        localImages.deleteCustomBackground(for: uuid)
    }
}
