import UIKit

class BackgroundPersistenceUserDefaults: BackgroundPersistence {
    
    func background(for uuid: String) -> UIImage? {
        let key = "BackgroundPersistenceUserDefaults.background." + uuid
        var id = UserDefaults.standard.integer(forKey: key)
        if id > 0 {
            return UIImage(named: "bg\(id)")
        } else {
            id = Int(arc4random_uniform(9) + 1)
            UserDefaults.standard.set(id, forKey: key)
            return UIImage(named: "bg\(id)")
        }
    }
    
}
