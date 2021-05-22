import Foundation
import Future

final class SensorServiceImpl: SensorService {
    var backgroundPersistence: BackgroundPersistence!

    func background(for identifier: Identifier) -> Future<UIImage, RUError> {
        let promise = Promise<UIImage, RUError>()
        if let image = backgroundPersistence.background(for: identifier) {
            promise.succeed(value: image)
        } else {
            promise.fail(error: .unexpected(.failedToFindOrGenerateBackgroundImage))
        }
        return promise.future
    }

    func setNextDefaultBackground(for identifier: Identifier) -> Future<UIImage, RUError> {
        let promise = Promise<UIImage, RUError>()
        if let image = backgroundPersistence.setNextDefaultBackground(for: identifier) {
            promise.succeed(value: image)
        } else {
            promise.fail(error: .unexpected(.failedToFindOrGenerateBackgroundImage))
        }
        return promise.future
    }

    func setCustomBackground(image: UIImage, for identifier: Identifier) -> Future<URL, RUError> {
        return backgroundPersistence.setCustomBackground(image: image, for: identifier)
    }

    func setBackground(_ id: Int, for identifier: Identifier) {
        backgroundPersistence.setBackground(id, for: identifier)
    }

    func deleteCustomBackground(for uuid: Identifier) {
        backgroundPersistence.deleteCustomBackground(for: uuid)
    }
}
