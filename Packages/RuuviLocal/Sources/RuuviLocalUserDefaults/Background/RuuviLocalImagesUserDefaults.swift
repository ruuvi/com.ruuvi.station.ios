import UIKit
import Future
import RuuviOntology

final class RuuviLocalImagesUserDefaults: RuuviLocalImages {
    init(imagePersistence: ImagePersistence) {
        self.imagePersistence = imagePersistence
    }

    private let imagePersistence: ImagePersistence
    private let bgMinIndex = 1 // must be > 0, 0 means custom background
    private let bgMaxIndex = 9

    private let usedBackgroundsUDKey = "BackgroundPersistenceUserDefaults.background.usedBackgroundsUDKey"
    private let bgUDKeyPrefix = "BackgroundPersistenceUserDefaults.background."

    private let uploadBackgroundKeyPrefix = "BackgroundPersistenceUserDefaults.uploadBackground."
    private let cloudSensorPictureUrlPrefix = "SensorServiceImpl.backgroundUrlPrefix"

    private var usedBackgrounds: [Int] {
        if let ub = UserDefaults.standard.array(forKey: usedBackgroundsUDKey) as? [Int] {
            return ub
        } else {
            let ub = Array(repeating: 0, count: bgMaxIndex - bgMinIndex + 1)
            UserDefaults.standard.set(ub, forKey: usedBackgroundsUDKey)
            return ub
        }
    }

    func deleteCustomBackground(for identifier: Identifier) {
        imagePersistence.deleteBgIfExists(for: identifier)
    }

    func setNextDefaultBackground(for identifier: Identifier) -> UIImage? {
        var id = backgroundId(for: identifier)
        if id >= bgMinIndex && id < bgMaxIndex {
            id += 1
            setBackground(id, for: identifier)
        } else if id >= bgMaxIndex {
            id = bgMinIndex
            setBackground(id, for: identifier)
        } else {
            id = biasedToNotUsedRandom()
            setBackground(id, for: identifier)
        }
        imagePersistence.deleteBgIfExists(for: identifier)
        return UIImage(named: "bg\(id)")
    }

    func getBackground(for identifier: Identifier) -> UIImage? {
        var id = backgroundId(for: identifier)
        if id >= bgMinIndex && id <= bgMaxIndex {
            return UIImage(named: "bg\(id)")
        } else {
            return imagePersistence.fetchBg(for: identifier)
        }
    }

    func getOrGenerateBackground(for identifier: Identifier) -> UIImage? {
        var id = backgroundId(for: identifier)
        if id >= bgMinIndex && id <= bgMaxIndex {
            return UIImage(named: "bg\(id)")
        } else {
            if let custom = imagePersistence.fetchBg(for: identifier) {
                return custom
            } else {
                id = biasedToNotUsedRandom()
                setBackground(id, for: identifier)
                return UIImage(named: "bg\(id)")
            }
        }
    }

    func setCustomBackground(image: UIImage, for identifier: Identifier) -> Future<URL, RuuviLocalError> {
        let promise = Promise<URL, RuuviLocalError>()
        let persist = imagePersistence.persistBg(image: image, for: identifier)
        persist.on(success: { url in
            self.setBackground(0, for: identifier)
            let userInfoKey: BPDidChangeBackgroundKey
            if identifier is LocalIdentifier {
                userInfoKey = .luid
            } else if identifier is MACIdentifier {
                userInfoKey = .macId
            } else {
                userInfoKey = .luid
                assertionFailure()
            }
            NotificationCenter
                .default
                .post(name: .BackgroundPersistenceDidChangeBackground,
                      object: nil,
                      userInfo: [userInfoKey: identifier])
            promise.succeed(value: url)
        }, failure: { (error) in
            promise.fail(error: error)
        })
        return promise.future
    }

    func setBackground(_ id: Int, for identifier: Identifier) {
        let uuid = identifier.value
        let key = bgUDKeyPrefix + uuid
        UserDefaults.standard.set(id, forKey: key)
        UserDefaults.standard.synchronize()
        let userInfoKey: BPDidChangeBackgroundKey
        if identifier is LocalIdentifier {
            userInfoKey = .luid
        } else if identifier is MACIdentifier {
            userInfoKey = .macId
        } else {
            userInfoKey = .luid
            assertionFailure()
        }
        NotificationCenter
            .default
            .post(name: .BackgroundPersistenceDidChangeBackground,
                  object: nil,
                  userInfo: [userInfoKey: identifier])
        if id >= bgMinIndex && id <= bgMaxIndex {
            var array = usedBackgrounds
            array[id - bgMinIndex] += 1
            UserDefaults.standard.set(array, forKey: usedBackgroundsUDKey)
        }
    }

    private func backgroundId(for identifier: Identifier) -> Int {
        let uuid = identifier.value
        let key = bgUDKeyPrefix + uuid
        let id = UserDefaults.standard.integer(forKey: key)
        return id
    }

    private func biasedToNotUsedRandom() -> Int {
        let array = usedBackgrounds
        var result: Int
        if let min = array.min() {
            let indicies = array.enumerated().compactMap({ $1 == min ? $0 + bgMinIndex : nil })
            if indicies.count == 0 {
                result = Int(arc4random_uniform(UInt32(bgMaxIndex)) + UInt32(bgMinIndex))
            } else {
                result = indicies.shuffled()[0]
            }
        } else {
            result = Int(arc4random_uniform(UInt32(bgMaxIndex)) + UInt32(bgMinIndex))
        }

        assert(result >= bgMinIndex)
        assert(result <= bgMaxIndex)
        assert(result - bgMinIndex < array.count)

        return result
    }

    func backgroundUploadProgress(for identifier: Identifier) -> Double? {
        let uuid = identifier.value
        let key = uploadBackgroundKeyPrefix + uuid
        return (UserDefaults.standard.object(forKey: key) as? NSNumber)?.doubleValue
    }

    func setBackgroundUploadProgress(percentage: Double, for identifier: Identifier) {
        let uuid = identifier.value
        let key = uploadBackgroundKeyPrefix + uuid
        let userInfoKey: BPDidUpdateBackgroundUploadProgressKey
        if identifier is LocalIdentifier {
            userInfoKey = .luid
        } else if identifier is MACIdentifier {
            userInfoKey = .macId
        } else {
            userInfoKey = .luid
            assertionFailure()
        }
        NotificationCenter
            .default
            .post(name: .BackgroundPersistenceDidUpdateBackgroundUploadProgress,
                  object: nil,
                  userInfo: [
                    userInfoKey: identifier,
                    BPDidUpdateBackgroundUploadProgressKey.progress: percentage
                  ])
        UserDefaults.standard.setValue(percentage, forKey: key)
    }

    func deleteBackgroundUploadProgress(for identifier: Identifier) {
        let uuid = identifier.value
        let key = uploadBackgroundKeyPrefix + uuid
        UserDefaults.standard.removeObject(forKey: key)
    }

    func isPictureCached(for cloudSensor: CloudSensor) -> Bool {
        guard let url = cloudSensor.picture else { return false }
        return UserDefaults.standard.url(
            forKey: cloudSensorPictureUrlPrefix + cloudSensor.id
        ) == url
    }

    func setPictureIsCached(for cloudSensor: CloudSensor) {
        UserDefaults.standard.set(
            cloudSensor.picture,
            forKey: cloudSensorPictureUrlPrefix + cloudSensor.id
        )
    }

    func setPictureRemovedFromCache(for ruuviTag: RuuviTagSensor) {
        UserDefaults.standard.set(
            nil,
            forKey: cloudSensorPictureUrlPrefix + ruuviTag.id
        )
    }
}
