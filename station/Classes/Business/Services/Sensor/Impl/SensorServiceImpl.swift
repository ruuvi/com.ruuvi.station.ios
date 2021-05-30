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
}
