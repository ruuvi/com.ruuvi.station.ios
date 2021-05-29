import Foundation
import Future
import UIKit
import RuuviOntology
import RuuviLocal
import RuuviCore

final class SensorServiceImpl: SensorService {
    var ruuviLocalImages: RuuviLocalImages!
    var ruuviNetwork: RuuviNetworkUserApi!
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

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func setCustomBackground(image: UIImage, sensor: RuuviTagSensor) -> Future<URL, RUError> {
        let promise = Promise<URL, RUError>()
        let luid = sensor.luid
        let macId = sensor.macId
        assert(luid != nil || macId != nil)
        let isOwner = sensor.isOwner
        var local: Future<URL, RuuviLocalError>?
        var remote: Future<URL, RUError>?

        if isOwner {
            if let mac = macId {
                let croppedImage = ruuviCoreImage.cropped(image: image, to: maxImageSize)
                remote = ruuviNetwork.upload(image: croppedImage, for: mac, with: self)
                local = ruuviLocalImages.setCustomBackground(image: image, for: mac)
            } else if let luid = luid {
                local = ruuviLocalImages.setCustomBackground(image: image, for: luid)
            } else {
                promise.fail(error: .unexpected(.bothLuidAndMacAreNil))
                return promise.future
            }
        } else {
            if let luid = luid {
                local = ruuviLocalImages.setCustomBackground(image: image, for: luid)
            } else if let mac = macId {
                local = ruuviLocalImages.setCustomBackground(image: image, for: mac)
            } else {
                promise.fail(error: .unexpected(.bothLuidAndMacAreNil))
                return promise.future
            }
        }

        if let local = local, let remote = remote {
            if let mac = macId {
                ruuviLocalImages.setBackgroundUploadProgress(percentage: 0.0, for: mac)
            }
            remote.on(success: { [weak self] _ in
                guard let sSelf = self else { return }
                local.on(success: { [weak sSelf] localUrl in
                    guard let ssSelf = sSelf else { return }
                    if let mac = macId {
                        ssSelf.ruuviLocalImages.deleteBackgroundUploadProgress(for: mac)
                    }
                    promise.succeed(value: localUrl)
                }, failure: { error in
                    promise.fail(error: .ruuviLocal(error))
                })
            }, failure: { error in
                promise.fail(error: error)
            })
        } else if let local = local {
            local.on(success: { url in
                promise.succeed(value: url)
            }, failure: { error in
                promise.fail(error: .ruuviLocal(error))
            })
        } else {
            promise.fail(error: .unexpected(.bothLuidAndMacAreNil))
            return promise.future
        }

        return promise.future
    }

    func setBackground(_ id: Int, for identifier: Identifier) {
        ruuviLocalImages.setBackground(id, for: identifier)
    }

    func deleteCustomBackground(for uuid: Identifier) {
        ruuviLocalImages.deleteCustomBackground(for: uuid)
    }

    @discardableResult
    func ensureNetworkBackgroundIsLoaded(for macId: MACIdentifier, from url: URL) -> Future<UIImage, RUError> {
        let promise = Promise<UIImage, RUError>()
        if let savedUrl = UserDefaults.standard.url(forKey: backgroundUrlPrefix + macId.mac),
           savedUrl == url,
           let image = ruuviLocalImages.background(for: macId) {
            promise.succeed(value: image)
        } else { // need to download image
            URLSession.shared.dataTask(with: url, completionHandler: { [weak self] data, _, error in
                guard let sSelf = self else { return }
                if let error = error {
                    promise.fail(error: .networking(error))
                } else if let data = data {
                    if let image = UIImage(data: data) {
                        sSelf.ruuviLocalImages.setCustomBackground(image: image, for: macId).on(success: { _ in
                            UserDefaults.standard.set(url, forKey: sSelf.backgroundUrlPrefix + macId.mac)
                            promise.succeed(value: image)
                        }, failure: { error in
                            promise.fail(error: .ruuviLocal(error))
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

extension SensorServiceImpl: RuuviNetworkUserApiOutput {
    func uploadImageUpdateProgress(_ mac: MACIdentifier, percentage: Double) {
        ruuviLocalImages.setBackgroundUploadProgress(percentage: percentage, for: mac)
    }
}
