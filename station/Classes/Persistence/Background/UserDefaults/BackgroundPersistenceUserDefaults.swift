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

    func background(for identifier: Identifier) -> UIImage? {
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

    func setCustomBackground(image: UIImage, for identifier: Identifier) -> Future<URL, RUError> {
        let promise = Promise<URL, RUError>()
        let persist = imagePersistence.persistBg(image: image, for: identifier)
        persist.on(success: { url in
            self.setBackground(0, for: identifier)
            let userInfo = identifier is LocalIdentifier ? [BPDidChangeBackgroundKey.luid: identifier] : [BPDidChangeBackgroundKey.macId: identifier]
            NotificationCenter
                .default
                .post(name: .BackgroundPersistenceDidChangeBackground,
                      object: nil,
                      userInfo: userInfo)
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
        let userInfo = identifier is LocalIdentifier ? [BPDidChangeBackgroundKey.luid: identifier] : [BPDidChangeBackgroundKey.macId: identifier]
        NotificationCenter
            .default
            .post(name: .BackgroundPersistenceDidChangeBackground,
                  object: nil,
                  userInfo: userInfo)
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
}
