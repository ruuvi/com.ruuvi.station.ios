import UIKit

class BackgroundPersistenceUserDefaults: BackgroundPersistence {
    
    private let usedBackgroundsUDKey = "BackgroundPersistenceUserDefaults.background.usedBackgroundsUDKey"
    let bgMinIndex = 1 // must be > 0
    let bgMaxIndex = 9
    
    private var usedBackgrounds: [Int] {
        if let usedBackgrounds = UserDefaults.standard.array(forKey: usedBackgroundsUDKey) as? [Int] {
            return usedBackgrounds
        } else {
            let usedBackgrounds = Array(repeating: 0, count: bgMaxIndex - bgMinIndex + 1)
            UserDefaults.standard.set(usedBackgrounds, forKey: usedBackgroundsUDKey)
            return usedBackgrounds
        }
    }
    
    func background(for uuid: String) -> UIImage? {
        let key = "BackgroundPersistenceUserDefaults.background." + uuid
        var id = UserDefaults.standard.integer(forKey: key)
        if id >= bgMinIndex  {
            return UIImage(named: "bg\(id)")
        } else {
            id = biasedToNotUsedRandom()
            UserDefaults.standard.set(id, forKey: key)
            return UIImage(named: "bg\(id)")
        }
    }
    
    func setBackground(_ id: Int, for uuid: String) {
        let key = "BackgroundPersistenceUserDefaults.background." + uuid
        UserDefaults.standard.set(id, forKey: key)
    }
    
    func biasedToNotUsedRandom() -> Int {
        var array = usedBackgrounds
        var result: Int
        if let min = array.min() {
            let indicies = array.enumerated().compactMap({ $1 == min ? $0 : nil })
            if indicies.count == 0 {
                result = Int(arc4random_uniform(UInt32(bgMaxIndex)) + UInt32(bgMinIndex))
            } else {
                result = indicies.shuffled()[0]
            }
        } else {
            result = Int(arc4random_uniform(UInt32(bgMaxIndex)) + UInt32(bgMinIndex))
        }
        array[result] += 1
        UserDefaults.standard.set(array, forKey: usedBackgroundsUDKey)
        return result
    }
}
