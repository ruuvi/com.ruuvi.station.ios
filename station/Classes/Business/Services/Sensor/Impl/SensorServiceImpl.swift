import Foundation
import Future
import UIKit
import RuuviOntology
import RuuviLocal
import RuuviCore

final class SensorServiceImpl: SensorService {
    var ruuviLocalImages: RuuviLocalImages!
    var ruuviCoreImage: RuuviCoreImage!
    private let backgroundUrlPrefix = "SensorServiceImpl.backgroundUrlPrefix"
    private let maxImageSize = CGSize(width: 1080, height: 1920)

    func background(luid: LocalIdentifier?, macId: MACIdentifier?) -> Future<UIImage, RUError> {
        let promise = Promise<UIImage, RUError>()
        if let macId = macId {
            if let image = ruuviLocalImages.background(for: macId) {
                promise.succeed(value: image)
            } else if let luid = luid, let image = ruuviLocalImages.background(for: luid) {
                promise.succeed(value: image)
            } else {
                promise.fail(error: .unexpected(.failedToFindOrGenerateBackgroundImage))
            }
        } else if let luid = luid {
            if let image = ruuviLocalImages.background(for: luid) {
                promise.succeed(value: image)
            } else {
                promise.fail(error: .unexpected(.failedToFindOrGenerateBackgroundImage))
            }
        } else {
            promise.fail(error: .unexpected(.bothLuidAndMacAreNil))
        }
        return promise.future
    }

    func setNextDefaultBackground(for identifier: Identifier) -> Future<UIImage, RUError> {
        let promise = Promise<UIImage, RUError>()
        if let image = ruuviLocalImages.setNextDefaultBackground(for: identifier) {
            promise.succeed(value: image)
        } else {
            promise.fail(error: .unexpected(.failedToFindOrGenerateBackgroundImage))
        }
        return promise.future
    }

    func setCustomBackground(image: UIImage, virtualSensor: VirtualTagSensor) -> Future<URL, RUError> {
        let promise = Promise<URL, RUError>()
        ruuviLocalImages.setCustomBackground(
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
        ruuviLocalImages.setBackground(id, for: identifier)
    }

    func deleteCustomBackground(for uuid: Identifier) {
        ruuviLocalImages.deleteCustomBackground(for: uuid)
    }
}
