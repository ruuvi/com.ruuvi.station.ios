import UIKit
import Future

class BackgroundPersistenceUserDefaults: BackgroundPersistence {

    var imagePersistence: ImagePersistence!

    private let bgMinIndex = 1 // must be > 0, 0 means custom background
    private let bgMaxIndex = 9

    private let usedBackgroundsUDKey = "BackgroundPersistenceUserDefaults.background.usedBackgroundsUDKey"
    private let bgUDKeyPrefix = "BackgroundPersistenceUserDefaults.background."

    private var usedBackgrounds: [Int] {
        if let ub = UserDefaults.standard.array(forKey: usedBackgroundsUDKey) as? [Int] {
            return ub
        } else {
            let ub = Array(repeating: 0, count: bgMaxIndex - bgMinIndex + 1)
            UserDefaults.standard.set(ub, forKey: usedBackgroundsUDKey)
            return ub
        }
    }

    func deleteCustomBackground(for luid: LocalIdentifier) {
        imagePersistence.deleteBgIfExists(for: luid)
    }

    func setNextDefaultBackground(for luid: LocalIdentifier) -> UIImage? {
        var id = backgroundId(for: luid)
        if id >= bgMinIndex && id < bgMaxIndex {
            id += 1
            setBackground(id, for: luid)
        } else if id >= bgMaxIndex {
            id = bgMinIndex
            setBackground(id, for: luid)
        } else {
            id = biasedToNotUsedRandom()
            setBackground(id, for: luid)
        }
        imagePersistence.deleteBgIfExists(for: luid)
        return UIImage(named: "bg\(id)")
    }

    func background(for luid: LocalIdentifier) -> UIImage? {
        var id = backgroundId(for: luid)
        if id >= bgMinIndex && id <= bgMaxIndex {
            return UIImage(named: "bg\(id)")
        } else {
            if let custom = imagePersistence.fetchBg(for: luid) {
                return custom
            } else {
                id = biasedToNotUsedRandom()
                setBackground(id, for: luid)
                return UIImage(named: "bg\(id)")
            }
        }
    }

    func setCustomBackground(image: UIImage, for luid: LocalIdentifier) -> Future<URL, RUError> {
        let promise = Promise<URL, RUError>()
        let persist = imagePersistence.persistBg(image: image, for: luid)
        persist.on(success: { url in
            self.setBackground(0, for: luid)
            NotificationCenter
                .default
                .post(name: .BackgroundPersistenceDidChangeBackground,
                      object: nil,
                      userInfo: [BPDidChangeBackgroundKey.luid: luid ])
            promise.succeed(value: url)
        }, failure: { (error) in
            promise.fail(error: error)
        })
        return promise.future
    }

    func setBackground(_ id: Int, for luid: LocalIdentifier) {
        let uuid = luid.value
        let key = bgUDKeyPrefix + uuid
        UserDefaults.standard.set(id, forKey: key)
        UserDefaults.standard.synchronize()
        NotificationCenter
            .default
            .post(name: .BackgroundPersistenceDidChangeBackground,
                  object: nil,
                  userInfo: [BPDidChangeBackgroundKey.luid: luid ])
        if id >= bgMinIndex && id <= bgMaxIndex {
            var array = usedBackgrounds
            array[id - bgMinIndex] += 1
            UserDefaults.standard.set(array, forKey: usedBackgroundsUDKey)
        }
    }

    private func backgroundId(for luid: LocalIdentifier) -> Int {
        let uuid = luid.value
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
}
