import Foundation

enum KeyedArchiver {
    static func archive(object: Any) -> Data? {
        if #available(iOS 12.0, *) {
            try? NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: false)
        } else {
            NSKeyedArchiver.archivedData(withRootObject: object)
        }
    }

    static func unarchive<T: Any>(_ data: Data, with _: T.Type) -> T? {
        if #available(iOS 12.0, *) {
            return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? T
        } else {
            return NSKeyedUnarchiver.unarchiveObject(with: data) as? T
        }
    }
}
