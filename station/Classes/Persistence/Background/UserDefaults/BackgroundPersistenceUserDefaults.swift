import UIKit
import Future

class BackgroundPersistenceUserDefaults: BackgroundPersistence {
    
    var imagePersistence: ImagePersistence!
    
    private let bgMinIndex = 1 // must be > 0, 0 means custom background
    private let bgMaxIndex = 9
    
    private let usedBackgroundsUDKey = "BackgroundPersistenceUserDefaults.background.usedBackgroundsUDKey"
    private let bgUDKeyPrefix = "BackgroundPersistenceUserDefaults.background."
    
    private var usedBackgrounds: [Int] {
        if let usedBackgrounds = UserDefaults.standard.array(forKey: usedBackgroundsUDKey) as? [Int] {
            return usedBackgrounds
        } else {
            let usedBackgrounds = Array(repeating: 0, count: bgMaxIndex - bgMinIndex + 1)
            UserDefaults.standard.set(usedBackgrounds, forKey: usedBackgroundsUDKey)
            return usedBackgrounds
        }
    }
    
    func setNextDefaultBackground(for uuid: String) -> UIImage? {
        var id = backgroundId(for: uuid)
        if id >= bgMinIndex && id < bgMaxIndex {
            id += 1
            setBackground(id, for: uuid)
        } else if id >= bgMaxIndex {
            id = bgMinIndex
            setBackground(id, for: uuid)
        } else {
            id = biasedToNotUsedRandom()
            setBackground(id, for: uuid)
        }
        imagePersistence.deleteBgIfExists(for: uuid)
        return UIImage(named: "bg\(id)")
    }
    
    func background(for uuid: String) -> UIImage? {
        var id = backgroundId(for: uuid)
        if id >= bgMinIndex && id <= bgMaxIndex {
            return UIImage(named: "bg\(id)")
        } else {
            if let custom = imagePersistence.fetchBg(for: uuid) {
                return custom
            } else {
                id = biasedToNotUsedRandom()
                setBackground(id, for: uuid)
                return UIImage(named: "bg\(id)")
            }
        }
    }
    
    func setCustomBackground(image: UIImage, for uuid: String) -> Future<URL,RUError> {
        let promise = Promise<URL,RUError>()
        let persist = imagePersistence.persistBg(image: image, for: uuid)
        persist.on(success: { url in
            self.setBackground(0, for: uuid)
            NotificationCenter.default.post(name: .BackgroundPersistenceDidChangeBackground, object: nil, userInfo: [BackgroundPersistenceDidChangeBackgroundKey.uuid: uuid ])
            promise.succeed(value: url)
        }, failure: { (error) in
            promise.fail(error: error)
        })
        return promise.future
    }
    
    func setBackground(_ id: Int, for uuid: String) {
        let key = bgUDKeyPrefix + uuid
        UserDefaults.standard.set(id, forKey: key)
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .BackgroundPersistenceDidChangeBackground, object: nil, userInfo: [BackgroundPersistenceDidChangeBackgroundKey.uuid: uuid ])
        if id >= bgMinIndex && id <= bgMaxIndex {
            var array = usedBackgrounds
            array[id - bgMinIndex] += 1
            UserDefaults.standard.set(array, forKey: usedBackgroundsUDKey)
        }
    }
    
    private func backgroundId(for uuid: String) -> Int {
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
