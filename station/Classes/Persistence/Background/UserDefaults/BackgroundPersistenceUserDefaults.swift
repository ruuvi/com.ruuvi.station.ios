import UIKit

class BackgroundPersistenceUserDefaults: BackgroundPersistence {
    
    let bgMinIndex = 1 // must be > 0
    let bgMaxIndex = 9
    
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
    
    func setNextBackground(for uuid: String) -> UIImage? {
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
        return UIImage(named: "bg\(id)")
    }
    
    func background(for uuid: String) -> UIImage? {
        var id = backgroundId(for: uuid)
        if id >= bgMinIndex && id <= bgMaxIndex {
            return UIImage(named: "bg\(id)")
        } else {
            id = biasedToNotUsedRandom()
            setBackground(id, for: uuid)
            return UIImage(named: "bg\(id)")
        }
    }
    
    func backgroundId(for uuid: String) -> Int {
        let key = bgUDKeyPrefix + uuid
        let id = UserDefaults.standard.integer(forKey: key)
        return id
    }
    
    func setBackground(_ id: Int, for uuid: String) {
        let key = bgUDKeyPrefix + uuid
        UserDefaults.standard.set(id, forKey: key)
        NotificationCenter.default.post(name: .BackgroundPersistenceDidChangeBackground, object: nil, userInfo: [BackgroundPersistenceDidChangeBackgroundKey.uuid: uuid ])
        if id >= bgMinIndex && id <= bgMaxIndex {
            var array = usedBackgrounds
            array[id - bgMinIndex] += 1
            UserDefaults.standard.set(array, forKey: usedBackgroundsUDKey)
        }
    }
    
    func biasedToNotUsedRandom() -> Int {
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
