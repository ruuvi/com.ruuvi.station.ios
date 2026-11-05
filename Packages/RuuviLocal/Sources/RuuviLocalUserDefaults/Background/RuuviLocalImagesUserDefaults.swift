#if SWIFT_PACKAGE
    import RuuviLocal
#endif
import RuuviOntology
import UIKit

final class RuuviLocalImagesUserDefaults: RuuviLocalImages {
    init(
        imagePersistence: ImagePersistence,
        defaults: UserDefaults = .standard,
        notifications: NotificationCenter = .default,
        imageNamed: @escaping (String) -> UIImage? = { UIImage(named: $0) }
    ) {
        self.imagePersistence = imagePersistence
        self.defaults = defaults
        self.notifications = notifications
        self.imageNamed = imageNamed
    }

    private let imagePersistence: ImagePersistence
    private let defaults: UserDefaults
    private let notifications: NotificationCenter
    private let imageNamed: (String) -> UIImage?
    private let bgMinIndex = 1  // must be > 0, 0 means custom background
    private let bgMaxIndex = 17
    // The images of index 16 will be used for default background for RuuviTag.
    private let bgIndexDefaultRuuviTag = 16
    // The images of index 17 will be used for default background for RuuviAur.
    private let bgIndexDefaultRuuviAir = 17

    private let usedBackgroundsUDKey = "BackgroundPersistenceUserDefaults.background.usedBackgroundsUDKey"
    private let bgUDKeyPrefix = "BackgroundPersistenceUserDefaults.background."

    private let uploadBackgroundKeyPrefix = "BackgroundPersistenceUserDefaults.uploadBackground."
    private let cloudSensorPictureUrlPrefix = "SensorServiceImpl.backgroundUrlPrefix"

    private var usedBackgrounds: [Int] {
        if let ub = defaults.array(forKey: usedBackgroundsUDKey) as? [Int],
            ub.count == bgMaxIndex, ub.allSatisfy({ $0 >= 0 })
        {
            return ub
        } else {
            let ub = Array(repeating: 0, count: bgMaxIndex - bgMinIndex + 1)
            defaults.set(ub, forKey: usedBackgroundsUDKey)
            return ub
        }
    }

    func deleteCustomBackground(for identifier: Identifier) {
        imagePersistence.deleteBgIfExists(for: identifier)
    }

    func setNextDefaultBackground(for identifier: Identifier) -> UIImage? {
        var id = backgroundId(for: identifier)
        if id >= bgMinIndex, id < bgMaxIndex {
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
        return imageNamed("bg\(id)")
    }

    func getCustomBackground(for identifier: Identifier) -> UIImage? {
        imagePersistence.fetchBg(for: identifier)
    }

    func getBackground(for identifier: Identifier) -> UIImage? {
        let id = backgroundId(for: identifier)
        if id >= bgMinIndex, id <= bgMaxIndex {
            return imageNamed("bg\(id)")
        } else {
            return getCustomBackground(for: identifier)
        }
    }

    func getOrGenerateBackground(
        for identifier: Identifier,
        ruuviDeviceType: RuuviDeviceType
    ) -> UIImage? {
        let id = backgroundId(for: identifier)
        if id >= bgMinIndex, id <= bgMaxIndex {
            return imageNamed("bg\(id)")
        } else {
            if let custom = getCustomBackground(for: identifier) {
                return custom
            } else {
                let bgIndexDefault: Int =
                    ruuviDeviceType == .ruuviTag ? bgIndexDefaultRuuviTag : bgIndexDefaultRuuviAir
                setBackground(bgIndexDefault, for: identifier)
                return imageNamed("bg\(bgIndexDefault)")
            }
        }
    }

    @MainActor
    func setCustomBackground(
        image: UIImage,
        compressionQuality: CGFloat,
        for identifier: Identifier
    ) async throws(RuuviLocalError) -> URL {
        let url = try await imagePersistence.persistBg(
            image: image,
            compressionQuality: compressionQuality,
            for: identifier
        )
        // setBackground publishes the change once, after the file is durable.
        setBackground(0, for: identifier)
        return url
    }

    func setBackground(_ id: Int, for identifier: Identifier) {
        let uuid = identifier.value
        let key = bgUDKeyPrefix + uuid
        defaults.set(id, forKey: key)
        if id >= bgMinIndex, id <= bgMaxIndex {
            var array = usedBackgrounds
            if array[id - bgMinIndex] < Int.max { array[id - bgMinIndex] += 1 }
            defaults.set(array, forKey: usedBackgroundsUDKey)
        }
        let userInfoKey: BPDidChangeBackgroundKey
        if identifier is LocalIdentifier {
            userInfoKey = .luid
        } else if identifier is MACIdentifier {
            userInfoKey = .macId
        } else {
            userInfoKey = .luid
            assertionFailure()
        }
        notifications.post(
            name: .BackgroundPersistenceDidChangeBackground,
            object: nil,
            userInfo: [userInfoKey: identifier]
        )
    }

    private func backgroundId(for identifier: Identifier) -> Int {
        let uuid = identifier.value
        let key = bgUDKeyPrefix + uuid
        let id = defaults.integer(forKey: key)
        return id
    }

    private func biasedToNotUsedRandom() -> Int {
        let array = usedBackgrounds
        // usedBackgrounds always contains one valid counter for each built-in image.
        let minimum = array.dropFirst().reduce(array[0], min)
        let indices = array.enumerated().compactMap { $1 == minimum ? $0 + bgMinIndex : nil }
        return indices[Int.random(in: indices.indices)]
    }

    func backgroundUploadProgress(for identifier: Identifier) -> Double? {
        let uuid = identifier.value
        let key = uploadBackgroundKeyPrefix + uuid
        return (defaults.object(forKey: key) as? NSNumber)?.doubleValue
    }

    func setBackgroundUploadProgress(percentage: Double, for identifier: Identifier) {
        let uuid = identifier.value
        let key = uploadBackgroundKeyPrefix + uuid
        defaults.set(percentage, forKey: key)
        let userInfoKey: BPDidUpdateBackgroundUploadProgressKey
        if identifier is LocalIdentifier {
            userInfoKey = .luid
        } else if identifier is MACIdentifier {
            userInfoKey = .macId
        } else {
            userInfoKey = .luid
            assertionFailure()
        }
        notifications.post(
            name: .BackgroundPersistenceDidUpdateBackgroundUploadProgress,
            object: nil,
            userInfo: [
                userInfoKey: identifier,
                BPDidUpdateBackgroundUploadProgressKey.progress: percentage,
            ]
        )
    }

    func deleteBackgroundUploadProgress(for identifier: Identifier) {
        let uuid = identifier.value
        let key = uploadBackgroundKeyPrefix + uuid
        defaults.removeObject(forKey: key)
    }

    func isPictureCached(for cloudSensor: CloudSensor) -> Bool {
        guard let url = cloudSensor.picture,
            let cachedUrl = defaults.url(
                forKey: cloudSensorPictureUrlPrefix + cloudSensor.id
            )
        else {
            return false
        }

        if let fileName = pictureFileName(from: url),
            let cachedFileName = pictureFileName(from: cachedUrl)
        {
            return fileName == cachedFileName
        }

        return cachedUrl == url
    }

    private func pictureFileName(from url: URL) -> String? {
        let fileName = url.lastPathComponent
        guard !fileName.isEmpty,
            !url.pathExtension.isEmpty
        else {
            return nil
        }
        return fileName
    }

    func setPictureIsCached(for cloudSensor: CloudSensor) {
        defaults.set(
            cloudSensor.picture,
            forKey: cloudSensorPictureUrlPrefix + cloudSensor.id
        )
    }

    func setPictureRemovedFromCache(for ruuviTag: RuuviTagSensor) {
        // Remove local cache
        if let macId = ruuviTag.macId {
            defaults.set(
                nil,
                forKey: bgUDKeyPrefix + macId.value
            )
        }
        if let luid = ruuviTag.luid {
            defaults.set(
                nil,
                forKey: bgUDKeyPrefix + luid.value
            )
        }

        // Remove cloud cache
        defaults.set(
            nil,
            forKey: cloudSensorPictureUrlPrefix + ruuviTag.id
        )
    }
}
