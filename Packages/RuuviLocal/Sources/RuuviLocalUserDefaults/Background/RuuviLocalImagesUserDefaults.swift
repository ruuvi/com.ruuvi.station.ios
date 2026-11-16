import Future
import RuuviOntology
import UIKit

final class RuuviLocalImagesUserDefaults: RuuviLocalImages {
    init(imagePersistence: ImagePersistence) {
        self.imagePersistence = imagePersistence
    }

    private let writeLock = NSLock()
    private struct PendingWrite {
        let generation: UUID
        let isDownload: Bool
    }
    private var pendingWrites: [String: PendingWrite] = [:]

    func isBackgroundWritePending(for identifier: Identifier) -> Bool {
        writeLock.lock()
        defer { writeLock.unlock() }
        return pendingWrites[identifier.value]?.isDownload == false
    }

    private let imagePersistence: ImagePersistence
    private let bgMinIndex = 1 // must be > 0, 0 means custom background
    private let bgMaxIndex = 17
    // The images of index 16 will be used for default background for RuuviTag.
    private let bgIndexDefaultRuuviTag = 16
    // The images of index 17 will be used for default background for RuuviAur.
    private let bgIndexDefaultRuuviAir = 17

    private let usedBackgroundsUDKey = "BackgroundPersistenceUserDefaults.background.usedBackgroundsUDKey"
    private let bgUDKeyPrefix = "BackgroundPersistenceUserDefaults.background."

    private let uploadBackgroundKeyPrefix = "BackgroundPersistenceUserDefaults.uploadBackground."

    private var usedBackgrounds: [Int] {
        if let ub = UserDefaults.standard.array(forKey: usedBackgroundsUDKey) as? [Int],
           ub.count == bgMaxIndex {
            return ub
        } else {
            let ub = Array(repeating: 0, count: bgMaxIndex - bgMinIndex + 1)
            UserDefaults.standard.set(ub, forKey: usedBackgroundsUDKey)
            return ub
        }
    }

    func deleteCustomBackground(for identifier: Identifier) {
        let hadImage = hasCustomBackground(for: identifier)
        writeLock.lock()
        pendingWrites.removeValue(forKey: identifier.value)
        writeLock.unlock()
        var record = BackgroundImageRecord(for: identifier)
        let previous = record.file
        record.file = nil
        record.selectedAt = nil
        record.cachedURL = nil
        record.forced = false
        record.retiredThrough = Date()
        record.save(for: identifier)
        retireFile(previous)
        if hadImage { notifyBackgroundChanged(for: identifier) }
    }

    private func retireFile(_ file: String?) {
        guard let file else { return }
        DispatchQueue.global(qos: .utility).async {
            // Retain the previous file until the new pointer is durable. A crash can then
            // restore either complete version, never an old image with a new date.
            if UserDefaults.standard.synchronize() {
                self.imagePersistence.deleteBgIfExists(for: file.luid)
            }
        }
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
        deleteCustomBackground(for: identifier)
        return UIImage(named: "bg\(id)")
    }

    func getBackground(for identifier: Identifier) -> UIImage? {
        let id = backgroundId(for: identifier)
        if id >= bgMinIndex, id <= bgMaxIndex {
            return UIImage(named: "bg\(id)")
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
            return UIImage(named: "bg\(id)")
        } else {
            if let custom = getCustomBackground(for: identifier) {
                return custom
            } else {
                let bgIndexDefault: Int =
                    ruuviDeviceType == .ruuviTag ? bgIndexDefaultRuuviTag : bgIndexDefaultRuuviAir
                setBackground(bgIndexDefault, for: identifier)
                return UIImage(named: "bg\(bgIndexDefault)")
            }
        }
    }

    func setBackground(_ id: Int, for identifier: Identifier) {
        let uuid = identifier.value
        let key = bgUDKeyPrefix + uuid
        UserDefaults.standard.set(id, forKey: key)
        notifyBackgroundChanged(for: identifier)
        if id >= bgMinIndex, id <= bgMaxIndex {
            var array = usedBackgrounds
            array[id - bgMinIndex] += 1
            UserDefaults.standard.set(array, forKey: usedBackgroundsUDKey)
        }
    }

    private func notifyBackgroundChanged(for identifier: Identifier) {
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
            .post(
                name: .BackgroundPersistenceDidChangeBackground,
                object: nil,
                userInfo: [userInfoKey: identifier]
            )
    }

    private func backgroundId(for identifier: Identifier) -> Int {
        let uuid = identifier.value
        let key = bgUDKeyPrefix + uuid
        let id = UserDefaults.standard.integer(forKey: key)
        return id
    }

    // swiftlint:disable legacy_random
    private func biasedToNotUsedRandom() -> Int {
        let array = usedBackgrounds
        var result: Int
        if let min = array.min() {
            let indicies = array.enumerated().compactMap { $1 == min ? $0 + bgMinIndex : nil }
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

    // swiftlint:enable legacy_random

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
            .post(
                name: .BackgroundPersistenceDidUpdateBackgroundUploadProgress,
                object: nil,
                userInfo: [
                    userInfoKey: identifier,
                    BPDidUpdateBackgroundUploadProgressKey.progress: percentage,
                ]
            )
        UserDefaults.standard.setValue(percentage, forKey: key)
    }

    func deleteBackgroundUploadProgress(for identifier: Identifier) {
        let uuid = identifier.value
        let key = uploadBackgroundKeyPrefix + uuid
        UserDefaults.standard.removeObject(forKey: key)
    }

    func cachedPictureURL(for identifier: Identifier) -> URL? {
        BackgroundImageRecord(for: identifier).cachedURL
    }

    func setCachedPictureURL(_ url: URL?, for identifier: Identifier) {
        var record = BackgroundImageRecord(for: identifier)
        record.cachedURL = url
        record.save(for: identifier)
    }

    func isBackgroundUploadForced(for identifier: Identifier) -> Bool {
        BackgroundImageRecord(for: identifier).forced
    }

    func setBackgroundUploadForced(_ forced: Bool, for identifier: Identifier) {
        var record = BackgroundImageRecord(for: identifier)
        record.forced = forced
        record.save(for: identifier)
    }

    func isPictureCached(for cloudSensor: CloudSensor) -> Bool {
        let identifier = cloudSensor.id.mac
        return customBackgroundLastUpdated(for: identifier) == nil
            && getCustomBackground(for: identifier) != nil
            && matchesCachedPicture(cloudSensor.picture, for: identifier)
    }

    func setPictureIsCached(for cloudSensor: CloudSensor) {
        setCustomBackgroundLastUpdated(nil, for: cloudSensor.id.mac)
        setBackgroundUploadForced(false, for: cloudSensor.id.mac)
        setCachedPictureURL(cloudSensor.picture, for: cloudSensor.id.mac)
    }

    func setPictureRemovedFromCache(for ruuviTag: RuuviTagSensor) {
        // Remove local cache
        if let macId = ruuviTag.macId {
            UserDefaults.standard.set(
                nil,
                forKey: bgUDKeyPrefix + macId.value
            )
        }
        if let luid = ruuviTag.luid {
            UserDefaults.standard.set(
                nil,
                forKey: bgUDKeyPrefix + luid.value
            )
        }

        // Remove cloud cache
        for identifier in [ruuviTag.macId as Identifier?, ruuviTag.luid as Identifier?].compactMap({ $0 }) {
            setCachedPictureURL(nil, for: identifier)
        }
    }
}

// MARK: - Versioned custom images
extension RuuviLocalImagesUserDefaults {
    func customBackgroundLastUpdated(for identifier: Identifier) -> Date? {
        BackgroundImageRecord(for: identifier).selectedAt
    }

    func setCustomBackgroundLastUpdated(_ date: Date?, for identifier: Identifier) {
        var record = BackgroundImageRecord(for: identifier)
        record.selectedAt = date
        record.save(for: identifier)
    }

    func backgroundUploadRetiredThrough(for identifier: Identifier) -> Date? {
        BackgroundImageRecord(for: identifier).retiredThrough
    }

    func acknowledgeBackgroundUpload(_ url: URL, selectedAt: Date, for identifier: Identifier) {
        var record = BackgroundImageRecord(for: identifier)
        guard let current = record.selectedAt, abs(current.timeIntervalSince(selectedAt)) < 0.001 else { return }
        record.cachedURL = url
        record.selectedAt = nil
        record.forced = false
        record.retiredThrough = max(record.retiredThrough ?? .distantPast, selectedAt)
        record.save(for: identifier)
    }

    func hasCustomBackground(for identifier: Identifier) -> Bool {
        guard let file = BackgroundImageRecord(for: identifier).file else { return false }
        return imagePersistence.hasBg(for: file.luid)
    }

    func getCustomBackground(for identifier: Identifier) -> UIImage? {
        guard let file = BackgroundImageRecord(for: identifier).file else { return nil }
        return imagePersistence.fetchBg(for: file.luid)
    }

    func backgroundUploadData(for identifier: Identifier) -> Future<Data, RuuviLocalError> {
        let result = Promise<Data, RuuviLocalError>()
        let file = BackgroundImageRecord(for: identifier).file
        DispatchQueue.global(qos: .utility).async {
            do {
                guard let file else { throw RuuviLocalError.backgroundSuperseded }
                result.succeed(value: try self.imagePersistence.fetchBgData(for: file.luid))
            } catch {
                result.fail(error: .disk(error))
            }
        }
        return result.future
    }

    func setUserSelectedBackground(
        image: UIImage, compressionQuality: CGFloat, selectedAt: Date, for identifier: Identifier
    ) -> Future<URL, RuuviLocalError> {
        persist(image: image, quality: compressionQuality, selectedAt: selectedAt, for: identifier)
    }

    func setCustomBackground(
        image: UIImage, compressionQuality: CGFloat, for identifier: Identifier
    ) -> Future<URL, RuuviLocalError> {
        persist(image: image, quality: compressionQuality, selectedAt: nil, for: identifier)
    }

    func setDownloadedBackground(
        image: UIImage, from url: URL, for identifier: Identifier, canPublish: @escaping () -> Bool
    ) -> Future<URL, RuuviLocalError> {
        persist(image: image, quality: 1, selectedAt: nil, cachedURL: url, for: identifier, canPublish: canPublish)
    }

    private func persist(
        image: UIImage, quality: CGFloat, selectedAt: Date?, cachedURL: URL? = nil,
        for identifier: Identifier, canPublish: @escaping () -> Bool = { true }
    ) -> Future<URL, RuuviLocalError> {
        let result = Promise<URL, RuuviLocalError>()
        let generation = UUID()
        let file = "image-" + generation.uuidString
        writeLock.lock()
        pendingWrites[identifier.value] = PendingWrite(generation: generation, isDownload: cachedURL != nil)
        writeLock.unlock()
        imagePersistence.persistBg(image: image, compressionQuality: quality, for: file.luid)
            .observe(on: .main)
            .on(success: { url in
                self.writeLock.lock()
                let current = self.pendingWrites[identifier.value]?.generation == generation
                if current { self.pendingWrites.removeValue(forKey: identifier.value) }
                self.writeLock.unlock()
                guard current, canPublish() else {
                    self.imagePersistence.deleteBgIfExists(for: file.luid)
                    result.fail(error: .backgroundSuperseded)
                    return
                }
                var record = BackgroundImageRecord(for: identifier)
                let previous = record.file
                record.file = file
                record.selectedAt = selectedAt
                record.forced = false
                if let cachedURL { record.cachedURL = cachedURL }
                record.save(for: identifier)
                self.setBackground(0, for: identifier)
                self.retireFile(previous)
                result.succeed(value: url)
            }, failure: { error in
                self.writeLock.lock()
                if self.pendingWrites[identifier.value]?.generation == generation {
                    self.pendingWrites.removeValue(forKey: identifier.value)
                }
                self.writeLock.unlock()
                result.fail(error: error)
            })
        return result.future
    }

}
