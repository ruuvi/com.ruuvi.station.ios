import Foundation
import Future

final class SensorServiceImpl: SensorService {
    var backgroundPersistence: BackgroundPersistence!
    var ruuviNetwork: RuuviNetworkUserApi!

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

    func setCustomBackground(image: UIImage, virtualSensor: VirtualTagSensor) -> Future<URL, RUError> {
        return backgroundPersistence.setCustomBackground(image: image, for: virtualSensor.id.luid)
    }

    // swiftlint:disable:next function_body_length
    func setCustomBackground(image: UIImage, sensor: RuuviTagSensor) -> Future<URL, RUError> {
        let promise = Promise<URL, RUError>()
        let luid = sensor.luid
        let mac = sensor.macId
        assert(luid != nil || mac != nil)
        let isOwner = sensor.isOwner
        var local: Future<URL, RUError>?
        var remote: Future<URL, RUError>?

        if isOwner {
            if let luid = luid, let mac = mac {
                local = backgroundPersistence.setCustomBackground(image: image, for: luid)
                remote = ruuviNetwork.upload(image: image, for: mac)
            } else if let mac = mac {
                remote = ruuviNetwork.upload(image: image, for: mac)
                local = backgroundPersistence.setCustomBackground(image: image, for: mac)
            } else if let luid = luid {
                local = backgroundPersistence.setCustomBackground(image: image, for: luid)
            } else {
                promise.fail(error: .unexpected(.bothLuidAndMacAreNil))
                return promise.future
            }
        } else {
            if let luid = luid {
                local = backgroundPersistence.setCustomBackground(image: image, for: luid)
            } else if let mac = mac {
                local = backgroundPersistence.setCustomBackground(image: image, for: mac)
            } else {
                promise.fail(error: .unexpected(.bothLuidAndMacAreNil))
                return promise.future
            }
        }

        if let local = local, let remote = remote {
            Future.zip([local, remote]).on(success: { urls in
                if let localUrl = urls.first(where: { $0.isFileURL }) {
                    promise.succeed(value: localUrl)
                } else {
                    promise.fail(error: .unexpected(.failedToConstructURL))
                }
            }, failure: { error in
                promise.fail(error: error)
            })
        } else if let local = local {
            local.on(success: { url in
                promise.succeed(value: url)
            }, failure: { error in
                promise.fail(error: error)
            })
        } else {
            promise.fail(error: .unexpected(.bothLuidAndMacAreNil))
            return promise.future
        }

        return promise.future
    }

    func setBackground(_ id: Int, for identifier: Identifier) {
        backgroundPersistence.setBackground(id, for: identifier)
    }

    func deleteCustomBackground(for uuid: Identifier) {
        backgroundPersistence.deleteCustomBackground(for: uuid)
    }
}
