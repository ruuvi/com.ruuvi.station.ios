import Foundation
import Future

final class SensorServiceImpl: SensorService {
    var backgroundPersistence: BackgroundPersistence!
    var ruuviNetwork: RuuviNetworkUserApi!
    var imageCoreService: ImageCoreService!
    private let backgroundUrlPrefix = "SensorServiceImpl.backgroundUrlPrefix"
    private let maxImageSize = CGSize(width: 1080, height: 1920)

    func background(luid: LocalIdentifier?, macId: MACIdentifier?) -> Future<UIImage, RUError> {
        let promise = Promise<UIImage, RUError>()
        if let macId = macId {
            if let image = backgroundPersistence.background(for: macId) {
                promise.succeed(value: image)
            } else if let luid = luid, let image = backgroundPersistence.background(for: luid) {
                promise.succeed(value: image)
            } else {
                promise.fail(error: .unexpected(.failedToFindOrGenerateBackgroundImage))
            }
        } else if let luid = luid {
            if let image = backgroundPersistence.background(for: luid) {
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
            if let mac = mac {
                let croppedImage = imageCoreService.cropped(image: image, to: maxImageSize)
                remote = ruuviNetwork.upload(image: croppedImage, for: mac)
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

    @discardableResult
    func ensureNetworkBackgroundIsLoaded(for macId: MACIdentifier, from url: URL) -> Future<UIImage, RUError> {
        let promise = Promise<UIImage, RUError>()
        if let savedUrl = UserDefaults.standard.url(forKey: backgroundUrlPrefix + macId.mac),
           savedUrl == url,
           let image = backgroundPersistence.background(for: macId) {
            promise.succeed(value: image)
        } else { // need to download image
            URLSession.shared.dataTask(with: url, completionHandler: { [weak self] data, _, error in
                guard let sSelf = self else { return }
                if let error = error {
                    promise.fail(error: .networking(error))
                } else if let data = data {
                    if let image = UIImage(data: data) {
                        sSelf.backgroundPersistence.setCustomBackground(image: image, for: macId).on(success: { _ in
                            UserDefaults.standard.set(url, forKey: sSelf.backgroundUrlPrefix + macId.mac)
                            promise.succeed(value: image)
                        }, failure: { error in
                            promise.fail(error: error)
                        })
                    } else {
                        promise.fail(error: .unexpected(.failedToParseHttpResponse))
                    }
                } else {
                    promise.fail(error: .unexpected(.failedToParseHttpResponse))
                }
            }).resume()
        }
        return promise.future
    }
}
